import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool useFirebase = bool.fromEnvironment('USE_FIREBASE', defaultValue: false);
const bool firebaseConfigured = bool.fromEnvironment('FIREBASE_CONFIGURED', defaultValue: false);
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4000/api');
const ink = Color(0xff18323a);
const muted = Color(0xff718087);
const cream = Color(0xfff7f4ed);
const paper = Color(0xfffffdf8);
const teal = Color(0xff2c7775);
const coral = Color(0xffe1715d);
const line = Color(0xffe2e0d8);

void main() => runApp(const StudyMateApp());

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AppStudyMate',
        theme: ThemeData(
          scaffoldBackgroundColor: cream,
          colorScheme: ColorScheme.fromSeed(seedColor: teal),
          fontFamily: 'sans',
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: paper,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
          ),
        ),
        home: const SessionGate(),
      );
}

class ApiClient {
  String? token;
  bool get firebaseReady => kIsWeb && useFirebase && firebaseConfigured;

  Future<void> init() async {
    if (!firebaseReady) return;
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: '',
        appId: '',
        messagingSenderId: '',
        projectId: '',
        authDomain: '',
        storageBucket: '',
      ),
    );
  }

  Future<dynamic> request(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    if (!firebaseReady) return _mockRequest(path, method: method, body: body);

    if (path == '/auth/login') {
      final email = body!['Email'] as String? ?? '';
      final password = body['Password'] as String? ?? '';
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      return {'Token': await userCredential.user?.getIdToken() ?? '', 'User': {'Id': user?.uid ?? '', 'Name': user?.displayName ?? 'User', 'Email': user?.email ?? email, 'Nim': ''}};
    }

    if (path == '/auth/register') {
      final email = body!['Email'] as String? ?? '';
      final password = body['Password'] as String? ?? '';
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      await user?.updateDisplayName(body['Name'] as String? ?? 'User');
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({'Name': body['Name'] ?? '', 'Email': email, 'Nim': body['Nim'] ?? ''});
      return {'Token': await user?.getIdToken() ?? '', 'User': {'Id': user?.uid ?? '', 'Name': body['Name'] ?? '', 'Email': email, 'Nim': body['Nim'] ?? ''}};
    }

    return {'Message': 'Firebase mode belum dikonfigurasi'};
  }

  Future<List<dynamic>> list(String path) async {
    final response = await request(path);
    return response is List<dynamic> ? response : [];
  }

  Future<dynamic> _mockRequest(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    final userMap = {
      'Id': 'demo-user-id',
      'Name': 'Budi Mahasiswa',
      'Email': 'mahasiswa@example.com',
      'Nim': '20240001',
    };

    if (path == '/auth/login') {
      final email = body?['Email'] as String? ?? '';
      final password = body?['Password'] as String? ?? '';
      if (email == 'mahasiswa@example.com' && password == 'password123') {
        return {'Token': 'demo-token', 'User': userMap};
      }
      throw Exception('Email atau password salah');
    }

    if (path == '/auth/register') {
      return {'Token': 'demo-token', 'User': {'Id': 'demo-user-id', 'Name': body?['Name'] ?? 'User', 'Email': body?['Email'] ?? '', 'Nim': body?['Nim'] ?? ''}};
    }

    if (path == '/dashboard') {
      return {
        'Summary': {'TotalTasks': 5, 'TotalCompletedTasks': 1, 'TotalPendingTasks': 3, 'TotalOverdueTasks': 1, 'TotalSchedulesToday': 2, 'TotalNotes': 2},
        'TodaySchedules': [
          {'Id': 's1', 'CourseName': 'Pemrograman Web', 'Lecturer': 'Dr. Sari', 'Day': 'Senin', 'StartTime': '08:00', 'EndTime': '10:00', 'Room': 'Lab A'},
          {'Id': 's2', 'CourseName': 'Basis Data', 'Lecturer': 'Bpk. Andi', 'Day': 'Rabu', 'StartTime': '10:00', 'EndTime': '12:00', 'Room': 'Ruang 204'},
        ],
        'UpcomingTasks': [
          {'Id': 't1', 'Title': 'API katalog buku', 'Description': 'Membuat endpoint katalog buku', 'Deadline': DateTime.now().add(const Duration(days: 2)).toIso8601String(), 'Status': 'IN_PROGRESS', 'Urgency': 'DUE_SOON'},
          {'Id': 't2', 'Title': 'Laporan basis data', 'Description': 'Menyelesaikan laporan normalisasi', 'Deadline': DateTime.now().add(const Duration(days: 5)).toIso8601String(), 'Status': 'TODO', 'Urgency': 'ON_TRACK'},
        ],
      };
    }

    if (path == '/schedules') {
      return [
      {'Id': 's1', 'CourseName': 'Pemrograman Web', 'Lecturer': 'Dr. Sari', 'Day': 'Senin', 'StartTime': '08:00', 'EndTime': '10:00', 'Room': 'Lab A'},
      {'Id': 's2', 'CourseName': 'Basis Data', 'Lecturer': 'Bpk. Andi', 'Day': 'Rabu', 'StartTime': '10:00', 'EndTime': '12:00', 'Room': 'Ruang 204'},
    ];
    }

    if (path == '/tasks') {
      return [
      {'Id': 't1', 'Title': 'API katalog buku', 'Description': 'Membuat endpoint katalog buku', 'Deadline': DateTime.now().add(const Duration(days: 2)).toIso8601String(), 'Status': 'IN_PROGRESS', 'Urgency': 'DUE_SOON'},
      {'Id': 't2', 'Title': 'Review proposal', 'Description': 'Review proposal skripsi', 'Deadline': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'Status': 'TODO', 'Urgency': 'OVERDUE'},
    ];
    }

    if (path == '/notes') {
      return [
      {'Id': 'n1', 'Title': 'Catatan REST API', 'Content': 'REST menggunakan resource dan HTTP method.', 'RelatedTaskId': 't1'},
      {'Id': 'n2', 'Title': 'Normalisasi database', 'Content': 'Pastikan setiap atribut bernilai atomik pada 1NF.'},
    ];
    }

    if (path.startsWith('/profile')) return userMap;
    return {};
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

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('token');
    final savedUser = preferences.getString('user');
    if (token != null && savedUser != null) {
      client.token = token;
      user = jsonDecode(savedUser) as Map<String, dynamic>;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> login(String email, String password, bool register, String name, String nim) async {
    final result = await client.request(register ? '/auth/register' : '/auth/login', method: 'POST', body: register ? {'Name': name, 'Email': email, 'Nim': nim, 'Password': password} : {'Email': email, 'Password': password});
    client.token = result['Token'] as String;
    user = result['User'] as Map<String, dynamic>;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('token', client.token!);
    await preferences.setString('user', jsonEncode(user));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (user == null) return LoginPage(onLogin: login);
    return HomePage(client: client, user: user!, onLogout: () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
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
    setState(() { busy = true; error = null; });
    try {
      await widget.onLogin(email.text, password.text, register, name.text, nim.text);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString().replaceFirst('Exception: ', ''));
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(16)), child: const Text('AS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
                  const SizedBox(height: 24),
                  const Text('APPSTUDYMATE', style: TextStyle(color: coral, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 11)),
                  const SizedBox(height: 10),
                  Text(register ? 'Mulai lebih teratur.' : 'Selamat datang kembali.', style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 32)),
                  const SizedBox(height: 10),
                  const Text('Semua jadwal, tugas, dan catatanmu dalam satu ruang.', style: TextStyle(color: muted, fontSize: 15)),
                  const SizedBox(height: 26),
                  if (register) ...[field('Nama lengkap', name, 'Nama kamu'), field('NIM', nim, '20240001')],
                  field('Email', email, 'nama@email.com'),
                  field('Password', password, 'Minimal 6 karakter', obscure: true),
                  if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(backgroundColor: teal, padding: const EdgeInsets.all(16)), child: Text(busy ? 'Memproses...' : register ? 'Buat akun' : 'Masuk'))),
                  Center(child: TextButton(onPressed: () => setState(() { register = !register; error = null; }), child: Text(register ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar'))),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget field(String label, TextEditingController controller, String hint, {bool obscure = false}) => Padding(padding: const EdgeInsets.only(bottom: 15), child: TextField(controller: controller, obscureText: obscure, decoration: InputDecoration(labelText: label, hintText: hint)));
}

class HomePage extends StatefulWidget {
  const HomePage({required this.client, required this.user, required this.onLogout, super.key});
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titles[tab]), backgroundColor: cream, foregroundColor: ink, elevation: 0),
        body: IndexedStack(index: tab, children: [Dashboard(client: widget.client, user: widget.user), DataList(client: widget.client, type: 'schedules'), DataList(client: widget.client, type: 'tasks'), DataList(client: widget.client, type: 'notes'), Profile(user: widget.user, onLogout: widget.onLogout)]),
        bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'), NavigationDestination(icon: Icon(Icons.schedule_outlined), label: 'Jadwal'), NavigationDestination(icon: Icon(Icons.task_alt_outlined), label: 'Tugas'), NavigationDestination(icon: Icon(Icons.notes_outlined), label: 'Catatan'), NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil')]),
      );
}

class Dashboard extends StatelessWidget {
  const Dashboard({required this.client, required this.user, super.key});
  final ApiClient client;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(future: client.request('/dashboard'), builder: (context, snapshot) {
        final summary = snapshot.data?['Summary'] as Map<String, dynamic>? ?? {};
        final cards = [('Tugas', summary['TotalTasks'] ?? 0), ('Selesai', summary['TotalCompletedTasks'] ?? 0), ('Pending', summary['TotalPendingTasks'] ?? 0), ('Terlambat', summary['TotalOverdueTasks'] ?? 0)];
        return ListView(padding: const EdgeInsets.all(24), children: [
          const Text('APPSTUDYMATE', style: TextStyle(color: coral, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 11)),
          const SizedBox(height: 10),
          Text('Halo, ${(user['Name'] as String? ?? '').split(' ').first}.', style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 30)),
          const Text('Mari jaga ritme belajarmu hari ini.', style: TextStyle(color: muted)),
          const SizedBox(height: 24),
          Wrap(spacing: 10, runSpacing: 10, children: cards.map((item) => SizedBox(width: MediaQuery.sizeOf(context).width / 2 - 34, child: Card(color: paper, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item.$2}', style: const TextStyle(color: teal, fontSize: 28, fontWeight: FontWeight.w800)), Text(item.$1, style: const TextStyle(color: muted))]))))).toList()),
          const SizedBox(height: 24),
          const Text('Ringkasan aktivitas', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
          if (snapshot.hasError) const Padding(padding: EdgeInsets.only(top: 16), child: Text('Tidak dapat memuat data dashboard.', style: TextStyle(color: muted))),
          if (snapshot.connectionState == ConnectionState.waiting) const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
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
  void initState() { super.initState(); future = widget.client.list('/${widget.type}'); }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(future: future, builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    final items = snapshot.data ?? [];
    return ListView(padding: const EdgeInsets.all(20), children: [if (items.isEmpty) const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('Belum ada data', style: TextStyle(color: muted)))), ...items.map((item) { final data = item as Map<String, dynamic>; final title = data['Title'] ?? data['CourseName'] ?? 'Item'; final detail = data['Description'] ?? data['Content'] ?? '${data['Day'] ?? ''} ${data['StartTime'] ?? ''}'; return Card(color: paper, child: ListTile(title: Text(title.toString(), style: const TextStyle(color: ink, fontWeight: FontWeight.w700)), subtitle: Text(detail.toString(), maxLines: 2, overflow: TextOverflow.ellipsis), leading: Icon(widget.type == 'tasks' ? Icons.check_circle_outline : widget.type == 'notes' ? Icons.notes_outlined : Icons.schedule, color: teal))); })]);
  });
}

class Profile extends StatelessWidget {
  const Profile({required this.user, required this.onLogout, super.key});
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [CircleAvatar(radius: 34, backgroundColor: teal, child: Text((user['Name'] as String? ?? 'A').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 26))), const SizedBox(height: 16), Center(child: Text(user['Name']?.toString() ?? '', style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 22))), Center(child: Text(user['Email']?.toString() ?? '', style: const TextStyle(color: muted))), const SizedBox(height: 28), OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout), label: const Text('Keluar'))]);
}
