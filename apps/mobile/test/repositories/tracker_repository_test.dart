import 'dart:convert';

import 'package:app_studymate_mobile/repositories/tracker_repository.dart';
import 'package:app_studymate_mobile/test/tracker_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('mengirim GET ke endpoint API dan mengurai JSON', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/courses');
      return http.Response(jsonEncode([trackerCourseFixture]), 200);
    });
    final repository = TrackerRepository(
      client: client,
      baseUrl: 'http://localhost:4000/api',
    );

    final result = await repository.get('/courses') as List;

    expect(result.first['Id'], 'course-1');
  });

  test('mengubah error API menjadi pesan yang dapat ditampilkan', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode(trackerApiErrorFixture),
          404,
        ));
    final repository = TrackerRepository(
      client: client,
      baseUrl: 'http://localhost:4000/api',
    );

    expect(repository.get('/courses/missing'), throwsException);
  });
}
