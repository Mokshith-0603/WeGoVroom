import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../providers/auth_provider.dart';
import '../../contact/screens/contact_us_screen.dart';
import '../../feedback/screens/admin_feedbacks_screen.dart';
import '../../feedback/screens/feedback_form_screen.dart';
import '../../notifications/screens/admin_notifications_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../screens/profile_setup_screen.dart';
import 'avatar_utils.dart';
import '../../../utils/responsive.dart';

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  bool _isAdmin(Map<String, dynamic> data) {
    final role = data['role']?.toString().trim().toLowerCase();
    return role == 'admin' || _parseBool(data['isAdmin']) || _parseBool(data['admin']);
  }

  Future<int> _completedTripCount(String? uid) async {
    if (uid == null) return 0;

    final db = FirebaseFirestore.instance;
    final completedTripIds = <String>{};

    final ownedSnap = await db.collection('trips').where('ownerId', isEqualTo: uid).get();
    for (final doc in ownedSnap.docs) {
      final data = doc.data();
      if (data['completed'] == true) {
        completedTripIds.add(doc.id);
      }
    }

    final participantSnap =
        await db.collection('tripParticipants').where('userId', isEqualTo: uid).get();
    for (final p in participantSnap.docs) {
      final tripId = p.data()['tripId'] as String?;
      if (tripId == null || tripId.isEmpty || completedTripIds.contains(tripId)) continue;

      final tripDoc = await db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) continue;
      final tripData = tripDoc.data() ?? {};
      if (tripData['completed'] == true) {
        completedTripIds.add(tripId);
      }
    }

    return completedTripIds.length;
  }

  Future<Map<String, dynamic>> _reviewSummary(String? uid) async {
    if (uid == null) {
      return {
        'count': 0,
        'avg': 0.0,
      };
    }

    final snap = await FirebaseFirestore.instance
        .collection('tripReviews')
        .where('revieweeId', isEqualTo: uid)
        .get();

    final docs = snap.docs;
    if (docs.isEmpty) {
      return {
        'count': 0,
        'avg': 0.0,
      };
    }

    double total = 0;
    for (final doc in docs) {
      final data = doc.data();
      total += ((data['rating'] ?? 0) as num).toDouble();
    }

    return {
      'count': docs.length,
      'avg': total / docs.length,
    };
  }

  Future<Map<String, dynamic>> _profileStats(String? uid) async {
    final results = await Future.wait<dynamic>([
      _completedTripCount(uid),
      _reviewSummary(uid),
    ]);

    return {
      'trips': results[0] as int,
      'review': results[1] as Map<String, dynamic>,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final r = context.rs;

    return Drawer(
      child: SafeArea(
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
          builder: (_, snap) {
            Map<String, dynamic> data = {};
            if (snap.hasData && snap.data!.exists) {
              data = snap.data!.data() as Map<String, dynamic>;
            }

            final name = data['displayName'] ?? user?.email?.split('@')[0] ?? 'User';

            final email = user?.email ?? '';
            final reg = data['register'] ?? '';
            final avatarIndex = normalizeAvatarIndex(data['avatar']);
            final isAdmin = _isAdmin(data);

            return FutureBuilder<Map<String, dynamic>>(
              future: _profileStats(user?.uid),
              builder: (context, statsSnap) {
                final stats = statsSnap.data ?? const <String, dynamic>{};
                final completedTrips = (stats['trips'] ?? 0) as int;
                final review = (stats['review'] ??
                    const <String, dynamic>{'count': 0, 'avg': 0.0}) as Map<String, dynamic>;
                final reviewCount = (review['count'] ?? 0) as int;
                final avgRating = ((review['avg'] ?? 0.0) as num).toDouble();

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: r(20), vertical: r(24)),
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
                            Text(email, style: const TextStyle(color: Colors.white70)),
                            if (reg.toString().isNotEmpty)
                              Text('Reg: $reg', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(r(16)),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Trips',
                                value: completedTrips.toString(),
                              ),
                            ),
                            SizedBox(width: r(12)),
                            Expanded(
                              child: _StatCard(
                                title: 'Reviews Got',
                                value: reviewCount.toString(),
                                subtitle: '${avgRating.toStringAsFixed(1)}/5 avg',
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Edit Profile'),
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
                        title: const Text('Notifications'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.rate_review_outlined),
                        title: const Text('Feedback'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FeedbackFormScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.contact_support_outlined),
                        title: const Text('Contact Us'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ContactUsScreen(),
                            ),
                          );
                        },
                      ),
                      if (isAdmin)
                        ListTile(
                          leading: const Icon(Icons.campaign_outlined),
                          title: const Text('Send Notifications'),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminNotificationsScreen(),
                              ),
                            );
                          },
                        ),
                      if (isAdmin)
                        ListTile(
                          leading: const Icon(Icons.feedback_outlined),
                          title: const Text('User Feedbacks'),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminFeedbacksScreen(),
                              ),
                            );
                          },
                        ),
                      SizedBox(height: r(20)),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          'Sign Out',
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
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
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
          Text(
            value,
            style: TextStyle(fontSize: r(18), fontWeight: FontWeight.bold),
          ),
          SizedBox(height: r(4)),
          Text(title, style: const TextStyle(color: Colors.grey)),
          if (subtitle != null) ...[
            SizedBox(height: r(2)),
            Text(
              subtitle!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: r(11)),
            ),
          ],
        ],
      ),
    );
  }
}
