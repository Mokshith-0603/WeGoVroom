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
  String _searchQuery = "";
  bool _isCheckingCreateTrip = false;
  Future<Map<String, dynamic>>? _userProfileFuture;

  @override
  void initState() {
    super.initState();
    _userProfileFuture = _loadUserProfile();
  }

  Future<bool> hasActiveTrip(String uid) async {
    final db = FirebaseFirestore.instance;
    final activeThreshold = DateTime.now().subtract(const Duration(hours: 12));

    final ownActiveFuture = db
        .collection("trips")
        .where("ownerId", isEqualTo: uid)
        .get();

    final partsFuture = db
        .collection("tripParticipants")
        .where("userId", isEqualTo: uid)
        .get();

    final ownSnap = await ownActiveFuture;
    final hasOwnedActive = ownSnap.docs.any((doc) {
      final data = doc.data();
      final ts = data["dateTime"];
      DateTime? dt;
      try {
        dt = (ts as Timestamp?)?.toDate();
      } catch (_) {
        dt = null;
      }
      return data["completed"] != true &&
          dt != null &&
          dt.isAfter(activeThreshold);
    });
    if (hasOwnedActive) return true;

    final parts = await partsFuture;
    if (parts.docs.isEmpty) return false;

    final tripIds = parts.docs
        .map((p) => (p.data()["tripId"] ?? "").toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (tripIds.isEmpty) return false;

    for (var i = 0; i < tripIds.length; i += 10) {
      final chunk = tripIds.sublist(
        i,
        i + 10 > tripIds.length ? tripIds.length : i + 10,
      );
      final snap = await db
          .collection("trips")
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      final hasJoinedActive = snap.docs.any((doc) {
        final data = doc.data();
        final ts = data["dateTime"];
        DateTime? dt;
        try {
          dt = (ts as Timestamp?)?.toDate();
        } catch (_) {
          dt = null;
        }
        return data["completed"] != true &&
            dt != null &&
            dt.isAfter(activeThreshold);
      });
      if (hasJoinedActive) return true;
    }

    return false;
  }

  Future<Map<String, dynamic>> _loadUserProfile() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return const {"name": "", "avatar": 0};
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();

    return {
      "name": data?['displayName'] ?? user.email?.split('@').first ?? "",
      "avatar": normalizeAvatarIndex(data?['avatar']),
    };
  }

  Future<void> _onCreateTripPressed() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || _isCheckingCreateTrip) return;

    setState(() => _isCheckingCreateTrip = true);
    try {
      final active = await hasActiveTrip(user.uid);
      if (!mounted) return;

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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to open Create Trip. Try again."),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingCreateTrip = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: bg,
      drawer: const ProfileDrawer(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: secondary,
        onPressed: _isCheckingCreateTrip ? null : _onCreateTripPressed,
        child: _isCheckingCreateTrip
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: r(16),
                  vertical: r(10),
                ),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        return GestureDetector(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: FutureBuilder<Map<String, dynamic>>(
                            future: _userProfileFuture,
                            builder: (_, snap) {
                              final avatar = (snap.data?["avatar"] ?? 0) as int;
                              return buildAvatar(avatar, radius: r(22));
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
                          FutureBuilder<Map<String, dynamic>>(
                            future: _userProfileFuture,
                            builder: (_, snap) {
                              final name = (snap.data?["name"] ?? "")
                                  .toString();
                              if (name.isEmpty) return const SizedBox.shrink();
                              return Text(
                                'Hi $name',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: r(16),
                                ),
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
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.headlineMedium,
                        children: [
                          const TextSpan(
                            text: 'WeGo',
                            style: TextStyle(color: Colors.black),
                          ),
                          TextSpan(
                            text: 'Vroom',
                            style: TextStyle(color: secondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r(16)),
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
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
                          horizontal: r(14),
                          vertical: r(8),
                        ),
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
                      final completed = data["completed"] == true;
                      if (completed) return false;
                      if (!now.isBefore(dt.add(const Duration(hours: 12)))) {
                        return false;
                      }

                      final isPublicTrip = data["isPublic"] != false;
                      if (isPublicTrip) return true;

                      final currentUser = fb.FirebaseAuth.instance.currentUser;
                      if (currentUser == null) return false;
                      if (data["ownerId"] == currentUser.uid) return true;

                      final invitedIds =
                          ((data["invitedUserIds"] as List?) ?? const [])
                              .map((e) => e.toString())
                              .toSet();
                      final invitedEmails =
                          ((data["invitedUserEmails"] as List?) ?? const [])
                              .map((e) => e.toString().trim().toLowerCase())
                              .toSet();
                      final currentEmail = (currentUser.email ?? "")
                          .trim()
                          .toLowerCase();

                      return invitedIds.contains(currentUser.uid) ||
                          (currentEmail.isNotEmpty &&
                              invitedEmails.contains(currentEmail));
                    }).toList();

                    if (docs.isEmpty) {
                      return const Center(child: Text("No active trips"));
                    }

                    final filtered = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final to = (data["to"] ?? "").toString();
                      final from = (data["from"] ?? "").toString();
                      final ownerName = (data["ownerName"] ?? "").toString();

                      final matchesChip =
                          selectedChip == "All" || to == selectedChip;
                      if (!matchesChip) return false;

                      if (_searchQuery.isEmpty) return true;

                      final haystack = "$from $to $ownerName".toLowerCase();
                      return haystack.contains(_searchQuery);
                    }).toList();

                    filtered.sort((a, b) {
                      final ad = a.data() as Map<String, dynamic>;
                      final bd = b.data() as Map<String, dynamic>;

                      DateTime? adt;
                      DateTime? bdt;
                      try {
                        adt = ad["dateTime"]?.toDate();
                      } catch (_) {}
                      try {
                        bdt = bd["dateTime"]?.toDate();
                      } catch (_) {}

                      final aActive = adt != null && now.isBefore(adt);
                      final bActive = bdt != null && now.isBefore(bdt);
                      if (aActive != bActive) return aActive ? -1 : 1;

                      if (adt == null && bdt != null) return 1;
                      if (adt != null && bdt == null) return -1;
                      if (adt != null && bdt != null) {
                        final dateCmp = adt.compareTo(bdt);
                        if (dateCmp != 0) return dateCmp;
                      }

                      final aj = (ad["joined"] as num?)?.toInt() ?? 0;
                      final bj = (bd["joined"] as num?)?.toInt() ?? 0;
                      return bj.compareTo(aj);
                    });

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text("No trips match your search"),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.all(r(16)),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final doc = filtered[i];
                        final data = doc.data() as Map<String, dynamic>;

                        return TripCard(tripId: doc.id, data: data);
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
