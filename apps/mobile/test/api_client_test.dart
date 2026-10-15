import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_studymate_mobile/main.dart';

void main() {
  test('schedule CRUD requests use authenticated REST endpoints', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      apiBaseUrl: 'http://localhost:4000/api',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response('[]', 200);
        }
        if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return http.Response('{}', request.method == 'POST' ? 201 : 200);
      }),
    )..token = 'test-token';

    expect(await client.list('/schedules'), isEmpty);
    await client.saveItem(
      'schedules',
      {
        'Id': 'temporary-id',
        'CourseName': 'Pemrograman',
        'Lecturer': 'Ibu Ani',
        'Day': 'Senin',
        'StartTime': '08:00',
        'EndTime': '09:30',
        'Room': 'Lab 1',
      },
      isNew: true,
    );
    await client.saveItem(
      'schedules',
      {
        'Id': 'schedule-1',
        'CourseName': 'Pemrograman Lanjut',
        'Lecturer': 'Ibu Ani',
        'Day': 'Senin',
        'StartTime': '08:00',
        'EndTime': '09:30',
        'Room': 'Lab 1',
      },
    );
    await client.deleteItem('schedules', 'schedule-1');

    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      [
        'GET /api/schedules',
        'POST /api/schedules',
        'PUT /api/schedules/schedule-1',
        'DELETE /api/schedules/schedule-1',
      ],
    );
    expect(
      requests.every(
          (request) => request.headers['authorization'] == 'Bearer test-token'),
      isTrue,
    );
    expect(jsonDecode(requests[1].body), isNot(contains('Id')));
  });

  test('REST API error messages are surfaced to the caller', () async {
    final client = ApiClient(
      apiBaseUrl: 'http://localhost:4000/api',
      httpClient: MockClient(
        (_) async => http.Response('{"Message":"Jadwal tidak ditemukan"}', 404),
      ),
    )..token = 'test-token';

    await expectLater(
      client.deleteItem('schedules', 'missing'),
      throwsA(isA<Exception>().having(
        (error) => error.toString(),
        'message',
        contains('Jadwal tidak ditemukan'),
      )),
    );
  });
}
