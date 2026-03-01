import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../navigation/app_router.dart';
import '../../../utils/responsive.dart';
import 'app_home_screen.dart';
import 'signup_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final emailController = TextEditingController();
  final passController = TextEditingController();

  bool loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final pass = passController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter email & password")),
      );
      return;
    }

    setState(() => loading = true);

    final auth = context.read<AuthProvider>();
    final error = await auth.signIn(email, pass);

    if (!mounted) return;

    setState(() => loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AppRouter()),
      (_) => false,
    );
  }

  void goSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
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
                  /// LOGO
                  CircleAvatar(
                    radius: r(42),
                    backgroundColor: Colors.white,
                    child: Icon(Icons.travel_explore, size: r(32)),
                  ),

                  SizedBox(height: r(24)),

                  /// TITLE
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style:
                          TextStyle(fontSize: r(26), fontWeight: FontWeight.bold),
                      children: [
                        const TextSpan(
                            text: "Welcome to ",
                            style: TextStyle(color: Colors.black)),
                        const TextSpan(
                            text: "WeGo",
                            style: TextStyle(color: Colors.black)),
                        const TextSpan(
                            text: "Vroom",
                            style: TextStyle(color: Color(0xffff7a00))),
                      ],
                    ),
                  ),

                  SizedBox(height: r(8)),
                  Text("Sign in to continue", style: TextStyle(fontSize: r(14))),
                  SizedBox(height: r(6)),
                  Text(
                    "Use only college email ids",
                    style: TextStyle(
                      fontSize: r(12.5),
                      color: const Color(0xffff7a00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  SizedBox(height: r(32)),

                  /// EMAIL
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: "you@college.edu",
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r(14)),
                      ),
                    ),
                  ),

                  SizedBox(height: r(12)),

                  /// PASSWORD
                  TextField(
                    controller: passController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      hintText: "Password",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r(14)),
                      ),
                    ),
                  ),

                  SizedBox(height: r(24)),

                  /// LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: r(56),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r(30)),
                        gradient: const LinearGradient(
                          colors: [Color(0xffff7a00), Color(0xffff9a3c)],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(r(30)),
                          onTap: loading ? null : login,
                          child: Center(
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    "Sign in",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: r(12)),

                  /// SIGNUP LINK
                  TextButton(
                    onPressed: loading ? null : goSignup,
                    child: const Text(
                      "Need an account? Sign up",
                      style: TextStyle(
                        color: Color(0xffff7a00),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
                      MaterialPageRoute(builder: (_) => const AppHomeScreen()),
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
}
