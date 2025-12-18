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
  final _confirmPassController = TextEditingController(); // 1. New controller
  bool loading = false;

  // Simple email validator
  bool isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);
  }

  Future<void> submit() async {
    if (loading) return;
    
    // 2. Validation Logic
    if (isRegister) {
      if (!isValidEmail(_emailController.text.trim())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please enter a valid email address"))
          );
        }
        return;
      }

      if (_passController.text != _confirmPassController.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Passwords do not match"))
          );
        }
        return;
      }
    }

    setState(() => loading = true);

    if (isRegister) {
      final res = await Api.request(
        "/auth/register",
        method: "POST",
        body: {
          "username": _userController.text,
          "email": _emailController.text,
          "password": _passController.text
        }
      );
      if (res['status'] == 200 || res['status'] == 201) {
        setState(() => isRegister = false);
        // Auto-login after register if token is present
        if (res['data'] != null && res['data']['token'] != null) {
          widget.onLogin(res['data']['token']);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Account created! Please login."))
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${res['error'] ?? 'Unknown'}"))
          );
        }
      }
    } else {
      final res = await Api.request(
        "/auth/login",
        method: "POST",
        body: {
          "identifier": _userController.text,
          "password": _passController.text
        }
      );
      if (res['data'] != null && res['data']['token'] != null) {
        widget.onLogin(res['data']['token']);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${res['error']}"))
          );
        }
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
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRegister ? "CREATE ACCOUNT" : "LOGIN",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white
                )
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder()
                )
              ),
              if (isRegister) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress, // Adds @ symbol to keyboard
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder()
                  )
                )
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                obscureText: true,
                // Only trigger submit here if NOT registering (since register needs confirm pass)
                textInputAction: isRegister ? TextInputAction.next : TextInputAction.done,
                onSubmitted: isRegister ? null : (_) => submit(),
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder()
                )
              ),
              
              // 3. New Confirm Password Field
              if (isRegister) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPassController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                    labelText: "Confirm Password",
                    border: OutlineInputBorder()
                  )
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ),
                  onPressed: loading ? null : submit,
                  child: Text(
                    loading
                      ? "PROCESSING..."
                      : (isRegister ? "REGISTER" : "CONNECT")
                  )
                )
              ),
              TextButton(
                onPressed: () {
                  // Clear errors or fields when switching modes if desired
                  setState(() => isRegister = !isRegister);
                },
                child: Text(
                  isRegister ? "Have account? Login" : "Need account? Register",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDim
                  )
                )
              )
            ]
          )
        )
      )
    );
  }
}
