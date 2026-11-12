import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_studymate_mobile/profile_form.dart';
import 'package:app_studymate_mobile/profile_repository.dart';

void main() {
  testWidgets('profile form validates fields before sending the request',
      (tester) async {
    var requestCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfileForm(
          user: const {'Name': '', 'Email': 'ani@example.com', 'Nim': '123'},
          repository: ProfileRepository(
            request: (_, {method = 'GET', body}) async {
              requestCount++;
              return body!;
            },
          ),
          canEditEmail: true,
          onUserSaved: (_) async {},
          onLogout: () {},
        ),
      ),
    ));

    await tester.ensureVisible(find.text('Simpan profil'));
    await tester.tap(find.text('Simpan profil'));
    await tester.pumpAndSettle();

    expect(find.text('Nama minimal 2 karakter.'), findsOneWidget);
    expect(requestCount, 0);
  });

  testWidgets('profile form displays a success status after saving',
      (tester) async {
    Map<String, dynamic>? savedUser;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfileForm(
          user: const {
            'Id': 'user-1',
            'Name': 'Ani',
            'Email': 'ani@example.com',
            'Nim': '123',
          },
          repository: ProfileRepository(
            request: (_, {method = 'GET', body}) async => {
              'Id': 'user-1',
              ...body!,
            },
          ),
          canEditEmail: true,
          onUserSaved: (user) async => savedUser = user,
          onLogout: () {},
        ),
      ),
    ));

    await tester.enterText(find.byType(TextFormField).first, 'Ani Putri');
    await tester.ensureVisible(find.text('Simpan profil'));
    await tester.tap(find.text('Simpan profil'));
    await tester.pumpAndSettle();

    expect(find.text('Profil berhasil diperbarui.'), findsOneWidget);
    expect(savedUser?['Name'], 'Ani Putri');
  });
}
