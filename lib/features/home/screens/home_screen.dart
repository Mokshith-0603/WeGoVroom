import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:provider/provider.dart';

import '../../../widgets/trip_card.dart';
import '../../trips/screens/create_trip_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../profile/widgets/profile_drawer.dart';
import '../../profile/widgets/avatar_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/responsive.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final chips = [
    "All",
    "Bus Stand",
    "Railway Station",
    "Airport",
    "City Center",
    "Shopping Mall",
  ];

  String selectedChip = "All";

  /// ⭐ CHECK ACTIVE TRIP (BLOCK CREATE)
  Future<bool> hasActiveTrip(String uid) async {
    final db = FirebaseFirestore.instance;

    // check both participant records and owned trips
    final now = DateTime.now();

    // owned trip
    final ownSnap = await db
        .collection("trips")
        .where("ownerId", isEqualTo: uid)
        .get();
    for (final t in ownSnap.docs) {
      final dt = t.data()["dateTime"]?.toDate();
      if (dt != null && dt.isAfter(now)) return true;
    }

    final parts = await db
        .collection("tripParticipants")
        .where("userId", isEqualTo: uid)
        .get();

    for (final p in parts.docs) {
      final tripId = p["tripId"];
      final tripDoc = await db.collection("trips").doc(tripId).get();

      if (!tripDoc.exists) continue;

      final data = tripDoc.data()!;
      final dt = data["dateTime"]?.toDate();

      if (dt != null && dt.isAfter(now)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final db = FirebaseFirestore.instance;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secondary = scheme.secondary;
    final bg = theme.scaffoldBackgroundColor;
    final r = context.rs;

    String greeting() {
      final hr = DateTime.now().hour;
      if (hr < 12) return 'Good morning';
      if (hr < 17) return 'Good afternoon';
      return 'Good evening';
    }

    /// ⭐ FETCH NAME FROM FIRESTORE
    Future<String> getDisplayName() async {
      if (user == null) return '';
      final doc = await db.collection('users').doc(user.uid).get();
      if (!doc.exists) return '';
      final data = doc.data();
      return data?['displayName'] ?? user.email?.split('@').first ?? '';
    }

    Future<int> getAvatarIndex() async {
      if (user == null) return 0;
      final doc = await db.collection('users').doc(user.uid).get();
      if (!doc.exists) return 0;
      final data = doc.data();
      return normalizeAvatarIndex(data?['avatar']);
    }

    return Scaffold(
      backgroundColor: bg,

      drawer: const ProfileDrawer(),

      /// ⭐ FAB — BLOCK IF ACTIVE
      floatingActionButton: FloatingActionButton(
        backgroundColor: secondary,
        onPressed: () async {
          if (user == null) return;

          final active = await hasActiveTrip(user.uid);

          if (active) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("You already have an active trip")),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTripScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),

      body: SafeArea(
        child: ResponsiveContent(
          child: Column(
          children: [
            /// HEADER
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r(16), vertical: r(10)),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      return GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: FutureBuilder<int>(
                          future: getAvatarIndex(),
                          builder: (_, snap) {
                            return buildAvatar(snap.data ?? 0, radius: r(22));
                          },
                        ),
                      );
                    },
                  ),
                  SizedBox(width: r(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting(),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        FutureBuilder<String>(
                          future: getDisplayName(),
                          builder: (_, snap) {
                            final name = snap.data ?? '';
                            if (name.isEmpty) return const SizedBox.shrink();
                            return Text(
                              'Hi 👋 $name',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: r(16)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),

                  /// styled app name
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.headlineMedium,
                      children: [
                        const TextSpan(
                            text: 'WeGo',
                            style: TextStyle(color: Colors.black)),
                        TextSpan(
                            text: 'Vroom',
                            style: TextStyle(color: secondary)),
                      ],
                    ),
                  )
                ],
              ),
            ),

            /// SEARCH
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r(16)),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search trips, destinations...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r(30)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            SizedBox(height: r(12)),

            /// CHIPS
            SizedBox(
              height: r(40),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: r(16)),
                scrollDirection: Axis.horizontal,
                itemCount: chips.length,
                itemBuilder: (_, i) {
                  final label = chips[i];
                  final selected = selectedChip == label;

                  return GestureDetector(
                    onTap: () => setState(() => selectedChip = label),
                    child: Container(
                      margin: EdgeInsets.only(right: r(8)),
                      padding: EdgeInsets.symmetric(
                          horizontal: r(14), vertical: r(8)),
                      decoration: BoxDecoration(
                        color: selected ? secondary : Colors.white,
                        borderRadius: BorderRadius.circular(r(20)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: r(10)),

            /// ⭐ ACTIVE TRIPS ONLY
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("trips")
                    .orderBy("dateTime")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final now = DateTime.now();

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final dt = data["dateTime"]?.toDate();
                    if (dt == null) return false;
                    if (!dt.isAfter(now)) return false;

                    final isPublicTrip = data["isPublic"] != false;
                    if (isPublicTrip) return true;

                    final currentUser = fb.FirebaseAuth.instance.currentUser;
                    if (currentUser == null) return false;
                    if (data["ownerId"] == currentUser.uid) return true;

                    final invitedIds = ((data["invitedUserIds"] as List?) ?? const [])
                        .map((e) => e.toString())
                        .toSet();
                    final invitedEmails = ((data["invitedUserEmails"] as List?) ?? const [])
                        .map((e) => e.toString().trim().toLowerCase())
                        .toSet();
                    final currentEmail = (currentUser.email ?? "").trim().toLowerCase();

                    return invitedIds.contains(currentUser.uid) ||
                        (currentEmail.isNotEmpty && invitedEmails.contains(currentEmail));
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text("No active trips"));
                  }

                  final filtered = docs.where((doc) {
                    if (selectedChip == "All") return true;
                    final data = doc.data() as Map<String, dynamic>;
                    return data["to"] == selectedChip;
                  }).toList();

                  return ListView.builder(
                    padding: EdgeInsets.all(r(16)),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final doc = filtered[i];
                      final data = doc.data() as Map<String, dynamic>;

                      return TripCard(
                        tripId: doc.id,
                        data: data,
                      );
                    },
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
