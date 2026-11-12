String? validateProfileName(String? value) {
  if ((value ?? '').trim().length < 2) {
    return 'Nama minimal 2 karakter.';
  }
  return null;
}

String? validateProfileEmail(String? value) {
  final email = (value ?? '').trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Masukkan email yang valid.';
  }
  return null;
}

String? validateProfileNim(String? value) {
  if ((value ?? '').trim().length < 3) {
    return 'NIM minimal 3 karakter.';
  }
  return null;
}
