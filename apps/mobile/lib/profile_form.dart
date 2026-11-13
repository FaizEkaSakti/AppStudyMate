import 'package:flutter/material.dart';

import 'error_message.dart';
import 'profile_repository.dart';
import 'profile_validation.dart';
import 'theme/app_theme.dart';

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    required this.user,
    required this.repository,
    required this.canEditEmail,
    required this.onUserSaved,
    required this.onLogout,
    super.key,
  });

  final Map<String, dynamic> user;
  final ProfileRepository repository;
  final bool canEditEmail;
  final Future<void> Function(Map<String, dynamic> user) onUserSaved;
  final VoidCallback onLogout;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _nimController;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _nimController = TextEditingController();
    _setUserFields(widget.user);
  }

  void _setUserFields(Map<String, dynamic> user) {
    _nameController.text = user['Name']?.toString() ?? '';
    _emailController.text = user['Email']?.toString() ?? '';
    _nimController.text = user['Nim']?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nimController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      final updatedUser = await widget.repository.updateProfile(
        name: _nameController.text,
        email: _emailController.text,
        nim: _nimController.text,
      );
      await widget.onUserSaved(updatedUser);
      if (!mounted) return;
      setState(() {
        _setUserFields(updatedUser);
        _success = 'Profil berhasil diperbarui.';
      });
    } on Exception catch (exception) {
      if (mounted) {
        setState(() => _error = formatErrorMessage(exception));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim();
    final initial = name.isEmpty ? 'A' : name.substring(0, 1).toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: teal,
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontSize: 26),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            name,
            style: const TextStyle(
              color: ink,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: validateProfileName,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                enabled: !_saving && widget.canEditEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  helperText: widget.canEditEmail
                      ? null
                      : 'Email akun tidak dapat diubah.',
                ),
                validator: validateProfileEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nimController,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'NIM'),
                validator: validateProfileNim,
              ),
              if (_error != null)
                _statusMessage(_error!, Colors.red),
              if (_success != null) _statusMessage(_success!, teal),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Menyimpan...' : 'Simpan profil'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saving ? null : widget.onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
      ],
    );
  }

  Widget _statusMessage(String message, Color color) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(message, style: TextStyle(color: color)),
        ),
      );
}
