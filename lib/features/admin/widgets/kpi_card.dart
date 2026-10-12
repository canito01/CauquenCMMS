import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool isTrendPositive;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.trend,
    this.isTrendPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (trend != null) ...[
                Icon(
                  isTrendPositive ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: isTrendPositive ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 4),
                Text(
                  trend!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isTrendPositive ? AppColors.success : AppColors.danger,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

