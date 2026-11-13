import 'package:flutter_test/flutter_test.dart';

import 'package:app_studymate_mobile/profile_validation.dart';

void main() {
  test('profile normalizers trim text and lowercase email', () {
    expect(normalizeProfileText('  Ani  '), 'Ani');
    expect(normalizeProfileEmail(' ANI@example.com '), 'ani@example.com');
    expect(normalizeProfileEmail(null), isNull);
  });

  test('profile validators enforce required identity fields', () {
    expect(validateProfileName('  A '), isNotNull);
    expect(validateProfileName('  Ani  '), isNull);
    expect(validateProfileEmail('invalid'), isNotNull);
    expect(validateProfileEmail(' ANI@example.com '), isNull);
    expect(validateProfileNim('12'), isNotNull);
    expect(validateProfileNim(' 123 '), isNull);
  });
}
