import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import 'trip_lobby_screen.dart';
 import 'package:firebase_auth/firebase_auth.dart';
 import '../services/auth_service.dart';

/// SignUpScreen — New user registration
///
/// Navigation position: Sign In → [Sign Up] → Trip Lobby
///
/// Firebase hooks (to be wired by Backend Lead):
///   - [_handleSignUp] → FirebaseAuth.createUserWithEmailAndPassword
///                       then Firestore.doc('users/{uid}').set({name, email, createdAt})
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late final AnimationController _entryController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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

  Future<void> _handleSignUp() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);
  try {
    await _authService.signUpWithEmail(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
  } on FirebaseAuthException catch (e) {
    if (mounted) {
      final msg = switch (e.code) {
        'email-already-in-use' => 'An account with this email already exists.',
        'invalid-email'        => 'That email address is not valid.',
        'weak-password'        => 'Password must be at least 6 characters.',
        _                      => 'Sign up failed: ${e.message}',
      };
      _showErrorSnackBar(msg);
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Wave header ──
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 220),
            painter: _WavePainter(),
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
                      const SizedBox(height: 60),
                      // ── Title ──
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.18),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text('🌴', style: TextStyle(fontSize: 30)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Join TropicaGuide and start planning',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      // ── Form ──
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildField(
                              controller: _nameController,
                              label: 'Full Name',
                              hint: 'Your name',
                              icon: Icons.person_outline_rounded,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Name is required';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'you@example.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Email is required';
                                if (!v.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Min. 8 characters',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePassword,
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
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Password is required';
                                if (v.length < 8) return 'Minimum 8 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _confirmController,
                              label: 'Confirm Password',
                              hint: 'Re-enter your password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscureConfirm,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textHint,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              validator: (v) {
                                if (v != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),
                            // ── Sign Up Button ──
                            _isLoading
                                ? Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.gradientStart,
                                          AppColors.gradientEnd,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: _handleSignUp,
                                    child: Container(
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppColors.gradientStart,
                                            AppColors.gradientEnd,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Create Account',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                            const SizedBox(height: 24),
                            // ── Sign In link ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

// ─── Wave Painter ──────────────────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..lineTo(0, size.height - 50)
      ..quadraticBezierTo(
        size.width * 0.25, size.height,
        size.width * 0.5, size.height - 30,
      )
      ..quadraticBezierTo(
        size.width * 0.75, size.height - 60,
        size.width, size.height - 20,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
