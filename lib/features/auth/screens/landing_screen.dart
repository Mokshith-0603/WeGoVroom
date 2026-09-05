import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../navigation/app_router.dart';
import '../../../theme/app_theme.dart';
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

  Future<void> signInWithGoogle() async {
    setState(() => loading = true);

    final auth = context.read<AuthProvider>();
    final error = await auth.signInWithGoogle();

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
            decoration: InputDecoration(
              labelText: "Email",
              hintText: "you${AuthProvider.allowedEmailDomain}",
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0A0C0D), Color(0xFF101214)]
                : const [Color(0xFFFFFEFC), Color(0xFFF9F7F3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(r(24), r(4), r(24), r(24)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: ResponsiveContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: "Back",
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            icon: Icon(Icons.arrow_back_rounded, size: r(28)),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AppHomeScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: r(4)),
                        _travelHero(context),
                        SizedBox(height: r(24)),
                        Text.rich(
                          TextSpan(
                            children: const [
                              TextSpan(text: "Welcome to\nWeGo"),
                              TextSpan(
                                text: "Vroom",
                                style: TextStyle(color: AppTheme.brandOrange),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: r(34),
                            height: 1.12,
                            letterSpacing: -1.1,
                          ),
                        ),
                        SizedBox(height: r(12)),
                        Text(
                          "Sign in to continue",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.68,
                            ),
                            fontSize: r(17),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: r(7)),
                        Text(
                          "Use only ${AuthProvider.allowedEmailDomainsLabel} email IDs",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: r(13.5),
                            color: AppTheme.brandOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: r(32)),
                        _authField(
                          context: context,
                          controller: emailController,
                          hintText: "you${AuthProvider.allowedEmailDomain}",
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: r(14)),
                        _authField(
                          context: context,
                          controller: passController,
                          hintText: "Password",
                          icon: Icons.lock_outline_rounded,
                          obscureText: !_showPassword,
                          suffix: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.68,
                              ),
                            ),
                            onPressed: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: loading ? null : _forgotPassword,
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.brandOrange,
                              padding: EdgeInsets.symmetric(
                                horizontal: r(2),
                                vertical: r(10),
                              ),
                            ),
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        SizedBox(height: r(14)),
                        _signInButton(context),
                        SizedBox(height: r(20)),
                        _googleButton(context),
                        SizedBox(height: r(24)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Need an account? ",
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: r(14),
                              ),
                            ),
                            TextButton(
                              onPressed: loading ? null : goSignup,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.brandOrange,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Sign up",
                                style: TextStyle(
                                  fontSize: r(14),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: r(24)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _travelHero(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: r(245),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _SignInHeroPainter(isDark: isDark)),
          ),
          Container(
            width: r(142),
            height: r(142),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.055)
                  : Colors.white.withValues(alpha: 0.78),
              border: Border.all(
                color: AppTheme.brandOrange.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandOrange.withValues(alpha: 0.10),
                  blurRadius: r(30),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: r(76),
                height: r(92),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.brandOrange, AppTheme.brandOrangeLight],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(38),
                    topRight: Radius.circular(38),
                    bottomLeft: Radius.circular(38),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Transform.rotate(
                  angle: -0.78,
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    color: Colors.white,
                    size: r(42),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: r(18),
            bottom: r(26),
            child: Container(
              width: r(112),
              height: r(54),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.brandOrange, AppTheme.brandOrangeLight],
                ),
                borderRadius: BorderRadius.circular(r(18)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandOrange.withValues(alpha: 0.26),
                    blurRadius: r(14),
                    offset: Offset(0, r(6)),
                  ),
                ],
              ),
              child: Icon(
                Icons.directions_car_filled_rounded,
                color: Colors.white,
                size: r(42),
              ),
            ),
          ),
          Positioned(
            left: r(28),
            bottom: r(34),
            child: Icon(
              Icons.location_on_rounded,
              color: AppTheme.brandOrange,
              size: r(36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authField({
    required BuildContext context,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(fontSize: r(15)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.72),
        contentPadding: EdgeInsets.symmetric(
          horizontal: r(16),
          vertical: r(20),
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.all(r(10)),
          child: Container(
            width: r(42),
            height: r(42),
            decoration: BoxDecoration(
              color: AppTheme.brandOrange.withValues(
                alpha: isDark ? 0.12 : 0.08,
              ),
              borderRadius: BorderRadius.circular(r(12)),
            ),
            child: Icon(icon, color: AppTheme.brandOrange, size: r(23)),
          ),
        ),
        prefixIconConstraints: BoxConstraints(
          minWidth: r(66),
          minHeight: r(64),
        ),
        suffixIcon: suffix,
        border: _fieldBorder(context, r),
        enabledBorder: _fieldBorder(context, r),
        focusedBorder: _fieldBorder(
          context,
          r,
          color: AppTheme.brandOrange,
          width: 1.5,
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(
    BuildContext context,
    double Function(double) r, {
    Color? color,
    double width = 1,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(r(18)),
      borderSide: BorderSide(
        color:
            color ??
            (isDark
                ? Colors.white.withValues(alpha: 0.20)
                : const Color(0xFFD8D4CE)),
        width: width,
      ),
    );
  }

  Widget _signInButton(BuildContext context) {
    final r = context.rs;

    return Container(
      height: r(58),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.brandOrange, AppTheme.brandOrangeLight],
        ),
        borderRadius: BorderRadius.circular(r(22)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandOrange.withValues(alpha: 0.27),
            blurRadius: r(20),
            offset: Offset(0, r(9)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(r(22)),
          onTap: loading ? null : login,
          child: Center(
            child: loading
                ? SizedBox(
                    width: r(24),
                    height: r(24),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Sign in",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r(17),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: r(14)),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: r(24),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _googleButton(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;

    return SizedBox(
      height: r(58),
      child: OutlinedButton(
        onPressed: loading ? null : signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          side: const BorderSide(color: AppTheme.brandOrange, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r(20)),
          ),
        ),
        child: loading
            ? SizedBox(
                width: r(22),
                height: r(22),
                child: const CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "G",
                    style: TextStyle(
                      color: const Color(0xFF4285F4),
                      fontSize: r(24),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: r(14)),
                  Text(
                    "Continue with Google",
                    style: TextStyle(
                      fontSize: r(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SignInHeroPainter extends CustomPainter {
  const _SignInHeroPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final skyline = Paint()
      ..color = isDark ? const Color(0xFF181B1D) : const Color(0xFFFFEBDD);
    final route = Paint()
      ..color = AppTheme.brandOrange.withValues(alpha: isDark ? 0.70 : 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final ring = Paint()
      ..color = AppTheme.brandOrange.withValues(alpha: isDark ? 0.11 : 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width * 0.5, size.height * 0.46);
    for (final radius in [58.0, 78.0, 98.0]) {
      canvas.drawCircle(center, radius, ring);
    }

    final baseY = size.height * 0.84;
    final buildings = <Rect>[
      Rect.fromLTWH(size.width * 0.00, baseY - 48, 31, 48),
      Rect.fromLTWH(size.width * 0.09, baseY - 80, 42, 80),
      Rect.fromLTWH(size.width * 0.22, baseY - 54, 34, 54),
      Rect.fromLTWH(size.width * 0.78, baseY - 66, 36, 66),
      Rect.fromLTWH(size.width * 0.89, baseY - 42, 34, 42),
    ];
    for (final building in buildings) {
      canvas.drawRect(building, skyline);
    }

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.83)
      ..cubicTo(
        size.width * 0.27,
        size.height * 0.74,
        size.width * 0.31,
        size.height * 0.94,
        size.width * 0.56,
        size.height * 0.83,
      )
      ..cubicTo(
        size.width * 0.71,
        size.height * 0.77,
        size.width * 0.78,
        size.height * 0.84,
        size.width * 0.94,
        size.height * 0.77,
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, (distance + 8).clamp(0, metric.length)),
          route,
        );
        distance += 15;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignInHeroPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
