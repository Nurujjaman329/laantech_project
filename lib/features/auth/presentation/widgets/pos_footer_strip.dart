import 'package:flutter/material.dart';

class PosFooterStrip extends StatelessWidget {
  const PosFooterStrip({super.key});

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
