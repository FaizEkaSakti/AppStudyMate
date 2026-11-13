typedef ProfileRequest = Future<dynamic> Function(
  String path, {
  String method,
  Map<String, dynamic>? body,
});

String normalizeProfileText(Object? value) =>
    value?.toString().trim() ?? '';

class ProfileRepository {
  const ProfileRepository({required ProfileRequest request})
      : _request = request;

  final ProfileRequest _request;

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String nim,
  }) async {
    final result = await _request(
      '/profile',
      method: 'PUT',
      body: {
        'Name': normalizeProfileText(name),
        'Email': email.trim().toLowerCase(),
        'Nim': normalizeProfileText(nim),
      },
    );
    if (result is! Map<String, dynamic>) {
      throw const FormatException('Respons profil dari server tidak valid.');
    }
    return result;
  }
}
