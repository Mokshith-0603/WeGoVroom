import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/screens/app_home_screen.dart';
import '../features/profile/screens/profile_setup_screen.dart';
import '../providers/auth_provider.dart';
import 'main_navigation.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  String? _tripIdFromUri(Uri uri) {
    final fromQuery = uri.queryParameters["tripId"];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

    final fragment = uri.fragment;
    if (fragment.isEmpty) return null;
    final queryStart = fragment.indexOf("?");
    if (queryStart == -1) return null;
    final query = fragment.substring(queryStart + 1);
    return Uri.splitQueryString(query)["tripId"];
  }

  Future<bool> _profileDone(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint("Profile check error: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return const AppHomeScreen();
    }

    if (auth.user != null && !auth.user!.emailVerified) {
      return const AppHomeScreen();
    }

    final uid = auth.user!.uid;

    return FutureBuilder<bool>(
      future: _profileDone(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Something went wrong")),
          );
        }

        final profileExists = snapshot.data ?? false;
        if (!profileExists) {
          return const ProfileSetupScreen();
        }

        final deepTripId = _tripIdFromUri(Uri.base);
        return MainNavigation(initialTripId: deepTripId);
      },
    );
  }
}
