import 'package:flutter/material.dart';
import '../../../utils/responsive.dart';
import 'landing_screen.dart';

class AppHomeScreen extends StatelessWidget {
  const AppHomeScreen({super.key});

  void _goToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Positioned(
            top: -r(90),
            right: -r(70),
            child: _blob(const Color(0x33ff7a00), r(240)),
          ),
          Positioned(
            top: r(120),
            left: -r(80),
            child: _blob(const Color(0x334169e1), r(220)),
          ),
          SafeArea(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 700),
              tween: Tween(begin: 0, end: 1),
              builder: (context, v, child) {
                return Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - v)),
                    child: child,
                  ),
                );
              },
              child: SingleChildScrollView(
                child: ResponsiveContent(
                  padding: EdgeInsets.fromLTRB(r(20), r(18), r(20), r(18)),
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
                          )
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
                                child: Icon(Icons.directions_car, color: Colors.white, size: r(20)),
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
                          Text(
                            "Join trusted students, split costs, chat in-trip, and travel together with confidence.",
                            style: TextStyle(
                              color: Color(0xffdbe8f2),
                              fontSize: r(14),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r(18)),
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
                      subtitle: "Coordinate pickup, timing, and updates inside each trip.",
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
                    SizedBox(height: r(20)),
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
                            child: Center(
                              child: Text(
                                "Log In",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r(16),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
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
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: r(14.5)),
                ),
                SizedBox(height: r(2)),
                Text(
                  subtitle,
                  style: TextStyle(color: const Color(0xff5f6772), fontSize: r(12.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
