import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// AddActivitiesScreen — Browse, search and add activities to a trip day
///
/// Navigation position:
///   Sign In → Trip Lobby → Itinerary View → [Add Activities] → Optimizer View
///
/// Firebase hooks (to be wired by Backend Lead):
///   - [_addActivity]       → Firestore trips/{id}/days[dayIndex].activities.add(...)
///   - [_searchActivities]  → Firestore activities collection with category + text filters
///   - Activity images      → Firebase Storage activity photo URLs
class AddActivitiesScreen extends StatefulWidget {
  final String tripId;
  final String tripDestination;
  final int selectedDayIndex;

  const AddActivitiesScreen({
    super.key,
    required this.tripId,
    required this.tripDestination,
    this.selectedDayIndex = 0,
  });

  @override
  State<AddActivitiesScreen> createState() => _AddActivitiesScreenState();
}

class _AddActivitiesScreenState extends State<AddActivitiesScreen>
    with TickerProviderStateMixin {
  // ─── Controllers ─────────────────────────────────────────────────────────
  final _searchController = TextEditingController();
  late final TabController _categoryTab;
  late final AnimationController _listFade;
  late final Animation<double> _listFadeAnim;

  // ─── State ────────────────────────────────────────────────────────────────
  String _searchQuery = '';
  int _selectedDay    = 0;
  final Set<String> _addedIds = {};

  static const _days = ['Day 1', 'Day 2', 'Day 3', 'Day 4'];

  static const _categories = [
    'All', 'Attraction', 'Beach', 'Adventure',
    'Food', 'Wellness', 'Culture', 'Nightlife',
  ];

  // ─── Mock data (replace with Firestore query) ─────────────────────────────
  final List<_Activity> _allActivities = [
    _Activity(
      id: 'a1', name: 'Tanah Lot Temple',
      category: 'Attraction', emoji: '🏛️',
      rating: 4.8, cost: 5.0, duration: '2 hrs', distance: '1.2 km',
      description: 'Iconic sea temple perched on a dramatic rock outcrop.',
      openHours: '7:00 AM – 7:00 PM',
      tags: ['Culture', 'Iconic', 'Photography'],
      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    _Activity(
      id: 'a2', name: 'Seminyak Beach',
      category: 'Beach', emoji: '🏖️',
      rating: 4.6, cost: 0.0, duration: '3 hrs', distance: '0.8 km',
      description: 'Pristine beach with stunning sunset views.',
      openHours: 'Open 24 hrs',
      tags: ['Sunset', 'Swimming', 'Free'],
      colors: [Color(0xFFFF6B6B), Color(0xFFFFB347)],
    ),
    _Activity(
      id: 'a3', name: 'Bali Swing Experience',
      category: 'Adventure', emoji: '🎢',
      rating: 4.9, cost: 35.0, duration: '1.5 hrs', distance: '3.5 km',
      description: 'Thrilling swings with jungle & rice terrace views.',
      openHours: '8:00 AM – 6:00 PM',
      tags: ['Thrilling', 'Instagram', 'Views'],
      colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
    ),
    _Activity(
      id: 'a4', name: 'Ubud Cooking Class',
      category: 'Food', emoji: '🍜',
      rating: 4.7, cost: 45.0, duration: '4 hrs', distance: '12 km',
      description: 'Learn to cook authentic Balinese dishes from a local chef.',
      openHours: '9:00 AM – 2:00 PM',
      tags: ['Culinary', 'Cultural', 'Hands-on'],
      colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
    ),
    _Activity(
      id: 'a5', name: 'Tegallalang Rice Terraces',
      category: 'Culture', emoji: '🌾',
      rating: 4.5, cost: 3.0, duration: '2 hrs', distance: '9 km',
      description: 'UNESCO-listed iconic stepped rice paddies.',
      openHours: '8:00 AM – 6:00 PM',
      tags: ['UNESCO', 'Scenic', 'Cultural'],
      colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
    ),
    _Activity(
      id: 'a6', name: 'Spa & Balinese Massage',
      category: 'Wellness', emoji: '💆',
      rating: 4.9, cost: 30.0, duration: '2 hrs', distance: '0.5 km',
      description: 'Traditional Balinese massage in a tranquil garden spa.',
      openHours: '9:00 AM – 9:00 PM',
      tags: ['Relaxation', 'Luxury', 'Traditional'],
      colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
    ),
    _Activity(
      id: 'a7', name: 'Kecak Fire Dance',
      category: 'Culture', emoji: '🔥',
      rating: 4.8, cost: 15.0, duration: '1.5 hrs', distance: '2.1 km',
      description: 'Mesmerising Hindu Ramayana dance performed at sunset.',
      openHours: '6:00 PM – 7:30 PM',
      tags: ['Performance', 'Cultural', 'Sunset'],
      colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
    ),
    _Activity(
      id: 'a8', name: 'Ku De Ta Rooftop Bar',
      category: 'Nightlife', emoji: '🍹',
      rating: 4.4, cost: 20.0, duration: '3 hrs', distance: '1.0 km',
      description: 'Iconic beach club with world-class cocktails & sunsets.',
      openHours: '11:00 AM – 2:00 AM',
      tags: ['Drinks', 'Sunset', 'Vibrant'],
      colors: [Color(0xFF4776E6), Color(0xFF8E54E9)],
    ),
  ];

  List<_Activity> get _filtered {
    final tab = _categoryTab.index;
    final cat = _categories[tab];
    return _allActivities.where((a) {
      final matchCat = cat == 'All' || a.category == cat;
      final matchQ   = _searchQuery.isEmpty ||
          a.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
      return matchCat && matchQ;
    }).toList();
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDayIndex;
    _categoryTab = TabController(length: _categories.length, vsync: this)
      ..addListener(() => setState(() {}));
    _listFade = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _listFadeAnim = CurvedAnimation(parent: _listFade, curve: Curves.easeOut);
    _listFade.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryTab.dispose();
    _listFade.dispose();
    super.dispose();
  }

  // ─── Handlers ────────────────────────────────────────────────────────────
  void _addActivity(_Activity activity) {
    HapticFeedback.lightImpact();
    setState(() => _addedIds.add(activity.id));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Text(activity.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text('${activity.name} added to ${_days[_selectedDay]}!',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: AppColors.primaryLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
      // TODO (Backend): Firestore write triggered here
    ));
  }

  void _removeActivity(_Activity activity) {
    HapticFeedback.lightImpact();
    setState(() => _addedIds.remove(activity.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${activity.name} removed.', style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showActivityDetail(_Activity activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityDetailSheet(
        activity: activity,
        isAdded: _addedIds.contains(activity.id),
        selectedDay: _days[_selectedDay],
        onAdd: () { Navigator.pop(context); _addActivity(activity); },
        onRemove: () { Navigator.pop(context); _removeActivity(activity); },
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildSliverAppBar(),
          _buildSearchBar(),
          _buildDaySelector(),
          _buildCategoryTabs(),
        ],
        body: FadeTransition(
          opacity: _listFadeAnim,
          child: _buildActivityList(),
        ),
      ),
    );
  }

  // ─── Sliver AppBar ────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add Activities',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        Text(widget.tripDestination,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
      ]),
      actions: [
        if (_addedIds.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 5),
              Text('${_addedIds.length} added',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
      ],
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.primary,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search activities, beaches, food...',
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Day Selector ─────────────────────────────────────────────────────────
  Widget _buildDaySelector() {
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Add to:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _days.length,
              itemBuilder: (_, i) {
                final selected = i == _selectedDay;
                return GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedDay = i); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: selected ? const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd], begin: Alignment.centerLeft, end: Alignment.centerRight) : null,
                      color: selected ? null : AppColors.inputFill,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.inputBorder, width: 1.2),
                    ),
                    child: Text(_days[i], style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    )),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Category Tabs ────────────────────────────────────────────────────────
  Widget _buildCategoryTabs() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CategoryTabDelegate(
        child: Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _categoryTab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicator: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd], begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(20),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tabs: _categories.map((c) => Tab(text: c)).toList(),
          ),
        ),
      ),
    );
  }

  // ─── Activity List ────────────────────────────────────────────────────────
  Widget _buildActivityList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔍', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        const Text('No activities found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Try a different search or category', style: TextStyle(color: AppColors.textSecondary)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final a = items[i];
        final added = _addedIds.contains(a.id);
        return _ActivityCard(
          activity: a,
          isAdded: added,
          onTap: () => _showActivityDetail(a),
          onAdd: () => added ? _removeActivity(a) : _addActivity(a),
        );
      },
    );
  }
}

// ─── Activity Card ────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final _Activity activity;
  final bool isAdded;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _ActivityCard({required this.activity, required this.isAdded, required this.onTap, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isAdded ? AppColors.primary : Colors.grey.shade100,
            width: isAdded ? 2 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          // ── Emoji gradient banner ──
          Container(
            width: 88,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: activity.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            child: Stack(children: [
              Center(child: Text(activity.emoji, style: const TextStyle(fontSize: 38))),
              if (isAdded)
                Positioned(top: 6, right: 6, child: Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 14),
                )),
            ]),
          ),

          // ── Content ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(activity.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                  _StarBadge(rating: activity.rating),
                ]),
                const SizedBox(height: 4),
                Text(activity.description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  _MiniChip(icon: Icons.access_time_rounded, label: activity.duration),
                  const SizedBox(width: 8),
                  _MiniChip(icon: Icons.near_me_rounded, label: activity.distance),
                  const SizedBox(width: 8),
                  _MiniChip(icon: Icons.attach_money_rounded, label: activity.cost == 0 ? 'Free' : '\$${activity.cost.toStringAsFixed(0)}', color: activity.cost == 0 ? AppColors.primaryLight : null),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Wrap(spacing: 4, children: activity.tags.take(2).map((t) => _Tag(label: t)).toList())),
                  GestureDetector(
                    onTap: onAdd,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isAdded ? null : const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd], begin: Alignment.centerLeft, end: Alignment.centerRight),
                        color: isAdded ? AppColors.inputFill : null,
                        borderRadius: BorderRadius.circular(20),
                        border: isAdded ? Border.all(color: AppColors.inputBorder) : null,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(isAdded ? Icons.remove_rounded : Icons.add_rounded, color: isAdded ? AppColors.textSecondary : Colors.white, size: 14),
                        const SizedBox(width: 3),
                        Text(isAdded ? 'Remove' : 'Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isAdded ? AppColors.textSecondary : Colors.white)),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Activity Detail Bottom Sheet ─────────────────────────────────────────────
class _ActivityDetailSheet extends StatelessWidget {
  final _Activity activity;
  final bool isAdded;
  final String selectedDay;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ActivityDetailSheet({
    required this.activity, required this.isAdded, required this.selectedDay,
    required this.onAdd, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          margin: const EdgeInsets.only(top: 14),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        )),

        // Header banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          height: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: activity.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(children: [
            Center(child: Text(activity.emoji, style: const TextStyle(fontSize: 64))),
            Positioned(top: 12, right: 12, child: _StarBadge(rating: activity.rating, large: true)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(activity.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(activity.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(activity.description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 16),

            // Info grid
            Row(children: [
              _DetailInfo(icon: Icons.access_time_rounded, label: 'Duration', value: activity.duration),
              _DetailInfo(icon: Icons.near_me_rounded, label: 'Distance', value: activity.distance),
              _DetailInfo(icon: Icons.attach_money_rounded, label: 'Cost', value: activity.cost == 0 ? 'Free' : '\$${activity.cost.toStringAsFixed(0)}'),
              _DetailInfo(icon: Icons.schedule_rounded, label: 'Hours', value: activity.openHours.split('–')[0].trim()),
            ]),
            const SizedBox(height: 16),

            // Tags
            Wrap(spacing: 8, runSpacing: 6, children: activity.tags.map((t) => _Tag(label: t)).toList()),
            const SizedBox(height: 20),

            // Action button
            GestureDetector(
              onTap: isAdded ? onRemove : onAdd,
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  gradient: isAdded ? null : const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd], begin: Alignment.centerLeft, end: Alignment.centerRight),
                  color: isAdded ? AppColors.error.withOpacity(0.08) : null,
                  borderRadius: BorderRadius.circular(14),
                  border: isAdded ? Border.all(color: AppColors.error.withOpacity(0.3)) : null,
                  boxShadow: isAdded ? null : [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(isAdded ? Icons.remove_circle_outline : Icons.add_circle_outline,
                      color: isAdded ? AppColors.error : Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(isAdded ? 'Remove from $selectedDay' : 'Add to $selectedDay',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isAdded ? AppColors.error : Colors.white)),
                ])),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ]),
    );
  }
}

// ─── Small Widgets ────────────────────────────────────────────────────────────

class _StarBadge extends StatelessWidget {
  final double rating;
  final bool large;
  const _StarBadge({required this.rating, this.large = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: large ? 10 : 7, vertical: large ? 5 : 3),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, color: const Color(0xFFFFD700), size: large ? 16 : 12),
      const SizedBox(width: 3),
      Text(rating.toStringAsFixed(1), style: TextStyle(color: Colors.white, fontSize: large ? 13 : 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MiniChip({required this.icon, required this.label, this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: color ?? AppColors.textSecondary),
    const SizedBox(width: 2),
    Text(label, style: TextStyle(fontSize: 11, color: color ?? AppColors.textSecondary, fontWeight: FontWeight.w500)),
  ]);
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)),
    child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
  );
}

class _DetailInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailInfo({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, size: 18, color: AppColors.primary),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
  ]));
}

// ─── Category Tab Delegate ────────────────────────────────────────────────────
class _CategoryTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _CategoryTabDelegate({required this.child});
  @override double get minExtent => 54;
  @override double get maxExtent => 54;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override bool shouldRebuild(_CategoryTabDelegate old) => old.child != child;
}

// ─── Data Model ───────────────────────────────────────────────────────────────
class _Activity {
  final String id, name, category, emoji, duration, distance, description, openHours;
  final double rating, cost;
  final List<String> tags;
  final List<Color> colors;

  const _Activity({
    required this.id, required this.name, required this.category, required this.emoji,
    required this.rating, required this.cost, required this.duration, required this.distance,
    required this.description, required this.openHours, required this.tags, required this.colors,
  });
}