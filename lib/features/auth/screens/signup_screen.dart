import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/responsive.dart';
import 'landing_screen.dart';
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
  bool _showPassword = false;
  bool _showConfirmPassword = false;

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
    final r = context.rs;
    return Scaffold(
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: r(24)),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xfff5f7ff), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: ResponsiveContent(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
               CircleAvatar(
                 radius: r(42),
                 backgroundColor: Colors.white,
                child: Icon(Icons.person_add_alt_1, size: r(32)),
              ),

              SizedBox(height: r(24)),

              Text(
                "Create your account",
                style: TextStyle(fontSize: r(26), fontWeight: FontWeight.bold),
              ),

              SizedBox(height: r(32)),

              _field(email, "College email", Icons.email),
              SizedBox(height: r(12)),
              _field(
                pass,
                "Password",
                Icons.lock,
                obscure: true,
                visible: _showPassword,
                onToggleVisibility: () {
                  setState(() => _showPassword = !_showPassword);
                },
              ),
              SizedBox(height: r(12)),
              _field(
                confirm,
                "Confirm Password",
                Icons.lock,
                obscure: true,
                visible: _showConfirmPassword,
                onToggleVisibility: () {
                  setState(() => _showConfirmPassword = !_showConfirmPassword);
                },
              ),

              SizedBox(height: r(24)),

               _button()
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LandingScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String h, IconData i,
      {bool obscure = false, bool visible = false, VoidCallback? onToggleVisibility}) {
    final r = context.rs;
    return TextField(
      controller: c,
      obscureText: obscure ? !visible : false,
      decoration: InputDecoration(
        hintText: h,
        prefixIcon: Icon(i),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
                onPressed: onToggleVisibility,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(r(14))),
      ),
    );
  }

  Widget _button() {
    final r = context.rs;
    return SizedBox(
      width: double.infinity,
      height: r(56),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r(30)),
          gradient:
              const LinearGradient(colors: [Color(0xffff7a00), Color(0xffff9a3c)]),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(r(30)),
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
