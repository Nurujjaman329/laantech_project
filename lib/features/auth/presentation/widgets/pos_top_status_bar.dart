import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PosTopStatusBar extends StatelessWidget {
  const PosTopStatusBar({super.key});

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
