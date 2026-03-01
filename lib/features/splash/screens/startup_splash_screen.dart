import 'dart:async';

import 'package:flutter/material.dart';

class StartupSplashScreen extends StatefulWidget {
  final Widget child;

  const StartupSplashScreen({
    super.key,
    required this.child,
  });

  @override
  State<StartupSplashScreen> createState() => _StartupSplashScreenState();
}

class _StartupSplashScreenState extends State<StartupSplashScreen> {
  bool _showApp = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() => _showApp = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showApp) return widget.child;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 900),
          tween: Tween(begin: 0.85, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Image.asset(
                  'web/icons/Icon-512.png',
                  width: 132,
                  height: 132,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                  children: [
                    TextSpan(
                      text: 'WeGo',
                      style: TextStyle(color: Color(0xff10111a)),
                    ),
                    TextSpan(
                      text: 'Vroom',
                      style: TextStyle(color: Color(0xffff7a00)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
