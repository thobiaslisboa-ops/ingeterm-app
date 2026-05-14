// lib/screens/users_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../firebase_options.dart';
import '../widgets/app_app_bar.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(
        title: 'Usuarios',
        icon: Icons.people,
        showBackButton: false,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snap.data!.docs
              .map((d) => UserModel.fromFirestore(d))
              .toList();

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay usuarios registrados',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72, endIndent: 16),
            itemBuilder: (_, i) => _UserTile(user: users[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Crear usuario'),
        backgroundColor: const Color(0xFF1A5DB5),
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateUserSheet(),
    );
  }
}

// ── Tile de usuario ────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final UserModel user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.rol == UserRole.administrador;
    final chipColor =
        isAdmin ? const Color(0xFF1A5DB5) : const Color(0xFFE8690A);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: chipColor.withValues(alpha: 0.15),
        child: Text(
          user.nombre.isNotEmpty ? user.nombre[0].toUpperCase() : '?',
          style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.nombreCompleto,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: chipColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              user.rol.label,
              style: TextStyle(
                  fontSize: 11,
                  color: chipColor,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(user.email,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ),
      trailing: Switch(
        value: user.activo,
        activeTrackColor: Colors.green,
        onChanged: (_) => _toggleActivo(context, user),
      ),
    );
  }

  Future<void> _toggleActivo(BuildContext context, UserModel user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'activo': !user.activo});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── Sheet: Crear usuario ───────────────────────────────────────────────────────

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet();

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  UserRole _rol = UserRole.tecnico;
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final nombre = _nombreCtrl.text.trim();
    final apellido = _apellidoCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (nombre.isEmpty || apellido.isEmpty) {
      setState(() => _error = 'Ingresa nombre y apellido');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Ingresa el correo electrónico');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Usar Firebase Auth REST API para no cerrar la sesión del admin actual.
      // Evita el bug de "configuration-not-found" con apps secundarias en web.
      final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
      final response = await http.post(
        Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': false,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body.containsKey('error')) {
        final errMsg =
            ((body['error'] as Map<String, dynamic>)['message'] as String? ?? '')
                .toUpperCase();
        String msg;
        if (errMsg.contains('EMAIL_EXISTS')) {
          msg = 'El correo ya está registrado';
        } else if (errMsg.contains('INVALID_EMAIL')) {
          msg = 'Correo no válido';
        } else if (errMsg.contains('WEAK_PASSWORD')) {
          msg = 'Contraseña muy débil (mínimo 6 caracteres)';
        } else if (errMsg.contains('OPERATION_NOT_ALLOWED')) {
          msg = 'El inicio de sesión con email/contraseña no está habilitado en Firebase Console';
        } else {
          msg = 'Error al crear usuario: $errMsg';
        }
        setState(() {
          _saving = false;
          _error = msg;
        });
        return;
      }

      final uid = body['localId'] as String;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'rol': _rol.value,
        'activo': true,
        'fotoUrl': null,
        'creadoEn': FieldValue.serverTimestamp(),
        'ultimoAcceso': null,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Error inesperado: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(children: [
              Icon(Icons.person_add, color: Color(0xFF1A5DB5)),
              SizedBox(width: 8),
              Text('Crear usuario',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 20),

            // Nombre / Apellido
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Nombre', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _apellidoCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Apellido', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Email
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            // Contraseña
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Contraseña temporal',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rol
            const Text('Rol',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _RolChip(
                rol: UserRole.administrador,
                color: const Color(0xFF1A5DB5),
                selected: _rol == UserRole.administrador,
                onTap: () => setState(() => _rol = UserRole.administrador),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _RolChip(
                rol: UserRole.tecnico,
                color: const Color(0xFFE8690A),
                selected: _rol == UserRole.tecnico,
                onTap: () => setState(() => _rol = UserRole.tecnico),
              )),
            ]),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            // Botón
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _crear,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5DB5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Crear usuario',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolChip extends StatelessWidget {
  final UserRole rol;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _RolChip(
      {required this.rol,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            rol.label,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
