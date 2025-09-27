import 'package:flutter/material.dart';
import '../../../data/repositories/userRepository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final UserRepository _userRepository = UserRepository();

  bool _isLogin = true;
  String _message = '';
  Color _messageColor = Colors.red;

  Future<void> _showMessage(String message, Color color, {int durationMs = 1000}) async {
    setState(() {
      _message = message;
      _messageColor = color;
    });
    await Future.delayed(Duration(milliseconds: durationMs));
    if (mounted) {
      setState(() {
        _message = '';
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      bool success;
      if (_isLogin) {
        // Login solo con username + password
        success = await _userRepository.loginUser(username, password);
        if (success) {
          await _showMessage('✅ Bienvenido!', Colors.green, durationMs: 800);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          await _showMessage('❌ Credenciales inválidas', Colors.red);
        }
      } else {
        // Registro con username + email + password
        success = await _userRepository.registerUser(username, email, password);
        if (success) {
          // Registro exitoso → mostrar mensaje corto y volver a login
          await _showMessage('✅ Usuario registrado con éxito', Colors.green, durationMs: 800);
          setState(() {
            _isLogin = true; // volver al modo login
            _emailController.clear();
            _passwordController.clear();
            _usernameController.clear();
          });
        } else {
          await _showMessage('⚠️ El usuario o correo ya existen', Colors.orange);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isLogin ? Icons.lock_open : Icons.person_add,
                      size: 60,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campo username
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Ingrese su usuario' : null,
                    ),
                    const SizedBox(height: 16),

                    // Campo email solo para registro
                    if (!_isLogin)
                      Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Ingrese su correo' : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // Campo contraseña
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: true,
                      validator: (value) =>
                          value!.isEmpty ? 'Ingrese su contraseña' : null,
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: Text(
                        _isLogin ? 'Login' : 'Registrar',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? '¿No tienes cuenta? Crear una'
                            : '¿Ya tienes cuenta? Inicia sesión',
                        style: const TextStyle(color: Colors.blueAccent),
                      ),
                    ),

                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        _message,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _messageColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
