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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter email & password")));
      return;
    }

    setState(() => loading = true);

    final auth = context.read<AuthProvider>();
    final error = await auth.signIn(email, pass);

    if (!mounted) return;

    setState(() => loading = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
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

  Future<void> _forgotPassword() async {
    final resetEmail = TextEditingController(text: emailController.text.trim());
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Forgot Password"),
          content: TextField(
            controller: resetEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "Email",
              hintText: "you@college.edu",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () async {
                final error = await auth.sendPasswordReset(
                  resetEmail.text.trim(),
                );
                if (!mounted) return;
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (error != null) {
                  messenger.showSnackBar(SnackBar(content: Text(error)));
                  return;
                }

                await showDialog(
                  context: context,
                  builder: (confirmDialogContext) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: const Row(
                      children: [
                        Icon(
                          Icons.mark_email_unread_rounded,
                          color: Color(0xffff7a00),
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "IMPORTANT",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    content: const Text(
                      "Check your spam mail for password reset.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    actions: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xffff7a00),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(confirmDialogContext),
                          child: const Text(
                            "OK",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Send"),
            ),
          ],
        );
      },
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
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
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
                                style: TextStyle(
                                  fontSize: r(26),
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  const TextSpan(
                                    text: "Welcome to ",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  const TextSpan(
                                    text: "WeGo",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  const TextSpan(
                                    text: "Vroom",
                                    style: TextStyle(color: Color(0xffff7a00)),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: r(8)),
                            Text(
                              "Sign in to continue",
                              style: TextStyle(fontSize: r(14)),
                            ),
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
                                    _showPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _showPassword = !_showPassword,
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(r(14)),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: loading ? null : _forgotPassword,
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: Color(0xffff7a00),
                                    fontWeight: FontWeight.w600,
                                  ),
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
                                    colors: [
                                      Color(0xffff7a00),
                                      Color(0xffff9a3c),
                                    ],
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
                                              color: Colors.white,
                                            )
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
