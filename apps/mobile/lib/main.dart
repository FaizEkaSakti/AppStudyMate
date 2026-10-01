import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/tracker_section.dart';
import 'repositories/tracker_repository.dart';
import 'routes/app_routes.dart';
import 'screens/tracker_screen_frame.dart';
import 'theme/app_theme.dart';
import 'widgets/metric_card.dart';

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
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
          settings,
          trackerBuilder: (arguments) => TrackerPage(
            user: arguments is Map<String, dynamic> ? arguments : const {},
          ),
        ),
      );
}

class ApiClient {
  String? token;
  Map<String, dynamic>? localUser;
  List<Map<String, dynamic>> localUsers = [];
  bool firebaseDisabled = false;
  final Map<String, List<Map<String, dynamic>>> localData = {
    'schedules': [],
    'tasks': [],
    'notes': [],
  };
  bool get firebaseConfigProvided =>
      firebaseApiKey.isNotEmpty ||
      firebaseAppId.isNotEmpty ||
      firebaseProjectId.isNotEmpty;
  bool get firebaseReady =>
      !firebaseDisabled &&
      kIsWeb &&
      firebaseApiKey.startsWith('AIza') &&
      firebaseAppId.startsWith('1:') &&
      firebaseProjectId.isNotEmpty &&
      !firebaseProjectId.contains('PROJECT_ID') &&
      !firebaseProjectId.contains('nama-project');

  Future<void> init() async {
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
      final completed = tasks.docs
          .where((document) => document.data()['Status'] == 'DONE')
          .length;
      return {
        'Summary': {
          'TotalTasks': tasks.size,
          'TotalCompletedTasks': completed,
          'TotalPendingTasks': tasks.size - completed,
          'TotalOverdueTasks': 0,
          'TotalSchedulesToday': schedules.size,
          'TotalNotes': notes.size
        }
      };
    }
    throw Exception('Endpoint tidak tersedia');
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

  Future<void> saveItem(String type, Map<String, dynamic> item) async {
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
      final tasks = localData['tasks']!;
      final completed = tasks.where((item) => item['Status'] == 'DONE').length;
      return {
        'Summary': {
          'TotalTasks': tasks.length,
          'TotalCompletedTasks': completed,
          'TotalPendingTasks': tasks.length - completed,
          'TotalOverdueTasks': 0,
          'TotalSchedulesToday': localData['schedules']!.length,
          'TotalNotes': localData['notes']!.length
        }
      };
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
    await preferences.setString('token', client.token!);
    await preferences.setString('user', jsonEncode(user));
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: teal,
                              borderRadius: BorderRadius.circular(16)),
                          child: const Text('AS',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18))),
                      const SizedBox(height: 24),
                      const Text('APPSTUDYMATE',
                          style: TextStyle(
                              color: coral,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              fontSize: 11)),
                      const SizedBox(height: 10),
                      Text(
                          register
                              ? 'Mulai lebih teratur.'
                              : 'Selamat datang kembali.',
                          style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 32)),
                      const SizedBox(height: 10),
                      const Text(
                          'Semua jadwal, tugas, dan catatanmu dalam satu ruang.',
                          style: TextStyle(color: muted, fontSize: 15)),
                      const SizedBox(height: 26),
                      if (register) ...[
                        field('Nama lengkap', name, 'Nama kamu'),
                        field('NIM', nim, '20240001')
                      ],
                      field('Email', email, 'nama@email.com'),
                      field('Password', password, 'Minimal 6 karakter',
                          obscure: true),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(error!,
                                style: const TextStyle(color: Colors.red))),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: busy ? null : submit,
                              style: FilledButton.styleFrom(
                                  backgroundColor: teal,
                                  padding: const EdgeInsets.all(16)),
                              child: Text(busy
                                  ? 'Memproses...'
                                  : register
                                      ? 'Buat akun'
                                      : 'Masuk'))),
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
                    ]),
              ),
            ),
          ),
        ),
      );

  Widget field(String label, TextEditingController controller, String hint,
          {bool obscure = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: TextField(
              controller: controller,
              obscureText: obscure,
              decoration: InputDecoration(labelText: label, hintText: hint)));
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
  final titles = const [
    'Dashboard',
    'Jadwal',
    'Tugas',
    'Catatan',
    'Profil',
    'Pelacak GitHub'
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(titles[tab]),
          backgroundColor: cream,
          foregroundColor: ink,
          elevation: 0,
          leading: tab == 5
              ? IconButton(
                  onPressed: () => setState(() => tab = 0),
                  icon: const Icon(Icons.arrow_back))
              : null,
          actions: [
            if (tab != 5)
              IconButton(
                tooltip: 'Pelacak GitHub',
                onPressed: () => setState(() => tab = 5),
                icon: const Icon(Icons.code),
              ),
          ],
        ),
        body: IndexedStack(
          index: tab,
          children: [
            Dashboard(client: widget.client, user: widget.user),
            DataList(client: widget.client, type: 'schedules'),
            DataList(client: widget.client, type: 'tasks'),
            DataList(client: widget.client, type: 'notes'),
            Profile(user: widget.user, onLogout: widget.onLogout),
            TrackerPage(user: widget.user),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab < 5 ? tab : 0,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), label: 'Beranda'),
            NavigationDestination(
                icon: Icon(Icons.schedule_outlined), label: 'Jadwal'),
            NavigationDestination(
                icon: Icon(Icons.task_alt_outlined), label: 'Tugas'),
            NavigationDestination(
                icon: Icon(Icons.notes_outlined), label: 'Catatan'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Profil'),
          ],
        ),
      );
}

class Dashboard extends StatelessWidget {
  const Dashboard({required this.client, required this.user, super.key});
  final ApiClient client;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
      future: client.request('/dashboard'),
      builder: (context, snapshot) {
        final summary =
            snapshot.data?['Summary'] as Map<String, dynamic>? ?? {};
        final cards = [
          ('Tugas', summary['TotalTasks'] ?? 0),
          ('Selesai', summary['TotalCompletedTasks'] ?? 0),
          ('Pending', summary['TotalPendingTasks'] ?? 0),
          ('Terlambat', summary['TotalOverdueTasks'] ?? 0)
        ];
        return ListView(padding: const EdgeInsets.all(24), children: [
          const Text('APPSTUDYMATE',
              style: TextStyle(
                  color: coral,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontSize: 11)),
          const SizedBox(height: 10),
          Text('Halo, ${(user['Name'] as String? ?? '').split(' ').first}.',
              style: const TextStyle(
                  color: ink, fontWeight: FontWeight.w800, fontSize: 30)),
          const Text('Mari jaga ritme belajarmu hari ini.',
              style: TextStyle(color: muted)),
          const SizedBox(height: 24),
          Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cards
                  .map((item) => SizedBox(
                      width: MediaQuery.sizeOf(context).width / 2 - 34,
                      child: Card(
                          color: paper,
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${item.$2}',
                                        style: const TextStyle(
                                            color: teal,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800)),
                                    Text(item.$1,
                                        style: const TextStyle(color: muted))
                                  ])))))
                  .toList()),
          const SizedBox(height: 24),
          const Text('Ringkasan aktivitas',
              style: TextStyle(
                  color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
          if (snapshot.hasError)
            const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('Tidak dapat memuat data dashboard.',
                    style: TextStyle(color: muted))),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator())),
        ]);
      });
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

  void _reload() => future = widget.client.list('/${widget.type}');

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ItemForm(type: widget.type, item: item),
    );
    if (result == null) return;
    await widget.client.saveItem(widget.type, result);
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
    await widget.client.deleteItem(widget.type, id);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
                        leading: Icon(
                            widget.type == 'tasks'
                                ? Icons.check_circle_outline
                                : widget.type == 'notes'
                                    ? Icons.notes_outlined
                                    : Icons.schedule,
                            color: teal),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) => action == 'edit'
                              ? _edit(data)
                              : _delete(data['Id'].toString()),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Hapus'))
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
  late final Map<String, TextEditingController> fields;
  late String status;
  DateTime? deadline;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? {};
    fields = {
      for (final key in widget.type == 'schedules'
          ? ['CourseName', 'Lecturer', 'Day', 'StartTime', 'EndTime', 'Room']
          : widget.type == 'tasks'
              ? ['Title', 'Description']
              : ['Title', 'Content'])
        key: TextEditingController(text: item[key]?.toString() ?? '')
    };
    status = item['Status']?.toString() ?? 'TODO';
    deadline = DateTime.tryParse(item['Deadline']?.toString() ?? '');
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

  void submit() {
    if (fields.values.any((controller) => controller.text.trim().isEmpty)) {
      return;
    }
    final item = {
      for (final entry in fields.entries) entry.key: entry.value.text.trim(),
      'Id': widget.item?['Id'] ??
          '${widget.type}-${DateTime.now().microsecondsSinceEpoch}'
    };
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
    return AlertDialog(
      title: Text(widget.item == null ? 'Tambah $label' : 'Edit $label'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...fields.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: entry.value,
                    maxLines:
                        entry.key == 'Description' || entry.key == 'Content'
                            ? 3
                            : 1,
                    decoration:
                        InputDecoration(labelText: fieldLabel(entry.key)),
                  ),
                )),
            if (widget.type == 'tasks') ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deadline'),
                subtitle: Text(
                    deadline == null ? 'Pilih tanggal' : formatDate(deadline)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: pickDeadline,
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                      value: 'TODO', child: Text('Belum dikerjakan')),
                  DropdownMenuItem(
                      value: 'IN_PROGRESS', child: Text('Dikerjakan')),
                  DropdownMenuItem(value: 'DONE', child: Text('Selesai')),
                ],
                onChanged: (value) => setState(() => status = value ?? 'TODO'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(onPressed: submit, child: const Text('Simpan')),
      ],
    );
  }
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

class TrackerPage extends StatefulWidget {
  const TrackerPage({required this.user, super.key});

  final Map<String, dynamic> user;

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  final api = TrackerRepository();
  List<Map<String, dynamic>> courses = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> repositories = [];
  Map<String, dynamic>? dashboard;
  Map<String, dynamic>? progress;
  String? selectedCourseId;
  String? selectedStudentId;
  TrackerSection section = TrackerSection.dashboard;
  bool loading = true;
  bool syncing = false;
  String? error;
  String? notice;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      courses = _maps(await api.get('/courses'));
      if (!courses.any((course) => course['Id'] == selectedCourseId)) {
        selectedCourseId =
            courses.isEmpty ? null : courses.first['Id']?.toString();
      }
      if (selectedCourseId != null) {
        await Future.wait([_loadDashboard(), _loadStudents()]);
      } else {
        dashboard = null;
        students = [];
      }
    } catch (exception) {
      error = _message(exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadDashboard() async {
    final id = selectedCourseId;
    if (id == null) {
      dashboard = null;
      return;
    }
    dashboard = _map(await api.get('/courses/$id/dashboard'));
  }

  Future<void> _loadStudents() async {
    final id = selectedCourseId;
    if (id == null) {
      students = [];
      return;
    }
    students = _maps(await api.get('/courses/$id/students'));
    if (!students.any((student) => student['Id'] == selectedStudentId)) {
      selectedStudentId =
          students.isEmpty ? null : students.first['Id']?.toString();
    }
  }

  Future<void> _loadRepositories() async {
    final id = selectedStudentId;
    if (id == null) {
      repositories = [];
      return;
    }
    repositories = _maps(await api.get('/students/$id/repositories'));
  }

  Future<void> _loadProgress(String id) async {
    setState(() {
      loading = true;
      error = null;
      section = TrackerSection.progress;
    });
    try {
      progress = _map(await api.get('/students/$id/progress'));
      selectedStudentId = id;
    } catch (exception) {
      error = _message(exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _changeCourse(String? id) async {
    if (id == null) return;
    setState(() {
      selectedCourseId = id;
      loading = true;
      error = null;
    });
    try {
      await Future.wait([_loadDashboard(), _loadStudents()]);
      if (section == TrackerSection.repositories) await _loadRepositories();
    } catch (exception) {
      error = _message(exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _changeSection(TrackerSection value) async {
    setState(() {
      section = value;
      loading = true;
      error = null;
    });
    try {
      if (value == TrackerSection.dashboard) await _loadDashboard();
      if (value == TrackerSection.students ||
          value == TrackerSection.repositories) {
        await _loadStudents();
      }
      if (value == TrackerSection.repositories) await _loadRepositories();
    } catch (exception) {
      error = _message(exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Map<String, dynamic>?> _showForm({
    required String title,
    required List<MapEntry<String, String>> fields,
    Map<String, dynamic>? initial,
    bool activeToggle = false,
  }) =>
      showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => TrackerFormDialog(
          title: title,
          fields: fields,
          initial: initial ?? {},
          activeToggle: activeToggle,
        ),
      );

  Future<void> _editCourse([Map<String, dynamic>? course]) async {
    final value = await _showForm(
      title: course == null ? 'Tambah kelas' : 'Ubah kelas',
      initial: course,
      fields: const [
        MapEntry('Name', 'Nama kelas'),
        MapEntry('Semester', 'Semester'),
        MapEntry('Year', 'Tahun'),
      ],
    );
    if (value == null) return;
    try {
      final id = course?['Id'];
      await (id == null
          ? api.post('/courses', value)
          : api.put('/courses/$id', value));
      notice = 'Data kelas berhasil disimpan.';
      await _loadCourses();
    } catch (exception) {
      setState(() => error = _message(exception));
    }
  }

  Future<void> _editStudent([Map<String, dynamic>? student]) async {
    if (selectedCourseId == null) return;
    final value = await _showForm(
      title: student == null ? 'Tambah mahasiswa' : 'Ubah mahasiswa',
      initial: student,
      fields: const [
        MapEntry('StudentNumber', 'Nomor mahasiswa'),
        MapEntry('Name', 'Nama lengkap'),
        MapEntry('Email', 'Alamat email'),
        MapEntry('GithubUsername', 'Username GitHub'),
      ],
    );
    if (value == null) return;
    try {
      final id = student?['Id'];
      await (id == null
          ? api.post('/courses/$selectedCourseId/students', value)
          : api.put('/students/$id', value));
      notice = 'Data mahasiswa berhasil disimpan.';
      await _loadStudents();
      await _loadDashboard();
      if (mounted) setState(() {});
    } catch (exception) {
      setState(() => error = _message(exception));
    }
  }

  Future<void> _editRepository([Map<String, dynamic>? repository]) async {
    if (selectedStudentId == null) return;
    final value = await _showForm(
      title: repository == null ? 'Tambah repositori' : 'Ubah repositori',
      initial: repository,
      activeToggle: true,
      fields: const [
        MapEntry('Name', 'Nama repositori'),
        MapEntry('RepositoryUrl', 'URL repositori GitHub'),
      ],
    );
    if (value == null) return;
    try {
      final id = repository?['Id'];
      await (id == null
          ? api.post('/students/$selectedStudentId/repositories', value)
          : api.put('/repositories/$id', value));
      notice = 'Data repositori berhasil disimpan.';
      await _loadRepositories();
      if (mounted) setState(() {});
    } catch (exception) {
      setState(() => error = _message(exception));
    }
  }

  Future<void> _delete(
      String path, String label, Future<void> Function() refresh) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus $label?'),
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
    if (confirm != true) return;
    try {
      await api.delete(path);
      notice = '$label berhasil dihapus.';
      await refresh();
      if (mounted) setState(() {});
    } catch (exception) {
      setState(() => error = _message(exception));
    }
  }

  Future<void> _syncAll() async {
    final id = selectedCourseId;
    if (id == null) return;
    setState(() {
      syncing = true;
      error = null;
      notice = null;
    });
    try {
      final result = _map(await api.post('/courses/$id/sync'));
      final results = _maps(result['Results']);
      final failures =
          results.where((item) => !item.containsKey('NewCommitCount')).toList();
      notice =
          '${result['SyncedRepositoryCount'] ?? 0} repositori selesai disinkronkan.';
      if (failures.isNotEmpty) {
        error = failures.map((item) => item['Message']).join('\n');
      }
      await _loadDashboard();
    } catch (exception) {
      error = _message(exception);
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> _syncRepository(Map<String, dynamic> repository) async {
    setState(() {
      syncing = true;
      error = null;
      notice = null;
    });
    try {
      final result =
          _map(await api.post('/repositories/${repository['Id']}/sync'));
      notice = '${repository['Name']}: ${result['Message']}';
      await _loadRepositories();
      await _loadDashboard();
    } catch (exception) {
      error = _message(exception);
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  String _message(Object exception) =>
      exception.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) => TrackerScreenFrame(
        toolbar: _toolbar(),
        error: error,
        notice: notice,
        content: loading
            ? const Center(child: CircularProgressIndicator())
            : _buildSection(),
      );

  Widget _toolbar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        courses.any((item) => item['Id'] == selectedCourseId)
                            ? selectedCourseId
                            : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Kelas'),
                    items: courses
                        .map((course) => DropdownMenuItem(
                              value: course['Id'].toString(),
                              child:
                                  Text('${course['Name']} · ${course['Year']}'),
                            ))
                        .toList(),
                    onChanged: _changeCourse,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Kelola kelas',
                  onPressed: () => _changeSection(TrackerSection.courses),
                  icon: const Icon(Icons.edit_note),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<TrackerSection>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: TrackerSection.dashboard,
                      label: Text('Ringkasan'),
                      icon: Icon(Icons.dashboard_outlined)),
                  ButtonSegment(
                      value: TrackerSection.students,
                      label: Text('Mahasiswa'),
                      icon: Icon(Icons.people_outline)),
                  ButtonSegment(
                      value: TrackerSection.repositories,
                      label: Text('Repositori'),
                      icon: Icon(Icons.code)),
                ],
                selected: {
                  section == TrackerSection.courses ||
                          section == TrackerSection.progress
                      ? TrackerSection.dashboard
                      : section
                },
                onSelectionChanged: (value) => _changeSection(value.first),
              ),
            ),
          ],
        ),
      );

  Widget _buildSection() {
    if (courses.isEmpty) {
      return _empty(
          'Belum ada kelas', 'Buat kelas untuk mulai mengelola mahasiswa.',
          action: 'Tambah kelas', onPressed: () => _editCourse());
    }
    return switch (section) {
      TrackerSection.dashboard => _dashboardSection(),
      TrackerSection.courses => _coursesSection(),
      TrackerSection.students => _studentsSection(),
      TrackerSection.repositories => _repositoriesSection(),
      TrackerSection.progress => _progressSection(),
    };
  }

  Widget _dashboardSection() {
    final summary = _map(dashboard?['Summary']);
    final studentRows = _maps(dashboard?['Students']);
    final metrics = [
      ('Mahasiswa', summary['TotalStudents'] ?? 0, Icons.people_outline, teal),
      ('Repositori', summary['TotalRepositories'] ?? 0, Icons.code, ink),
      ('Total commit', summary['TotalCommits'] ?? 0, Icons.commit, coral),
      (
        'Mahasiswa aktif',
        summary['ActiveStudents'] ?? 0,
        Icons.trending_up,
        teal
      ),
      (
        'Belum ada commit',
        summary['StudentsWithoutCommits'] ?? 0,
        Icons.hourglass_empty,
        coral
      ),
    ];
    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                  child: Text('Progres GitHub mahasiswa',
                      style: TextStyle(
                          color: ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800))),
              FilledButton.tonalIcon(
                onPressed: syncing ? null : _syncAll,
                icon: syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync, size: 17),
                label: Text(syncing ? 'Menyinkronkan' : 'Sinkronkan semua'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: metrics
                    .map((item) => SizedBox(
                          width: width,
                          child: MetricCard(
                              title: item.$1,
                              value: item.$2.toString(),
                              icon: item.$3,
                              color: item.$4),
                        ))
                    .toList());
          }),
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(
                child: Text('Aktivitas mahasiswa',
                    style: TextStyle(
                        color: ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800))),
            IconButton(
                onPressed: _loadCourses,
                tooltip: 'Muat ulang',
                icon: const Icon(Icons.refresh)),
          ]),
          if (studentRows.isEmpty)
            _empty('Belum ada mahasiswa', 'Tambahkan mahasiswa ke kelas ini.',
                action: 'Tambah mahasiswa',
                onPressed: () => _changeSection(TrackerSection.students))
          else
            ...studentRows.map(_studentProgressTile),
        ],
      ),
    );
  }

  Widget _studentProgressTile(Map<String, dynamic> student) {
    final status = student['ActivityStatus']?.toString() ?? 'NO_COMMIT';
    final color = status == 'ACTIVE'
        ? teal
        : status == 'INACTIVE'
            ? const Color(0xffc78131)
            : coral;
    final label = status == 'ACTIVE'
        ? 'Aktif'
        : status == 'INACTIVE'
            ? 'Tidak aktif'
            : 'Belum ada commit';
    return Card(
      color: paper,
      child: ListTile(
        onTap: () => _loadProgress(student['StudentId'].toString()),
        leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(Icons.person_outline, color: color)),
        title: Text(student['StudentName']?.toString() ?? '',
            style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${student['StudentNumber']} · ${student['RepositoryCount']} repositori · ${student['TotalCommits']} commit\nTerakhir: ${formatDate(student['LatestCommitAt'])}'),
        isThreeLine: true,
        trailing:
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _coursesSection() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(
                child: Text('Kelola kelas',
                    style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800))),
            FilledButton.icon(
                onPressed: () => _editCourse(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah')),
          ]),
          const SizedBox(height: 10),
          ...courses.map((course) => Card(
              color: paper,
              child: ListTile(
                title: Text(course['Name'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle:
                    Text('Semester ${course['Semester']} · ${course['Year']}'),
                onTap: () => _changeCourse(course['Id']?.toString()),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') _editCourse(course);
                    if (action == 'delete') {
                      _delete(
                          '/courses/${course['Id']}', 'kelas', _loadCourses);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Ubah')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ))),
        ],
      );

  Widget _studentsSection() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(
                child: Text('Daftar mahasiswa',
                    style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800))),
            FilledButton.icon(
                onPressed: () => _editStudent(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah')),
          ]),
          const SizedBox(height: 10),
          if (students.isEmpty)
            _empty('Belum ada mahasiswa',
                'Tambahkan mahasiswa ke kelas yang dipilih.'),
          ...students.map((student) => Card(
              color: paper,
              child: ListTile(
                onTap: () => _loadProgress(student['Id'].toString()),
                leading: const CircleAvatar(
                    backgroundColor: Color(0xffe5eee1),
                    child: Icon(Icons.person_outline, color: teal)),
                title: Text(student['Name'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${student['StudentNumber']} · ${student['GithubUsername']}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') _editStudent(student);
                    if (action == 'repositories') {
                      selectedStudentId = student['Id'].toString();
                      _changeSection(TrackerSection.repositories);
                    }
                    if (action == 'delete') {
                      _delete('/students/${student['Id']}', 'mahasiswa',
                          _loadStudents);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'repositories', child: Text('Repositori')),
                    PopupMenuItem(value: 'edit', child: Text('Ubah')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ))),
        ],
      );

  Widget _repositoriesSection() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue:
                students.any((student) => student['Id'] == selectedStudentId)
                    ? selectedStudentId
                    : null,
            decoration: const InputDecoration(labelText: 'Mahasiswa'),
            items: students
                .map((student) => DropdownMenuItem(
                      value: student['Id'].toString(),
                      child: Text(
                          '${student['Name']} · ${student['StudentNumber']}'),
                    ))
                .toList(),
            onChanged: (value) async {
              setState(() {
                selectedStudentId = value;
                loading = true;
              });
              try {
                await _loadRepositories();
              } catch (exception) {
                error = _message(exception);
              }
              if (mounted) setState(() => loading = false);
            },
          ),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(
                child: Text('Repositori GitHub',
                    style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800))),
            IconButton.filledTonal(
              tooltip: 'Tambah repositori',
              onPressed:
                  selectedStudentId == null ? null : () => _editRepository(),
              icon: const Icon(Icons.add),
            ),
          ]),
          if (repositories.isEmpty)
            _empty('Belum ada repositori',
                'Tambahkan URL GitHub publik mahasiswa.'),
          ...repositories.map((repository) => Card(
              color: paper,
              child: ListTile(
                leading: Icon(
                    repository['IsActive'] == true
                        ? Icons.code
                        : Icons.pause_circle_outline,
                    color: teal),
                title: Text(repository['Name'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${repository['Owner']}/${repository['RepositoryName']}\n${repository['CommitCount'] ?? 0} commit · Sinkron ${formatDate(repository['LastSyncedAt'])}'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'sync') _syncRepository(repository);
                    if (action == 'edit') _editRepository(repository);
                    if (action == 'delete') {
                      _delete('/repositories/${repository['Id']}', 'repositori',
                          _loadRepositories);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'sync', child: Text('Sinkronkan commit')),
                    PopupMenuItem(value: 'edit', child: Text('Ubah')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ))),
          if (repositories
              .any((repository) => repository['IsActive'] == true)) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: syncing ? null : _syncAll,
              icon: syncing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: Text(syncing
                  ? 'Menyinkronkan...'
                  : 'Sinkronkan semua repositori kelas'),
            ),
          ],
        ],
      );

  Widget _progressSection() {
    if (progress == null) {
      return _empty('Progres tidak tersedia',
          'Pilih mahasiswa dari daftar untuk membuka detail.');
    }
    final student = _map(progress?['Student']);
    final repos = _maps(progress?['Repositories']);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(student['Name']?.toString() ?? '',
            style: const TextStyle(
                color: ink, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
            '${student['StudentNumber']} · ${student['Email']} · GitHub: ${student['GithubUsername']}',
            style: const TextStyle(color: muted)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          MetricCard(
              title: 'Total commit',
              value: '${progress?['TotalCommits'] ?? 0}',
              icon: Icons.commit,
              color: teal),
          MetricCard(
              title: 'Repositori',
              value: '${repos.length}',
              icon: Icons.code,
              color: ink),
          MetricCard(
              title: 'Commit terbaru',
              value: formatDate(progress?['LatestCommitAt']),
              icon: Icons.history,
              color: coral),
        ]),
        const SizedBox(height: 18),
        const Text('Riwayat commit',
            style: TextStyle(
                color: ink, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (repos.isEmpty)
          _empty('Belum ada repositori',
              'Mahasiswa belum memiliki repositori terdaftar.'),
        ...repos.map((repository) {
          final commits = _maps(repository['Commits']);
          return Card(
            color: paper,
            child: ExpansionTile(
              leading: const Icon(Icons.code, color: teal),
              title: Text(repository['Name'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${repository['Owner']}/${repository['RepositoryName']} · ${commits.length} commit'),
              children: commits.isEmpty
                  ? [const ListTile(title: Text('Belum ada commit tersimpan.'))]
                  : commits
                      .map((commit) => ListTile(
                            title: Text(
                                commit['Message'].toString().split('\n').first,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${commit['AuthorName']} · ${formatDate(commit['CommittedAt'])} · ${(commit['Sha']?.toString() ?? '').substring(0, (commit['Sha']?.toString() ?? '').length.clamp(0, 8))}'),
                            trailing: IconButton(
                              tooltip: 'Buka commit di GitHub',
                              onPressed: () => launchUrl(
                                  Uri.parse(commit['CommitUrl'].toString()),
                                  mode: LaunchMode.externalApplication),
                              icon: const Icon(Icons.open_in_new, size: 18),
                            ),
                          ))
                      .toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _empty(String title, String description,
          {String? action, VoidCallback? onPressed}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inbox_outlined, color: muted, size: 32),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12)),
          if (action != null && onPressed != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onPressed, child: Text(action)),
          ],
        ]),
      );
}

class TrackerFormDialog extends StatefulWidget {
  const TrackerFormDialog({
    required this.title,
    required this.fields,
    required this.initial,
    this.activeToggle = false,
    super.key,
  });
  final String title;
  final List<MapEntry<String, String>> fields;
  final Map<String, dynamic> initial;
  final bool activeToggle;

  @override
  State<TrackerFormDialog> createState() => _TrackerFormDialogState();
}

class _TrackerFormDialogState extends State<TrackerFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  late bool active;

  @override
  void initState() {
    super.initState();
    controllers = {
      for (final field in widget.fields)
        field.key: TextEditingController(
            text: widget.initial[field.key]?.toString() ?? ''),
    };
    active = widget.initial['IsActive'] != false;
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ...widget.fields.map((field) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: controllers[field.key],
                      keyboardType: field.key == 'Year'
                          ? TextInputType.number
                          : field.key == 'Email'
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                      decoration: InputDecoration(labelText: field.value),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bagian ini wajib diisi.';
                        }
                        if (field.key == 'Email' && !value.contains('@')) {
                          return 'Masukkan alamat email yang valid.';
                        }
                        if (field.key == 'Year' && int.tryParse(value) == null) {
                          return 'Masukkan tahun yang valid.';
                        }
                        if (field.key == 'RepositoryUrl' &&
                            !value.startsWith('https://github.com/')) {
                          return 'Gunakan URL GitHub yang valid.';
                        }
                        return null;
                      },
                    ),
                  )),
              if (widget.activeToggle)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repositori aktif'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final result = <String, dynamic>{
                for (final entry in controllers.entries)
                  entry.key: entry.value.text.trim(),
              };
              if (result.containsKey('Year')) {
                result['Year'] = int.parse(result['Year'] as String);
              }
              if (widget.activeToggle) result['IsActive'] = active;
              Navigator.pop(context, result);
            },
            child: const Text('Simpan'),
          ),
        ],
      );
}

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : <Map<String, dynamic>>[];

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
