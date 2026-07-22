import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';
import 'landing_screen.dart';

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
    final signupEmail = email.text.trim();

    if (pass.text != confirm.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords don’t match")));
      return;
    }

    setState(() => loading = true);

    final auth = context.read<AuthProvider>();
    final error = await auth.signUp(signupEmail, pass.text.trim());

    setState(() => loading = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    if (!mounted) return;

    if (auth.isAdminEmail(signupEmail)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppRouter()),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
          "Check your spam mail for verification.",
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "OK",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
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
                ? const [Color(0xFF0A0C0D), Color(0xFF101318)]
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
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              size: r(28),
                            ),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LandingScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: r(12)),
                        _signupHero(context),
                        SizedBox(height: r(30)),
                        Text.rich(
                          TextSpan(
                            children: const [
                              TextSpan(text: "Create your "),
                              TextSpan(
                                text: "account",
                                style: TextStyle(
                                  color: AppTheme.brandOrange,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: r(29),
                            letterSpacing: -0.9,
                          ),
                        ),
                        SizedBox(height: r(12)),
                        Text(
                          "Join WeGoVroom and start your\n"
                          "journey with trusted companions.",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.62,
                            ),
                            fontSize: r(14),
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: r(14)),
                        Text(
                          "Use only college email ids",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.brandOrange,
                            fontSize: r(13.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: r(32)),
                        _field(
                          email,
                          "College email",
                          Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: r(14)),
                        _field(
                          pass,
                          "Password",
                          Icons.lock_outline_rounded,
                          obscure: true,
                          visible: _showPassword,
                          onToggleVisibility: () {
                            setState(() => _showPassword = !_showPassword);
                          },
                        ),
                        SizedBox(height: r(14)),
                        _field(
                          confirm,
                          "Confirm Password",
                          Icons.verified_user_outlined,
                          obscure: true,
                          visible: _showConfirmPassword,
                          onToggleVisibility: () {
                            setState(
                              () => _showConfirmPassword =
                                  !_showConfirmPassword,
                            );
                          },
                        ),
                        SizedBox(height: r(26)),
                        _button(),
                        SizedBox(height: r(32)),
                        _campusIllustration(context),
                        SizedBox(height: r(22)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: AppTheme.brandOrange,
                              size: r(24),
                            ),
                            SizedBox(width: r(12)),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: const [
                                    TextSpan(
                                      text:
                                          "We keep your data safe and secure.\n"
                                          "Read our ",
                                    ),
                                    TextSpan(
                                      text: "Privacy Policy",
                                      style: TextStyle(
                                        color: AppTheme.brandOrange,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.68,
                                  ),
                                  fontSize: r(12.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: r(8)),
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

  Widget _field(
    TextEditingController c,
    String h,
    IconData i, {
    bool obscure = false,
    bool visible = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    final r = context.rs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: c,
      keyboardType: keyboardType,
      obscureText: obscure ? !visible : false,
      style: TextStyle(fontSize: r(15)),
      decoration: InputDecoration(
        hintText: h,
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
            child: Icon(i, color: AppTheme.brandOrange, size: r(23)),
          ),
        ),
        prefixIconConstraints: BoxConstraints(
          minWidth: r(66),
          minHeight: r(64),
        ),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(
                  visible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        border: _fieldBorder(r),
        enabledBorder: _fieldBorder(r),
        focusedBorder: _fieldBorder(
          r,
          color: AppTheme.brandOrange,
          width: 1.5,
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(
    double Function(double) r, {
    Color? color,
    double width = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

  Widget _button() {
    final r = context.rs;
    return Container(
      width: double.infinity,
      height: r(58),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r(22)),
        gradient: const LinearGradient(
          colors: [AppTheme.brandOrange, AppTheme.brandOrangeLight],
        ),
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
          onTap: loading ? null : create,
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
                        "Create account",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r(16),
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

  Widget _signupHero(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: r(220),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _SignupSparkPainter(isDark: isDark),
          ),
          Container(
            width: r(154),
            height: r(154),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.045)
                  : Colors.white.withValues(alpha: 0.82),
              border: Border.all(
                color: AppTheme.brandOrange.withValues(
                  alpha: isDark ? 0.55 : 0.10,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandOrange.withValues(alpha: 0.14),
                  blurRadius: r(35),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.person_rounded,
                  color: AppTheme.brandOrange,
                  size: r(88),
                ),
                Positioned(
                  right: r(26),
                  bottom: r(34),
                  child: Container(
                    width: r(38),
                    height: r(38),
                    decoration: BoxDecoration(
                      color: AppTheme.brandOrange,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF101318)
                            : Colors.white,
                        width: r(3),
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: r(27),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campusIllustration(BuildContext context) {
    final r = context.rs;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: r(190),
      child: CustomPaint(
        painter: _CampusSignupPainter(isDark: isDark),
        child: Align(
          alignment: const Alignment(0, 0.78),
          child: Container(
            width: r(72),
            height: r(35),
            decoration: BoxDecoration(
              color: AppTheme.brandOrange,
              borderRadius: BorderRadius.circular(r(14)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandOrange.withValues(alpha: 0.25),
                  blurRadius: r(12),
                  offset: Offset(0, r(5)),
                ),
              ],
            ),
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.white,
              size: r(29),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignupSparkPainter extends CustomPainter {
  const _SignupSparkPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.brandOrange.withValues(alpha: isDark ? 0.55 : 0.32);
    final points = [
      Offset(size.width * 0.16, size.height * 0.45),
      Offset(size.width * 0.27, size.height * 0.22),
      Offset(size.width * 0.72, size.height * 0.18),
      Offset(size.width * 0.83, size.height * 0.42),
      Offset(size.width * 0.68, size.height * 0.82),
      Offset(size.width * 0.22, size.height * 0.74),
    ];

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], i.isEven ? 3.5 : 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignupSparkPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _CampusSignupPainter extends CustomPainter {
  const _CampusSignupPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.25)
          : AppTheme.brandOrange.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final accent = Paint()
      ..color = AppTheme.brandOrange.withValues(alpha: isDark ? 0.70 : 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final baseY = size.height * 0.78;

    final building = Path()
      ..moveTo(size.width * 0.14, baseY)
      ..lineTo(size.width * 0.14, size.height * 0.42)
      ..lineTo(size.width * 0.34, size.height * 0.42)
      ..lineTo(size.width * 0.50, size.height * 0.18)
      ..lineTo(size.width * 0.66, size.height * 0.42)
      ..lineTo(size.width * 0.86, size.height * 0.42)
      ..lineTo(size.width * 0.86, baseY)
      ..close();
    canvas.drawPath(building, line);

    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.18),
      Offset(size.width * 0.50, size.height * 0.08),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.08),
      Offset(size.width * 0.56, size.height * 0.12),
      accent,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.38),
      8,
      accent,
    );
    canvas.drawLine(
      Offset(size.width * 0.06, baseY),
      Offset(size.width * 0.94, baseY),
      line,
    );

    for (final x in [0.22, 0.32, 0.68, 0.78]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.56),
          width: 9,
          height: 16,
        ),
        accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CampusSignupPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
