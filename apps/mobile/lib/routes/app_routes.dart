import 'package:flutter/material.dart';

class AppRoutes {
  static const studentTracker = '/student-tracker';

  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings, {
    required Widget Function(Object? arguments) trackerBuilder,
  }) {
    if (settings.name != studentTracker) return null;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => trackerBuilder(settings.arguments),
    );
  }
}
