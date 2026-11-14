import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';

class PosAuthPanel extends StatelessWidget {
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

  const PosAuthPanel({
    super.key,
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
            PosModeSwitch(
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

class PosModeSwitch extends StatelessWidget {
  final bool isRegisterMode;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const PosModeSwitch({
    super.key,
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
