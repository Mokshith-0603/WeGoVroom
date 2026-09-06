import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';
import '../../../widgets/trip_card.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../notifications/widgets/notification_indicator_icon.dart';
import '../../profile/widgets/avatar_utils.dart';
import '../../profile/widgets/profile_drawer.dart';
import '../../trips/screens/create_trip_screen.dart';

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

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final profileProvider = context.read<UserProfileProvider>();
    if (auth.user != null) {
      profileProvider.listenToUserProfile(auth.user!.uid);
    }
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
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;

    String greeting() {
      final hr = DateTime.now().hour;
      if (hr < 12) return 'Good morning';
      if (hr < 17) return 'Good afternoon';
      return 'Good evening';
    }

    return Scaffold(
      drawer: const ProfileDrawer(),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF06131E), Color(0xFF08111A)]
                : const [Color(0xFFFFFEFC), Color(0xFFF8F5F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ResponsiveContent(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(r(20), r(14), r(20), r(125)),
              children: [
                Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final profileProvider = context
                            .watch<UserProfileProvider>();
                        final auth = context.watch<AuthProvider>();
                        final profile = auth.user != null
                            ? profileProvider.getUserProfile(auth.user!.uid)
                            : null;
                        return GestureDetector(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.brandOrange.withValues(
                                    alpha: 0.24,
                                  ),
                                  blurRadius: r(18),
                                  offset: Offset(0, r(7)),
                                ),
                              ],
                            ),
                            child: buildAvatar(
                              normalizeAvatarIndex(profile?["avatar"]),
                              radius: r(28),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: r(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting(),
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.66),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final profileProvider = context
                                  .watch<UserProfileProvider>();
                              final auth = context.watch<AuthProvider>();
                              final profile = auth.user != null
                                  ? profileProvider.getUserProfile(
                                      auth.user!.uid,
                                    )
                                  : null;
                              final name =
                                  (profile?["displayName"] ??
                                          profile?["name"] ??
                                          "")
                                      .toString();
                              if (name.isEmpty) return const SizedBox.shrink();
                              return Text(
                                'Hi $name',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: r(19),
                                  height: 1.2,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const NotificationIndicatorIcon(
                        icon: Icons.notifications_none,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: r(4)),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: r(20),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'WeGo',
                            style: TextStyle(color: scheme.onSurface),
                          ),
                          const TextSpan(
                            text: 'Vroom',
                            style: TextStyle(color: AppTheme.brandOrange),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r(28)),
                _searchBox(context),
                SizedBox(height: r(24)),
                SizedBox(
                  height: r(46),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: chips.length,
                    itemBuilder: (_, i) {
                      final label = chips[i];
                      return _destinationChip(
                        context,
                        label,
                        selectedChip == label,
                      );
                    },
                  ),
                ),
                SizedBox(height: r(20)),
                _planJourneyCard(context),
                SizedBox(height: r(28)),
                Row(
                  children: [
                    Text(
                      "Upcoming Trip",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: r(21),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "View all",
                      style: TextStyle(
                        color: AppTheme.brandOrange,
                        fontWeight: FontWeight.w700,
                        fontSize: r(14),
                      ),
                    ),
                    SizedBox(width: r(4)),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.brandOrange,
                      size: r(20),
                    ),
                  ],
                ),
                SizedBox(height: r(14)),
                _upcomingTripStream(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBox(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r(26)),
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF111B25)
            : Colors.white,
        border: Border.all(
          color: AppTheme.brandOrange.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: r(18),
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.055,
            ),
            offset: Offset(0, r(8)),
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: "Search trips, destinations...",
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
          suffixIcon: const Icon(
            Icons.tune_rounded,
            color: AppTheme.brandOrange,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r(26)),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: r(16),
            vertical: r(18),
          ),
        ),
      ),
    );
  }

  Widget _destinationChip(BuildContext context, String label, bool selected) {
    final theme = Theme.of(context);
    final r = context.rs;
    final icon = switch (label) {
      "Bus Stand" => Icons.directions_bus_rounded,
      "Railway Station" => Icons.train_rounded,
      "Airport" => Icons.flight_rounded,
      "City Center" => Icons.location_city_rounded,
      "Shopping Mall" => Icons.shopping_bag_rounded,
      _ => Icons.apps_rounded,
    };
    final iconColor = switch (label) {
      "Railway Station" => const Color(0xFFD12BC5),
      "Airport" => const Color(0xFF2297F3),
      _ => AppTheme.brandOrange,
    };

    return GestureDetector(
      onTap: () => setState(() => selectedChip = label),
      child: Container(
        margin: EdgeInsets.only(right: r(10)),
        padding: EdgeInsets.symmetric(horizontal: r(15), vertical: r(10)),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.brandOrange
              : (theme.brightness == Brightness.dark
                    ? const Color(0xFF111B25)
                    : Colors.white),
          borderRadius: BorderRadius.circular(r(20)),
          border: Border.all(
            color: selected
                ? AppTheme.brandOrange
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.10 : 0.04),
              blurRadius: r(12),
              offset: Offset(0, r(5)),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : iconColor, size: r(19)),
            SizedBox(width: r(7)),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: r(13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upcomingTripStream(BuildContext context) {
    final r = context.rs;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("trips")
          .orderBy("dateTime")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: r(180),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final now = DateTime.now();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dt = data["dateTime"]?.toDate();
          if (dt == null) return false;
          if (data["completed"] == true) return false;
          return now.isBefore(dt.add(const Duration(hours: 12)));
        }).toList();

        if (docs.isEmpty) return _emptyTrips(context, "No active trips");

        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final to = (data["to"] ?? "").toString();
          final from = (data["from"] ?? "").toString();
          final ownerName = (data["ownerName"] ?? "").toString();

          if (selectedChip != "All" && to != selectedChip) return false;
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
          return _emptyTrips(context, "No trips match your search");
        }

        return Column(
          children: filtered.map((doc) {
            return TripCard(
              tripId: doc.id,
              data: doc.data() as Map<String, dynamic>,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _emptyTrips(BuildContext context, String message) {
    final r = context.rs;
    return Container(
      height: r(170),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111B25)
            : Colors.white,
        borderRadius: BorderRadius.circular(r(24)),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Text(message),
    );
  }

  Widget _planJourneyCard(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: r(188),
      padding: EdgeInsets.all(r(20)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101B25) : Colors.white,
        borderRadius: BorderRadius.circular(r(24)),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: r(20),
            offset: Offset(0, r(9)),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: r(8),
            top: r(10),
            child: Icon(
              Icons.map_rounded,
              size: r(108),
              color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.18 : 0.11),
            ),
          ),
          Positioned(
            right: r(42),
            top: r(28),
            child: Icon(
              Icons.location_on_rounded,
              size: r(76),
              color: AppTheme.brandOrange,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Plan your next journey",
                style: theme.textTheme.titleLarge?.copyWith(fontSize: r(19)),
              ),
              SizedBox(height: r(10)),
              Text(
                "Safe rides, trusted drivers,\nhassle-free travel.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isCheckingCreateTrip ? null : _onCreateTripPressed,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text("Book a Trip"),
                style: FilledButton.styleFrom(
                  minimumSize: Size(r(132), r(46)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
