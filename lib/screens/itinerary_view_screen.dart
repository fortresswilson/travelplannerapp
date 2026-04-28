import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// ItineraryViewScreen — Ranked activity list for a trip
///
/// Navigation position: Trip Lobby → Create/Join Trip → [Itinerary View] → ...
///
/// Firebase hooks (to be wired by Backend Lead):
///   - [_loadActivities]       → Firestore.collection('trips/{tripId}/activities').orderBy('score', descending: true)
///   - [_onReorder]            → Firestore batch update of 'order' field on all affected docs
///   - [_toggleActivityDone]   → Firestore.doc('trips/{tripId}/activities/{actId}').update({'done': !done})
///   - [_deleteActivity]       → Firestore.doc(...).delete()
///   - [_addActivity]          → push to AddActivitiesScreen
///   - Budget remaining        → Firestore trip doc 'budgetTotal' - sum of activity costs
///   - Score badges            → computed by Cloud Function / optimizer engine
class ItineraryViewScreen extends StatefulWidget {
  /// Pass the real tripId from Firestore when navigating here
  final String tripId;
  final String destination;

  const ItineraryViewScreen({
    super.key,
    this.tripId = 't1',
    this.destination = 'Bali, Indonesia',
  });

  @override
  State<ItineraryViewScreen> createState() => _ItineraryViewScreenState();
}

class _ItineraryViewScreenState extends State<ItineraryViewScreen>
    with TickerProviderStateMixin {
  // ─── Animation ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;

  // ─── State ────────────────────────────────────────────────────────────────
  int _selectedDay = 0;
  bool _showOptimizedOrder = true;

  // ─── Mock data (replace with Firestore stream) ────────────────────────────
  final List<String> _days = ['Day 1', 'Day 2', 'Day 3', 'Day 4'];

  // Activities per day — key is day index
  late Map<int, List<_Activity>> _activitiesByDay;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _activitiesByDay = {
      0: [
        _Activity(id: 'a1', title: 'Tanah Lot Temple', category: ActivityCategory.culture,
            startTime: '08:00', endTime: '10:00', cost: 12.0,
            score: 94, note: 'Iconic sea temple — go at sunrise', done: true,
            emoji: '⛩️', distanceKm: 1.2),
        _Activity(id: 'a2', title: 'Seminyak Beach', category: ActivityCategory.outdoor,
            startTime: '11:00', endTime: '13:00', cost: 0.0,
            score: 88, note: 'Voted #1 by group 🗳️', done: false,
            emoji: '🏖️', distanceKm: 4.5),
        _Activity(id: 'a3', title: 'Jimbaran Seafood Dinner', category: ActivityCategory.food,
            startTime: '18:00', endTime: '20:00', cost: 35.0,
            score: 91, note: 'Book ahead — gets crowded', done: false,
            emoji: '🦞', distanceKm: 7.8),
        _Activity(id: 'a4', title: 'Spa & Wellness', category: ActivityCategory.wellness,
            startTime: '14:00', endTime: '16:00', cost: 55.0,
            score: 76, note: 'Optional — low group votes', done: false,
            emoji: '💆', distanceKm: 2.1),
      ],
      1: [
        _Activity(id: 'b1', title: 'Ubud Monkey Forest', category: ActivityCategory.outdoor,
            startTime: '09:00', endTime: '11:00', cost: 8.0,
            score: 89, note: 'Watch your bags!', done: false,
            emoji: '🐒', distanceKm: 38.0),
        _Activity(id: 'b2', title: 'Tegalalang Rice Terrace', category: ActivityCategory.outdoor,
            startTime: '12:00', endTime: '14:00', cost: 5.0,
            score: 96, note: 'Top-voted by all members', done: false,
            emoji: '🌾', distanceKm: 42.0),
        _Activity(id: 'b3', title: 'Ubud Traditional Market', category: ActivityCategory.shopping,
            startTime: '07:00', endTime: '09:00', cost: 20.0,
            score: 72, note: 'Great for souvenirs', done: false,
            emoji: '🛍️', distanceKm: 37.5),
      ],
      2: [
        _Activity(id: 'c1', title: 'Mount Batur Sunrise Hike', category: ActivityCategory.outdoor,
            startTime: '02:00', endTime: '07:00', cost: 40.0,
            score: 98, note: '🔥 Highest score! Book guide', done: false,
            emoji: '🌋', distanceKm: 65.0),
        _Activity(id: 'c2', title: 'Tirta Empul Water Temple', category: ActivityCategory.culture,
            startTime: '09:00', endTime: '11:00', cost: 6.0,
            score: 85, note: 'Sacred purification ritual', done: false,
            emoji: '🕍', distanceKm: 48.0),
      ],
      3: [
        _Activity(id: 'd1', title: 'Nusa Penida Day Trip', category: ActivityCategory.outdoor,
            startTime: '06:00', endTime: '18:00', cost: 75.0,
            score: 97, note: 'Kelingking Beach — wow!', done: false,
            emoji: '🏝️', distanceKm: 20.0),
      ],
    };

    // Sort by score (optimizer order)
    for (final day in _activitiesByDay.values) {
      day.sort((a, b) => b.score.compareTo(a.score));
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  // ─── Handlers ─────────────────────────────────────────────────────────────
  void _onReorder(int oldIndex, int newIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final items = _activitiesByDay[_selectedDay]!;
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      _showOptimizedOrder = false;
    });
    // TODO (Backend): batch update Firestore 'order' field for all affected docs
  }

  void _toggleDone(String actId) {
    HapticFeedback.selectionClick();
    setState(() {
      final items = _activitiesByDay[_selectedDay]!;
      final idx = items.indexWhere((a) => a.id == actId);
      if (idx != -1) {
        items[idx] = items[idx].copyWith(done: !items[idx].done);
      }
    });
    // TODO (Backend): Firestore update done field
  }

  void _deleteActivity(String actId) {
    setState(() {
      _activitiesByDay[_selectedDay]!.removeWhere((a) => a.id == actId);
    });
    // TODO (Backend): Firestore delete
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Activity removed'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {}, // TODO: restore from Firestore
        ),
      ),
    );
  }

  void _restoreOptimizedOrder() {
    HapticFeedback.lightImpact();
    setState(() {
      _activitiesByDay[_selectedDay]!
          .sort((a, b) => b.score.compareTo(a.score));
      _showOptimizedOrder = true;
    });
  }

  // ─── Computed ─────────────────────────────────────────────────────────────
  double get _dayBudgetSpent {
    return _activitiesByDay[_selectedDay]!
        .fold(0.0, (sum, a) => sum + a.cost);
  }

  double get _totalBudget => 3200.0; // TODO: pull from Firestore trip doc
  double get _totalSpent => _activitiesByDay.values
      .expand((a) => a)
      .fold(0.0, (sum, a) => sum + a.cost);

  List<_Activity> get _currentActivities =>
      _activitiesByDay[_selectedDay] ?? [];

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildBudgetSummaryCard()),
          SliverToBoxAdapter(child: _buildDaySelector()),
          SliverToBoxAdapter(child: _buildDayHeader()),
          _buildActivityList(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _buildAddFAB(),
    );
  }

  // ─── Sliver AppBar ────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: Colors.white),
          onPressed: () {}, // TODO: open optimizer settings
          tooltip: 'Optimizer settings',
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {},
          tooltip: 'Share itinerary',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Text('🗺️', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.destination,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'May 14 – 22, 2026  •  3 travelers',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        title: Text(
          widget.destination,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ─── Budget summary card ──────────────────────────────────────────────────
  Widget _buildBudgetSummaryCard() {
    final pct = (_totalSpent / _totalBudget).clamp(0.0, 1.0);
    final remaining = _totalBudget - _totalSpent;

    return FadeTransition(
      opacity: _entryController,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MiniStat(
                  label: 'Total Budget',
                  value: '\$${_totalBudget.toStringAsFixed(0)}',
                  color: AppColors.textPrimary,
                ),
                _MiniStat(
                  label: 'Spent',
                  value: '\$${_totalSpent.toStringAsFixed(0)}',
                  color: pct > 0.85 ? AppColors.accent : AppColors.primaryLight,
                ),
                _MiniStat(
                  label: 'Remaining',
                  value: '\$${remaining.toStringAsFixed(0)}',
                  color: AppColors.primary,
                ),
                _MiniStat(
                  label: 'Activities',
                  value:
                      '${_activitiesByDay.values.expand((a) => a).length}',
                  color: AppColors.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => LinearProgressIndicator(
                  value: val,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(
                    pct > 0.85 ? AppColors.accent : AppColors.primaryLight,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(pct * 100).toStringAsFixed(0)}% of budget used',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (pct > 0.85)
                  const Text(
                    '⚠️ Budget alert',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Day selector tabs ────────────────────────────────────────────────────
  Widget _buildDaySelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(_days.length, (i) {
            final selected = _selectedDay == i;
            final count = _activitiesByDay[i]?.length ?? 0;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedDay = i;
                  _showOptimizedOrder = true;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                          )
                        ],
                ),
                child: Column(
                  children: [
                    Text(
                      _days[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count acts',
                      style: TextStyle(
                        fontSize: 10,
                        color: selected
                            ? Colors.white70
                            : AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── Day header + optimizer toggle ───────────────────────────────────────
  Widget _buildDayHeader() {
    final dayBudget = _dayBudgetSpent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _days[_selectedDay],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_currentActivities.length} activities  •  \$${dayBudget.toStringAsFixed(0)} est. cost',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!_showOptimizedOrder)
            TextButton.icon(
              onPressed: _restoreOptimizedOrder,
              icon: const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: AppColors.primary),
              label: const Text(
                'Restore score order',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: AppColors.primary.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Reorderable activity list ────────────────────────────────────────────
  Widget _buildActivityList() {
    if (_currentActivities.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyDay());
    }

    return SliverToBoxAdapter(
      child: ReorderableListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        onReorder: _onReorder,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (_, __) => Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(20),
              shadowColor: AppColors.primary.withOpacity(0.3),
              child: child,
            ),
          );
        },
        itemCount: _currentActivities.length,
        itemBuilder: (context, index) {
          final activity = _currentActivities[index];
          return _ActivityCard(
            key: ValueKey(activity.id),
            activity: activity,
            rank: index + 1,
            onToggleDone: () => _toggleDone(activity.id),
            onDelete: () => _deleteActivity(activity.id),
            entryAnimation: CurvedAnimation(
              parent: _entryController,
              curve: Interval(
                (index * 0.1).clamp(0.0, 0.7),
                ((index * 0.1) + 0.4).clamp(0.0, 1.0),
                curve: Curves.easeOutCubic,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyDay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 40),
      child: Column(
        children: [
          const Text('📋', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          const Text(
            'No activities yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap + to add activities for this day.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.lightImpact();
        // TODO: Navigator.pushNamed(context, '/add-activities', arguments: widget.tripId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add Activities screen coming next!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      backgroundColor: AppColors.primary,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text(
        'Add Activity',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ─── Activity Card ────────────────────────────────────────────────────────────

class _ActivityCard extends StatefulWidget {
  final _Activity activity;
  final int rank;
  final VoidCallback onToggleDone;
  final VoidCallback onDelete;
  final Animation<double> entryAnimation;

  const _ActivityCard({
    super.key,
    required this.activity,
    required this.rank,
    required this.onToggleDone,
    required this.onDelete,
    required this.entryAnimation,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final scoreColor = a.score >= 90
        ? const Color(0xFF0D7377)
        : a.score >= 75
            ? const Color(0xFFFFB347)
            : const Color(0xFFFF6B6B);

    return FadeTransition(
      opacity: widget.entryAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(widget.entryAnimation),
        child: Dismissible(
          key: ValueKey('dismiss_${a.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline_rounded,
                    color: AppColors.accent, size: 28),
                SizedBox(height: 4),
                Text('Remove',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          onDismissed: (_) => widget.onDelete(),
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            decoration: BoxDecoration(
              color: a.done ? Colors.grey.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: a.done
                  ? Border.all(color: Colors.grey.shade200)
                  : Border.all(color: Colors.transparent),
              boxShadow: a.done
                  ? []
                  : [
                      BoxShadow(
                        color: _categoryColor(a.category).withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              children: [
                // ── Main row ──
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                      bottom: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        ReorderableDragStartListener(
                          index: widget.rank - 1,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2, right: 8),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: Colors.grey.shade300,
                              size: 20,
                            ),
                          ),
                        ),

                        // Rank badge
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: scoreColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '#${widget.rank}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Emoji
                        Text(a.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),

                        // Title + time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: a.done
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  decoration: a.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded,
                                      size: 12,
                                      color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${a.startTime} – ${a.endTime}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(Icons.near_me_rounded,
                                      size: 12,
                                      color: AppColors.textSecondary),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${a.distanceKm} km',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Right side: score + cost + done toggle
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Score pill
                            _ScorePill(score: a.score, color: scoreColor),
                            const SizedBox(height: 6),
                            Text(
                              a.cost == 0
                                  ? 'Free'
                                  : '\$${a.cost.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: a.cost == 0
                                    ? AppColors.primaryLight
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: widget.onToggleDone,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: a.done
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: a.done
                                        ? AppColors.primary
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: a.done
                                    ? const Icon(Icons.check_rounded,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Expanded note + category ──
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _expanded
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(
                                  color: Colors.grey.shade100, height: 1),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _CategoryChip(category: a.category),
                                  const Spacer(),
                                ],
                              ),
                              if (a.note.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded,
                                        size: 13,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        a.note,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Score breakdown hint
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded,
                                        size: 13, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Optimizer score: ${a.score}/100  •  Distance factor applied',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _categoryColor(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.outdoor:   return const Color(0xFF14A085);
      case ActivityCategory.culture:   return const Color(0xFF667EEA);
      case ActivityCategory.food:      return const Color(0xFFFF6B6B);
      case ActivityCategory.shopping:  return const Color(0xFFFFB347);
      case ActivityCategory.wellness:  return const Color(0xFF9B59B6);
    }
  }
}

// ─── Score Pill ───────────────────────────────────────────────────────────────

class _ScorePill extends StatelessWidget {
  final int score;
  final Color color;
  const _ScorePill({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final ActivityCategory category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final info = _categoryInfo(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: info.$2.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${info.$1}  ${info.$3}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: info.$2,
        ),
      ),
    );
  }

  (String, Color, String) _categoryInfo(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.outdoor:
        return ('Outdoor', const Color(0xFF14A085), '🌿');
      case ActivityCategory.culture:
        return ('Culture', const Color(0xFF667EEA), '🏛️');
      case ActivityCategory.food:
        return ('Food & Drink', const Color(0xFFFF6B6B), '🍽️');
      case ActivityCategory.shopping:
        return ('Shopping', const Color(0xFFFFB347), '🛍️');
      case ActivityCategory.wellness:
        return ('Wellness', const Color(0xFF9B59B6), '✨');
    }
  }
}

// ─── Mini Stat ────────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

enum ActivityCategory { outdoor, culture, food, shopping, wellness }

class _Activity {
  final String id;
  final String title;
  final ActivityCategory category;
  final String startTime;
  final String endTime;
  final double cost;
  final int score;
  final String note;
  final bool done;
  final String emoji;
  final double distanceKm;

  const _Activity({
    required this.id,
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.cost,
    required this.score,
    required this.note,
    required this.done,
    required this.emoji,
    required this.distanceKm,
  });

  _Activity copyWith({bool? done}) => _Activity(
        id: id,
        title: title,
        category: category,
        startTime: startTime,
        endTime: endTime,
        cost: cost,
        score: score,
        note: note,
        done: done ?? this.done,
        emoji: emoji,
        distanceKm: distanceKm,
      );
}
