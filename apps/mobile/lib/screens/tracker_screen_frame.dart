import 'package:flutter/material.dart';

class TrackerScreenFrame extends StatelessWidget {
  const TrackerScreenFrame({
    required this.toolbar,
    required this.content,
    this.error,
    this.notice,
    super.key,
  });

  final Widget toolbar;
  final Widget content;
  final String? error;
  final String? notice;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          toolbar,
          if (error != null) _message(error!, const Color(0xffffeeeb), const Color(0xffe1715d)),
          if (notice != null) _message(notice!, const Color(0xffe9f4e8), const Color(0xff2c7775)),
          Expanded(child: content),
        ],
      );

  Widget _message(String value, Color background, Color foreground) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(value, style: TextStyle(color: foreground, fontSize: 12)),
      );
}