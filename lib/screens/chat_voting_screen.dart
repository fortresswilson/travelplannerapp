import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import 'optimizer_and_budget_optimizer_screen.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ChatVotingScreen — Real-time group chat with activity voting
///
/// Navigation position:
///   Trip Lobby → Itinerary View → [Chat & Voting]  (via chat tab / FAB)
///
/// Firebase hooks (to be wired by Backend Lead):
///   - [_loadMessages]       → Firestore.collection('trips/{id}/messages').orderBy('ts').snapshots()
///   - [_sendMessage]        → Firestore.collection('trips/{id}/messages').add({...})
///   - [_castVote]           → Firestore.doc('trips/{id}/votes/{actId}').update({'votes.{uid}': emoji})
///   - [_loadVoteCards]      → Firestore.collection('trips/{id}/activities').where('status', isEqualTo: 'pending_vote')
///   - Presence / online     → Firebase Realtime Database presence pattern
///   - Push notifications    → FirebaseMessaging — new message badge
class ChatVotingScreen extends StatefulWidget {
  final String tripId;
  final String tripDestination;

  const ChatVotingScreen({
    super.key,
    this.tripId = 't1',
    this.tripDestination = 'Bali, Indonesia',
  });

  @override
  State<ChatVotingScreen> createState() => _ChatVotingScreenState();
}

class _ChatVotingScreenState extends State<ChatVotingScreen>
    with TickerProviderStateMixin {
  // ─── Controllers ─────────────────────────────────────────────────────────
  final _messageController = TextEditingController();
  final _scrollController  = ScrollController();
   final _chatService = ChatService();
  late final TabController _tabController;
  late final AnimationController _entryController;
  late final AnimationController _sendPulse;

  // ─── State ────────────────────────────────────────────────────────────────
  bool _isSending = false;
  String _typingText = '';

  // ─── Mock messages ────────────────────────────────────────────────────────
  final List<_ChatMessage> _messages = [
    _ChatMessage(id: 'm1', senderId: 'fortress', senderName: 'Fortress', senderEmoji: '🏕️',
        text: 'Hey team! Should we do the Bali Swing on Day 1?', ts: DateTime.now().subtract(const Duration(hours: 2)),
        type: MessageType.text, reactions: {'🔥': 2, '👍': 1}),
    _ChatMessage(id: 'm2', senderId: 'me', senderName: 'Vaish', senderEmoji: '🧳',
        text: 'Yes!! I\'ve been dying to do it 🎢', ts: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
        type: MessageType.text),
    _ChatMessage(id: 'm3', senderId: 'aashika', senderName: 'Aashika', senderEmoji: '🌸',
        text: 'Added it to Day 2 actually — it pairs nicely with Ubud cooking class nearby 🍜', ts: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        type: MessageType.text, reactions: {'❤️': 3}),
    _ChatMessage(id: 'm4', senderId: 'system', senderName: 'TropicaGuide', senderEmoji: '🌴',
        text: 'Vote opened: Kecak Fire Dance on Day 3 evening — cast your vote below!', ts: DateTime.now().subtract(const Duration(hours: 1)),
        type: MessageType.system),
    _ChatMessage(id: 'm5', senderId: 'fortress', senderName: 'Fortress', senderEmoji: '🏕️',
        text: 'Mount Batur hike is a MUST. 2am start though 😅', ts: DateTime.now().subtract(const Duration(minutes: 40)),
        type: MessageType.text, reactions: {'😅': 2, '💪': 1}),
    _ChatMessage(id: 'm6', senderId: 'me', senderName: 'Vaish', senderEmoji: '🧳',
        text: 'Budget check — we\'re at \$1,750 spent so far. Still good!', ts: DateTime.now().subtract(const Duration(minutes: 15)),
        type: MessageType.text),
  ];

  // ─── Mock vote cards ──────────────────────────────────────────────────────
  final List<_VoteCard> _voteCards = [
    _VoteCard(
      id: 'v1', activityName: 'Kecak Fire Dance', emoji: '🔥',
      description: 'Sunset Ramayana performance at Uluwatu Temple',
      cost: 15.0, duration: '1.5 hrs', day: 'Day 3',
      colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
      votes: {'fortress': '✅', 'aashika': '✅', 'me': '🤔'},
      totalMembers: 3,
    ),
    _VoteCard(
      id: 'v2', activityName: 'Seminyak Beach Club', emoji: '🏖️',
      description: 'Afternoon at a premium beach club with pool & cocktails',
      cost: 30.0, duration: '3 hrs', day: 'Day 2',
      colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
      votes: {'fortress': '❌', 'me': '✅'},
      totalMembers: 3,
    ),
  ];

  static const _quickReactions = ['👍', '❤️', '🔥', '😂', '😅', '💪', '✅', '❌'];
  static const _quickReplies   = ['Sounds great! 🙌', 'Let\'s vote!', 'Check the budget', 'Add to itinerary'];

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController  = TabController(length: 2, vsync: this);
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _sendPulse      = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
     _chatService.setupFCM(widget.tripId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _entryController.dispose();
    _sendPulse.dispose();
    super.dispose();
  }

  // ─── Handlers ────────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
  final text = _messageController.text;
  if (text.trim().isEmpty) return;
  _messageController.clear();
  await _chatService.sendMessage(tripId: widget.tripId, text: text);
  await _chatService.setTyping(widget.tripId, false);
}

  void _addReaction(String messageId, String emoji) {
    HapticFeedback.selectionClick();
    setState(() {
      final msg = _messages.firstWhere((m) => m.id == messageId);
      final updated = Map<String, int>.from(msg.reactions ?? {});
      updated[emoji] = (updated[emoji] ?? 0) + 1;
      final idx = _messages.indexOf(msg);
      _messages[idx] = _ChatMessage(
        id: msg.id, senderId: msg.senderId, senderName: msg.senderName,
        senderEmoji: msg.senderEmoji, text: msg.text, ts: msg.ts,
        type: msg.type, reactions: updated,
      );
    });
    // TODO (Backend): Firestore.doc('trips/${widget.tripId}/messages/${messageId}').update({'reactions.$emoji': FieldValue.increment(1)})
  }

  void _castVote(String voteCardId, String emoji) async {
  await _chatService.castVote(
    tripId: widget.tripId,
    activityId: voteCardId,
    voteEmoji: emoji,
  );
}
  void _showReactionPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReactionPicker(
        reactions: _quickReactions,
        onSelect: (emoji) { Navigator.pop(context); _addReaction(messageId, emoji); },
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tabs: [
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  const SizedBox(width: 6),
                  const Text('Group Chat'),
                  if (_messages.any((m) => m.senderId != 'me' && m.senderId != 'system'))
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                      child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                ])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.how_to_vote_rounded, size: 15),
                  const SizedBox(width: 6),
                  const Text('Vote'),
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_voteCards.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ])),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab(),
                _buildVotingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Chat & Vote', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        Text(widget.tripDestination, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
      ]),
      actions: [
        // Online members indicator
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text('3 online', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ─── Chat tab ────────────────────────────────────────────────────────────
  Widget _buildChatTab() {
    return Column(
      children: [
        // Online member avatars
        _buildOnlineBar(),

        // Messages
       Expanded(
  child: StreamBuilder<List<MessageModel>>(
    stream: _chatService.messagesStream(widget.tripId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final messages = snapshot.data!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        physics: const BouncingScrollPhysics(),
        itemCount: messages.length,
        itemBuilder: (_, i) => _buildMessageBubble(messages[i], i),
      );
    },
  ),
), // Expanded
        

        // Quick replies
        _buildQuickReplies(),

        // Input bar
        _buildInputBar(),
      ],
    );
  }

  Widget _buildOnlineBar() {
    final onlineMembers = [
      ('🧳', 'Vaish'),
      ('🏕️', 'Fortress'),
      ('🌸', 'Aashika'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ...onlineMembers.map((m) => Container(
            margin: const EdgeInsets.only(right: 12),
            child: Column(children: [
              Stack(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(m.$1, style: const TextStyle(fontSize: 18))),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 11, height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Text(m.$2, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ]),
          )),
          const Spacer(),
          Text('All active', style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, int i) {
   final isMe = msg.senderId == FirebaseAuth.instance.currentUser?.uid;
    final isSystem = msg.type == MessageType.system;

    if (isSystem) {
     return _SystemMessage(message: msg.text);
    }

    
  final showDate = i == 0 || msg.ts == null;

    return Column(
      children: [
   if (showDate) _buildDateSeparator(msg.ts!),
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => _showReactionPicker(msg.id),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name (for others)
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 44, bottom: 3),
                    child: Text(msg.senderName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Avatar (others only)
                    if (!isMe) ...[
                      Container(
                        width: 34, height: 34,
                        margin: const EdgeInsets.only(right: 8, bottom: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                       child: Center(child: Text('👤', style: const TextStyle(fontSize: 16))),
                      ),
                    ],

                    // Bubble
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isMe ? const LinearGradient(
                          colors: [AppColors.gradientStart, AppColors.gradientEnd],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ) : null,
                        color: isMe ? null : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 14,
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),

                // Timestamp + reactions
                Padding(
                  padding: EdgeInsets.only(left: isMe ? 0 : 44, bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                       _formatTime(msg.ts ?? DateTime.now()),
                        style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                      ),
                      if (msg.reactions?.isNotEmpty == true) ...[
                        const SizedBox(width: 8),
                        ...(msg.reactions!.entries.map((e) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.inputBorder),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                          ),
                          child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 11)),
                        ))),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final today = DateTime.now();
    String label;
    if (date.day == today.day) label = 'Today';
    else if (date.day == today.day - 1) label = 'Yesterday';
    else label = '${date.day}/${date.month}/${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey.shade200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade200)),
      ]),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      color: AppColors.background,
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: _quickReplies.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () {
            _messageController.text = _quickReplies[i];
            setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.inputBorder),
            ),
            alignment: Alignment.center,
            child: Text(_quickReplies[i], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 14, right: 14, top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Row(children: [
        // Emoji / attachment
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26),
          onPressed: () {},
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),

        // Text input
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onChanged: (v) => setState(() => _typingText = v),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Message the group...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              if (_typingText.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: const Icon(Icons.sentiment_satisfied_alt_rounded, color: AppColors.textHint, size: 20),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 8),

        // Send button
        AnimatedBuilder(
          animation: _sendPulse,
          builder: (_, child) => Transform.scale(
            scale: 1.0 + _sendPulse.value * 0.1,
            child: child,
          ),
          child: GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Voting tab ───────────────────────────────────────────────────────────
  Widget _buildVotingTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            const Text('🗳️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Activity Votes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              Text('${_voteCards.length} open votes · Cast yours!', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),

        // Vote cards
        ..._voteCards.map((card) => _VoteCardWidget(
          card: card,
          onVote: (emoji) => _castVote(card.id, emoji),
        )),

        // Voting results summary
        const SizedBox(height: 8),
        _buildVotingSummary(),
      ],
    );
  }

  Widget _buildVotingSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Voting Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 12),
        const Text('Based on current votes, the optimizer will:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        _SummaryRow(icon: '✅', text: 'Add Kecak Fire Dance to Day 3 (2/3 yes)'),
        const SizedBox(height: 6),
        _SummaryRow(icon: '⏳', text: 'Kecak Dance awaiting Aashika\'s vote'),
        const SizedBox(height: 6),
        _SummaryRow(icon: '❌', text: 'Beach Club leaning rejected (1/3 yes)'),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OptimizerBudgetScreen(
                    tripId: widget.tripId,
                    destination: widget.tripDestination,
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.tune_rounded, size: 16),
              SizedBox(width: 8),
              Text('Run Optimizer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  String _formatTime(DateTime ts) {
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── System Message ───────────────────────────────────────────────────────────

class _SystemMessage extends StatelessWidget {
  final String message;
  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Text('🌴', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
       Expanded(child: Text(message,
            style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

// ─── Vote Card Widget ─────────────────────────────────────────────────────────

class _VoteCardWidget extends StatelessWidget {
  final _VoteCard card;
  final void Function(String emoji) onVote;

  const _VoteCardWidget({required this.card, required this.onVote});

  static const _voteOptions = [
    ('✅', 'Yes!', Color(0xFF2ECC71)),
    ('🤔', 'Maybe', Color(0xFFFFB347)),
    ('❌', 'No', Color(0xFFFF6B6B)),
  ];

  @override
  Widget build(BuildContext context) {
    final myVote = card.votes['me'];
    final yesCount  = card.votes.values.where((v) => v == '✅').length;
    final maybeCount= card.votes.values.where((v) => v == '🤔').length;
    final noCount   = card.votes.values.where((v) => v == '❌').length;
    final voted     = card.votes.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: card.colors.first.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header band
        Container(
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: card.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Stack(children: [
            Positioned(right: -10, top: -10,
              child: Text(card.emoji, style: TextStyle(fontSize: 80, color: Colors.white.withOpacity(0.15)))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(card.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(card.activityName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                Text(card.description, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
              ]),
            ),
            Positioned(top: 12, right: 12, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
              child: Text(card.day, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            // Info row
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(card.duration, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              const Icon(Icons.attach_money_rounded, size: 13, color: AppColors.textSecondary),
              Text('\$${card.cost.toStringAsFixed(0)}/person', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Text('$voted/${card.totalMembers} voted', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),

            // Vote tally bar
            _VoteTallyBar(yes: yesCount, maybe: maybeCount, no: noCount, total: card.totalMembers),
            const SizedBox(height: 12),

            // Vote buttons
            Row(children: _voteOptions.map((opt) {
              final selected = myVote == opt.$1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: opt.$1 == '❌' ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => onVote(opt.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? opt.$3.withOpacity(0.15) : AppColors.inputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? opt.$3 : AppColors.inputBorder,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(children: [
                        Text(opt.$1, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 3),
                        Text(opt.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? opt.$3 : AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                ),
              );
            }).toList()),
          ]),
        ),
      ]),
    );
  }
}

// ─── Vote Tally Bar ───────────────────────────────────────────────────────────

class _VoteTallyBar extends StatelessWidget {
  final int yes, maybe, no, total;
  const _VoteTallyBar({required this.yes, required this.maybe, required this.no, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _TallyLabel('✅ $yes', const Color(0xFF2ECC71)),
        const SizedBox(width: 10),
        _TallyLabel('🤔 $maybe', const Color(0xFFFFB347)),
        const SizedBox(width: 10),
        _TallyLabel('❌ $no', const Color(0xFFFF6B6B)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 8,
          child: Row(children: [
            if (yes > 0) Expanded(flex: yes, child: Container(color: const Color(0xFF2ECC71))),
            if (maybe > 0) Expanded(flex: maybe, child: Container(color: const Color(0xFFFFB347))),
            if (no > 0) Expanded(flex: no, child: Container(color: const Color(0xFFFF6B6B))),
            if (total - yes - maybe - no > 0)
              Expanded(flex: total - yes - maybe - no, child: Container(color: Colors.grey.shade200)),
          ]),
        ),
      ),
    ]);
  }
}

class _TallyLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _TallyLabel(this.text, this.color);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color));
}

// ─── Summary Row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String icon, text;
  const _SummaryRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(icon, style: const TextStyle(fontSize: 14)),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
  ]);
}

// ─── Reaction Picker Bottom Sheet ─────────────────────────────────────────────

class _ReactionPicker extends StatelessWidget {
  final List<String> reactions;
  final void Function(String) onSelect;
  const _ReactionPicker({required this.reactions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('React', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: reactions.map((e) => GestureDetector(
            onTap: () => onSelect(e),
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
            ),
          )).toList(),
        ),
      ]),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

enum MessageType { text, system }

class _ChatMessage {
  final String id, senderId, senderName, senderEmoji, text;
  final DateTime ts;
  final MessageType type;
  final Map<String, int>? reactions;

  const _ChatMessage({
    required this.id, required this.senderId, required this.senderName,
    required this.senderEmoji, required this.text, required this.ts,
    required this.type, this.reactions,
  });
}

class _VoteCard {
  final String id, activityName, emoji, description, duration, day;
  final double cost;
  final List<Color> colors;
  final Map<String, String> votes; // uid → emoji
  final int totalMembers;

  const _VoteCard({
    required this.id, required this.activityName, required this.emoji,
    required this.description, required this.cost, required this.duration,
    required this.day, required this.colors, required this.votes,
    required this.totalMembers,
  });
}