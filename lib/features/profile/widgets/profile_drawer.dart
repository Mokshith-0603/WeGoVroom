import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../providers/auth_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../screens/profile_setup_screen.dart';
import 'avatar_utils.dart';

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    return Drawer(
      child: SafeArea(
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection("users")
              .doc(user?.uid)
              .get(),
          builder: (_, snap) {
            Map<String, dynamic> data = {};
            if (snap.hasData && snap.data!.exists) {
              data = snap.data!.data() as Map<String, dynamic>;
            }

            final name =
                data["displayName"] ??
                user?.email?.split("@")[0] ??
                "User";

            final email = user?.email ?? "";
            final reg = data["register"] ?? "";
            final avatarIndex = normalizeAvatarIndex(data["avatar"]);

            return SingleChildScrollView(
              child: Column(
                children: [
                  /// ⭐ HEADER (ORANGE THEME)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: const BoxDecoration(
                      color: Color(0xffff7a00),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildAvatar(avatarIndex, radius: 32),
                        const SizedBox(height: 12),

                        Text(
                          name.toString().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(email,
                            style:
                                const TextStyle(color: Colors.white70)),

                        if (reg.toString().isNotEmpty)
                          Text("Reg: $reg",
                              style:
                                  const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),

                  /// ⭐ STATS
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        Expanded(
                          child: _StatCard(title: "Trips", value: "0"),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(title: "Trust Score", value: "5"),
                        ),
                      ],
                    ),
                  ),

                  /// ⭐ OPTIONS
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text("Edit Profile"),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileSetupScreen(),
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.notifications_none),
                    title: const Text("Notifications"),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  /// ⭐ LOGOUT (FIXED)
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      "Sign Out",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      await context.read<AuthProvider>().logout();
                    },
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
