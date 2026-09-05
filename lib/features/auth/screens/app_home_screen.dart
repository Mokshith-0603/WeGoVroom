import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';
import 'landing_screen.dart';

class AppHomeScreen extends StatefulWidget {
  const AppHomeScreen({super.key});

  @override
  State<AppHomeScreen> createState() => _AppHomeScreenState();
}

class _AppHomeScreenState extends State<AppHomeScreen> {
  bool _acceptedTerms = false;

  void _goToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
    );
  }

  void _openTerms(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (termsContext) {
          final isDark = Theme.of(termsContext).brightness == Brightness.dark;
          final r = termsContext.rs;
          return Scaffold(
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF0A0C0D), Color(0xFF111315)]
                      : const [Color(0xFFFDFCFB), Color(0xFFF7F5F1)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -r(120),
                    right: -r(90),
                    child: _ambientGlow(
                      AppTheme.brandOrange.withValues(
                        alpha: isDark ? 0.10 : 0.08,
                      ),
                      r(300),
                    ),
                  ),
                  SafeArea(
                    child: _guidelinesPage(
                      termsContext,
                      onBack: () => Navigator.pop(termsContext),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.rs;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0A0C0D), Color(0xFF111315)]
                : const [Color(0xFFFDFCFB), Color(0xFFF7F5F1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -r(120),
              right: -r(90),
              child: _ambientGlow(
                AppTheme.brandOrange.withValues(alpha: isDark ? 0.10 : 0.08),
                r(300),
              ),
            ),
            SafeArea(child: _introPage(context)),
          ],
        ),
      ),
    );
  }

  Widget _introPage(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(r(20), r(14), r(20), r(8)),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroCard(context),
            SizedBox(height: r(18)),
            _verificationNotice(context),
            SizedBox(height: r(26)),
            Text(
              "Why Use WeGoVroom?",
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: r(24)),
            ),
            SizedBox(height: r(14)),
            _featureCard(
              context: context,
              icon: Icons.location_on_rounded,
              title: "Easy Trip Discovery",
              subtitle: "Find rides from your college community in seconds.",
            ),
            _featureCard(
              context: context,
              icon: Icons.forum_rounded,
              title: "Trip-Based Chat",
              subtitle:
                  "Coordinate pickup, timing, and updates inside each trip.",
            ),
            _featureCard(
              context: context,
              icon: Icons.verified_user_rounded,
              title: "Trusted Network",
              subtitle: "College-email sign-in keeps the community reliable.",
            ),
            _featureCard(
              context: context,
              icon: Icons.rate_review_rounded,
              title: "Member Reviews",
              subtitle: "Rate travel companions after completed trips.",
            ),
            SizedBox(height: r(8)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(r(12), r(8), r(12), r(10)),
              decoration: _surfaceDecoration(context, radius: r(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: _acceptedTerms,
                    onChanged: (value) {
                      setState(() => _acceptedTerms = value ?? false);
                    },
                    activeColor: AppTheme.brandOrange,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      "I agree to the Terms and Conditions",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: r(14),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openTerms(context),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text("Read Terms and Conditions"),
                  ),
                ],
              ),
            ),
            SizedBox(height: r(14)),
            _gradientButton(
              context: context,
              label: "Continue to Sign In",
              onTap: _acceptedTerms ? () => _goToLogin(context) : null,
            ),
            SizedBox(height: r(6)),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE9E5DF);

    return Container(
      height: r(430),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111315) : const Color(0xFFFFFEFC),
        borderRadius: BorderRadius.circular(r(26)),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: r(32),
            offset: Offset(0, r(14)),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _CampusHeroPainter(isDark: isDark)),
          ),
          Padding(
            padding: EdgeInsets.all(r(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: r(52),
                      height: r(52),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.brandOrange,
                            AppTheme.brandOrangeLight,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(r(18)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.brandOrange.withValues(alpha: 0.28),
                            blurRadius: r(16),
                            offset: Offset(0, r(7)),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        color: Colors.white,
                        size: r(27),
                      ),
                    ),
                    SizedBox(width: r(14)),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: r(23),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                        children: const [
                          TextSpan(text: "WeGo"),
                          TextSpan(
                            text: "Vroom",
                            style: TextStyle(color: AppTheme.brandOrange),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r(26)),
                Text.rich(
                  TextSpan(
                    children: const [
                      TextSpan(text: "Shared Rides for\nSmarter "),
                      TextSpan(
                        text: "Campus Travel",
                        style: TextStyle(color: AppTheme.brandOrange),
                      ),
                    ],
                  ),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: r(28),
                    height: 1.17,
                    letterSpacing: -0.9,
                  ),
                ),
                SizedBox(height: r(16)),
                Text(
                  "Join trusted students, split costs,\n"
                  "chat in-trip, and travel together\n"
                  "with confidence.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontSize: r(15),
                    height: 1.55,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: r(142),
                    height: r(72),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.brandOrange,
                          AppTheme.brandOrangeLight,
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(r(44)),
                        topRight: Radius.circular(r(18)),
                        bottomLeft: Radius.circular(r(16)),
                        bottomRight: Radius.circular(r(22)),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandOrange.withValues(alpha: 0.32),
                          blurRadius: r(18),
                          offset: Offset(0, r(8)),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(
                            Icons.directions_car_filled_rounded,
                            color: Colors.white,
                            size: r(52),
                          ),
                        ),
                        Positioned(
                          left: r(22),
                          bottom: -r(7),
                          child: _wheel(r),
                        ),
                        Positioned(
                          right: r(20),
                          bottom: -r(7),
                          child: _wheel(r),
                        ),
                      ],
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

  Widget _verificationNotice(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: r(18), vertical: r(15)),
      decoration: BoxDecoration(
        color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.09 : 0.08),
        borderRadius: BorderRadius.circular(r(20)),
        border: Border.all(
          color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.28 : 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: r(34),
            height: r(34),
            decoration: BoxDecoration(
              color: AppTheme.brandOrange,
              borderRadius: BorderRadius.circular(r(11)),
            ),
            child: Icon(
              Icons.mark_email_read_rounded,
              color: Colors.white,
              size: r(19),
            ),
          ),
          SizedBox(width: r(12)),
          Expanded(
            child: Text(
              "Check spam mail for verification",
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDark
                    ? const Color(0xFFFFA35E)
                    : const Color(0xFF8C3B00),
                fontSize: r(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guidelinesPage(BuildContext context, {required VoidCallback onBack}) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;

    final guidelines = [
      (
        Icons.handshake_outlined,
        "Respect all users",
        "Treat fellow users with respect and courtesy. Harassment, discrimination, or offensive behavior toward anyone will not be tolerated.",
      ),
      (
        Icons.volunteer_activism_outlined,
        "Use the platform responsibly",
        "WeGoVroom should only be used for its intended purpose -- finding travel companions and sharing travel expenses.",
      ),
      (
        Icons.warning_amber_rounded,
        "No misuse or fraudulent activity",
        "Any attempt to misuse the platform, including fake trips, scams, or misleading information, is strictly prohibited.",
      ),
      (
        Icons.forum_outlined,
        "Maintain respectful communication",
        "All conversations within the platform must remain polite and appropriate. Abusive language, threats, or harassment are not allowed.",
      ),
      (
        Icons.health_and_safety_outlined,
        "Ensure personal safety",
        "Users should always prioritize their safety and travel responsibly. Meeting points and trip details should be shared transparently.",
      ),
      (
        Icons.balance_rounded,
        "No illegal activities",
        "The platform must not be used to promote or participate in any illegal activities.",
      ),
      (
        Icons.lock_outline_rounded,
        "Protect privacy",
        "Do not share or misuse personal information of other users without their consent.",
      ),
      (
        Icons.account_balance_outlined,
        "Follow university standards",
        "As the platform is used within the university community, all users must adhere to the institution's code of conduct.",
      ),
      (
        Icons.outlined_flag_rounded,
        "Report inappropriate behavior",
        "If you encounter any misuse or inappropriate activity, please report it immediately through the appropriate channels.",
      ),
      (
        Icons.gavel_rounded,
        "Consequences for violations",
        "Any violation of these guidelines may result in warnings, account suspension, or other strict disciplinary action.",
      ),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(r(20), r(14), r(20), r(8)),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: "Back",
                    onPressed: onBack,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: theme.colorScheme.onSurface,
                      size: r(27),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: r(106),
                      height: r(106),
                      decoration: BoxDecoration(
                        color: AppTheme.brandOrange.withValues(
                          alpha: isDark ? 0.09 : 0.08,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: AppTheme.brandOrange,
                            size: r(78),
                          ),
                          Icon(
                            Icons.check_rounded,
                            color: AppTheme.brandOrange,
                            size: r(42),
                          ),
                          Positioned(
                            right: r(3),
                            bottom: r(7),
                            child: Container(
                              padding: EdgeInsets.all(r(7)),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1C1E20)
                                    : const Color(0xFFFFF1E6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.groups_rounded,
                                color: AppTheme.brandOrange,
                                size: r(27),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: r(4)),
            Text.rich(
              TextSpan(
                children: const [
                  TextSpan(text: "WeGo"),
                  TextSpan(
                    text: "Vroom",
                    style: TextStyle(color: AppTheme.brandOrange),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: r(21),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              "Terms and Conditions",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: r(27),
                height: 1.15,
              ),
            ),
            SizedBox(height: r(9)),
            Text(
              "Together we create a safe, respectful\nand trusted travel community.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                fontSize: r(14),
                height: 1.45,
              ),
            ),
            SizedBox(height: r(20)),
            ...guidelines.indexed.map(
              (entry) => Container(
                margin: EdgeInsets.only(bottom: r(8)),
                padding: EdgeInsets.fromLTRB(r(12), r(12), r(14), r(12)),
                decoration: _surfaceDecoration(context, radius: r(18)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: r(58),
                      height: r(58),
                      decoration: BoxDecoration(
                        color: AppTheme.brandOrange.withValues(
                          alpha: isDark ? 0.08 : 0.09,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        entry.$2.$1,
                        color: AppTheme.brandOrange,
                        size: r(30),
                      ),
                    ),
                    SizedBox(width: r(11)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: r(23),
                                height: r(23),
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppTheme.brandOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  "${entry.$1 + 1}".padLeft(2, "0"),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: r(9),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              SizedBox(width: r(8)),
                              Expanded(
                                child: Text(
                                  entry.$2.$2,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: r(13.5),
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: r(4)),
                          Text(
                            entry.$2.$3,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.76,
                              ),
                              fontSize: r(11.7),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: r(2)),
            Container(
              padding: EdgeInsets.all(r(15)),
              decoration: BoxDecoration(
                color: AppTheme.brandOrange.withValues(
                  alpha: isDark ? 0.055 : 0.08,
                ),
                borderRadius: BorderRadius.circular(r(18)),
                border: Border.all(
                  color: AppTheme.brandOrange.withValues(
                    alpha: isDark ? 0.75 : 0.18,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: r(46),
                    height: r(46),
                    decoration: const BoxDecoration(
                      color: AppTheme.brandOrange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_user_outlined,
                      color: Colors.white,
                      size: r(25),
                    ),
                  ),
                  SizedBox(width: r(12)),
                  Expanded(
                    child: Text(
                      "By using WeGoVroom, you agree to follow these community guidelines and help maintain a safe travel community.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: r(12.3),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r(6)),
          ],
        ),
      ),
    );
  }

  Widget _featureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final r = context.rs;

    return Container(
      margin: EdgeInsets.only(bottom: r(11)),
      padding: EdgeInsets.all(r(16)),
      decoration: _surfaceDecoration(context, radius: r(22)),
      child: Row(
        children: [
          _iconTile(context, icon),
          SizedBox(width: r(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: r(15.5),
                  ),
                ),
                SizedBox(height: r(4)),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    fontSize: r(12.5),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r(8)),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppTheme.brandOrange,
            size: r(17),
          ),
        ],
      ),
    );
  }

  Widget _iconTile(BuildContext context, IconData icon, {double? size}) {
    final r = context.rs;
    final tileSize = size ?? r(52);

    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        color: AppTheme.brandOrange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(r(17)),
      ),
      child: Icon(icon, color: AppTheme.brandOrange, size: r(25)),
    );
  }

  Widget _gradientButton({
    required BuildContext context,
    required String label,
    required VoidCallback? onTap,
  }) {
    final r = context.rs;
    final enabled = onTap != null;

    return Container(
      width: double.infinity,
      height: r(58),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? const [AppTheme.brandOrange, AppTheme.brandOrangeLight]
              : const [Color(0xFFBDBDBD), Color(0xFF9E9E9E)],
        ),
        borderRadius: BorderRadius.circular(r(22)),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppTheme.brandOrange.withValues(alpha: 0.28),
                  blurRadius: r(20),
                  offset: Offset(0, r(9)),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(r(22)),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r(17),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: r(12)),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: r(24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _surfaceDecoration(
    BuildContext context, {
    required double radius,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BoxDecoration(
      color: isDark ? const Color(0xFF151719) : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.09)
            : const Color(0xFFEAE7E2),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.045),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }

  static Widget _ambientGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  static Widget _wheel(double Function(double) r) {
    return Container(
      width: r(24),
      height: r(24),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF202124),
        border: Border.all(color: const Color(0xFF77797C), width: r(4)),
      ),
    );
  }
}

class _CampusHeroPainter extends CustomPainter {
  const _CampusHeroPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final orange = Paint()
      ..color = AppTheme.brandOrange.withValues(alpha: isDark ? 0.14 : 0.10);
    final skyline = Paint()
      ..color = isDark ? const Color(0xFF1D2022) : const Color(0xFFFFE8D6);
    final road = Paint()
      ..color = AppTheme.brandOrange.withValues(alpha: isDark ? 0.75 : 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.18),
      size.width * 0.24,
      orange,
    );

    final baseY = size.height * 0.88;
    final buildings = <Rect>[
      Rect.fromLTWH(size.width * 0.05, baseY - 52, 38, 52),
      Rect.fromLTWH(size.width * 0.16, baseY - 86, 45, 86),
      Rect.fromLTWH(size.width * 0.30, baseY - 66, 38, 66),
      Rect.fromLTWH(size.width * 0.41, baseY - 112, 52, 112),
      Rect.fromLTWH(size.width * 0.57, baseY - 78, 42, 78),
      Rect.fromLTWH(size.width * 0.70, baseY - 98, 50, 98),
      Rect.fromLTWH(size.width * 0.85, baseY - 64, 42, 64),
    ];

    for (final building in buildings) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(building, const Radius.circular(4)),
        skyline,
      );
    }

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.84)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.76,
        size.width * 0.26,
        size.height * 0.95,
        size.width * 0.48,
        size.height * 0.88,
      )
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.82,
        size.width * 0.72,
        size.height * 0.91,
        size.width * 0.92,
        size.height * 0.82,
      );
    _drawDashedPath(canvas, path, road);

    final pinCenter = Offset(size.width * 0.12, size.height * 0.73);
    canvas.drawCircle(pinCenter, 16, Paint()..color = AppTheme.brandOrange);
    canvas.drawCircle(
      pinCenter,
      6,
      Paint()..color = isDark ? const Color(0xFF111315) : Colors.white,
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + 9, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 16;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CampusHeroPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
