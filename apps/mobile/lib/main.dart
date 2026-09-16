import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyBsTO332dtvoRfqy321FASqDhTeFzUD6Xc');
const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:185834578847:web:cb2cf16c3fede5f25353aa');
const firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '185834578847');
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'appstudymate-13de0');
const firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: 'appstudymate-13de0.firebaseapp.com');
const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'appstudymate-13de0.firebasestorage.app');
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
  Map<String, dynamic>? localUser;
  List<Map<String, dynamic>> localUsers = [];
  bool firebaseDisabled = false;
  final Map<String, List<Map<String, dynamic>>> localData = {
    'schedules': [],
    'tasks': [],
    'notes': [],
  };
  bool get firebaseConfigProvided => firebaseApiKey.isNotEmpty || firebaseAppId.isNotEmpty || firebaseProjectId.isNotEmpty;
  bool get firebaseReady => !firebaseDisabled && kIsWeb && firebaseApiKey.startsWith('AIza') && firebaseAppId.startsWith('1:') && firebaseProjectId.isNotEmpty && !firebaseProjectId.contains('PROJECT_ID') && !firebaseProjectId.contains('nama-project');

  Future<void> init() async {
    if (!firebaseConfigProvided) {
      await _loadLocalData();
      return;
    }
    if (!firebaseReady) {
      throw Exception('Konfigurasi Firebase Web tidak valid. Gunakan apiKey, appId, dan projectId asli dari Firebase Console.');
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
      localUsers = (jsonDecode(savedUsers) as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
      localUser = localUsers.isEmpty ? null : localUsers.last;
    }
    final savedUser = preferences.getString('local_user');
    if (savedUser != null) localUser = jsonDecode(savedUser) as Map<String, dynamic>;
    for (final type in localData.keys) {
      final savedItems = preferences.getString(type);
      if (savedItems != null) localData[type] = (jsonDecode(savedItems) as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
  }

  Future<dynamic> request(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    if (!firebaseReady) return localRequest(path, body: body);

    if (path == '/auth/login') {
      final email = body!['Email'] as String? ?? '';
      final password = body['Password'] as String? ?? '';
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user == null) throw Exception('Firebase tidak mengembalikan user setelah login');
      final profile = await _findProfile(user, email);
      return {'Token': await user.getIdToken() ?? '', 'User': {'Id': user.uid, 'Name': profile['Name'] ?? user.displayName ?? 'User', 'Email': user.email ?? email, 'Nim': profile['Nim'] ?? ''}};
    }

    if (path == '/auth/register') {
      final email = (body!['Email'] as String? ?? '').trim().toLowerCase();
      final password = body['Password'] as String? ?? '';
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user == null) throw Exception('Firebase tidak mengembalikan user setelah pendaftaran');
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
      return {'Token': await user.getIdToken() ?? '', 'User': {'Id': user.uid, 'Name': name, 'Email': email, 'Nim': nim}};
    }

    if (path == '/dashboard') {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Sesi Firebase tidak ditemukan');
      final tasks = await FirebaseFirestore.instance.collection('tasks').where('UserId', isEqualTo: userId).get();
      final schedules = await FirebaseFirestore.instance.collection('schedules').where('UserId', isEqualTo: userId).get();
      final notes = await FirebaseFirestore.instance.collection('notes').where('UserId', isEqualTo: userId).get();
      final completed = tasks.docs.where((document) => document.data()['Status'] == 'DONE').length;
      return {'Summary': {'TotalTasks': tasks.size, 'TotalCompletedTasks': completed, 'TotalPendingTasks': tasks.size - completed, 'TotalOverdueTasks': 0, 'TotalSchedulesToday': schedules.size, 'TotalNotes': notes.size}};
    }
    throw Exception('Endpoint tidak tersedia');
  }

  Future<Map<String, dynamic>> firebaseUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {};
    final profile = await _findProfile(currentUser, currentUser.email ?? '');
    return {'Id': currentUser.uid, 'Name': profile['Name'] ?? currentUser.displayName ?? 'User', 'Email': currentUser.email ?? '', 'Nim': profile['Nim'] ?? ''};
  }

  Future<Map<String, dynamic>> _findProfile(User user, String email) async {
    final byId = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (byId.exists) return byId.data() ?? {};
    final byEmail = await FirebaseFirestore.instance.collection('users').where('Email', isEqualTo: email).limit(1).get();
    return byEmail.docs.isEmpty ? {} : byEmail.docs.first.data();
  }

  Future<List<dynamic>> list(String path) async {
    final type = path.replaceFirst('/', '');
    if (!firebaseReady) return localData[type] ?? [];
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('Sesi Firebase tidak ditemukan');
    final snapshot = await FirebaseFirestore.instance.collection(type).where('UserId', isEqualTo: userId).get();
    return snapshot.docs.map((document) => {'Id': document.id, ...document.data()}).toList();
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
    await FirebaseFirestore.instance.collection(type).doc(item['Id'] as String).set({...item, 'UserId': userId});
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

  Future<dynamic> localRequest(String path, {Map<String, dynamic>? body}) async {
    if (path == '/auth/register') {
      final email = body?['Email']?.toString().trim().toLowerCase() ?? '';
      if (localUsers.any((account) => account['Email'] == email)) throw Exception('Email sudah terdaftar');
      localUser = {'Id': 'local-user', 'Name': body?['Name'] ?? '', 'Email': email, 'Nim': body?['Nim'] ?? '', 'Password': body?['Password'] ?? ''};
      localUsers.add(localUser!);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('local_user', jsonEncode(localUser));
      await preferences.setString('local_users', jsonEncode(localUsers));
      return {'Token': 'local-token', 'User': localUser};
    }
    if (path == '/auth/login') {
      final email = body?['Email']?.toString().trim().toLowerCase();
      final account = localUsers.cast<Map<String, dynamic>?>().firstWhere((item) => item?['Email'] == email && item?['Password'] == body?['Password'], orElse: () => null);
      if (account == null) throw Exception('Email atau password salah');
      localUser = account;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('local_user', jsonEncode(localUser));
      return {'Token': 'local-token', 'User': localUser};
    }
    if (path == '/dashboard') {
      final tasks = localData['tasks']!;
      final completed = tasks.where((item) => item['Status'] == 'DONE').length;
      return {'Summary': {'TotalTasks': tasks.length, 'TotalCompletedTasks': completed, 'TotalPendingTasks': tasks.length - completed, 'TotalOverdueTasks': 0, 'TotalSchedulesToday': localData['schedules']!.length, 'TotalNotes': localData['notes']!.length}};
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
        if (user!.isNotEmpty) client.token = await FirebaseAuth.instance.currentUser?.getIdToken();
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
    if (startupError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off, size: 48, color: coral),
              const SizedBox(height: 16),
              const Text('Firebase belum siap', style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(startupError!, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: () { setState(() { loading = true; startupError = null; }); restore(); }, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
            ]),
          ),
        ),
      );
    }
    if (user == null) return LoginPage(onLogin: login);
    return HomePage(client: client, user: user!, onLogout: () async {
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
  void initState() { super.initState(); _reload(); }

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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.client.deleteItem(widget.type, id);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(future: future, builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    final items = snapshot.data ?? [];
    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 90), children: [
        if (items.isEmpty) const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('Belum ada data', style: TextStyle(color: muted)))),
        ...items.map((item) {
          final data = item as Map<String, dynamic>;
          final title = data['Title'] ?? data['CourseName'] ?? 'Item';
          final detail = widget.type == 'tasks'
              ? '${data['Description'] ?? ''}\nDeadline: ${formatDate(data['Deadline'])} - ${statusLabel(data['Status'])}'
              : widget.type == 'notes'
                  ? data['Content'] ?? ''
                  : '${data['Day'] ?? ''} | ${data['StartTime'] ?? ''}-${data['EndTime'] ?? ''} | ${data['Room'] ?? ''}';
          return Card(color: paper, child: ListTile(
            isThreeLine: widget.type == 'tasks',
            title: Text(title.toString(), style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
            subtitle: Text(detail.toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
            leading: Icon(widget.type == 'tasks' ? Icons.check_circle_outline : widget.type == 'notes' ? Icons.notes_outlined : Icons.schedule, color: teal),
            trailing: PopupMenuButton<String>(
              onSelected: (action) => action == 'edit' ? _edit(data) : _delete(data['Id'].toString()),
              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Hapus'))],
            ),
          ));
        }),
      ]),
      Positioned(right: 20, bottom: 20, child: FloatingActionButton.extended(onPressed: () => _edit(), backgroundColor: teal, icon: const Icon(Icons.add), label: Text(widget.type == 'schedules' ? 'Jadwal' : widget.type == 'tasks' ? 'Tugas' : 'Catatan'))),
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
    fields = {for (final key in widget.type == 'schedules' ? ['CourseName', 'Lecturer', 'Day', 'StartTime', 'EndTime', 'Room'] : widget.type == 'tasks' ? ['Title', 'Description'] : ['Title', 'Content']) key: TextEditingController(text: item[key]?.toString() ?? '')};
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
    final picked = await showDatePicker(context: context, initialDate: deadline ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (picked != null) setState(() => deadline = picked);
  }

  void submit() {
    if (fields.values.any((controller) => controller.text.trim().isEmpty)) return;
    final item = {for (final entry in fields.entries) entry.key: entry.value.text.trim(), 'Id': widget.item?['Id'] ?? '${widget.type}-${DateTime.now().microsecondsSinceEpoch}'};
    if (widget.type == 'tasks') {
      item['Status'] = status;
      item['Deadline'] = (deadline ?? DateTime.now()).toIso8601String();
    }
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.type == 'schedules' ? 'jadwal' : widget.type == 'tasks' ? 'tugas' : 'catatan';
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
                maxLines: entry.key == 'Description' || entry.key == 'Content' ? 3 : 1,
                decoration: InputDecoration(labelText: fieldLabel(entry.key)),
              ),
            )),
            if (widget.type == 'tasks') ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deadline'),
                subtitle: Text(deadline == null ? 'Pilih tanggal' : formatDate(deadline)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: pickDeadline,
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'TODO', child: Text('Belum dikerjakan')),
                  DropdownMenuItem(value: 'IN_PROGRESS', child: Text('Dikerjakan')),
                  DropdownMenuItem(value: 'DONE', child: Text('Selesai')),
                ],
                onChanged: (value) => setState(() => status = value ?? 'TODO'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
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
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [CircleAvatar(radius: 34, backgroundColor: teal, child: Text((user['Name'] as String? ?? 'A').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 26))), const SizedBox(height: 16), Center(child: Text(user['Name']?.toString() ?? '', style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 22))), Center(child: Text(user['Email']?.toString() ?? '', style: const TextStyle(color: muted))), const SizedBox(height: 28), OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout), label: const Text('Keluar'))]);
}
