// lib/features/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/validators.dart';
import 'login_screen.dart' show DotGridPainter;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _localLoading = false;

  // Multi-select state
  final Set<String> _selectedCrisisTypes = {};
  final Set<String> _selectedLocations = {};

  // Validation errors for chip groups
  String? _crisisError;
  String? _locationError;

  // Crisis types
  static const List<Map<String, String>> _crisisTypes = [
    {'key': 'food', 'label': 'Food/Ration'},
    {'key': 'medical', 'label': 'Medical'},
    {'key': 'education', 'label': 'Education'},
    {'key': 'emergency_cash', 'label': 'Emergency Cash'},
    {'key': 'flood_relief', 'label': 'Flood Relief'},
  ];

  // Locations
  static const List<String> _locations = [
    'Karachi', 'Lahore', 'Islamabad', 'Rawalpindi',
    'Quetta', 'Peshawar', 'Multan', 'Hyderabad', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuart));
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Password strength calculation
  double _getPasswordStrength(String password) {
    if (password.isEmpty) return 0.0;
    double strength = 0.0;
    if (password.length >= 8) strength += 0.25;
    if (password.length >= 12) strength += 0.15;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength += 0.2;
    return strength.clamp(0.0, 1.0);
  }

  String _getStrengthLabel(double strength) {
    if (strength < 0.35) return 'Weak';
    if (strength < 0.70) return 'Fair';
    return 'Strong';
  }

  Color _getStrengthColor(double strength) {
    if (strength < 0.35) return AppColors.critical;
    if (strength < 0.70) return AppColors.warning;
    return AppColors.primaryAccent;
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    // Validate chip groups
    setState(() {
      _crisisError = _selectedCrisisTypes.isEmpty ? 'Select at least one crisis type' : null;
      _locationError = _selectedLocations.isEmpty ? 'Select at least one location' : null;
    });

    final formValid = _formKey.currentState?.validate() ?? false;
    final chipsValid = _crisisError == null && _locationError == null;

    if (!formValid || !chipsValid) return;

    setState(() => _localLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      crisisTypes: _selectedCrisisTypes.toList(),
      locations: _selectedLocations.toList(),
    );

    if (mounted) {
      setState(() => _localLoading = false);

      if (success) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _SuccessDialog(
            onContinue: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        );
      } else {
        final error = authProvider.errorMessage ?? 'Registration failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.replaceAll('Exception: ', ''), style: AppTextStyles.bodyMedium(color: Colors.white)),
            backgroundColor: AppColors.critical,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topHeight = size.height * 0.25;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Dot grid background
          Positioned.fill(child: CustomPaint(painter: DotGridPainter())),

          // Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textMuted, size: 18),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),

          // Main layout
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: Column(
                    children: [
                      // Top branding block
                      SizedBox(
                        height: topHeight,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('RaahAI', style: AppTextStyles.heading2(color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(
                                'Humanitarian Intelligence Platform',
                                style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 10),
                              Container(width: 60, height: 2, color: AppColors.primaryAccent),
                            ],
                          ),
                        ),
                      ),

                      // Slide-up Form Card
                      Expanded(
                        child: SlideTransition(
                          position: _slideAnimation,
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
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Register your NGO', style: AppTextStyles.heading3(color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Create an account to start managing cases',
                                      style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                                    ),
                                    const SizedBox(height: 28),

                                    // ─── SECTION 1: Organization Details ───
                                    _SectionHeader(title: 'Organization Details'),
                                    const SizedBox(height: 16),

                                    _FieldLabel('Organization Name'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _nameController,
                                      key: const Key('register_name_field'),
                                      style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                                      validator: Validators.validateName,
                                      decoration: _buildInputDecoration('e.g. Saylani Welfare Trust'),
                                    ),
                                    const SizedBox(height: 16),

                                    _FieldLabel('Email Address'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _emailController,
                                      key: const Key('register_email_field'),
                                      keyboardType: TextInputType.emailAddress,
                                      style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                                      validator: Validators.validateEmail,
                                      decoration: _buildInputDecoration('admin@ngo.org'),
                                    ),
                                    const SizedBox(height: 16),

                                    _FieldLabel('Password'),
                                    const SizedBox(height: 8),
                                    StatefulBuilder(
                                      builder: (context, setLocalState) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            TextFormField(
                                              controller: _passwordController,
                                              key: const Key('register_password_field'),
                                              obscureText: _obscurePassword,
                                              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                                              onChanged: (_) => setLocalState(() {}),
                                              validator: (val) {
                                                if (val == null || val.isEmpty) return 'Password is required';
                                                if (val.length < 8) return 'Minimum 8 characters required';
                                                return null;
                                              },
                                              decoration: _buildInputDecoration('Min. 8 characters').copyWith(
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                                    color: AppColors.textMuted,
                                                  ),
                                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                                ),
                                              ),
                                            ),
                                            if (_passwordController.text.isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              _PasswordStrengthBar(
                                                strength: _getPasswordStrength(_passwordController.text),
                                                label: _getStrengthLabel(_getPasswordStrength(_passwordController.text)),
                                                color: _getStrengthColor(_getPasswordStrength(_passwordController.text)),
                                              ),
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    _FieldLabel('Confirm Password'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      key: const Key('register_confirm_password_field'),
                                      obscureText: _obscureConfirm,
                                      style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                                      validator: (val) {
                                        if (val == null || val.isEmpty) return 'Please confirm your password';
                                        if (val != _passwordController.text) return 'Passwords do not match';
                                        return null;
                                      },
                                      decoration: _buildInputDecoration('Repeat your password').copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                            color: AppColors.textMuted,
                                          ),
                                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 32),
                                    const _SectionDivider(),
                                    const SizedBox(height: 24),

                                    // ─── SECTION 2: Operational Coverage ───
                                    _SectionHeader(title: 'Operational Coverage'),
                                    const SizedBox(height: 16),

                                    _FieldLabel('Crisis Types Handled'),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _crisisTypes.map((type) {
                                        final selected = _selectedCrisisTypes.contains(type['key']);
                                        return _SelectableChip(
                                          label: type['label']!,
                                          selected: selected,
                                          onTap: () => setState(() {
                                            if (selected) {
                                              _selectedCrisisTypes.remove(type['key']);
                                            } else {
                                              _selectedCrisisTypes.add(type['key']!);
                                            }
                                            _crisisError = _selectedCrisisTypes.isEmpty
                                                ? 'Select at least one crisis type'
                                                : null;
                                          }),
                                        );
                                      }).toList(),
                                    ),
                                    if (_crisisError != null) ...[
                                      const SizedBox(height: 6),
                                      Text(_crisisError!, style: AppTextStyles.labelSmall(color: AppColors.critical)),
                                    ],

                                    const SizedBox(height: 20),

                                    _FieldLabel('Locations Served'),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _locations.map((loc) {
                                        final selected = _selectedLocations.contains(loc);
                                        return _SelectableChip(
                                          label: loc,
                                          selected: selected,
                                          onTap: () => setState(() {
                                            if (selected) {
                                              _selectedLocations.remove(loc);
                                            } else {
                                              _selectedLocations.add(loc);
                                            }
                                            _locationError = _selectedLocations.isEmpty
                                                ? 'Select at least one location'
                                                : null;
                                          }),
                                        );
                                      }).toList(),
                                    ),
                                    if (_locationError != null) ...[
                                      const SizedBox(height: 6),
                                      Text(_locationError!, style: AppTextStyles.labelSmall(color: AppColors.critical)),
                                    ],

                                    const SizedBox(height: 32),
                                    const _SectionDivider(),
                                    const SizedBox(height: 24),

                                    // ─── SECTION 3: Submit ───
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        key: const Key('register_submit_button'),
                                        onPressed: _localLoading ? null : _handleRegister,
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
                                                  Text('Register NGO ', style: AppTextStyles.heading4(color: AppColors.background)),
                                                  const Icon(Icons.arrow_forward, color: AppColors.background, size: 18),
                                                ],
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    Center(
                                      child: TextButton(
                                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                                        child: RichText(
                                          text: TextSpan(
                                            text: 'Already have an account? ',
                                            style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                                            children: [
                                              TextSpan(
                                                text: 'Sign In',
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

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      fillColor: AppColors.background,
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium(color: AppColors.textMuted),
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.labelMedium(color: AppColors.primaryAccent)),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.6), thickness: 1)),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTextStyles.labelMedium(color: AppColors.textPrimary));
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryAccent.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.primaryAccent : AppColors.border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium(
            color: selected ? AppColors.primaryAccent : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final double strength;
  final String label;
  final Color color;

  const _PasswordStrengthBar({
    required this.strength,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: strength,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Password strength: $label',
          style: AppTextStyles.labelSmall(color: color),
        ),
      ],
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final VoidCallback onContinue;
  const _SuccessDialog({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.primaryAccent,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text('NGO Registered!', style: AppTextStyles.heading3(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Your organization has been successfully registered. You can now sign in.',
              style: AppTextStyles.bodySmall(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Go to Sign In', style: AppTextStyles.labelMedium(color: AppColors.background)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
