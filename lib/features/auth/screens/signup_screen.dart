import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../profile/screens/profile_setup_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();

  bool loading = false;

  Future<void> create() async {
    if (pass.text != confirm.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Passwords don’t match")));
      return;
    }

    setState(() => loading = true);

    final auth = context.read<AuthProvider>();
    final error = await auth.signUp(email.text.trim(), pass.text.trim());

    setState(() => loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xfff5f7ff), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white,
                child: Icon(Icons.person_add_alt_1, size: 32),
              ),

              const SizedBox(height: 24),

              const Text(
                "Create your account",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 32),

              _field(email, "College email", Icons.email),
              const SizedBox(height: 12),
              _field(pass, "Password", Icons.lock, obscure: true),
              const SizedBox(height: 12),
              _field(confirm, "Confirm Password", Icons.lock, obscure: true),

              const SizedBox(height: 24),

              _button()
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String h, IconData i,
      {bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: h,
        prefixIcon: Icon(i),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _button() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient:
              const LinearGradient(colors: [Color(0xffff7a00), Color(0xffff9a3c)]),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: loading ? null : create,
            child: Center(
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Create account",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
