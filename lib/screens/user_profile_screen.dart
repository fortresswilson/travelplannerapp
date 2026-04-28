import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// UserProfileScreen — View and edit a traveller's profile
///
/// Navigation position:
///   Trip Lobby → [User Profile] (via avatar tap or profile nav item)
///
/// Firebase hooks (to be wired by Backend Lead):
///   - [_loadProfile]        → Firestore.doc('users/{uid}').snapshots()
///   - [_savePreferences]    → Firestore.doc('users/{uid}').update({...})
///   - [_uploadAvatar]       → FirebaseStorage.ref('avatars/{uid}').putFile(...)
///   - [_loadPastTrips]      → Firestore.collection('trips').where('members', arrayContains: uid).where('status', isEqualTo: 'past')
///   - [_loadSquad]          → Firestore.collection('users').where('uid', whereIn: friendUids)
class UserProfileScreen extends StatefulWidget {
  /// Pass the uid of the profile to view; null = current user
  final String? userId;

  const UserProfileScreen({super.key, this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with TickerProviderStateMixin {
  // ─── Animation ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── State ────────────────────────────────────────────────────────────────
  bool _isCurrentUser = true; // TODO: compare widget.userId with FirebaseAuth.currentUser.uid
  bool _isEditing = false;
  final Set<String> _selectedInterests = {
    'Beaches', 'Culture', 'Adventure', 'Food Tours', 'Nature',
  };

  // ─── Mock data ────────────────────────────────────────────────────────────
  final _UserProfile _profile = const _UserProfile(
    name: 'Vaishali Mehta',
    handle: '@vaish',
    location: 'Atlanta, GA',
    emoji: '🧳',
    tripCount: 7,
    activityCount: 43,
    countryCount: 3,
    voteCount: 12,
    travelStyle: 'Adventure',
    budgetRange: '\$2k – \$5k',
    foodPref: 'Vegetarian · Loves local cuisine',
    accommodation: 'Boutique hotels · Mid-range',
    badges: ['🌍 Explorer', '🔥 7 Trips', '⭐ Top Voter'],
    isOnline: true,
  );

  final List<_PastDestination> _pastTrips = const [
    _PastDestination(emoji: '🏛️', name: 'Santorini', date: 'Mar 2026', colors: [Color(0xFFFF6B6B), Color(0xFFFFB347)]),
    _PastDestination(emoji: '⛩️', name: 'Tokyo',     date: 'Nov 2025', colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
    _PastDestination(emoji: '🌊', name: 'Maldives',  date: 'Aug 2025', colors: [Color(0xFF00B4DB), Color(0xFF0083B0)]),
  ];

  final List<_SquadMember> _squad = const [
    _SquadMember(name: 'Fortress', emoji: '🏕️', role: 'Adventure Seeker · Mumbai', color: Color(0xFFFF6B6B), trips: 5),
    _SquadMember(name: 'Aashika',  emoji: '🌸', role: 'Culture & Food Lover · Pune',    color: Color(0xFFFFB347), trips: 4),
    _SquadMember(name: 'Leo',      emoji: '🎒', role: 'Budget Expert · Bangalore',       color: Color(0xFF0D7377), trips: 2),
  ];

  static const _allInterests = [
    '🏖️ Beaches', '🏛️ Culture', '🌋 Adventure', '🌃 Nightlife',
    '🍜 Food Tours', '🛍️ Shopping', '🏕️ Nature', '💆 Wellness',
    '📸 Photography', '🚴 Cycling', '🎭 Arts',
  ];

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim  = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  // ─── Handlers ────────────────────────────────────────────────────────────
  void _toggleEdit() {
    HapticFeedback.lightImpact();
    setState(() => _isEditing = !_isEditing);
    if (!_isEditing) _showSavedSnackBar();
  }

  void _toggleInterest(String interest) {
    HapticFeedback.selectionClick();
    setState(() {
      final key = interest.split(' ').skip(1).join(' ');
      if (_selectedInterests.contains(key)) {
        _selectedInterests.remove(key);
      } else {
        _selectedInterests.add(key);
      }
    });
  }

  void _showSavedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        SizedBox(width: 10),
        Text('Profile saved!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: AppColors.primaryLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  void _handleAvatarTap() {
    if (!_isEditing) return;
    HapticFeedback.lightImpact();
    // TODO (Backend): launch image picker → upload to FirebaseStorage → update Firestore photoURL
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Avatar upload — wire Firebase Storage here.'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatsBar(),
                    const SizedBox(height: 20),
                    _buildTravelPreferences(),
                    const SizedBox(height: 20),
                    _buildInterestsSection(),
                    const SizedBox(height: 20),
                    _buildPastTrips(),
                    const SizedBox(height: 20),
                    _buildSquadSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sliver AppBar with avatar hero ──────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_isCurrentUser)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isEditing
                ? TextButton(
                    key: const ValueKey('save'),
                    onPressed: _toggleEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  )
                : TextButton(
                    key: const ValueKey('edit'),
                    onPressed: _toggleEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.white.withOpacity(0.4)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    ),
                    child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
          ),
        const SizedBox(width: 16),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Avatar
                GestureDetector(
                  onTap: _handleAvatarTap,
                  child: Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Center(
                          child: Text('🧳', style: TextStyle(fontSize: 40)),
                        ),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                          ),
                        ),
                      if (_profile.isOnline && !_isEditing)
                        Positioned(
                          bottom: 4, right: 4,
                          child: Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2ECC71),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _profile.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_profile.handle}  ·  ${_profile.location}',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.82)),
                ),
                const SizedBox(height: 10),
                // Badges
                Wrap(
                  spacing: 8, runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: _profile.badges.map((b) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: Text(b, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
        title: Text(
          _profile.name,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
      ),
    );
  }

  // ─── Stats bar ────────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _StatItem(label: 'Trips',      value: '${_profile.tripCount}',     icon: '🗺️'),
          _VDivider(),
          _StatItem(label: 'Activities', value: '${_profile.activityCount}', icon: '📍'),
          _VDivider(),
          _StatItem(label: 'Countries',  value: '${_profile.countryCount}',  icon: '🌍'),
          _VDivider(),
          _StatItem(label: 'Votes',      value: '${_profile.voteCount}',     icon: '🗳️'),
        ],
      ),
    );
  }

  // ─── Travel preferences ───────────────────────────────────────────────────
  Widget _buildTravelPreferences() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Travel Preferences'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
            ),
            child: Column(
              children: [
                _PrefRow(
                  icon: '✈️', iconBg: AppColors.primary.withOpacity(0.1),
                  label: 'Travel Style', value: 'Balanced explorer',
                  pill: _profile.travelStyle, pillColor: AppColors.primary,
                  isEditing: _isEditing,
                ),
                _Divider(),
                _PrefRow(
                  icon: '💰', iconBg: AppColors.accent.withOpacity(0.1),
                  label: 'Budget Range', value: 'Per trip target',
                  pill: _profile.budgetRange, pillColor: AppColors.primary,
                  isEditing: _isEditing,
                ),
                _Divider(),
                _PrefRow(
                  icon: '🍽️', iconBg: const Color(0xFFFFB347).withOpacity(0.15),
                  label: 'Food Preferences', value: _profile.foodPref,
                  pill: 'Veg', pillColor: AppColors.accent,
                  isEditing: _isEditing,
                ),
                _Divider(),
                _PrefRow(
                  icon: '🛏️', iconBg: const Color(0xFF9B59B6).withOpacity(0.1),
                  label: 'Accommodation', value: _profile.accommodation,
                  pill: 'Hotel', pillColor: AppColors.primary,
                  isEditing: _isEditing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Interests tag cloud ──────────────────────────────────────────────────
  Widget _buildInterestsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Destination Interests'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allInterests.map((interest) {
              final key = interest.split(' ').skip(1).join(' ');
              final active = _selectedInterests.contains(key);
              return GestureDetector(
                onTap: _isEditing ? () => _toggleInterest(interest) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: active ? AppColors.primary : AppColors.inputBorder,
                      width: 1.2,
                    ),
                    boxShadow: active
                        ? [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
                        : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                  ),
                  child: Text(
                    interest,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Tap to toggle interests — used for activity recommendations.',
                style: TextStyle(fontSize: 11, color: AppColors.textHint, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Past trips ───────────────────────────────────────────────────────────
  Widget _buildPastTrips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Past Destinations'),
          const SizedBox(height: 10),
          Row(
            children: _pastTrips.map((d) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: _pastTrips.last == d ? 0 : 10),
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: d.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.emoji, style: const TextStyle(fontSize: 22)),
                      const Spacer(),
                      Text(d.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(d.date, style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 10)),
                    ],
                  ),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Travel squad ─────────────────────────────────────────────────────────
  Widget _buildSquadSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel('Travel Squad'),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('See all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: _squad.map((m) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  // TODO (Backend): swap emoji with CachedNetworkImage from Firebase Storage
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: m.color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(m.emoji, style: const TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(m.role, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${m.trips} trips', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const SizedBox(height: 4),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
                    ],
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5),
  );
}

class _StatItem extends StatelessWidget {
  final String label, value, icon;
  const _StatItem({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: Colors.grey.shade100);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(color: Colors.grey.shade100, height: 1);
}

class _PrefRow extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String label, value, pill;
  final Color pillColor;
  final bool isEditing;

  const _PrefRow({
    required this.icon, required this.iconBg,
    required this.label, required this.value,
    required this.pill, required this.pillColor,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 17))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (isEditing)
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: pillColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(pill, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pillColor)),
            ),
        ],
      ),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

class _UserProfile {
  final String name, handle, location, emoji;
  final int tripCount, activityCount, countryCount, voteCount;
  final String travelStyle, budgetRange, foodPref, accommodation;
  final List<String> badges;
  final bool isOnline;

  const _UserProfile({
    required this.name, required this.handle, required this.location, required this.emoji,
    required this.tripCount, required this.activityCount, required this.countryCount, required this.voteCount,
    required this.travelStyle, required this.budgetRange, required this.foodPref, required this.accommodation,
    required this.badges, required this.isOnline,
  });
}

class _PastDestination {
  final String emoji, name, date;
  final List<Color> colors;
  const _PastDestination({required this.emoji, required this.name, required this.date, required this.colors});
}

class _SquadMember {
  final String name, emoji, role;
  final Color color;
  final int trips;
  const _SquadMember({required this.name, required this.emoji, required this.role, required this.color, required this.trips});
}