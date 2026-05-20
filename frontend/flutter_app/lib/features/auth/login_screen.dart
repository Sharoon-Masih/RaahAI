// lib/features/auth/login_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/validators.dart';
import '../home/home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _shakeController;
  bool _obscurePassword = true;
  bool _localLoading = false; // For showing the loader in sync state

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // Trigger shake animation on 401 error
  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  // Submit Login Action
  Future<void> _handleLogin() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _localLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final success = await authProvider.login(email, password);

      if (mounted) {
        setState(() {
          _localLoading = false;
        });

        if (success) {
          // Success: Navigate with a clean fade transition to HomeShell
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomeShell(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
            (route) => false,
          );
        } else {
          final error = authProvider.errorMessage ?? '';
          _triggerShake();

          if (error.contains('401') || error.toLowerCase().contains('invalid') || error.toLowerCase().contains('unauthorized')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Invalid credentials',
                  style: AppTextStyles.bodyMedium(color: Colors.white),
                ),
                backgroundColor: AppColors.critical,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Connection failed. Check your internet.',
                  style: AppTextStyles.bodyMedium(color: Colors.white),
                ),
                backgroundColor: AppColors.critical,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } else {
      // Trigger a shake even for client validation failure
      _triggerShake();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topHeight = size.height * 0.40;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background CSS-style dot grid overlay
          Positioned.fill(
            child: CustomPaint(
              painter: DotGridPainter(),
            ),
          ),

          // Main Layout
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      // Top 40%: App logo/wordmark
                      SizedBox(
                        height: topHeight,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'RaahAI',
                                style: AppTextStyles.heading1(color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Humanitarian Intelligence Platform',
                                style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 12),
                              // Subtle green accent line (2px, #00C896)
                              Container(
                                width: 80,
                                height: 2,
                                color: AppColors.primaryAccent,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom 60%: Content card sliding up
                      Expanded(
                        child: SlideUpWidget(
                          child: ShakeWidget(
                            controller: _shakeController,
                            child: Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                border: Border(
                                  top: BorderSide(color: AppColors.border, width: 1.5),
                                  left: BorderSide(color: AppColors.border, width: 1.5),
                                  right: BorderSide(color: AppColors.border, width: 1.5),
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              padding: const EdgeInsets.all(28.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back',
                                      style: AppTextStyles.heading3(color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Sign in to your NGO account',
                                      style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                                    ),
                                    const SizedBox(height: 24),

                                    // Email Field
                                    Text(
                                      'Email address',
                                      style: AppTextStyles.labelMedium(color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _emailController,
                                      style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: Validators.validateEmail,
                                      key: const Key('login_email_field'),
                                      decoration: InputDecoration(
                                        fillColor: AppColors.background,
                                        hintText: 'you@ngo.org',
                                        hintStyle: AppTextStyles.bodyMedium(color: AppColors.textMuted),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Password Field
                                    Text(
                                      'Password',
                                      style: AppTextStyles.labelMedium(color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                                      obscureText: _obscurePassword,
                                      key: const Key('login_password_field'),
                                      validator: (val) {
                                        if (val == null || val.isEmpty) {
                                          return 'Password is required';
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        fillColor: AppColors.background,
                                        hintText: 'Enter password',
                                        hintStyle: AppTextStyles.bodyMedium(color: AppColors.textMuted),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                            color: AppColors.textMuted,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Sign In Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        key: const Key('login_submit_button'),
                                        onPressed: _localLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryAccent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: _localLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.background),
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Sign In ',
                                                    style: AppTextStyles.heading4(color: AppColors.background),
                                                  ),
                                                  const Icon(
                                                    Icons.arrow_forward,
                                                    color: AppColors.background,
                                                    size: 18,
                                                  )
                                                ],
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Register Navigation option
                                    Center(
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(context, '/register');
                                        },
                                        child: RichText(
                                          text: TextSpan(
                                            text: 'New to RaahAI? ',
                                            style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                                            children: [
                                              TextSpan(
                                                text: 'Register your NGO',
                                                style: AppTextStyles.bodySmall(color: AppColors.secondary).copyWith(
                                                  decoration: TextDecoration.underline,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// DotGridPainter for CSS-style background dot pattern
// -------------------------------------------------------------
class DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E2D45).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    const double spacing = 24.0;
    const double radius = 1.2;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// SlideUpWidget for smooth card entry transition on load
// -------------------------------------------------------------
class SlideUpWidget extends StatefulWidget {
  final Widget child;
  const SlideUpWidget({super.key, required this.child});

  @override
  State<SlideUpWidget> createState() => _SlideUpWidgetState();
}

class _SlideUpWidgetState extends State<SlideUpWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: widget.child,
    );
  }
}

// -------------------------------------------------------------
// ShakeWidget for input form error feedback vibration effect
// -------------------------------------------------------------
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final AnimationController controller;

  const ShakeWidget({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> {
  late final Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _offsetAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 15.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 15.0, end: -15.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -15.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0), weight: 1),
    ]).animate(widget.controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
