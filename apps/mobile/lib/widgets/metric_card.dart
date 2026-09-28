import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 158,
        child: Card(
          color: paper,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 8),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 21,
                        fontWeight: FontWeight.w800)),
                Text(title, style: const TextStyle(color: muted, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
}