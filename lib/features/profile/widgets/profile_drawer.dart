import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../providers/auth_provider.dart';
import '../../notifications/screens/admin_notifications_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../screens/profile_setup_screen.dart';
import 'avatar_utils.dart';
import '../../../utils/responsive.dart';

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  Future<int> _completedTripCount(String? uid) async {
    if (uid == null) return 0;

    final db = FirebaseFirestore.instance;
    final completedTripIds = <String>{};

    final ownedSnap = await db.collection("trips").where("ownerId", isEqualTo: uid).get();
    for (final doc in ownedSnap.docs) {
      final data = doc.data();
      if (data["completed"] == true) {
        completedTripIds.add(doc.id);
      }
    }

    final participantSnap =
        await db.collection("tripParticipants").where("userId", isEqualTo: uid).get();
    for (final p in participantSnap.docs) {
      final tripId = p.data()["tripId"] as String?;
      if (tripId == null || tripId.isEmpty || completedTripIds.contains(tripId)) continue;

      final tripDoc = await db.collection("trips").doc(tripId).get();
      if (!tripDoc.exists) continue;
      final tripData = tripDoc.data() ?? {};
      if (tripData["completed"] == true) {
        completedTripIds.add(tripId);
      }
    }

    return completedTripIds.length;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final r = context.rs;

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
            final isAdmin = data["role"] == "admin" || data["isAdmin"] == true;

            return FutureBuilder<int>(
              future: _completedTripCount(user?.uid),
              builder: (context, tripCountSnap) {
                final completedTrips = tripCountSnap.data ?? 0;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                  /// ⭐ HEADER (ORANGE THEME)
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: r(20), vertical: r(24)),
                    decoration: const BoxDecoration(
                      color: Color(0xffff7a00),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildAvatar(avatarIndex, radius: r(32)),
                        SizedBox(height: r(12)),

                        Text(
                          name.toString().toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: r(18),
                          ),
                        ),

                        SizedBox(height: r(4)),

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
                    padding: EdgeInsets.all(r(16)),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: "Trips",
                            value: completedTrips.toString(),
                          ),
                        ),
                        SizedBox(width: r(12)),
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

                  if (isAdmin)
                    ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: const Text("Send Notifications"),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminNotificationsScreen(),
                          ),
                        );
                      },
                    ),

                  SizedBox(height: r(20)),

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

                  SizedBox(height: r(30)),
                    ],
                  ),
                );
              },
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
    final r = context.rs;
    return Container(
      padding: EdgeInsets.symmetric(vertical: r(16)),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(r(14)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontSize: r(18), fontWeight: FontWeight.bold)),
          SizedBox(height: r(4)),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
