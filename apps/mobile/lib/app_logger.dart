import 'dart:developer' as developer;

class AppLogger {
  static const _name = 'AppStudyMate';

  static void info(
    String event, {
    Map<String, Object?> context = const {},
  }) {
    developer.log(
      _message(event, context),
      name: _name,
      level: 800,
    );
  }

  static void warning(
    String event,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) {
    developer.log(
      '$event (${error.runtimeType}) ${_message('', context)}',
      name: _name,
      level: 900,
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String event,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) {
    developer.log(
      '$event (${error.runtimeType}) ${_message('', context)}',
      name: _name,
      level: 1000,
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
  }

  static String routeGroup(String path) {
    final firstSegment = path.split('/').where((part) => part.isNotEmpty);
    final group = firstSegment.isEmpty ? '' : firstSegment.first;
    return const {'auth', 'dashboard', 'notes', 'profile', 'schedules', 'tasks'}
            .contains(group)
        ? group
        : 'other';
  }

  static String _message(String event, Map<String, Object?> context) {
    final details =
        context.entries.map((entry) => '${entry.key}=${entry.value}');
    return [if (event.isNotEmpty) event, ...details].join(' ');
  }
}
