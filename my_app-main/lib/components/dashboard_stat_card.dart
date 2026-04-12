import 'package:flutter/material.dart';
import '../theme_provider.dart';

class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? delta;
  final String? subtitle;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon — top right aligned
          Align(
            alignment: Alignment.topRight,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ),

          const Spacer(),

          // Value
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
              height: 1,
            ),
          ),

          const SizedBox(height: 6),

          // Title — full width, no truncation
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),

          if (delta != null || subtitle != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (delta != null) ...[
                  Text(
                    delta!,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
