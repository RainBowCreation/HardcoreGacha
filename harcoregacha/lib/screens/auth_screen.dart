import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/api.dart';
import 'dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isLoggedIn = false;

  void login(String t) {
    Api.token = t;
    setState(() => isLoggedIn = true);
  }

  void logout() {
    final res = Api.request("/auth/logout", method: "POST");
    Api.token = null;
    setState(() => isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return isLoggedIn
        ? MainDashboard(onLogout: logout)
        : LoginScreen(onLogin: login);
  }
}

class LoginScreen extends StatefulWidget {
  final Function(String) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isRegister = false;
  final _userController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool loading = false;

  Future<void> submit() async {
    if (loading) return;
    setState(() => loading = true);
    if (isRegister) {
      final res = await Api.request(
        "/auth/register",
        method: "POST",
        body: {
          "username": _userController.text,
          "email": _emailController.text,
          "password": _passController.text,
        },
      );
      if (res['status'] == 200 || res['status'] == 201) {
        setState(() => isRegister = false);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registered! Please login.")),
          );
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${res['error'] ?? 'Unknown'}")),
          );
      }
    } else {
      final res = await Api.request(
        "/auth/login",
        method: "POST",
        body: {
          "identifier": _userController.text,
          "password": _passController.text,
        },
      );
      if (res['data'] != null && res['data']['token'] != null) {
        widget.onLogin(res['data']['token']);
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Login Failed")));
      }
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRegister ? "CREATE ACCOUNT" : "LOGIN",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(),
                ),
              ),
              if (isRegister) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                obscureText: true,
                textInputAction: TextInputAction.done, // Shows "Check" icon on mobile keyboard
                onSubmitted: (_) => submit(), // Triggers submit when Enter is pressed
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: loading ? null : submit,
                  child: Text(
                    loading
                        ? "PROCESSING..."
                        : (isRegister ? "REGISTER" : "CONNECT"),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => isRegister = !isRegister),
                child: Text(
                  isRegister ? "Have account? Login" : "Need account? Register",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDim,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
