const _weekdays = [
  'Minggu',
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
];

Map<String, dynamic> buildMobileDashboard({
  required List<Map<String, dynamic>> tasks,
  required List<Map<String, dynamic>> schedules,
  required int totalNotes,
  required DateTime now,
}) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final upcomingLimit = now.add(const Duration(days: 14));
  final pendingTasks = tasks.where((task) => task['Status'] != 'DONE').toList();
  final todaySchedules = schedules
      .where((schedule) => schedule['Day'] == _weekdays[now.weekday % 7])
      .toList()
    ..sort((left, right) => (left['StartTime']?.toString() ?? '')
        .compareTo(right['StartTime']?.toString() ?? ''));
  final upcomingTasks = pendingTasks.where((task) {
    final deadline = DateTime.tryParse(task['Deadline']?.toString() ?? '');
    return deadline != null &&
        !deadline.isBefore(todayStart) &&
        !deadline.isAfter(upcomingLimit);
  }).toList()
    ..sort((left, right) {
      final leftDeadline = DateTime.parse(left['Deadline'].toString());
      final rightDeadline = DateTime.parse(right['Deadline'].toString());
      return leftDeadline.compareTo(rightDeadline);
    });

  return {
    'Summary': {
      'TotalTasks': tasks.length,
      'TotalCompletedTasks': tasks.length - pendingTasks.length,
      'TotalPendingTasks': pendingTasks.length,
      'TotalOverdueTasks': pendingTasks.where((task) {
        final deadline = DateTime.tryParse(task['Deadline']?.toString() ?? '');
        return deadline != null && deadline.isBefore(now);
      }).length,
      'TotalSchedulesToday': todaySchedules.length,
      'TotalNotes': totalNotes,
    },
    'TodaySchedules': todaySchedules,
    'UpcomingTasks': upcomingTasks.take(5).toList(),
  };
}
