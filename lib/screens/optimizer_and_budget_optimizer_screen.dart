import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// OptimizerBudgetScreen — Score breakdown per activity, budget tracking,
/// distance estimates, and most-voted destinations.
///
/// Navigation position:
///   Add Activities → [Optimizer & Budget] → Itinerary View → Vote & Chat
///
/// Firebase hooks (to be wired by Backend Lead):
///   - [_runOptimizer]       → FirebaseFunctions.instance.httpsCallable('optimizeItinerary').call({'tripId': tripId})
///   - [_loadScores]         → Firestore.collection('trips/{id}/activities').orderBy('score', descending: true)
///   - [_loadBudget]         → Firestore.doc('trips/{id}') — fields: budgetTotal, perCategory
///   - [_loadVotes]          → Firestore.collection('trips/{id}/votes') — aggregate yes/no/maybe counts
///   - [_saveBudgetTotal]    → Firestore.doc('trips/{id}').update({'budgetTotal': value})
///   - Distance estimates    → Computed by Cloud Function from Google Maps Distance Matrix API
class OptimizerBudgetScreen extends StatefulWidget {
  /// Real tripId from Firestore — passed in from ItineraryViewScreen
  final String tripId;
  final String destination;

  const OptimizerBudgetScreen({
    super.key,
    this.tripId = 't1',
    this.destination = 'Bali, Indonesia',
  });

  @override
  State<OptimizerBudgetScreen> createState() => _OptimizerBudgetScreenState();
}

class _OptimizerBudgetScreenState extends State<OptimizerBudgetScreen>
    with TickerProviderStateMixin {
  // ─── Animation controllers ────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final AnimationController _spinController;

  late final Animation<double> _entryFade;
  late final Animation<Offset>  _entrySlide;

  // ─── State ────────────────────────────────────────────────────────────────
  int _selectedTab    = 0; // 0 = Score  1 = Budget  2 = Most Voted
  bool _isOptimizing  = false;
  bool _hasOptimized  = false;
  bool _editingBudget = false;
  double _budgetTotal = 3200.0;

  final _budgetEditController = TextEditingController();

  // ─── Mock score data (replace with Firestore stream) ─────────────────────
  final List<_ScoredActivity> _activities = const [
    _ScoredActivity(id: 's1', title: 'Mount Batur Sunrise Hike', emoji: '🌋',
        score: 98, voteScore: 35, distScore: 28, budgetScore: 22, popularityScore: 13,
        cost: 40.0, category: 'Outdoor', day: 'Day 3'),
    _ScoredActivity(id: 's2', title: 'Nusa Penida Day Trip', emoji: '🏝️',
        score: 97, voteScore: 34, distScore: 27, budgetScore: 23, popularityScore: 13,
        cost: 75.0, category: 'Outdoor', day: 'Day 4'),
    _ScoredActivity(id: 's3', title: 'Tegalalang Rice Terrace', emoji: '🌾',
        score: 96, voteScore: 33, distScore: 30, budgetScore: 24, popularityScore: 9,
        cost: 5.0, category: 'Culture', day: 'Day 2'),
    _ScoredActivity(id: 's4', title: 'Tanah Lot Temple', emoji: '⛩️',
        score: 94, voteScore: 32, distScore: 29, budgetScore: 22, popularityScore: 11,
        cost: 12.0, category: 'Culture', day: 'Day 1'),
    _ScoredActivity(id: 's5', title: 'Jimbaran Seafood Dinner', emoji: '🦞',
        score: 91, voteScore: 30, distScore: 26, budgetScore: 20, popularityScore: 15,
        cost: 35.0, category: 'Food', day: 'Day 1'),
    _ScoredActivity(id: 's6', title: 'Bali Swing Experience', emoji: '🎢',
        score: 89, voteScore: 28, distScore: 25, budgetScore: 22, popularityScore: 14,
        cost: 35.0, category: 'Adventure', day: 'Day 2'),
    _ScoredActivity(id: 's7', title: 'Kecak Fire Dance', emoji: '🔥',
        score: 88, voteScore: 29, distScore: 24, budgetScore: 22, popularityScore: 13,
        cost: 15.0, category: 'Culture', day: 'Day 3'),
    _ScoredActivity(id: 's8', title: 'Ubud Cooking Class', emoji: '🍜',
        score: 85, voteScore: 27, distScore: 22, budgetScore: 21, popularityScore: 15,
        cost: 45.0, category: 'Food', day: 'Day 2'),
    _ScoredActivity(id: 's9', title: 'Spa & Balinese Massage', emoji: '💆',
        score: 76, voteScore: 22, distScore: 24, budgetScore: 18, popularityScore: 12,
        cost: 30.0, category: 'Wellness', day: 'Day 1'),
    _ScoredActivity(id: 's10', title: 'Ubud Traditional Market', emoji: '🛍️',
        score: 72, voteScore: 20, distScore: 22, budgetScore: 18, popularityScore: 12,
        cost: 20.0, category: 'Shopping', day: 'Day 2'),
  ];

  // ─── Mock budget categories (replace with Firestore stream) ──────────────
  late final List<_BudgetCategory> _categories;

  // ─── Mock most-voted (replace with aggregated Firestore votes query) ──────
  final List<_VotedItem> _mostVoted = const [
    _VotedItem(title: 'Tegalalang Rice Terrace',  emoji: '🌾', yesVotes: 3, totalMembers: 3,
        category: 'Culture',   colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)]),
    _VotedItem(title: 'Mount Batur Sunrise Hike', emoji: '🌋', yesVotes: 3, totalMembers: 3,
        category: 'Adventure', colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
    _VotedItem(title: 'Nusa Penida Day Trip',      emoji: '🏝️', yesVotes: 2, totalMembers: 3,
        category: 'Outdoor',   colors: [Color(0xFF00B4DB), Color(0xFF0083B0)]),
    _VotedItem(title: 'Kecak Fire Dance',          emoji: '🔥', yesVotes: 2, totalMembers: 3,
        category: 'Culture',   colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
    _VotedItem(title: 'Bali Swing Experience',     emoji: '🎢', yesVotes: 1, totalMembers: 3,
        category: 'Adventure', colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
  ];

  // ─── Computed ─────────────────────────────────────────────────────────────
  double get _totalSpent   => _categories.fold(0.0, (s, c) => s + c.spent);
  double get _remaining    => _budgetTotal - _totalSpent;
  bool   get _isOverBudget => _totalSpent > _budgetTotal;

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _categories = [
      _BudgetCategory(label: 'Accommodation', emoji: '🏨', allocated: 1200, spent: 980,  color: const Color(0xFF667EEA)),
      _BudgetCategory(label: 'Food & Drink',  emoji: '🍽️', allocated: 600,  spent: 425,  color: AppColors.accent),
      _BudgetCategory(label: 'Activities',    emoji: '🏄', allocated: 800,  spent: 312,  color: AppColors.primaryLight),
      _BudgetCategory(label: 'Transport',     emoji: '✈️', allocated: 400,  spent: 315,  color: const Color(0xFFFFB347)),
      _BudgetCategory(label: 'Shopping',      emoji: '🛍️', allocated: 200,  spent: 88,   color: const Color(0xFF9B59B6)),
    ];

    _budgetEditController.text = _budgetTotal.toStringAsFixed(0);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _entryFade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _spinController.dispose();
    _budgetEditController.dispose();
    super.dispose();
  }

  // ─── Handlers ─────────────────────────────────────────────────────────────

  /// TODO (Backend): Replace body with FirebaseFunctions.instance
  ///   .httpsCallable('optimizeItinerary').call({'tripId': widget.tripId})
  Future<void> _runOptimizer() async {
    HapticFeedback.mediumImpact();
    setState(() => _isOptimizing = true);
    _spinController.repeat();

    // Simulate Cloud Function — remove when Firebase is wired
    await Future.delayed(const Duration(seconds: 3));

    _spinController.stop();
    _spinController.reset();

    if (mounted) {
      setState(() {
        _isOptimizing = false;
        _hasOptimized = true;
      });
      HapticFeedback.lightImpact();
      _showSuccessSnackBar('✨  Itinerary optimized! Activities reordered for max score.');
    }
  }

  /// TODO (Backend): Firestore.doc('trips/${widget.tripId}').update({'budgetTotal': value})
  void _saveBudgetTotal() {
    final value = double.tryParse(_budgetEditController.text);
    if (value == null || value <= 0) {
      _showErrorSnackBar('Enter a valid budget amount.');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _budgetTotal   = value;
      _editingBudget = false;
    });
    _showSuccessSnackBar('Budget updated to \$${value.toStringAsFixed(0)}!');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Space for transparent AppBar
          const SliverToBoxAdapter(child: SizedBox(height: 90)),

          // ── Optimizer engine card ──
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _entryFade,
              child: SlideTransition(
                position: _entrySlide,
                child: _buildOptimizerCard(),
              ),
            ),
          ),

          // ── Tab selector ──
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _entryFade,
              child: _buildTabSelector(),
            ),
          ),

          // ── Active tab content ──
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              child: _buildActiveTab(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.gradientStart, AppColors.gradientMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Optimizer & Budget',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            widget.destination,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white, size: 22),
          onPressed: () {},
        ),
        const SizedBox(width: 6),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ─── Optimizer engine card ────────────────────────────────────────────────
  Widget _buildOptimizerCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon + title row
          Row(
            children: [
              AnimatedBuilder(
                animation: _spinController,
                builder: (_, child) => Transform.rotate(
                  angle: _isOptimizing
                      ? _spinController.value * 2 * math.pi
                      : 0.0,
                  child: child,
                ),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.35), width: 1.2),
                  ),
                  child: Center(
                    child: Text(
                      _isOptimizing ? '⚙️' : _hasOptimized ? '✅' : '🤖',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Route Optimizer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isOptimizing
                          ? 'Crunching distances & votes...'
                          : _hasOptimized
                              ? 'Last run: just now  ·  Score ↑ 12 pts'
                              : 'Factors: votes, distance, budget & popularity',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.84),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Score factor chips
          Row(
            children: [
              _FactorChip(label: '🗳️ Votes',   value: '35%'),
              const SizedBox(width: 8),
              _FactorChip(label: '📍 Distance', value: '30%'),
              const SizedBox(width: 8),
              _FactorChip(label: '💰 Budget',   value: '23%'),
              const SizedBox(width: 8),
              _FactorChip(label: '⭐ Popular',  value: '12%'),
            ],
          ),
          const SizedBox(height: 16),

          // Run Optimizer button
          _buildRunOptimizerButton(),
        ],
      ),
    );
  }

  Widget _buildRunOptimizerButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 50,
      decoration: BoxDecoration(
        color: _isOptimizing ? Colors.white.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _isOptimizing
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isOptimizing ? null : _runOptimizer,
          child: Center(
            child: _isOptimizing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Optimizing...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _hasOptimized ? 'Re-run Optimizer' : 'Run Optimizer',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ─── Tab selector ─────────────────────────────────────────────────────────
  Widget _buildTabSelector() {
    final tabs = ['Score Breakdown', 'Budget', 'Most Voted'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                          ),
                        ],
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Active tab router ────────────────────────────────────────────────────
  Widget _buildActiveTab() {
    switch (_selectedTab) {
      case 0:  return _buildScoreTab();
      case 1:  return _buildBudgetTab();
      case 2:  return _buildMostVotedTab();
      default: return const SizedBox.shrink();
    }
  }

  // ─── Score breakdown tab ──────────────────────────────────────────────────
  Widget _buildScoreTab() {
    return Padding(
      key: const ValueKey('score'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: List.generate(_activities.length, (i) {
          return _AnimatedScoreCard(
            activity: _activities[i],
            rank: i + 1,
            entryController: _entryController,
            index: i,
          );
        }),
      ),
    );
  }

  // ─── Budget tab ───────────────────────────────────────────────────────────
  Widget _buildBudgetTab() {
    final overallPct = (_totalSpent / _budgetTotal).clamp(0.0, 1.0);

    return Padding(
      key: const ValueKey('budget'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Total budget card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Budget',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (_editingBudget) {
                          _saveBudgetTotal();
                        } else {
                          setState(() => _editingBudget = true);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _editingBudget ? 'Save' : 'Edit',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Editable total amount
                _editingBudget
                    ? TextField(
                        controller: _budgetEditController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        onSubmitted: (_) => _saveBudgetTotal(),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          prefixText: '\$',
                          prefixStyle: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${_budgetTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'per trip',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 16),

                // Mini stats row
                Row(
                  children: [
                    _BudgetMiniStat(
                      value: '\$${_totalSpent.toStringAsFixed(0)}',
                      label: 'Spent',
                      color: _isOverBudget
                          ? AppColors.accent
                          : AppColors.primaryLight,
                    ),
                    const SizedBox(width: 20),
                    _BudgetMiniStat(
                      value: '\$${_remaining.abs().toStringAsFixed(0)}',
                      label: _isOverBudget ? 'Over budget' : 'Remaining',
                      color: _isOverBudget ? AppColors.accent : AppColors.primary,
                    ),
                    const SizedBox(width: 20),
                    _BudgetMiniStat(
                      value: '${(overallPct * 100).toStringAsFixed(0)}%',
                      label: 'Used',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Overall progress bar
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: overallPct),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: val,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(
                        _isOverBudget
                            ? AppColors.accent
                            : AppColors.primaryLight,
                      ),
                    ),
                  ),
                ),

                if (_isOverBudget) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        'Exceeded budget by \$${_remaining.abs().toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── By category label ──
          const Text(
            'By Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ..._categories
              .map((cat) => _BudgetCategoryCard(category: cat)),

          const SizedBox(height: 14),

          // ── Distance note ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Distance estimates are calculated by the optimizer engine '
                    'using Google Maps data. Budget figures update in real time '
                    'from your itinerary.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Most voted tab ───────────────────────────────────────────────────────
  Widget _buildMostVotedTab() {
    return Padding(
      key: const ValueKey('voted'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trophy header card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB347), Color(0xFFFF6B6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Most Voted Activities',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_mostVoted.where((v) => v.yesVotes == v.totalMembers).length} unanimous picks this trip',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.86), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ..._mostVoted.asMap().entries.map((e) {
            return _VotedItemCard(item: e.value, rank: e.key + 1);
          }),
        ],
      ),
    );
  }
}

// ─── Animated Score Card ──────────────────────────────────────────────────────

class _AnimatedScoreCard extends StatelessWidget {
  final _ScoredActivity activity;
  final int rank;
  final AnimationController entryController;
  final int index;

  const _AnimatedScoreCard({
    required this.activity,
    required this.rank,
    required this.entryController,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final delay = index * 0.08;
    final anim  = CurvedAnimation(
      parent: entryController,
      curve: Interval(
        delay.clamp(0.0, 0.8),
        (delay + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    final scoreColor = activity.score >= 90
        ? AppColors.primaryLight
        : activity.score >= 75
            ? const Color(0xFFFFB347)
            : AppColors.accent;

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(anim),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──
              Row(
                children: [
                  // Rank badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(activity.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${activity.day}  ·  ${activity.category}  ·  \$${activity.cost.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Score pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 13, color: scoreColor),
                        const SizedBox(width: 3),
                        Text(
                          '${activity.score}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Score factor bars ──
              _ScoreFactorBar(label: '🗳️ Votes',     value: activity.voteScore,       max: 35, color: AppColors.primary),
              const SizedBox(height: 7),
              _ScoreFactorBar(label: '📍 Distance',   value: activity.distScore,       max: 30, color: const Color(0xFF667EEA)),
              const SizedBox(height: 7),
              _ScoreFactorBar(label: '💰 Budget fit', value: activity.budgetScore,     max: 23, color: const Color(0xFFFFB347)),
              const SizedBox(height: 7),
              _ScoreFactorBar(label: '⭐ Popularity', value: activity.popularityScore, max: 12, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Score factor progress bar ────────────────────────────────────────────────

class _ScoreFactorBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;

  const _ScoreFactorBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value / max),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: val,
                minHeight: 8,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Budget category card ─────────────────────────────────────────────────────

class _BudgetCategoryCard extends StatelessWidget {
  final _BudgetCategory category;
  const _BudgetCategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final pct  = (category.spent / category.allocated).clamp(0.0, 1.0);
    final over = category.spent > category.allocated;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: over
            ? Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(category.emoji,
                      style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Allocated: \$${category.allocated.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${category.spent.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: over ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}% used',
                    style: TextStyle(
                      fontSize: 10,
                      color: over ? AppColors.accent : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: val,
                minHeight: 7,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(
                  over ? AppColors.accent : category.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Voted item card ──────────────────────────────────────────────────────────

class _VotedItemCard extends StatelessWidget {
  final _VotedItem item;
  final int rank;
  const _VotedItemCard({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    final pct   = item.yesVotes / item.totalMembers;
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank.';
    final isAll = item.yesVotes == item.totalMembers;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: item.colors.first.withOpacity(0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Gradient colour band
          Container(
            width: 76,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(20)),
            ),
            child: Stack(
              children: [
                Center(
                  child:
                      Text(item.emoji, style: const TextStyle(fontSize: 32)),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Text(medal,
                      style: const TextStyle(fontSize: 15)),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.category,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        '${item.yesVotes}/${item.totalMembers} voted ✅',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: val,
                        minHeight: 7,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(
                          isAll
                              ? AppColors.primaryLight
                              : const Color(0xFFFFB347),
                        ),
                      ),
                    ),
                  ),
                  if (isAll) ...[
                    const SizedBox(height: 5),
                    const Text(
                      '🎉 Unanimous! Added to itinerary.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small helper widgets ─────────────────────────────────────────────────────

class _FactorChip extends StatelessWidget {
  final String label;
  final String value;
  const _FactorChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetMiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _BudgetMiniStat(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

class _ScoredActivity {
  final String id;
  final String title;
  final String emoji;
  final String category;
  final String day;
  final int score;
  final int voteScore;
  final int distScore;
  final int budgetScore;
  final int popularityScore;
  final double cost;

  const _ScoredActivity({
    required this.id,
    required this.title,
    required this.emoji,
    required this.category,
    required this.day,
    required this.score,
    required this.voteScore,
    required this.distScore,
    required this.budgetScore,
    required this.popularityScore,
    required this.cost,
  });
}

class _BudgetCategory {
  final String label;
  final String emoji;
  final double allocated;
  final double spent;
  final Color color;

  const _BudgetCategory({
    required this.label,
    required this.emoji,
    required this.allocated,
    required this.spent,
    required this.color,
  });
}

class _VotedItem {
  final String title;
  final String emoji;
  final String category;
  final int yesVotes;
  final int totalMembers;
  final List<Color> colors;

  const _VotedItem({
    required this.title,
    required this.emoji,
    required this.category,
    required this.yesVotes,
    required this.totalMembers,
    required this.colors,
  });
}