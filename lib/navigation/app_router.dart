import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/auth_provider.dart';
import '../features/auth/screens/landing_screen.dart';
import '../features/profile/screens/profile_setup_screen.dart';
import 'main_navigation.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  /// ⭐ Check if profile exists
  Future<bool> _profileDone(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();

      return doc.exists;
    } catch (e) {
      debugPrint("Profile check error: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    /// ❌ NOT LOGGED
    if (!auth.isLoggedIn) {
      return const LandingScreen();
    }

    final uid = auth.user!.uid;

    /// 🔁 PROFILE CHECK
    return FutureBuilder<bool>(
      future: _profileDone(uid),
      builder: (context, snapshot) {
        /// ⏳ loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        /// ⚠️ error fallback
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Something went wrong")),
          );
        }

        final profileExists = snapshot.data ?? false;

        /// 🧾 profile not done
        if (!profileExists) {
          return const ProfileSetupScreen();
        }

        /// ✅ main app
        return const MainNavigation();
      },
    );
  }
}