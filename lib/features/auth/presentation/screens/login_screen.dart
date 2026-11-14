import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  late final AnimationController _entrance;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      if (_isRegisterMode) {
        context.read<AuthBloc>().add(
              AuthRegisterRequested(
                username: username,
                password: password,
              ),
            );
      } else {
        context.read<AuthBloc>().add(
              AuthLoginRequested(
                username: username,
                password: password,
              ),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              widget.onLoginSuccess();
            } else if (state is AuthFailureState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: theme.colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Stack(
              children: [
                const _PosTerminalBackdrop(),
                SafeArea(
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              16,
                              20,
                              24 + bottomInset,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight - 40,
                                maxWidth: 460,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _PosTopStatusBar(),
                                    const SizedBox(height: 28),
                                    const _PosBrandHero(),
                                    const SizedBox(height: 28),
                                    _PosAuthPanel(
                                      formKey: _formKey,
                                      isRegisterMode: _isRegisterMode,
                                      isLoading: isLoading,
                                      obscurePassword: _obscurePassword,
                                      usernameController: _usernameController,
                                      passwordController: _passwordController,
                                      confirmPasswordController:
                                          _confirmPasswordController,
                                      onToggleObscure: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      onModeChanged: (register) {
                                        setState(() {
                                          _isRegisterMode = register;
                                        });
                                      },
                                      onSubmit: _submit,
                                    ),
                                    const Spacer(),
                                    const SizedBox(height: 24),
                                    const _PosFooterStrip(),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PosTerminalBackdrop extends StatelessWidget {
  const _PosTerminalBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.posNavy,
            AppColors.posInk,
            Color(0xFF0F2A44),
            Color(0xFF081624),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _PosGridPainter()),
          Align(
            alignment: Alignment.topRight,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-1.1, 0.85),
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.posAccent.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PosTopStatusBar extends StatelessWidget {
  const _PosTopStatusBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(
          icon: Icons.storefront_rounded,
          label: 'STORE #104',
        ),
        const SizedBox(width: 8),
        _chip(
          icon: Icons.point_of_sale_rounded,
          label: 'TERMINAL',
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.posAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.posAccent.withValues(alpha: 0.45),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: AppColors.posAccent),
              SizedBox(width: 6),
              Text(
                'ONLINE',
                style: TextStyle(
                  color: AppColors.posAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosBrandHero extends StatelessWidget {
  const _PosBrandHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, Color(0xFF1565C0)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LAANTECH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      height: 1.05,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'POS CATALOG SYNC',
                    style: TextStyle(
                      color: AppColors.posWarm,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Operator terminal access',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to sync product catalogs, media packs, and audit exports for this store.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PosAuthPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool isRegisterMode;
  final bool isLoading;
  final bool obscurePassword;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSubmit;

  const _PosAuthPanel({
    required this.formKey,
    required this.isRegisterMode,
    required this.isLoading,
    required this.obscurePassword,
    required this.usernameController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onToggleObscure,
    required this.onModeChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.posPanel : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_person_rounded,
                  size: 18,
                  color: isDark ? AppColors.posAccent : AppColors.posInk,
                ),
                const SizedBox(width: 8),
                Text(
                  isRegisterMode ? 'Create operator account' : 'Terminal login',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppColors.posInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PosModeSwitch(
              isRegisterMode: isRegisterMode,
              enabled: !isLoading,
              onChanged: onModeChanged,
            ),
            const SizedBox(height: 18),
            AppTextFormField(
              controller: usernameController,
              enabled: !isLoading,
              labelText: 'Operator ID',
              hintText: 'e.g. cashier_01',
              prefixIcon: const Icon(Icons.badge_outlined),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your operator ID';
                }
                if (value.trim().length < 3) {
                  return 'Operator ID must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              enabled: !isLoading,
              labelText: 'Passcode',
              hintText: 'Enter passcode',
              prefixIcon: const Icon(Icons.password_rounded),
              textInputAction:
                  isRegisterMode ? TextInputAction.next : TextInputAction.done,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: onToggleObscure,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your passcode';
                }
                if (value.length < 4) {
                  return 'Passcode must be at least 4 characters';
                }
                return null;
              },
            ),
            if (isRegisterMode) ...[
              const SizedBox(height: 14),
              AppTextFormField(
                controller: confirmPasswordController,
                obscureText: obscurePassword,
                enabled: !isLoading,
                labelText: 'Confirm passcode',
                hintText: 'Re-enter passcode',
                prefixIcon: const Icon(Icons.verified_user_outlined),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your passcode';
                  }
                  if (value != passwordController.text) {
                    return 'Passcodes do not match';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: isLoading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.posInk,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isRegisterMode
                            ? 'Register & open terminal'
                            : 'Unlock terminal',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => onModeChanged(!isRegisterMode),
              child: Text(
                isRegisterMode
                    ? 'Already provisioned? Sign in'
                    : 'New store operator? Register',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosModeSwitch extends StatelessWidget {
  final bool isRegisterMode;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PosModeSwitch({
    required this.isRegisterMode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.posNavy : AppColors.surfaceContainerLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tab(
              context: context,
              label: 'Sign in',
              selected: !isRegisterMode,
              onTap: enabled ? () => onChanged(false) : null,
            ),
          ),
          Expanded(
            child: _tab(
              context: context,
              label: 'Register',
              selected: isRegisterMode,
              onTap: enabled ? () => onChanged(true) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? AppColors.posPanel : Colors.white;
    final selectedText = isDark ? Colors.white : AppColors.posInk;
    final unselectedText = isDark ? Colors.white60 : AppColors.secondary;

    return Material(
      color: selected ? selectedBg : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      elevation: selected ? 1.5 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? selectedText : unselectedText,
            ),
          ),
        ),
      ),
    );
  }
}

class _PosFooterStrip extends StatelessWidget {
  const _PosFooterStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.sync_rounded, size: 16, color: Colors.white70),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ready for catalog import · audit export · resumable sync',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
