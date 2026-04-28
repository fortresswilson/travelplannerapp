import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// SignInScreen — TropicaGuide Entry Point
///
/// Navigation: This screen is the first stop in the flow:
///   Sign In → Trip Lobby → Create/Join Trip → ...
///
/// Firebase hooks (to be wired by Backend Lead):
///   - [_handleEmailSignIn] → FirebaseAuth.signInWithEmailAndPassword
///   - [_handleGoogleSignIn] → GoogleAuthProvider + FirebaseAuth.signInWithCredential
///   - [_handleForgotPassword] → FirebaseAuth.sendPasswordResetEmail
///   - [_navigateToSignUp]   → push to SignUpScreen (to be built next)
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with TickerProviderStateMixin {
  // ─── Form ───────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  // ─── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _waveController;
  late final AnimationController _fadeController;
  late final AnimationController _slideController;

  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Continuous wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Fade-in on load
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Slide-up on load
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Trigger entrance animations
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Handlers ───────────────────────────────────────────────────────────────

  /// TODO (Backend): Replace body with FirebaseAuth.signInWithEmailAndPassword
  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Simulate network call — remove when Firebase is wired
      await Future.delayed(const Duration(seconds: 2));

      // On success → navigate to Trip Lobby
      if (mounted) {
        _showSuccessSnackBar('Welcome back, explorer! 🌴');
        // Navigator.pushReplacementNamed(context, '/lobby');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Sign in failed. Please check your credentials.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// TODO (Backend): Replace with GoogleAuthProvider flow
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _showSuccessSnackBar('Google sign-in coming soon!');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// TODO (Backend): FirebaseAuth.sendPasswordResetEmail
  void _handleForgotPassword() {
    if (_emailController.text.isEmpty) {
      _showErrorSnackBar('Enter your email first to reset your password.');
      return;
    }
    _showSuccessSnackBar('Password reset email sent to ${_emailController.text}');
  }

  void _navigateToSignUp() {
    // Navigator.pushNamed(context, '/signup');
    _showSuccessSnackBar('Sign Up screen coming soon!');
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Animated wave header background ──
          _buildWaveBackground(size),

          // ── Main scrollable content ──
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section (logo + tagline)
                  _buildHeader(size),

                  // Card form section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildFormCard(),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sub-builders ────────────────────────────────────────────────────────────

  Widget _buildWaveBackground(Size size) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(size.width, size.height * 0.42),
          painter: _TropicalWavePainter(animation: _waveController.value),
        );
      },
    );
  }

  Widget _buildHeader(Size size) {
    return SizedBox(
      height: size.height * 0.36,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo / icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              ),
              child: const Center(
                child: Text('🌴', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'TropicaGuide',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Plan together. Explore together.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.10),
              blurRadius: 30,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Section heading ──
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sign in to continue your adventure',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Email ──
              _buildLabel('Email address'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: _validateEmail,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: Icon(Icons.mail_outline_rounded,
                        color: AppColors.textHint, size: 20),
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
              const SizedBox(height: 16),

              // ── Password ──
              _buildLabel('Password'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleEmailSignIn(),
                validator: _validatePassword,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: Icon(Icons.lock_outline_rounded,
                        color: AppColors.textHint, size: 20),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    splashRadius: 20,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Remember me + Forgot password ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Transform.scale(
                        scale: 0.85,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                        ),
                      ),
                      const Text(
                        'Remember me',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _handleForgotPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Sign In button ──
              _buildSignInButton(),
              const SizedBox(height: 20),

              // ── Divider ──
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey.shade200, thickness: 1.2),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'or continue with',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey.shade200, thickness: 1.2),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Google Sign In ──
              _buildGoogleButton(),
              const SizedBox(height: 24),

              // ── Sign Up link ──
              Center(
                child: RichText(
                  text: TextSpan(
                    text: "New to TropicaGuide? ",
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: 'Create account',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = _navigateToSignUp,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSignInButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        gradient: _isLoading
            ? null
            : const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: _isLoading ? AppColors.inputFill : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _isLoading
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isLoading ? null : _handleEmailSignIn,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Google "G" icon drawn with colored text (no assets needed)
          _GoogleGIcon(),
          const SizedBox(width: 10),
          const Text(
            'Continue with Google',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tropical Wave Painter ────────────────────────────────────────────────────

class _TropicalWavePainter extends CustomPainter {
  final double animation;

  _TropicalWavePainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    // Back wave (lighter teal)
    final backPaint = Paint()
      ..color = const Color(0xFF14A085).withOpacity(0.55)
      ..style = PaintingStyle.fill;

    // Mid wave
    final midPaint = Paint()
      ..color = const Color(0xFF0D7377).withOpacity(0.80)
      ..style = PaintingStyle.fill;

    // Front wave (primary)
    final frontPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0D7377), Color(0xFF14A085)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    _drawWave(canvas, size, backPaint,  amplitude: 22, speed: animation,       yBase: 0.76);
    _drawWave(canvas, size, midPaint,   amplitude: 18, speed: animation + 0.3, yBase: 0.80);
    _drawWave(canvas, size, frontPaint, amplitude: 14, speed: animation + 0.6, yBase: 0.84);
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    Paint paint, {
    required double amplitude,
    required double speed,
    required double yBase,
  }) {
    final path = Path();
    final baseY = size.height * yBase;

    path.moveTo(0, baseY);

    for (double x = 0; x <= size.width; x++) {
      final y = baseY +
          amplitude *
              math.sin((x / size.width * 2 * math.pi) + (speed * 2 * math.pi));
      path.lineTo(x, y);
    }

    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TropicalWavePainter oldDelegate) =>
      oldDelegate.animation != animation;
}

// ─── Google G Icon (no external assets) ──────────────────────────────────────

class _GoogleGIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw colored circle arcs to mimic the Google "G"
    final colors = [
      const Color(0xFF4285F4), // blue
      const Color(0xFF34A853), // green
      const Color(0xFFFBBC05), // yellow
      const Color(0xFFEA4335), // red
    ];
    final sweeps = [math.pi * 0.5, math.pi * 0.5, math.pi * 0.5, math.pi * 0.5];
    final starts = [
      -math.pi * 0.25,
      math.pi * 0.25,
      math.pi * 0.75,
      math.pi * 1.25,
    ];

    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1),
        starts[i],
        sweeps[i],
        false,
        Paint()
          ..color = colors[i]
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    // White fill center
    canvas.drawCircle(
        center, radius - 3.5, Paint()..color = Colors.white);

    // "G" bar (right side cutout detail)
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - 2, radius - 1, 4),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter old) => false;
}
