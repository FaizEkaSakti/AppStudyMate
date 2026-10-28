// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_studymate_mobile/main.dart';

void main() {
  testWidgets('StudyMate app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyMateApp());
    expect(find.byType(StudyMateApp), findsOneWidget);
  });

  testWidgets('tapping a task opens its detail popup',
      (WidgetTester tester) async {
    final client = ApiClient();
    client.localData['tasks']!.add({
      'Id': 'task-1',
      'Title': 'Kumpulkan laporan',
      'Description': 'Bab satu dan dua',
      'Deadline': '2026-10-20T00:00:00.000Z',
      'Status': 'IN_PROGRESS',
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DataList(client: client, type: 'tasks')),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kumpulkan laporan'));
    await tester.pumpAndSettle();

    expect(find.text('Detail tugas'), findsOneWidget);
    expect(find.text('20/10/2026'), findsOneWidget);
    expect(find.text('Dikerjakan'), findsOneWidget);
    expect(find.text('Tugas sedang dikerjakan'), findsOneWidget);
    expect(find.text('Bab satu dan dua'), findsOneWidget);
  });

  testWidgets('task details explain completed and pending status',
      (WidgetTester tester) async {
    final client = ApiClient();
    client.localData['tasks']!.addAll([
      {
        'Id': 'done-task',
        'Title': 'Tugas selesai',
        'Description': 'Sudah dikumpulkan',
        'Deadline': '2026-10-20T00:00:00.000Z',
        'Status': 'DONE',
      },
      {
        'Id': 'pending-task',
        'Title': 'Tugas tertunda',
        'Description': 'Belum mulai',
        'Deadline': '2026-10-21T00:00:00.000Z',
        'Status': 'TODO',
      },
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DataList(client: client, type: 'tasks')),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tugas selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Tugas sudah dikerjakan'), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tugas tertunda'));
    await tester.pumpAndSettle();
    expect(find.text('Tugas belum dikerjakan'), findsOneWidget);
  });

  testWidgets('schedule popup menu opens schedule details',
      (WidgetTester tester) async {
    final client = ApiClient();
    client.localData['schedules']!.add({
      'Id': 'schedule-1',
      'CourseName': 'Pemrograman',
      'Lecturer': 'Ibu Ani',
      'Day': 'Senin',
      'StartTime': '08:00',
      'EndTime': '09:30',
      'Room': 'Lab 1',
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DataList(client: client, type: 'schedules')),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat detail'));
    await tester.pumpAndSettle();

    expect(find.text('Detail jadwal'), findsOneWidget);
    expect(find.text('Pemrograman'), findsNWidgets(2));
    expect(find.text('Ibu Ani'), findsOneWidget);
    expect(find.text('Senin'), findsOneWidget);
    expect(find.text('08:00 - 09:30'), findsOneWidget);
    expect(find.text('Lab 1'), findsOneWidget);
  });

  testWidgets('schedule form guides day and time entry with validation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ItemForm(type: 'schedules')),
    ));

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Pilih jam'), findsNWidgets(2));

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Lengkapi semua informasi terlebih dahulu.'),
        findsOneWidget);
  });

  testWidgets('saving an edited task refreshes the list synchronously',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = ApiClient();
    client.localData['tasks']!.add({
      'Id': 'task-1',
      'Title': 'Tugas lama',
      'Description': 'Deskripsi',
      'Deadline': '2026-10-20T00:00:00.000Z',
      'Status': 'TODO',
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DataList(client: client, type: 'tasks')),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Tugas baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Tugas baru'), findsOneWidget);
  });
}
