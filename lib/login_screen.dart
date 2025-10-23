import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // For AuthGate navigation

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLogin = true;
  final _auth = FirebaseAuth.instance;

  Future<void> _submit() async {
    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e", style: const TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.terracotta,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
  backgroundColor: AppTheme.warmBeige, // soft background
      body: Center(
        child: Container(
          width: size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white, // white card background
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isLogin ? "Login" : "Register",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A5F5F),
                ),
              ),
              const SizedBox(height: 20),

              // Email
              TextField(
                controller: _emailController,
                style: TextStyle(color: AppTheme.mediumBrown),
                decoration: InputDecoration(
                  hintText: "Email",
                  hintStyle: TextStyle(color: AppTheme.mediumBrown.withOpacity(0.6)),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFFE07A5F)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                style: TextStyle(color: AppTheme.mediumBrown),
                decoration: InputDecoration(
                  hintText: "Password",
                  hintStyle: TextStyle(color: AppTheme.mediumBrown.withOpacity(0.6)),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFFE07A5F)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                      color: const Color(0xFFE07A5F),
                    ),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.terracotta, // primary button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isLogin ? "Login" : "Register",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Switch Login/Register
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin
                      ? "Don't have an account? Register"
                      : "Already have an account? Login",
                  style: const TextStyle(color: Color(0xFF3A5F5F)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
