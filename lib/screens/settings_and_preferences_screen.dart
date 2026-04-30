import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';

/// SettingsAndPreferencesScreen — App-wide settings and travel preferences
///
/// Navigation position:
///   Trip Lobby → User Profile → [Settings & Preferences]
///   (also accessible via nav drawer or profile menu)
///
/// Firebase hooks (to be wired by Backend Lead):
///   - [_saveNotificationSettings] → Firestore.doc('users/{uid}').update({'notifications': {...}})
///   - [_savePrivacySettings]      → Firestore.doc('users/{uid}').update({'privacy': {...}})
///   - [_saveTravelPreferences]    → Firestore.doc('users/{uid}').update({'travelPrefs': {...}})
///   - [_saveBudgetLimit]          → Firestore.doc('users/{uid}').update({'defaultBudget': value})
///   - [_handleSignOut]            → FirebaseAuth.instance.signOut()
///   - [_handleDeleteAccount]      → FirebaseAuth.currentUser.delete() + Firestore cleanup
class SettingsAndPreferencesScreen extends StatefulWidget {
  const SettingsAndPreferencesScreen({super.key});

  @override
  State<SettingsAndPreferencesScreen> createState() =>
      _SettingsAndPreferencesScreenState();
}

class _SettingsAndPreferencesScreenState
    extends State<SettingsAndPreferencesScreen>
    with TickerProviderStateMixin {
  // ─── Animation ────────────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─── Notification settings ────────────────────────────────────────────────
  bool _notifyNewMessage      = true;
  bool _notifyVoteOpen        = true;
  bool _notifyItineraryUpdate = true;
  bool _notifyBudgetAlert     = true;
  bool _notifyTripReminder    = true;
  bool _notifyGroupJoin       = false;

  // ─── Privacy settings ─────────────────────────────────────────────────────
  bool _profileVisible        = true;
  bool _showTripHistory       = true;
  bool _allowGroupInvites     = true;
  bool _shareLocationInTrip   = true;

  // ─── Travel preferences ───────────────────────────────────────────────────
  String _defaultBudgetRange  = '\$2k – \$5k';
  String _travelStyle         = 'Balanced';
  String _preferredClimate    = 'Tropical';
  String _groupSizePreference = '3–5 people';

  // ─── Budget ───────────────────────────────────────────────────────────────
  double _defaultBudget = 3000;
  final _budgetController = TextEditingController();
  bool _editingBudget = false;

  // ─── Currency & Units ─────────────────────────────────────────────────────
  String _currency  = 'USD (\$)';
  String _distanceUnit = 'Kilometres';

  // ─── App appearance ───────────────────────────────────────────────────────
  bool _darkMode = false;

  // ─── Expanded section tracker ─────────────────────────────────────────────
  int? _expandedSection;

  @override
  void initState() {
    super.initState();
    _budgetController.text = _defaultBudget.toStringAsFixed(0);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  // ─── Handlers ─────────────────────────────────────────────────────────────
  void _saveBudget() {
    final value = double.tryParse(_budgetController.text);
    if (value == null || value <= 0) {
      _showErrorSnackBar('Enter a valid budget amount.');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _defaultBudget  = value;
      _editingBudget  = false;
    });
    _showSuccessSnackBar('Default budget updated to \$${value.toStringAsFixed(0)}');
    // TODO (Backend): Firestore.doc('users/{uid}').update({'defaultBudget': value})
  }

  void _handleSignOut() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out of TropicaGuide?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO (Backend): FirebaseAuth.instance.signOut()
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SignInScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent)),
        content: const Text(
          'This will permanently delete your account, all trips, and your travel data. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO (Backend): FirebaseAuth.currentUser.delete() + Firestore batch delete
              _showErrorSnackBar('Account deletion — wire Firebase here.');
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.primaryLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.error,
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Notification Settings ──
                      _buildSectionCard(
                        index: 0,
                        icon: '🔔',
                        iconColor: const Color(0xFFFFB347),
                        title: 'Notifications',
                        subtitle: 'Control when TropicaGuide alerts you',
                        children: [
                          _buildToggleRow(
                            label: 'New group messages',
                            sublabel: 'When a member posts in your trip chat',
                            value: _notifyNewMessage,
                            onChanged: (v) {
                              setState(() => _notifyNewMessage = v);
                              // TODO: Firestore update
                            },
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            label: 'Vote opened',
                            sublabel: 'When a new activity vote is created',
                            value: _notifyVoteOpen,
                            onChanged: (v) {
                              setState(() => _notifyVoteOpen = v);
                            },
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            label: 'Itinerary updates',
                            sublabel: 'Activities added, removed or reordered',
                            value: _notifyItineraryUpdate,
                            onChanged: (v) {
                              setState(() => _notifyItineraryUpdate = v);
                            },
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            label: 'Budget alerts',
                            sublabel: 'When spending exceeds 85% of budget',
                            value: _notifyBudgetAlert,
                            onChanged: (v) {
                              setState(() => _notifyBudgetAlert = v);
                            },
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            label: 'Trip reminders',
                            sublabel: '24 h before your trip departs',
                            value: _notifyTripReminder,
                            onChanged: (v) {
                              setState(() => _notifyTripReminder = v);
                            },
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            label: 'Group join requests',
                            sublabel: 'When someone asks to join your trip',
                            value: _notifyGroupJoin,
                            onChanged: (v) {
                              setState(() => _notifyGroupJoin = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Privacy Controls ──
                      _buildSectionCard(
                        index: 1,
                        icon: '🔒',
                        iconColor: const Color(0xFF667EEA),
                        title: 'Privacy',
                        subtitle: 'Manage who can see your data',
                        children: [
                          _buildToggleRow(
                            label: 'Public profile',
                            sublabel: 'Other travellers can find your profile',
                            value: _profileVisible,
                            onChanged: (v) {
                              setState(() => _profileVisible = v);
                            },
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            label: 'Show trip history',
                            sublabel: 'Past destinations visible on your profile',
                            value: _showTripHistory,
                            onChanged: (v) {
                              setState(() => _showTripHistory = v);
                            },
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            label: 'Allow group invites',
                            sublabel: 'Anyone can invite you to a trip',
                            value: _allowGroupInvites,
                            onChanged: (v) {
                              setState(() => _allowGroupInvites = v);
                            },
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            label: 'Share location in trip',
                            sublabel: 'Let trip members see your live location',
                            value: _shareLocationInTrip,
                            onChanged: (v) {
                              setState(() => _shareLocationInTrip = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Budget Limits ──
                      _buildSectionCard(
                        index: 2,
                        icon: '💰',
                        iconColor: AppColors.primaryLight,
                        title: 'Budget Limits',
                        subtitle: 'Set default spending targets for new trips',
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Default Trip Budget',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        if (_editingBudget) {
                                          _saveBudget();
                                        } else {
                                          setState(() => _editingBudget = true);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.10),
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
                                const SizedBox(height: 10),
                                _editingBudget
                                    ? TextField(
                                        controller: _budgetController,
                                        keyboardType: TextInputType.number,
                                        autofocus: true,
                                        onSubmitted: (_) => _saveBudget(),
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                        decoration: const InputDecoration(
                                          prefixText: '\$',
                                          prefixStyle: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      )
                                    : Text(
                                        '\$${_defaultBudget.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Applied when you create a new trip. You can override per trip.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Budget Range Preference',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 10),
                                _buildOptionPicker(
                                  options: ['\$500–\$1k', '\$1k–\$2k', '\$2k–\$5k', '\$5k+'],
                                  selected: _defaultBudgetRange,
                                  onSelect: (v) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _defaultBudgetRange = v);
                                    // TODO: Firestore update
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Travel Preferences ──
                      _buildSectionCard(
                        index: 3,
                        icon: '✈️',
                        iconColor: AppColors.primary,
                        title: 'Travel Preferences',
                        subtitle: 'Help the optimizer match activities to you',
                        children: [
                          _buildPreferencePicker(
                            label: 'Travel Style',
                            emoji: '🧭',
                            options: ['Relaxed', 'Balanced', 'Adventure', 'Luxury', 'Budget'],
                            selected: _travelStyle,
                            onSelect: (v) {
                              HapticFeedback.selectionClick();
                              setState(() => _travelStyle = v);
                              // TODO: Firestore update
                            },
                          ),
                          _buildDivider(),
                          _buildPreferencePicker(
                            label: 'Preferred Climate',
                            emoji: '🌤️',
                            options: ['Tropical', 'Mediterranean', 'Cold', 'Desert', 'Any'],
                            selected: _preferredClimate,
                            onSelect: (v) {
                              HapticFeedback.selectionClick();
                              setState(() => _preferredClimate = v);
                            },
                          ),
                          _buildDivider(),
                          _buildPreferencePicker(
                            label: 'Group Size',
                            emoji: '👥',
                            options: ['Solo', '2 people', '3–5 people', '6–10 people', '10+'],
                            selected: _groupSizePreference,
                            onSelect: (v) {
                              HapticFeedback.selectionClick();
                              setState(() => _groupSizePreference = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── App Settings ──
                      _buildSectionCard(
                        index: 4,
                        icon: '⚙️',
                        iconColor: AppColors.textSecondary,
                        title: 'App Settings',
                        subtitle: 'Display, units and regional preferences',
                        children: [
                          _buildToggleRow(
                            label: 'Dark Mode',
                            sublabel: 'Switch to a dark colour scheme',
                            value: _darkMode,
                            onChanged: (v) {
                              setState(() => _darkMode = v);
                              // TODO: ThemeMode switch via Provider / Riverpod
                            },
                          ),
                          _buildDivider(),
                          _buildPreferencePicker(
                            label: 'Currency',
                            emoji: '💱',
                            options: ['USD (\$)', 'EUR (€)', 'GBP (£)', 'INR (₹)', 'AUD (A\$)'],
                            selected: _currency,
                            onSelect: (v) {
                              HapticFeedback.selectionClick();
                              setState(() => _currency = v);
                            },
                          ),
                          _buildDivider(),
                          _buildPreferencePicker(
                            label: 'Distance Unit',
                            emoji: '📏',
                            options: ['Kilometres', 'Miles'],
                            selected: _distanceUnit,
                            onSelect: (v) {
                              HapticFeedback.selectionClick();
                              setState(() => _distanceUnit = v);
                            },
                          ),
                          _buildDivider(),
                          _buildTapRow(
                            label: 'Clear cache',
                            sublabel: 'Free up locally stored trip data',
                            emoji: '🗑️',
                            onTap: () => _showSuccessSnackBar('Cache cleared successfully.'),
                          ),
                          _buildDivider(),
                          _buildTapRow(
                            label: 'Rate TropicaGuide',
                            sublabel: 'Leave us a review on the App Store',
                            emoji: '⭐',
                            onTap: () => _showSuccessSnackBar('Thanks for the love! 🌴'),
                          ),
                          _buildDivider(),
                          _buildTapRow(
                            label: 'Send feedback',
                            sublabel: 'Report a bug or suggest a feature',
                            emoji: '📬',
                            onTap: () => _showSuccessSnackBar('Feedback screen — coming soon!'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── About ──
                      _buildSectionCard(
                        index: 5,
                        icon: 'ℹ️',
                        iconColor: const Color(0xFF9B59B6),
                        title: 'About',
                        subtitle: 'Version info and legal',
                        children: [
                          _buildTapRow(
                            label: 'Version',
                            sublabel: '1.0.0 (build 42)',
                            emoji: '📦',
                            onTap: null,
                            trailing: const Text(
                              'Up to date',
                              style: TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                            ),
                          ),
                          _buildDivider(),
                          _buildTapRow(
                            label: 'Terms of Service',
                            sublabel: 'Read our terms and conditions',
                            emoji: '📄',
                            onTap: () {},
                          ),
                          _buildDivider(),
                          _buildTapRow(
                            label: 'Privacy Policy',
                            sublabel: 'How we handle your data',
                            emoji: '🛡️',
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Account Actions ──
                      _buildSignOutButton(),
                      const SizedBox(height: 12),
                      _buildDeleteAccountButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sliver AppBar ────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings & Preferences',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            'Customise your TropicaGuide experience',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ─── Section Card ─────────────────────────────────────────────────────────
  Widget _buildSectionCard({
    required int index,
    required String icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade100, height: 1),
          ...children,
        ],
      ),
    );
  }

  // ─── Toggle row ───────────────────────────────────────────────────────────
  Widget _buildToggleRow({
    required String label,
    required String sublabel,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(sublabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade200,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }

  // ─── Preference picker row (dropdown-style chips) ─────────────────────────
  Widget _buildPreferencePicker({
    required String label,
    required String emoji,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = opt == selected;
              return GestureDetector(
                onTap: () => onSelect(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.inputFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.inputBorder,
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Option picker (horizontal chips for fewer options) ───────────────────
  Widget _buildOptionPicker({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          return GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.inputFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.inputBorder,
                  width: 1.2,
                ),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Tap row (navigable rows with no toggle) ──────────────────────────────
  Widget _buildTapRow({
    required String label,
    required String sublabel,
    required String emoji,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  // ─── Divider ──────────────────────────────────────────────────────────────
  Widget _buildDivider() => Divider(color: Colors.grey.shade100, height: 1, indent: 16, endIndent: 16);

  // ─── Sign Out button ──────────────────────────────────────────────────────
  Widget _buildSignOutButton() {
    return OutlinedButton(
      onPressed: _handleSignOut,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, size: 18),
          SizedBox(width: 10),
          Text('Sign Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ─── Delete account button ────────────────────────────────────────────────
  Widget _buildDeleteAccountButton() {
    return TextButton(
      onPressed: _handleDeleteAccount,
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        foregroundColor: AppColors.error,
      ),
      child: const Text(
        'Delete Account',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
      ),
    );
  }
}
