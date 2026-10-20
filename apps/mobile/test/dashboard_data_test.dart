import 'package:flutter_test/flutter_test.dart';
import 'package:app_studymate_mobile/dashboard_data.dart';

void main() {
  final now = DateTime(2026, 10, 14, 12);

  test('dashboard summarizes overdue work and only today\'s sorted schedules',
      () {
    final dashboard = buildMobileDashboard(
      tasks: [
        {
          'Id': 'overdue',
          'Status': 'TODO',
          'Deadline': DateTime(2026, 10, 13, 11).toIso8601String(),
        },
        {
          'Id': 'complete',
          'Status': 'DONE',
          'Deadline': DateTime(2026, 10, 13, 11).toIso8601String(),
        },
        {
          'Id': 'today',
          'Status': 'IN_PROGRESS',
          'Deadline': DateTime(2026, 10, 14, 15).toIso8601String(),
        },
      ],
      schedules: [
        {'Id': 'late', 'Day': 'Rabu', 'StartTime': '10:00'},
        {'Id': 'other-day', 'Day': 'Kamis', 'StartTime': '08:00'},
        {'Id': 'early', 'Day': 'Rabu', 'StartTime': '08:00'},
      ],
      totalNotes: 2,
      now: now,
    );

    expect(dashboard['Summary'], {
      'TotalTasks': 3,
      'TotalCompletedTasks': 1,
      'TotalPendingTasks': 2,
      'TotalOverdueTasks': 1,
      'TotalSchedulesToday': 2,
      'TotalNotes': 2,
    });
    expect(
      (dashboard['TodaySchedules'] as List<Map<String, dynamic>>)
          .map((schedule) => schedule['Id']),
      ['early', 'late'],
    );
  });

  test(
      'upcoming work excludes completed/out-of-window tasks and keeps nearest five',
      () {
    final tasks = List.generate(
      7,
      (index) => {
        'Id': 'task-${index + 1}',
        'Title': 'Task ${index + 1}',
        'Status': 'TODO',
        'Deadline': DateTime(2026, 10, 15 + index, 12).toIso8601String(),
      },
    )
      ..add({
        'Id': 'completed',
        'Status': 'DONE',
        'Deadline': DateTime(2026, 10, 15).toIso8601String(),
      })
      ..add({
        'Id': 'too-late',
        'Status': 'TODO',
        'Deadline': DateTime(2026, 10, 28, 13).toIso8601String(),
      })
      ..add({
        'Id': 'overdue',
        'Status': 'TODO',
        'Deadline': DateTime(2026, 10, 13).toIso8601String(),
      });

    final dashboard = buildMobileDashboard(
      tasks: tasks,
      schedules: const [],
      totalNotes: 0,
      now: now,
    );

    expect(
      (dashboard['UpcomingTasks'] as List<Map<String, dynamic>>)
          .map((task) => task['Id']),
      ['task-1', 'task-2', 'task-3', 'task-4', 'task-5'],
    );
  });
}
