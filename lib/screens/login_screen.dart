// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Ingresa tu correo y contraseña');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Capturar referencias antes de los gaps asíncronos
    final userProvider = context.read<UserProvider>();
    final navigator = Navigator.of(context);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userProvider.loadUser(cred.user!.uid);

      final user = userProvider.currentUser;

      // Sin documento en Firestore → cuenta no configurada
      if (user == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Tu cuenta no está configurada. Contacta al administrador.';
        });
        return;
      }

      // Cuenta desactivada
      if (!user.activo) {
        await FirebaseAuth.instance.signOut();
        userProvider.clearUser();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Tu cuenta está desactivada. Contacta al administrador.';
        });
        return;
      }

      navigator.pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'INVALID_LOGIN_CREDENTIALS':
          msg = 'Correo o contraseña incorrectos';
          break;
        case 'user-disabled':
          msg = 'Tu cuenta está deshabilitada';
          break;
        case 'too-many-requests':
          msg = 'Demasiados intentos. Intenta más tarde';
          break;
        default:
          msg = 'Error al ingresar. Intenta nuevamente';
      }
      setState(() {
        _loading = false;
        _error = msg;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error inesperado. Intenta nuevamente';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo_vertical.jpg',
                    width: 200,
                  ),
                ),
                const SizedBox(height: 48),

                // Email
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enabled: !_loading,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 16),

                // Contraseña
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 12),

                // Mensaje de error
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _error != null
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),

                // Botón Ingresar
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5DB5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'Ingresar',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
