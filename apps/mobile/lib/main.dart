import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_data.dart';
import 'theme/app_theme.dart';

const apiUrl = String.fromEnvironment('API_URL');
const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY',
    defaultValue: 'AIzaSyBsTO332dtvoRfqy321FASqDhTeFzUD6Xc');
const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID',
    defaultValue: '1:185834578847:web:cb2cf16c3fede5f25353aa');
const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '185834578847');
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID',
    defaultValue: 'appstudymate-13de0');
const firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN',
    defaultValue: 'appstudymate-13de0.firebaseapp.com');
const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
    defaultValue: 'appstudymate-13de0.firebasestorage.app');
void main() => runApp(const StudyMateApp());

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AppStudyMate',
        theme: appTheme(),
        home: const SessionGate(),
      );
}

class ApiClient {
  ApiClient({http.Client? httpClient, String? apiBaseUrl})
      : _httpClient = httpClient ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? apiUrl;

  final http.Client _httpClient;
  final String _apiBaseUrl;
  String? token;
  Map<String, dynamic>? localUser;
  List<Map<String, dynamic>> localUsers = [];
  bool firebaseDisabled = false;
  final Map<String, List<Map<String, dynamic>>> localData = {
    'schedules': [],
    'tasks': [],
    'notes': [],
  };
  bool get apiEnabled => _apiBaseUrl.trim().isNotEmpty;
  bool get firebaseConfigProvided =>
      firebaseApiKey.isNotEmpty ||
      firebaseAppId.isNotEmpty ||
      firebaseProjectId.isNotEmpty;
  bool get firebaseReady =>
      !apiEnabled &&
      !firebaseDisabled &&
      kIsWeb &&
      firebaseApiKey.startsWith('AIza') &&
      firebaseAppId.startsWith('1:') &&
      firebaseProjectId.isNotEmpty &&
      !firebaseProjectId.contains('PROJECT_ID') &&
      !firebaseProjectId.contains('nama-project');

  Future<void> init() async {
    if (apiEnabled) return;
    if (!firebaseConfigProvided) {
      await _loadLocalData();
      return;
    }
    if (!firebaseReady) {
      throw Exception(
          'Konfigurasi Firebase Web tidak valid. Gunakan apiKey, appId, dan projectId asli dari Firebase Console.');
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: firebaseApiKey,
            appId: firebaseAppId,
            messagingSenderId: firebaseMessagingSenderId,
            projectId: firebaseProjectId,
            authDomain: firebaseAuthDomain,
            storageBucket: firebaseStorageBucket,
          ),
        );
      }
    } catch (exception) {
      throw Exception('Firebase gagal diinisialisasi: $exception');
    }
  }

  Future<void> _loadLocalData() async {
    final preferences = await SharedPreferences.getInstance();
    final savedUsers = preferences.getString('local_users');
    if (savedUsers != null) {
      localUsers = (jsonDecode(savedUsers) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      localUser = localUsers.isEmpty ? null : localUsers.last;
    }
    final savedUser = preferences.getString('local_user');
    if (savedUser != null) {
      localUser = jsonDecode(savedUser) as Map<String, dynamic>;
    }
    for (final type in localData.keys) {
      final savedItems = preferences.getString(type);
      if (savedItems != null) {
        localData[type] = (jsonDecode(savedItems) as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    }
  }

  Future<dynamic> request(String path,
      {String method = 'GET', Map<String, dynamic>? body}) async {
    if (apiEnabled) return _apiRequest(path, method: method, body: body);
    if (!firebaseReady) return localRequest(path, body: body);

    if (path == '/auth/login') {
      final email = body!['Email'] as String? ?? '';
      final password = body['Password'] as String? ?? '';
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Firebase tidak mengembalikan user setelah login');
      }
      final profile = await _findProfile(user, email);
      return {
        'Token': await user.getIdToken() ?? '',
        'User': {
          'Id': user.uid,
          'Name': profile['Name'] ?? user.displayName ?? 'User',
          'Email': user.email ?? email,
          'Nim': profile['Nim'] ?? ''
        }
      };
    }

    if (path == '/auth/register') {
      final email = (body!['Email'] as String? ?? '').trim().toLowerCase();
      final password = body['Password'] as String? ?? '';
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user == null) {
        throw Exception(
            'Firebase tidak mengembalikan user setelah pendaftaran');
      }
      final name = (body['Name'] as String? ?? 'User').trim();
      final nim = (body['Nim'] as String? ?? '').trim();
      await user.updateDisplayName(name);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'UserId': user.uid,
        'Name': name,
        'Email': email,
        'Nim': nim,
        'CreatedAt': FieldValue.serverTimestamp(),
      });
      return {
        'Token': await user.getIdToken() ?? '',
        'User': {'Id': user.uid, 'Name': name, 'Email': email, 'Nim': nim}
      };
    }

    if (path == '/dashboard') {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Sesi Firebase tidak ditemukan');
      final tasks = await FirebaseFirestore.instance
          .collection('tasks')
          .where('UserId', isEqualTo: userId)
          .get();
      final schedules = await FirebaseFirestore.instance
          .collection('schedules')
          .where('UserId', isEqualTo: userId)
          .get();
      final notes = await FirebaseFirestore.instance
          .collection('notes')
          .where('UserId', isEqualTo: userId)
          .get();
      return buildMobileDashboard(
        tasks: tasks.docs
            .map((document) => {'Id': document.id, ...document.data()})
            .toList(),
        schedules: schedules.docs
            .map((document) => {'Id': document.id, ...document.data()})
            .toList(),
        totalNotes: notes.size,
        now: DateTime.now(),
      );
    }
    throw Exception('Endpoint tidak tersedia');
  }

  Future<dynamic> _apiRequest(String path,
      {required String method, Map<String, dynamic>? body}) async {
    final configuredApiUrl = _apiBaseUrl.trim();
    final baseUrl = configuredApiUrl.endsWith('/')
        ? configuredApiUrl
        : '$configuredApiUrl/';
    final endpoint = Uri.parse(baseUrl)
        .resolve(path.startsWith('/') ? path.substring(1) : path);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null && !path.startsWith('/auth/')) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _httpClient
        .send(http.Request(method, endpoint)
          ..headers.addAll(headers)
          ..body = body == null ? '' : jsonEncode(body))
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 15));
    final result = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          result is Map<String, dynamic> ? result['Message']?.toString() : null;
      throw Exception(
          message ?? 'Permintaan API gagal (HTTP ${response.statusCode})');
    }
    return result;
  }

  Future<Map<String, dynamic>> firebaseUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {};
    final profile = await _findProfile(currentUser, currentUser.email ?? '');
    return {
      'Id': currentUser.uid,
      'Name': profile['Name'] ?? currentUser.displayName ?? 'User',
      'Email': currentUser.email ?? '',
      'Nim': profile['Nim'] ?? ''
    };
  }

  Future<Map<String, dynamic>> _findProfile(User user, String email) async {
    final byId = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (byId.exists) return byId.data() ?? {};
    final byEmail = await FirebaseFirestore.instance
        .collection('users')
        .where('Email', isEqualTo: email)
        .limit(1)
        .get();
    return byEmail.docs.isEmpty ? {} : byEmail.docs.first.data();
  }

  Future<List<dynamic>> list(String path) async {
    if (apiEnabled) {
      final result = await request(path);
      return result as List<dynamic>;
    }
    final type = path.replaceFirst('/', '');
    if (!firebaseReady) return localData[type] ?? [];
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('Sesi Firebase tidak ditemukan');
    final snapshot = await FirebaseFirestore.instance
        .collection(type)
        .where('UserId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((document) => {'Id': document.id, ...document.data()})
        .toList();
  }

  Future<void> saveItem(String type, Map<String, dynamic> item,
      {bool isNew = false}) async {
    if (apiEnabled) {
      final body = Map<String, dynamic>.from(item)..remove('Id');
      final path =
          '/$type${isNew ? '' : '/${Uri.encodeComponent(item['Id'].toString())}'}';
      await request(path, method: isNew ? 'POST' : 'PUT', body: body);
      return;
    }
    if (!firebaseReady) {
      final items = localData[type]!;
      final index = items.indexWhere((entry) => entry['Id'] == item['Id']);
      if (index == -1) {
        items.add(item);
      } else {
        items[index] = item;
      }
      await _persistLocal(type);
      return;
    }
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('Sesi Firebase tidak ditemukan');
    await FirebaseFirestore.instance
        .collection(type)
        .doc(item['Id'] as String)
        .set({...item, 'UserId': userId});
  }

  Future<void> deleteItem(String type, String id) async {
    if (apiEnabled) {
      await request('/$type/${Uri.encodeComponent(id)}', method: 'DELETE');
      return;
    }
    if (!firebaseReady) {
      localData[type]!.removeWhere((item) => item['Id'] == id);
      await _persistLocal(type);
      return;
    }
    await FirebaseFirestore.instance.collection(type).doc(id).delete();
  }

  Future<void> _persistLocal(String type) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(type, jsonEncode(localData[type]));
  }

  Future<dynamic> localRequest(String path,
      {Map<String, dynamic>? body}) async {
    if (path == '/auth/register') {
      final email = body?['Email']?.toString().trim().toLowerCase() ?? '';
      if (localUsers.any((account) => account['Email'] == email)) {
        throw Exception('Email sudah terdaftar');
      }
      localUser = {
        'Id': 'local-user',
        'Name': body?['Name'] ?? '',
        'Email': email,
        'Nim': body?['Nim'] ?? '',
        'Password': body?['Password'] ?? ''
      };
      localUsers.add(localUser!);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('local_user', jsonEncode(localUser));
      await preferences.setString('local_users', jsonEncode(localUsers));
      return {'Token': 'local-token', 'User': localUser};
    }
    if (path == '/auth/login') {
      final email = body?['Email']?.toString().trim().toLowerCase();
      final account = localUsers.cast<Map<String, dynamic>?>().firstWhere(
          (item) =>
              item?['Email'] == email && item?['Password'] == body?['Password'],
          orElse: () => null);
      if (account == null) throw Exception('Email atau password salah');
      localUser = account;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('local_user', jsonEncode(localUser));
      return {'Token': 'local-token', 'User': localUser};
    }
    if (path == '/dashboard') {
      return buildMobileDashboard(
        tasks: localData['tasks']!,
        schedules: localData['schedules']!,
        totalNotes: localData['notes']!.length,
        now: DateTime.now(),
      );
    }
    throw Exception('Data belum tersedia');
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final client = ApiClient();
  Map<String, dynamic>? user;
  bool loading = true;
  String? startupError;

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    try {
      await client.init().timeout(const Duration(seconds: 10));
      final preferences = await SharedPreferences.getInstance();
      if (client.firebaseReady) {
        user = await client.firebaseUser();
        if (user!.isNotEmpty) {
          client.token = await FirebaseAuth.instance.currentUser?.getIdToken();
        }
      } else if (client.apiEnabled) {
        final token = preferences.getString('api_token');
        final savedUser = preferences.getString('api_user');
        if (token != null && savedUser != null) {
          client.token = token;
          user = jsonDecode(savedUser) as Map<String, dynamic>;
        }
      } else if (!client.firebaseReady && client.localUser != null) {
        client.token = 'local-token';
        user = client.localUser;
      } else {
        final token = preferences.getString('token');
        final savedUser = preferences.getString('user');
        if (token != null && savedUser != null) {
          client.token = token;
          user = jsonDecode(savedUser) as Map<String, dynamic>;
        }
      }
    } catch (exception) {
      startupError = exception.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> login(String email, String password, bool register, String name,
      String nim) async {
    final result = await client.request(
        register ? '/auth/register' : '/auth/login',
        method: 'POST',
        body: register
            ? {'Name': name, 'Email': email, 'Nim': nim, 'Password': password}
            : {'Email': email, 'Password': password});
    client.token = result['Token'] as String;
    user = result['User'] as Map<String, dynamic>;
    final preferences = await SharedPreferences.getInstance();
    final tokenKey = client.apiEnabled ? 'api_token' : 'token';
    final userKey = client.apiEnabled ? 'api_user' : 'user';
    await preferences.setString(tokenKey, client.token!);
    await preferences.setString(userKey, jsonEncode(user));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (startupError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off, size: 48, color: coral),
              const SizedBox(height: 16),
              const Text('Firebase belum siap',
                  style: TextStyle(
                      color: ink, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(startupError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted)),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      loading = true;
                      startupError = null;
                    });
                    restore();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi')),
            ]),
          ),
        ),
      );
    }
    if (user == null) return LoginPage(onLogin: login);
    return HomePage(
        client: client,
        user: user!,
        onLogout: () async {
          if (client.firebaseReady) {
            await FirebaseAuth.instance.signOut();
          } else {
            final preferences = await SharedPreferences.getInstance();
            await preferences.remove('token');
            await preferences.remove('user');
            await preferences.remove('api_token');
            await preferences.remove('api_user');
            await preferences.remove('local_user');
            client.localUser = null;
          }
          client.token = null;
          if (mounted) setState(() => user = null);
        });
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({required this.onLogin, super.key});
  final Future<void> Function(String, String, bool, String, String) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final nim = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? error;

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onLogin(
          email.text, password.text, register, name.text, nim.text);
    } catch (exception) {
      if (mounted) {
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final intro = Container(
                height: wide ? 560 : null,
                padding: EdgeInsets.all(wide ? 40 : 0),
                decoration: wide
                    ? BoxDecoration(
                        color: teal,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Column(
                  mainAxisAlignment:
                      wide ? MainAxisAlignment.center : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: wide ? Colors.white : teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'S',
                          style: TextStyle(
                            color: wide ? teal : Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'STUDYMATE',
                        style: TextStyle(
                          color: wide ? Colors.white : teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ]),
                    SizedBox(height: wide ? 42 : 24),
                    Text(
                      'Ruang belajar,\nlebih tertata.',
                      style: TextStyle(
                        color: wide ? Colors.white : ink,
                        fontSize: wide ? 42 : 32,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Atur jadwal, tugas, dan catatan dengan tenang.',
                      style: TextStyle(
                        color: wide
                            ? Colors.white.withValues(alpha: 0.78)
                            : muted,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    if (wide) ...[
                      const SizedBox(height: 40),
                      Container(height: 1, color: Colors.white24),
                      const SizedBox(height: 20),
                      const Row(children: [
                        Icon(Icons.auto_awesome_outlined,
                            color: leaf, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Satu langkah kecil, setiap hari.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ]),
                    ],
                  ],
                ),
              );

              final form = Container(
                padding: EdgeInsets.all(wide ? 36 : 24),
                decoration: BoxDecoration(
                  color: paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      register ? 'Buat akun' : 'Masuk ke akunmu',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      register
                          ? 'Mulai susun kegiatan kuliahmu.'
                          : 'Senang melihatmu kembali.',
                      style: const TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 26),
                    if (register) ...[
                      field('Nama lengkap', name, 'Nama kamu',
                          icon: Icons.person_outline),
                      field('NIM', nim, '20240001',
                          icon: Icons.badge_outlined),
                    ],
                    field('Email', email, 'nama@email.com',
                        icon: Icons.mail_outline),
                    field('Password', password, 'Minimal 6 karakter',
                        obscure: true, icon: Icons.lock_outline),
                    if (error != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: coral.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(color: coral, fontSize: 13),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : submit,
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(register
                                ? Icons.person_add_alt_1
                                : Icons.arrow_forward),
                        label: Text(busy
                            ? 'Memproses...'
                            : register
                                ? 'Buat akun'
                                : 'Masuk'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          register = !register;
                          error = null;
                        }),
                        child: Text(register
                            ? 'Sudah punya akun? Masuk'
                            : 'Belum punya akun? Daftar'),
                      ),
                    ),
                  ],
                ),
              );

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(wide ? 32 : 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1080 : 480),
                    child: wide
                        ? Row(
                            children: [
                              Expanded(flex: 11, child: intro),
                              const SizedBox(width: 24),
                              Expanded(flex: 9, child: form),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              intro,
                              const SizedBox(height: 24),
                              form,
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      );

  Widget field(String label, TextEditingController controller, String hint,
          {bool obscure = false, required IconData icon}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: label == 'Email' ? TextInputType.emailAddress : null,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
          ),
        ),
      );
}

class HomePage extends StatefulWidget {
  const HomePage(
      {required this.client,
      required this.user,
      required this.onLogout,
      super.key});
  final ApiClient client;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  final titles = const ['Dashboard', 'Jadwal', 'Tugas', 'Catatan', 'Profil'];

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationDestination(
          icon: Icon(Icons.grid_view_outlined), label: 'Beranda'),
      NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined), label: 'Jadwal'),
      NavigationDestination(
          icon: Icon(Icons.task_alt_outlined), label: 'Tugas'),
      NavigationDestination(
          icon: Icon(Icons.sticky_note_2_outlined), label: 'Catatan'),
      NavigationDestination(
          icon: Icon(Icons.person_outline), label: 'Profil'),
    ];
      const railDestinations = [
        NavigationRailDestination(
          icon: Icon(Icons.grid_view_outlined), label: Text('Beranda')),
        NavigationRailDestination(
          icon: Icon(Icons.calendar_month_outlined), label: Text('Jadwal')),
        NavigationRailDestination(
          icon: Icon(Icons.task_alt_outlined), label: Text('Tugas')),
        NavigationRailDestination(
          icon: Icon(Icons.sticky_note_2_outlined), label: Text('Catatan')),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline), label: Text('Profil')),
      ];
    final firstName = (widget.user['Name'] as String? ?? 'Mahasiswa')
        .trim()
        .split(' ')
        .first;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final pages = IndexedStack(
              index: tab,
              children: [
                Dashboard(
                  client: widget.client,
                  user: widget.user,
                  onNavigate: (value) => setState(() => tab = value),
                ),
                DataList(client: widget.client, type: 'schedules'),
                DataList(client: widget.client, type: 'tasks'),
                DataList(client: widget.client, type: 'notes'),
                Profile(user: widget.user, onLogout: widget.onLogout),
              ],
            );

            return Row(
              children: [
                if (wide)
                  Container(
                    width: 256,
                    decoration: const BoxDecoration(
                      color: paper,
                      border: Border(right: BorderSide(color: line)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 26, 20, 20),
                          child: Row(children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: teal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('S',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Georgia')),
                            ),
                            const SizedBox(width: 10),
                            const Text('STUDYMATE',
                                style: TextStyle(
                                    color: ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ]),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 8, 24, 12),
                          child: Text('MENU UTAMA',
                              style: TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                        Expanded(
                          child: NavigationRail(
                            extended: true,
                            minExtendedWidth: 256,
                            backgroundColor: paper,
                            selectedIndex: tab,
                            onDestinationSelected: (value) =>
                                setState(() => tab = value),
                            destinations: railDestinations,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: leaf.withValues(alpha: 0.35),
                              child: Text(
                                firstName.isEmpty
                                    ? 'S'
                                    : firstName[0].toUpperCase(),
                                style: const TextStyle(
                                    color: teal, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(firstName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 72,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        decoration: const BoxDecoration(
                          color: paper,
                          border: Border(bottom: BorderSide(color: line)),
                        ),
                        child: Row(children: [
                          Text(titles[tab],
                              style: const TextStyle(
                                  color: ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Georgia')),
                          const Spacer(),
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: leaf.withValues(alpha: 0.35),
                            child: Text(
                              firstName.isEmpty
                                  ? 'S'
                                  : firstName[0].toUpperCase(),
                              style: const TextStyle(
                                  color: teal, fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (!wide) ...[
                            const SizedBox(width: 9),
                            Text(firstName,
                                style: const TextStyle(
                                    color: ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ]),
                      ),
                      Expanded(child: pages),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 900
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (value) => setState(() => tab = value),
              destinations: destinations,
            ),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard(
      {required this.client,
      required this.user,
      required this.onNavigate,
      super.key});
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<int> onNavigate;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late Future<dynamic> future;

  @override
  void initState() {
    super.initState();
    future = widget.client.request('/dashboard');
  }

  Future<void> _refresh() async {
    final next = widget.client.request('/dashboard');
    setState(() => future = next);
    try {
      await next;
    } on Exception {
      // The FutureBuilder presents the error state.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        final summary =
            snapshot.data?['Summary'] as Map<String, dynamic>? ?? {};
        final cards = [
          ('Total tugas', summary['TotalTasks'] ?? 0, Icons.checklist, teal),
          ('Selesai', summary['TotalCompletedTasks'] ?? 0,
              Icons.task_alt, const Color(0xff718f50)),
          ('Berjalan', summary['TotalPendingTasks'] ?? 0,
              Icons.timelapse, gold),
          ('Terlambat', summary['TotalOverdueTasks'] ?? 0,
              Icons.warning_amber_outlined, coral),
        ];
        final todaySchedules =
            snapshot.data?['TodaySchedules'] as List<dynamic>? ?? [];
        final upcomingTasks =
            snapshot.data?['UpcomingTasks'] as List<dynamic>? ?? [];
        final firstName = (widget.user['Name'] as String? ?? 'Mahasiswa')
            .trim()
            .split(' ')
            .first;
        final width = MediaQuery.sizeOf(context).width;
        final horizontalPadding = width >= 900 ? 36.0 : 20.0;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, 28, horizontalPadding, 40),
                children: [
                  Container(
                    padding: EdgeInsets.all(width >= 600 ? 28 : 22),
                    decoration: BoxDecoration(
                      color: teal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_todayLabel(),
                                style: const TextStyle(
                                    color: leaf,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            Text('Halo, $firstName.',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: width >= 600 ? 34 : 27,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Georgia')),
                            const SizedBox(height: 8),
                            Text('Mari jaga ritme belajarmu hari ini.',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: width >= 600 ? 76 : 54,
                        height: width >= 600 ? 76 : 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: leaf,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.menu_book_rounded,
                            size: width >= 600 ? 36 : 27, color: teal),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  _sectionHeading('Aktivitas belajar'),
                  const SizedBox(height: 14),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    _statePanel(
                      icon: Icons.hourglass_top_rounded,
                      title: 'Menyiapkan ringkasan',
                      detail: 'Aktivitasmu akan tampil sebentar lagi.',
                      busy: true,
                    ),
                  if (snapshot.hasError)
                    _statePanel(
                      icon: Icons.cloud_off_outlined,
                      title: 'Data belum dapat dimuat',
                      detail: 'Periksa koneksi, lalu coba muat ulang.',
                      onRetry: _refresh,
                    ),
                  if (snapshot.hasData) ...[
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760 ? 4 : 2;
                      final tileWidth = (constraints.maxWidth -
                              (columns - 1) * 12) /
                          columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: cards
                            .map((item) => SizedBox(
                                  width: tileWidth,
                                  child: _metricTile(
                                    title: item.$1,
                                    value: item.$2.toString(),
                                    icon: item.$3,
                                    color: item.$4,
                                  ),
                                ))
                            .toList(),
                      );
                    }),
                    const SizedBox(height: 30),
                    _sectionHeading('Jadwal hari ini',
                        action: 'Lihat jadwal',
                        onTap: () => widget.onNavigate(1)),
                    const SizedBox(height: 14),
                    if (todaySchedules.isEmpty)
                      _emptyPanel(
                        icon: Icons.calendar_today_outlined,
                        title: 'Hari ini masih lapang',
                        detail: 'Belum ada jadwal kuliah untuk hari ini.',
                      )
                    else
                      for (final schedule in todaySchedules)
                        _scheduleTile(schedule as Map<String, dynamic>),
                    const SizedBox(height: 28),
                    _sectionHeading('Tugas mendatang',
                        action: 'Lihat tugas',
                        onTap: () => widget.onNavigate(2)),
                    const SizedBox(height: 14),
                    if (upcomingTasks.isEmpty)
                      _emptyPanel(
                        icon: Icons.task_alt_outlined,
                        title: 'Belum ada tenggat dekat',
                        detail: 'Tugas 14 hari ke depan akan tampil di sini.',
                      )
                    else
                      for (final task in upcomingTasks)
                        _taskTile(task as Map<String, dynamic>),
                  ],
                ],
              ),
            ),
          ),
        );
      });

  Widget _sectionHeading(String title, {String? action, VoidCallback? onTap}) =>
      Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Georgia')),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: onTap,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 15),
            label: Text(action),
          ),
      ]);

  Widget _metricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 23,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Georgia')),
                const SizedBox(height: 4),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 11)),
              ],
            ),
          ),
        ]),
      );

  Widget _scheduleTile(Map<String, dynamic> schedule) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: leaf.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.schedule_rounded, color: teal, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schedule['CourseName']?.toString() ?? 'Mata kuliah',
                    style: const TextStyle(
                        color: ink, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(schedule['Room']?.toString() ?? 'Ruang belum diatur',
                    style: const TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${schedule['StartTime'] ?? '-'}',
              style: const TextStyle(
                  color: teal, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _taskTile(Map<String, dynamic> task) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: coral,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task['Title']?.toString() ?? 'Tugas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: ink, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(formatDate(task['Deadline']),
                    style: const TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(statusLabel(task['Status']),
              style: const TextStyle(
                  color: teal, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _emptyPanel({
    required IconData icon,
    required String title,
    required String detail,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Icon(icon, color: muted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: ink, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(detail,
                    style: const TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
        ]),
      );

  Widget _statePanel({
    required IconData icon,
    required String title,
    required String detail,
    bool busy = false,
    VoidCallback? onRetry,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: line),
        ),
        child: Column(children: [
          if (busy)
            const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5))
          else
            Icon(icon, color: coral, size: 24),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: ink, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Coba lagi'),
            ),
          ],
        ]),
      );
}

String _todayLabel() {
  const weekdays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final now = DateTime.now();
  return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
}

class DataList extends StatefulWidget {
  const DataList({required this.client, required this.type, super.key});
  final ApiClient client;
  final String type;

  @override
  State<DataList> createState() => _DataListState();
}

class _DataListState extends State<DataList> {
  late Future<List<dynamic>> future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    future = widget.client.list('/${widget.type}');
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ItemForm(type: widget.type, item: item),
    );
    if (result == null) return;
    try {
      await widget.client.saveItem(widget.type, result, isNew: item == null);
    } on Exception catch (error) {
      if (mounted) _showError(error);
      return;
    }
    if (mounted) setState(_reload);
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus data?'),
        content: const Text('Data yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.deleteItem(widget.type, id);
    } on Exception catch (error) {
      if (mounted) _showError(error);
      return;
    }
    if (mounted) setState(_reload);
  }

  void _showError(Exception error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message.isEmpty ? 'Permintaan gagal. Coba lagi.' : message),
    ));
  }

  Future<void> _showDetails(Map<String, dynamic> item) async {
    final isTask = widget.type == 'tasks';
    final title = item[isTask ? 'Title' : 'CourseName']?.toString() ?? '';
    final isDone = item['Status'] == 'DONE';
    final isInProgress = item['Status'] == 'IN_PROGRESS';
    final taskInfoTitle = isDone
      ? 'Tugas sudah dikerjakan'
      : isInProgress
        ? 'Tugas sedang dikerjakan'
        : 'Tugas belum dikerjakan';
    final taskInfoDetail = isDone
      ? 'Tugas ini telah ditandai selesai.'
      : isInProgress
        ? 'Progres tugas ini sedang berjalan.'
        : 'Tugas ini masih perlu diselesaikan.';
    final taskInfoColor = isDone
      ? teal
      : isInProgress
        ? gold
        : coral;
    final taskInfoIcon = isDone
      ? Icons.check_circle_outline
      : isInProgress
        ? Icons.pending_outlined
        : Icons.radio_button_unchecked;

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: const BoxDecoration(
                  color: teal,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(children: [
                  Icon(
                    isTask ? Icons.task_alt_rounded : Icons.event_note_rounded,
                    color: leaf,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isTask ? 'Detail tugas' : 'Detail jadwal',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Georgia')),
                      const SizedBox(height: 18),
                      if (isTask) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: line),
                          ),
                          child: Row(children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: coral,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.event_available_outlined,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('TENGGAT TUGAS',
                                      style: TextStyle(
                                          color: muted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 5),
                                  Text(formatDate(item['Deadline']),
                                      style: const TextStyle(
                                          color: ink,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: paper,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: line),
                          ),
                          child: Row(children: [
                            const Icon(Icons.flag_outlined,
                                color: teal, size: 19),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text('STATUS',
                                  style: TextStyle(
                                      color: muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: leaf.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(statusLabel(item['Status']),
                                  style: const TextStyle(
                                      color: teal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: taskInfoColor.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: taskInfoColor.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(taskInfoIcon,
                                  color: taskInfoColor, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(taskInfoTitle,
                                        style: TextStyle(
                                            color: taskInfoColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 3),
                                    Text(taskInfoDetail,
                                        style: const TextStyle(
                                            color: ink, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: paper,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Icon(Icons.notes_rounded,
                                    color: teal, size: 18),
                                SizedBox(width: 8),
                                Text('DESKRIPSI',
                                    style: TextStyle(
                                        color: muted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(height: 10),
                              Text(
                                (item['Description']?.toString().trim().isNotEmpty ??
                                        false)
                                    ? item['Description'].toString()
                                    : 'Belum ada deskripsi untuk tugas ini.',
                                style: const TextStyle(
                                    color: ink, fontSize: 14, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: line),
                          ),
                          child: Row(children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: teal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.calendar_month_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('HARI & WAKTU',
                                      style: TextStyle(
                                          color: muted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 5),
                                  Text(item['Day']?.toString() ?? '-',
                                      style: const TextStyle(
                                          color: ink,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item['StartTime'] ?? '-'} - ${item['EndTime'] ?? '-'}',
                                    style: const TextStyle(
                                        color: teal,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 360;
                          final tileWidth = stacked
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _ScheduleDetailCard(
                                width: tileWidth,
                                icon: Icons.person_outline,
                                label: 'DOSEN',
                                value: item['Lecturer']?.toString() ?? '-',
                              ),
                              _ScheduleDetailCard(
                                width: tileWidth,
                                icon: Icons.location_on_outlined,
                                label: 'RUANGAN',
                                value: item['Room']?.toString() ?? '-',
                              ),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Selesai'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Data gagal dimuat. Periksa koneksi API lalu coba lagi.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(_reload),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        return Stack(children: [
          ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
              children: [
                if (items.isEmpty)
                  const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('Belum ada data',
                              style: TextStyle(color: muted)))),
                ...items.map((item) {
                  final data = item as Map<String, dynamic>;
                  final title = data['Title'] ?? data['CourseName'] ?? 'Item';
                  final detail = widget.type == 'tasks'
                      ? '${data['Description'] ?? ''}\nDeadline: ${formatDate(data['Deadline'])} - ${statusLabel(data['Status'])}'
                      : widget.type == 'notes'
                          ? data['Content'] ?? ''
                          : '${data['Day'] ?? ''} | ${data['StartTime'] ?? ''}-${data['EndTime'] ?? ''} | ${data['Room'] ?? ''}';
                  return Card(
                      color: paper,
                      child: ListTile(
                        isThreeLine: widget.type == 'tasks',
                        title: Text(title.toString(),
                            style: const TextStyle(
                                color: ink, fontWeight: FontWeight.w700)),
                        subtitle: Text(detail.toString(),
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                        onTap:
                            widget.type == 'tasks' || widget.type == 'schedules'
                                ? () => _showDetails(data)
                                : null,
                        leading: Icon(
                            widget.type == 'tasks'
                                ? Icons.check_circle_outline
                                : widget.type == 'notes'
                                    ? Icons.notes_outlined
                                    : Icons.schedule,
                            color: teal),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'details') {
                              _showDetails(data);
                            } else if (action == 'edit') {
                              _edit(data);
                            } else {
                              _delete(data['Id'].toString());
                            }
                          },
                          itemBuilder: (_) => [
                            if (widget.type == 'tasks' ||
                                widget.type == 'schedules')
                              const PopupMenuItem(
                                  value: 'details',
                                  child: Text('Lihat detail')),
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Hapus')),
                          ],
                        ),
                      ));
                }),
              ]),
          Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton.extended(
                  onPressed: () => _edit(),
                  backgroundColor: teal,
                  icon: const Icon(Icons.add),
                  label: Text(widget.type == 'schedules'
                      ? 'Jadwal'
                      : widget.type == 'tasks'
                          ? 'Tugas'
                          : 'Catatan'))),
        ]);
      });
}

class _ScheduleDetailCard extends StatelessWidget {
  const _ScheduleDetailCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: teal, size: 17),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      color: muted, fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 9),
            Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: ink, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

String formatDate(dynamic value) {
  if (value == null || value.toString().isEmpty) return '-';
  final date = DateTime.tryParse(value.toString());
  if (date == null) return value.toString();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String statusLabel(dynamic value) => switch (value) {
      'DONE' => 'Selesai',
      'IN_PROGRESS' => 'Dikerjakan',
      _ => 'Belum dikerjakan',
    };

class ItemForm extends StatefulWidget {
  const ItemForm({required this.type, this.item, super.key});
  final String type;
  final Map<String, dynamic>? item;

  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  static const days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  late final Map<String, TextEditingController> fields;
  late String status;
  DateTime? deadline;
  String? selectedDay;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? formError;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? {};
    fields = {
      for (final key in widget.type == 'schedules'
        ? ['CourseName', 'Lecturer', 'Room']
          : widget.type == 'tasks'
              ? ['Title', 'Description']
              : ['Title', 'Content'])
        key: TextEditingController(text: item[key]?.toString() ?? '')
    };
    status = item['Status']?.toString() ?? 'TODO';
    deadline = DateTime.tryParse(item['Deadline']?.toString() ?? '');
    final savedDay = item['Day']?.toString();
    selectedDay = days.contains(savedDay) ? savedDay : null;
    startTime = _parseTime(item['StartTime']?.toString());
    endTime = _parseTime(item['EndTime']?.toString());
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> pickDeadline() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: deadline ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (picked != null) setState(() => deadline = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? startTime : endTime) ??
          (isStart
              ? const TimeOfDay(hour: 8, minute: 0)
              : const TimeOfDay(hour: 9, minute: 0)),
      helpText: isStart ? 'Pilih jam mulai' : 'Pilih jam selesai',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        startTime = picked;
      } else {
        endTime = picked;
      }
      formError = null;
    });
  }

  void submit() {
    final hasEmptyField =
        fields.values.any((controller) => controller.text.trim().isEmpty);
    if (hasEmptyField) {
      setState(() => formError = 'Lengkapi semua informasi terlebih dahulu.');
      return;
    }

    if (widget.type == 'schedules') {
      if (selectedDay == null || startTime == null || endTime == null) {
        setState(() => formError = 'Pilih hari serta jam mulai dan selesai.');
        return;
      }
      final startMinutes = startTime!.hour * 60 + startTime!.minute;
      final endMinutes = endTime!.hour * 60 + endTime!.minute;
      if (endMinutes <= startMinutes) {
        setState(
            () => formError = 'Jam selesai harus setelah jam mulai.');
        return;
      }
    }

    final item = {
      for (final entry in fields.entries) entry.key: entry.value.text.trim(),
      'Id': widget.item?['Id'] ??
          '${widget.type}-${DateTime.now().microsecondsSinceEpoch}'
    };
    if (widget.type == 'schedules') {
      item['Day'] = selectedDay!;
      item['StartTime'] = _formatTime(startTime!);
      item['EndTime'] = _formatTime(endTime!);
    }
    if (widget.type == 'tasks') {
      item['Status'] = status;
      item['Deadline'] = (deadline ?? DateTime.now()).toIso8601String();
    }
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.type == 'schedules'
        ? 'jadwal'
        : widget.type == 'tasks'
            ? 'tugas'
            : 'catatan';
    final title = '${widget.item == null ? 'Tambah' : 'Edit'} $label';
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 15, 12, 15),
              decoration: const BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(children: [
                Icon(
                  widget.type == 'schedules'
                      ? Icons.calendar_month_outlined
                      : widget.type == 'tasks'
                          ? Icons.task_alt_outlined
                          : Icons.sticky_note_2_outlined,
                  color: leaf,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        widget.type == 'schedules'
                            ? 'Atur waktu dan detail perkuliahan.'
                            : widget.type == 'tasks'
                                ? 'Catat tenggat dan progres tugas.'
                                : 'Simpan materi pentingmu.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.type == 'schedules') ...[
                      _formSectionLabel('INFORMASI KULIAH'),
                      const SizedBox(height: 12),
                    ],
                    ...fields.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: entry.value,
                            onChanged: (_) {
                              if (formError != null) {
                                setState(() => formError = null);
                              }
                            },
                            maxLines: entry.key == 'Description' ||
                                    entry.key == 'Content'
                                ? 3
                                : 1,
                            decoration: InputDecoration(
                              labelText: fieldLabel(entry.key),
                              hintText: _fieldHint(entry.key),
                              alignLabelWithHint: entry.key == 'Description' ||
                                  entry.key == 'Content',
                              prefixIcon: entry.key == 'CourseName'
                                  ? const Icon(Icons.menu_book_outlined)
                                  : entry.key == 'Lecturer'
                                      ? const Icon(Icons.person_outline)
                                      : entry.key == 'Room'
                                          ? const Icon(Icons.location_on_outlined)
                                          : null,
                            ),
                          ),
                        )),
                    if (widget.type == 'schedules') ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedDay,
                        decoration: const InputDecoration(
                          labelText: 'Hari kuliah',
                          prefixIcon: Icon(Icons.today_outlined),
                        ),
                        items: days
                            .map((day) => DropdownMenuItem(
                                value: day, child: Text(day)))
                            .toList(),
                        onChanged: (value) => setState(() {
                          selectedDay = value;
                          formError = null;
                        }),
                      ),
                      const SizedBox(height: 14),
                      _formSectionLabel('WAKTU KULIAH'),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: _timeField(
                            label: 'Mulai',
                            value: startTime,
                            onTap: () => _pickTime(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _timeField(
                            label: 'Selesai',
                            value: endTime,
                            onTap: () => _pickTime(isStart: false),
                          ),
                        ),
                      ]),
                    ],
                    if (widget.type == 'tasks') ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined, color: teal),
                        title: const Text('Tenggat'),
                        subtitle: Text(deadline == null
                            ? 'Pilih tanggal'
                            : formatDate(deadline)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: pickDeadline,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(Icons.flag_outlined)),
                        items: const [
                          DropdownMenuItem(
                              value: 'TODO', child: Text('Belum dikerjakan')),
                          DropdownMenuItem(
                              value: 'IN_PROGRESS', child: Text('Dikerjakan')),
                          DropdownMenuItem(
                              value: 'DONE', child: Text('Selesai')),
                        ],
                        onChanged: (value) =>
                            setState(() => status = value ?? 'TODO'),
                      ),
                    ],
                    if (formError != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: coral.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline,
                              color: coral, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(formError!,
                                style: const TextStyle(
                                    color: coral, fontSize: 12)),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: line),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 17),
                    label: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: submit,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Simpan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formSectionLabel(String label) => Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: const TextStyle(
                color: muted, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  Widget _timeField({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) =>
      Semantics(
        button: true,
        label: '$label ${value == null ? 'belum dipilih' : value.format(context)}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.access_time),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              value == null ? 'Pilih jam' : _formatTime(value),
              style: TextStyle(
                  color: value == null ? muted : ink,
                  fontSize: 14,
                  fontWeight: value == null ? FontWeight.w400 : FontWeight.w600),
            ),
          ),
        ),
      );

  String _fieldHint(String key) => switch (key) {
        'CourseName' => 'Contoh: Pemrograman Mobile',
        'Lecturer' => 'Nama dosen pengampu',
        'Room' => 'Contoh: Lab 2',
        'Title' => 'Tulis judul singkat',
        'Description' => 'Tambahkan detail jika diperlukan',
        'Content' => 'Tulis isi catatanmu',
        _ => '',
      };

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String fieldLabel(String key) => switch (key) {
      'CourseName' => 'Mata kuliah',
      'Lecturer' => 'Dosen',
      'Day' => 'Hari',
      'StartTime' => 'Jam mulai',
      'EndTime' => 'Jam selesai',
      'Room' => 'Ruangan',
      'Description' => 'Deskripsi',
      'Content' => 'Isi catatan',
      _ => 'Judul',
    };

class Profile extends StatelessWidget {
  const Profile({required this.user, required this.onLogout, super.key});
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        CircleAvatar(
            radius: 34,
            backgroundColor: teal,
            child: Text(
                (user['Name'] as String? ?? 'A').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 26))),
        const SizedBox(height: 16),
        Center(
            child: Text(user['Name']?.toString() ?? '',
                style: const TextStyle(
                    color: ink, fontWeight: FontWeight.w800, fontSize: 22))),
        Center(
            child: Text(user['Email']?.toString() ?? '',
                style: const TextStyle(color: muted))),
        const SizedBox(height: 28),
        OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'))
      ]);
}
