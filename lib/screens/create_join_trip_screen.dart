import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'itinerary_view_screen.dart';

/// Trip mode enum — passed in from TripLobbyScreen
enum TripMode { create, join }

/// CreateJoinTripScreen — Create a new trip or join via invite code
///
/// Navigation position: Trip Lobby → [Create/Join Trip] → Itinerary View
///
/// Firebase hooks (to be wired by Backend Lead):
///   - Create: Firestore.collection('trips').add({name, destination, startDate, endDate, budget, ownerId})
///             then add the owner to 'members' subcollection
///   - Join:   Firestore.collection('trips').where('inviteCode', isEqualTo: code).get()
///             then update 'members' array to include current uid
class CreateJoinTripScreen extends StatefulWidget {
  final TripMode mode;

  const CreateJoinTripScreen({
    super.key,
    required this.mode,
  });

  @override
  State<CreateJoinTripScreen> createState() => _CreateJoinTripScreenState();
}

class _CreateJoinTripScreenState extends State<CreateJoinTripScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Create-mode fields
  final _tripNameController = TextEditingController();
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  // Join-mode field
  final _inviteCodeController = TextEditingController();

  bool _isLoading = false;

  late final AnimationController _entryController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  bool get _isCreate => widget.mode == TripMode.create;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _tripNameController.dispose();
    _destinationController.dispose();
    _budgetController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isCreate && (_startDate == null || _endDate == null)) {
      _showError('Please select your travel dates.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Simulate network call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ItineraryViewScreen(
              tripId: 't_${DateTime.now().millisecondsSinceEpoch}',
              destination: _isCreate
                  ? _destinationController.text.trim()
                  : 'Your Trip',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? (_startDate?.add(const Duration(days: 3)) ?? now));
    final first = isStart ? now : (_startDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day} ${_month(d.month)} ${d.year}';
  }

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Gradient header ──
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.gradientStart, AppColors.gradientMid],
              ),
            ),
          ),
          // ── Back button ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // ── Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 52),
                      // ── Header text ──
                      Text(
                        _isCreate ? '✈️  Plan a Trip' : '🔗  Join a Trip',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isCreate
                            ? 'Set up your adventure and invite your crew'
                            : 'Enter the invite code your trip organizer shared',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // ── Card ──
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: _isCreate ? _buildCreateForm() : _buildJoinForm(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── Submit button ──
                      GestureDetector(
                        onTap: _isLoading ? null : _handleSubmit,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: _isLoading
                                ? null
                                : const LinearGradient(
                                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                                  ),
                            color: _isLoading ? AppColors.textHint : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _isLoading
                                ? []
                                : [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _isCreate ? 'Create Trip 🌍' : 'Join Trip 🚀',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
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

  // ─── Create Trip Form ──────────────────────────────────────────────────────
  Widget _buildCreateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Trip Name'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _tripNameController,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a trip name' : null,
          decoration: const InputDecoration(
            hintText: 'e.g. Bali Squad Trip 2026',
            prefixIcon: Icon(Icons.beach_access_rounded, color: AppColors.textHint, size: 20),
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 18),
        _fieldLabel('Destination'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _destinationController,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a destination' : null,
          decoration: const InputDecoration(
            hintText: 'e.g. Bali, Indonesia',
            prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.textHint, size: 20),
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 18),
        _fieldLabel('Travel Dates'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _dateTile(isStart: true)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('→', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
            ),
            Expanded(child: _dateTile(isStart: false)),
          ],
        ),
        const SizedBox(height: 18),
        _fieldLabel('Total Budget (USD)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _budgetController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter a budget';
            if (int.tryParse(v) == null) return 'Invalid number';
            return null;
          },
          decoration: const InputDecoration(
            hintText: '2000',
            prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.textHint, size: 20),
            prefixText: '\$ ',
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _dateTile({required bool isStart}) {
    final date = isStart ? _startDate : _endDate;
    return GestureDetector(
      onTap: () => _pickDate(isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: date != null ? AppColors.primary : AppColors.inputBorder,
            width: date != null ? 1.5 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStart ? 'Start' : 'End',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 3),
            Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: date != null ? AppColors.textPrimary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Join Trip Form ────────────────────────────────────────────────────────
  Widget _buildJoinForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ask the trip organizer to share their 6-character invite code.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _fieldLabel('Invite Code'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _inviteCodeController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          validator: (v) {
            if (v == null || v.trim().length < 4) return 'Enter the invite code';
            return null;
          },
          decoration: const InputDecoration(
            hintText: 'ABC123',
            prefixIcon: Icon(Icons.vpn_key_outlined, color: AppColors.textHint, size: 20),
            counterText: '',
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 8,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
