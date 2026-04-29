import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';
import 'itinerary_view_screen.dart';
import 'create_join_trip_screen.dart';
import 'user_profile_screen.dart';
import 'settings_and_preferences_screen.dart';

/// TripLobbyScreen — Home screen after successful sign-in
///
/// Navigation position: Sign In → [Trip Lobby] → Create/Join Trip → ...
///
/// Firebase hooks (to be wired by Backend Lead):
///   - [_loadTrips]          → Firestore.collection('trips').where('members', arrayContains: uid)
///   - [_handleCreateTrip]   → push to CreateJoinTripScreen with mode=create
///   - [_handleJoinTrip]     → push to CreateJoinTripScreen with mode=join
///   - [_openTrip]           → push to ItineraryViewScreen with tripId
///   - [_handleSignOut]      → FirebaseAuth.signOut()
///   - Member avatars        → Firebase Storage profile photo URLs
class TripLobbyScreen extends StatefulWidget {
  const TripLobbyScreen({super.key});

  @override
  State<TripLobbyScreen> createState() => _TripLobbyScreenState();
}

class _TripLobbyScreenState extends State<TripLobbyScreen>
    with TickerProviderStateMixin {
  // ─── Animation controllers ────────────────────────────────────────────────
  late final AnimationController _headerController;
  late final AnimationController _cardController;
  late final AnimationController _fabController;

  late final Animation<double> _headerFade;
  late final Animation<double> _fabScale;

  // ─── State ────────────────────────────────────────────────────────────────
  int _selectedFilter = 0; // 0=All, 1=Upcoming, 2=Past
  bool _isLoading = false;

  // ─── Mock data (replace with Firestore stream) ────────────────────────────
  final List<_TripData> _trips = [
    _TripData(
      id: 't1',
      destination: 'Bali, Indonesia',
      emoji: '🌺',
      coverGradient: [Color(0xFFFF6B6B), Color(0xFFFFB347)],
      startDate: DateTime(2026, 5, 14),
      endDate: DateTime(2026, 5, 22),
      status: TripStatus.upcoming,
      members: [
        _Member('Vaish', '🧳', Color(0xFF0D7377)),
        _Member('Fortress', '🏕️', Color(0xFFFF6B6B)),
        _Member('Aashika', '🌸', Color(0xFFFFB347)),
      ],
      activitiesCount: 12,
      budgetTotal: 3200,
      budgetSpent: 1450,
      itineraryStatus: 'Optimizer running...',
    ),
    _TripData(
      id: 't2',
      destination: 'Kyoto, Japan',
      emoji: '⛩️',
      coverGradient: [Color(0xFF667EEA), Color(0xFF764BA2)],
      startDate: DateTime(2026, 6, 3),
      endDate: DateTime(2026, 6, 10),
      status: TripStatus.upcoming,
      members: [
        _Member('Vaish', '🧳', Color(0xFF0D7377)),
        _Member('Fortress', '🏕️', Color(0xFFFF6B6B)),
      ],
      activitiesCount: 7,
      budgetTotal: 4500,
      budgetSpent: 300,
      itineraryStatus: 'Planning phase',
    ),
    _TripData(
      id: 't3',
      destination: 'Santorini, Greece',
      emoji: '🏛️',
      coverGradient: [Color(0xFF00B4DB), Color(0xFF0083B0)],
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 8),
      status: TripStatus.past,
      members: [
        _Member('Vaish', '🧳', Color(0xFF0D7377)),
        _Member('Aashika', '🌸', Color(0xFFFFB347)),
        _Member('Fortress', '🏕️', Color(0xFFFF6B6B)),
        _Member('Leo', '🎒', Color(0xFF667EEA)),
      ],
      activitiesCount: 18,
      budgetTotal: 5000,
      budgetSpent: 4820,
      itineraryStatus: 'Completed',
    ),
  ];

  List<_TripData> get _filteredTrips {
    if (_selectedFilter == 0) return _trips;
    if (_selectedFilter == 1) {
      return _trips.where((t) => t.status == TripStatus.upcoming).toList();
    }
    return _trips.where((t) => t.status == TripStatus.past).toList();
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fabScale = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _headerController.forward();
        _cardController.forward();
        _fabController.forward();
      }
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _cardController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  // ─── Handlers ────────────────────────────────────────────────────────────
  void _handleCreateTrip() {
    HapticFeedback.lightImpact();
    _showBottomSheet();
  }

  void _openTrip(_TripData trip) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItineraryViewScreen(
          tripId: trip.id,
          destination: trip.destination,
        ),
      ),
    );
  }

  void _handleSignOut() {
    // TODO (Backend): FirebaseAuth.instance.signOut()
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  // ─── Bottom Sheet: Create or Join ────────────────────────────────────────
  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateJoinSheet(),
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
          // Space for AppBar
          const SliverToBoxAdapter(child: SizedBox(height: 110)),

          // ── Greeting header ──
          SliverToBoxAdapter(child: _buildGreetingHeader()),

          // ── Stats bar ──
          SliverToBoxAdapter(child: _buildStatsBar()),

          // ── Filter chips ──
          SliverToBoxAdapter(child: _buildFilterChips()),

          // ── Section label ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedFilter == 2 ? 'Past Trips' :
                    _selectedFilter == 1 ? 'Upcoming Trips' : 'All Trips',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${_filteredTrips.length} trips',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Trip cards ──
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final trip = _filteredTrips[index];
                return _AnimatedTripCard(
                  trip: trip,
                  index: index,
                  controller: _cardController,
                  onTap: () => _openTrip(trip),
                );
              },
              childCount: _filteredTrips.length,
            ),
          ),

          // ── Empty state ──
          if (_filteredTrips.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState()),

          // Bottom padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: _buildFAB(),
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
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('🌴', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'TropicaGuide',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        // Notification bell
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 26),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                ),
              ),
            ],
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsAndPreferencesScreen()),
            );
          },
        ),
        // Avatar / profile tap
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserProfileScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Center(
              child: Text('🧳', style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ─── Greeting ─────────────────────────────────────────────────────────────
  Widget _buildGreetingHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return FadeTransition(
      opacity: _headerFade,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, Vaish! 👋',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Where are you headed next?',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stats bar ────────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    return FadeTransition(
      opacity: _headerFade,
      child: Container(
        margin: const EdgeInsets.fromLTRB(22, 18, 22, 0),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(label: 'Total Trips', value: '${_trips.length}', icon: '🗺️'),
            _VerticalDivider(),
            _StatItem(
              label: 'Upcoming',
              value: '${_trips.where((t) => t.status == TripStatus.upcoming).length}',
              icon: '✈️',
            ),
            _VerticalDivider(),
            _StatItem(
              label: 'Activities',
              value: '${_trips.fold(0, (sum, t) => sum + t.activitiesCount)}',
              icon: '📍',
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter chips ─────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final filters = ['All', 'Upcoming', 'Past'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: List.generate(filters.length, (i) {
          final selected = _selectedFilter == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedFilter = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                        ),
                      ],
              ),
              child: Text(
                filters[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        children: [
          const Text('🌍', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'No trips here yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new trip or join one\nwith your travel squad!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _handleCreateTrip,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'New Trip',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
}

// ─── Animated Trip Card ───────────────────────────────────────────────────────

class _AnimatedTripCard extends StatefulWidget {
  final _TripData trip;
  final int index;
  final AnimationController controller;
  final VoidCallback onTap;

  const _AnimatedTripCard({
    required this.trip,
    required this.index,
    required this.controller,
    required this.onTap,
  });

  @override
  State<_AnimatedTripCard> createState() => _AnimatedTripCardState();
}

class _AnimatedTripCardState extends State<_AnimatedTripCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Staggered slide-up per card
    final delay = widget.index * 0.15;
    final animation = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(
        delay.clamp(0.0, 0.8),
        (delay + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: _buildCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final trip = widget.trip;
    final isPast = trip.status == TripStatus.past;
    final budgetPct = trip.budgetSpent / trip.budgetTotal;
    final daysLeft = trip.startDate.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: trip.coverGradient.first.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Colorful gradient header band ──
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPast
                    ? [Colors.grey.shade400, Colors.grey.shade500]
                    : trip.coverGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Stack(
              children: [
                // Big destination emoji (background decoration)
                Positioned(
                  right: -10,
                  top: -10,
                  child: Text(
                    trip.emoji,
                    style: TextStyle(
                      fontSize: 90,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                ),
                // Status badge
                Positioned(
                  top: 14,
                  right: 14,
                  child: _StatusBadge(status: trip.status),
                ),
                // Destination name
                Positioned(
                  left: 18,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trip.destination,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Card body ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date row
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _formatDateRange(trip.startDate, trip.endDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (!isPast && daysLeft >= 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          daysLeft == 0
                              ? 'Today!'
                              : 'In $daysLeft day${daysLeft != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Member avatars + activity count
                Row(
                  children: [
                    // Stacked avatars
                    _StackedAvatars(members: trip.members),
                    const SizedBox(width: 10),
                    Text(
                      '${trip.members.length} traveler${trip.members.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.place_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.activitiesCount} activities',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Itinerary status chip
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isPast ? Colors.grey : AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      trip.itineraryStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isPast ? AppColors.textSecondary : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Budget progress
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Budget',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '\$${trip.budgetSpent.toStringAsFixed(0)} / \$${trip.budgetTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: budgetPct.clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(
                          budgetPct > 0.9
                              ? AppColors.accent
                              : AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // View Trip button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onTap,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isPast
                            ? Colors.grey.shade300
                            : AppColors.primary,
                        width: 1.5,
                      ),
                      foregroundColor:
                          isPast ? AppColors.textSecondary : AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isPast ? 'View Memories' : 'Open Trip',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
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

  String _formatDateRange(DateTime start, DateTime end) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}, ${end.year}';
  }
}

// ─── Stacked Member Avatars ───────────────────────────────────────────────────

class _StackedAvatars extends StatelessWidget {
  final List<_Member> members;
  const _StackedAvatars({required this.members});

  @override
  Widget build(BuildContext context) {
    final show = members.take(3).toList();
    final overflow = members.length - show.length;

    return SizedBox(
      width: show.length * 22.0 + (overflow > 0 ? 26 : 0),
      height: 32,
      child: Stack(
        children: [
          // TODO (Backend): swap emoji with CachedNetworkImage from Firebase Storage URL
          ...List.generate(show.length, (i) {
            return Positioned(
              left: i * 22.0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: show[i].color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(show[i].emoji,
                      style: const TextStyle(fontSize: 14)),
                ),
              ),
            );
          }),
          if (overflow > 0)
            Positioned(
              left: show.length * 22.0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$overflow',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final TripStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPast = status == TripStatus.past;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isPast ? 0.25 : 0.30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: Text(
        isPast ? '✅ Completed' : '🗓️ Upcoming',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Stat Item ────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey.shade100,
    );
  }
}

// ─── Create / Join Bottom Sheet ───────────────────────────────────────────────

class _CreateJoinSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Start your adventure',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a new trip or join one\nwith a group code.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          // Create trip option
          _SheetOption(
            icon: '✈️',
            title: 'Create a Trip',
            subtitle: 'Start planning from scratch',
            color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateJoinTripScreen(mode: TripMode.create),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Join trip option
          _SheetOption(
            icon: '🔗',
            title: 'Join a Trip',
            subtitle: 'Enter an invite code to join your group',
            color: AppColors.accent,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateJoinTripScreen(mode: TripMode.join),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

enum TripStatus { upcoming, past }

class _TripData {
  final String id;
  final String destination;
  final String emoji;
  final List<Color> coverGradient;
  final DateTime startDate;
  final DateTime endDate;
  final TripStatus status;
  final List<_Member> members;
  final int activitiesCount;
  final double budgetTotal;
  final double budgetSpent;
  final String itineraryStatus;

  const _TripData({
    required this.id,
    required this.destination,
    required this.emoji,
    required this.coverGradient,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.members,
    required this.activitiesCount,
    required this.budgetTotal,
    required this.budgetSpent,
    required this.itineraryStatus,
  });
}

class _Member {
  final String name;
  final String emoji;
  final Color color;
  const _Member(this.name, this.emoji, this.color);
}
