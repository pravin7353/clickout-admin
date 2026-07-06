import 'package:flutter/material.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';
import '../screens/super_admin_screen.dart'; // For EnterpriseTokens

class ActivityFeedItem extends StatelessWidget {
  final String time;
  final String text;
  final Color color;

  const ActivityFeedItem({
    super.key,
    required this.time,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              time,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 11,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
