import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';
import 'landing_screen.dart';

class AppHomeScreen extends StatefulWidget {
  const AppHomeScreen({super.key});

  @override
  State<AppHomeScreen> createState() => _AppHomeScreenState();
}

class _AppHomeScreenState extends State<AppHomeScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
    );
  }

  Future<void> _goNextPage() async {
    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.rs;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xfff2f8ff), Color(0xfffff7ee)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          if (_pageIndex == 0)
            Positioned(
              top: -r(90),
              right: -r(70),
              child: _blob(const Color(0x33ff7a00), r(240)),
            ),
          if (_pageIndex == 0)
            Positioned(
              top: r(120),
              left: -r(80),
              child: _blob(const Color(0x334169e1), r(220)),
            ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _pageIndex = i),
                    children: [_introPage(context), _guidelinesPage(context)],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: r(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      2,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.symmetric(horizontal: r(4)),
                        width: _pageIndex == i ? r(22) : r(8),
                        height: r(8),
                        decoration: BoxDecoration(
                          color: _pageIndex == i
                              ? const Color(0xffff7a00)
                              : Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(r(8)),
                        ),
                      ),
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

  Widget _introPage(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(r(20), r(18), r(20), r(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(r(18)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r(24)),
              gradient: const LinearGradient(
                colors: [Color(0xcc000000), Color(0x88000000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: r(20),
                      backgroundColor: const Color(0xffff7a00),
                      child: Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: r(20),
                      ),
                    ),
                    SizedBox(width: r(10)),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: r(22),
                          fontWeight: FontWeight.w800,
                        ),
                        children: const [
                          TextSpan(
                            text: "WeGo",
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: "Vroom",
                            style: TextStyle(color: Color(0xffff7a00)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r(14)),
                Text(
                  "Shared Rides for Smarter Campus Travel",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r(24),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: r(8)),
                const Text(
                  "Join trusted students, split costs, chat in-trip, and travel together with confidence.",
                  style: TextStyle(
                    color: Color(0xffdbe8f2),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r(18)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: r(12), vertical: r(10)),
            decoration: BoxDecoration(
              color: const Color(0xffff7a00).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r(12)),
              border: Border.all(
                color: const Color(0xffff7a00).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xffff7a00),
                  size: r(18),
                ),
                SizedBox(width: r(8)),
                Expanded(
                  child: Text(
                    "Check spam mail for verification",
                    style: TextStyle(
                      color: const Color(0xff7a3c00),
                      fontWeight: FontWeight.w700,
                      fontSize: r(12.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r(12)),
          Text(
            "Why Use WeGoVroom?",
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: r(22)),
          ),
          SizedBox(height: r(10)),
          _featureCard(
            context: context,
            icon: Icons.route_outlined,
            title: "Easy Trip Discovery",
            subtitle: "Find rides from your college community in seconds.",
          ),
          _featureCard(
            context: context,
            icon: Icons.chat_bubble_outline,
            title: "Trip-Based Chat",
            subtitle:
                "Coordinate pickup, timing, and updates inside each trip.",
          ),
          _featureCard(
            context: context,
            icon: Icons.verified_user_outlined,
            title: "Trusted Network",
            subtitle: "College-email sign-in keeps the community reliable.",
          ),
          _featureCard(
            context: context,
            icon: Icons.reviews_outlined,
            title: "Member Reviews",
            subtitle: "Rate travel companions after completed trips.",
          ),
          SizedBox(height: r(16)),
          SizedBox(
            width: double.infinity,
            height: r(56),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r(30)),
                gradient: const LinearGradient(
                  colors: [Color(0xffff7a00), Color(0xffff9a3c)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33ff7a00),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(r(30)),
                  onTap: _goNextPage,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: r(8)),
                      const Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: r(8)),
        ],
      ),
    );
  }

  Widget _guidelinesPage(BuildContext context) {
    final r = context.rs;

    final guidelines = [
      "Respect all users: Treat fellow users with respect and courtesy. Harassment, discrimination, or offensive behavior toward anyone will not be tolerated.",
      "Use the platform responsibly: WeGoVroom should only be used for its intended purpose — finding travel companions and sharing travel expenses.",
      "No misuse or fraudulent activity: Any attempt to misuse the platform, including fake trips, scams, or misleading information, is strictly prohibited.",
      "Maintain respectful communication: All conversations within the platform must remain polite and appropriate. Abusive language, threats, or harassment are not allowed.",
      "Ensure personal safety: Users should always prioritize their safety and travel responsibly. Meeting points and trip details should be shared transparently.",
      "No illegal activities: The platform must not be used to promote or participate in any illegal activities.",
      "Protect privacy: Do not share or misuse personal information of other users without their consent.",
      "Follow university community standards: As the platform is currently used within the university community, all users must adhere to the institution’s code of conduct.",
      "Report inappropriate behavior: If you encounter any misuse or inappropriate activity, please report it immediately through the appropriate channels.",
      "Consequences for violations: Any violation of these guidelines may result in warnings, account suspension, or other strict disciplinary action.",
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(r(20), r(18), r(20), r(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: r(12), vertical: r(10)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(r(14)),
              border: Border.all(color: const Color(0xffeef2f8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.gpp_good_outlined,
                  color: const Color(0xffff7a00),
                  size: r(22),
                ),
                SizedBox(width: r(8)),
                Expanded(
                  child: Text(
                    "WeGoVroom Community Guidelines",
                    softWrap: true,
                    style: TextStyle(
                      fontSize: r(18),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r(10)),
          ...guidelines.map(
            (item) => Container(
              margin: EdgeInsets.only(bottom: r(10)),
              padding: EdgeInsets.all(r(12)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(r(14)),
                border: Border.all(color: const Color(0xffeef2f8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: r(2)),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: r(18),
                      color: const Color(0xffff7a00),
                    ),
                  ),
                  SizedBox(width: r(8)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: const Color(0xff1f2430),
                        fontSize: r(12.5),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(r(12)),
            decoration: BoxDecoration(
              color: const Color(0xffff7a00).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r(12)),
              border: Border.all(
                color: const Color(0xffff7a00).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("✅", style: TextStyle(fontSize: 16)),
                SizedBox(width: r(8)),
                const Expanded(
                  child: Text(
                    "By using WeGoVroom, you agree to follow these community guidelines and help maintain a safe travel community.",
                    style: TextStyle(
                      color: Color(0xff7a3c00),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r(16)),
          SizedBox(
            width: double.infinity,
            height: r(56),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r(30)),
                gradient: const LinearGradient(
                  colors: [Color(0xffff7a00), Color(0xffff9a3c)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33ff7a00),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(r(30)),
                  onTap: () => _goToLogin(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Start",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: r(8)),
                      const Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: r(8)),
        ],
      ),
    );
  }

  static Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _featureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final r = context.rs;
    return Container(
      margin: EdgeInsets.only(bottom: r(10)),
      padding: EdgeInsets.all(r(14)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(r(16)),
        border: Border.all(color: const Color(0xffeef2f8)),
      ),
      child: Row(
        children: [
          Container(
            width: r(38),
            height: r(38),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r(10)),
              color: const Color(0xfffff0e0),
            ),
            child: Icon(icon, color: const Color(0xffff7a00), size: r(20)),
          ),
          SizedBox(width: r(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r(14.5),
                  ),
                ),
                SizedBox(height: r(2)),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: const Color(0xff5f6772),
                    fontSize: r(12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
