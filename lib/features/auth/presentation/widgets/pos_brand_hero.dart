import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PosBrandHero extends StatelessWidget {
  const PosBrandHero({super.key});

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
