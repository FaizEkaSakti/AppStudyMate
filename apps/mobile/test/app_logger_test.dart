import 'package:app_studymate_mobile/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route groups do not expose record identifiers', () {
    expect(AppLogger.routeGroup('/tasks/task-secret-id'), 'tasks');
    expect(AppLogger.routeGroup('/auth/login'), 'auth');
    expect(AppLogger.routeGroup('/users/user-secret-id'), 'other');
  });
}
