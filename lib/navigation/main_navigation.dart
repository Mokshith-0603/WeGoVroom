import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/chat/screens/chat_screen.dart';
import '../features/drivers/screens/drivers_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/trips/screens/my_trips_screen.dart';
import '../features/trips/screens/trip_detail_screen.dart';
import '../services/trip_link_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class MainNavigation extends StatefulWidget {
  final String? initialTripId;

  const MainNavigation({super.key, this.initialTripId});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int index = 0;

  final user = FirebaseAuth.instance.currentUser;
  final db = FirebaseFirestore.instance;
  late final Stream<String?> _activeTripStream;
  StreamSubscription<Uri>? _linkSubscription;
  bool _openedInitialTrip = false;
  String? _lastOpenedTripId;

  @override
  void initState() {
    super.initState();
    _activeTripStream = activeTripStream();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openDeepLinkedTripIfAny();
    });
    _linkSubscription = TripLinkService.instance.uriStream.listen((uri) {
      final tripId = TripLinkService.instance.tripIdFromUri(uri);
      if (tripId != null && tripId.isNotEmpty) {
        _openTripById(tripId);
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openDeepLinkedTripIfAny() async {
    if (_openedInitialTrip || !mounted) return;
    _openedInitialTrip = true;

    final tripId =
        widget.initialTripId ?? await TripLinkService.instance.getInitialTripId();
    if (tripId == null || tripId.isEmpty) return;

    await _openTripById(tripId);
  }

  Future<void> _openTripById(String tripId) async {
    if (!mounted || _lastOpenedTripId == tripId) return;
    _lastOpenedTripId = tripId;

    try {
      final tripDoc = await db.collection("trips").doc(tripId).get();
      if (!tripDoc.exists || tripDoc.data() == null || !mounted) {
        _lastOpenedTripId = null;
        return;
      }
      final tripData = tripDoc.data() as Map<String, dynamic>;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripDetailScreen(tripId: tripId, data: tripData),
        ),
      ).whenComplete(() {
        if (_lastOpenedTripId == tripId) _lastOpenedTripId = null;
      });
    } catch (_) {
      _lastOpenedTripId = null;
    }
  }

  Stream<String?> activeTripStream() {
    if (user == null) return Stream.value(null);
    String? lastKnownTripId;

    return db
        .collection("tripParticipants")
        .where("userId", isEqualTo: user!.uid)
        .snapshots()
        .asyncMap((snap) async {
          try {
            final now = DateTime.now();
            final ownedSnapFuture = db
                .collection("trips")
                .where("ownerId", isEqualTo: user!.uid)
                .get();
            final participantTripIds = snap.docs
                .map((doc) => doc.data()["tripId"] as String?)
                .whereType<String>()
                .where((tid) => tid.isNotEmpty)
                .toSet()
                .toList();

            String? fallbackJoinedTripId;

            for (var i = 0; i < participantTripIds.length; i += 10) {
              final chunk = participantTripIds.sublist(
                i,
                i + 10 > participantTripIds.length
                    ? participantTripIds.length
                    : i + 10,
              );
              final tripsSnap = await db
                  .collection("trips")
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get();

              for (final tripDoc in tripsSnap.docs) {
                final data = tripDoc.data();
                fallbackJoinedTripId ??= tripDoc.id;
                final ts = data["dateTime"];
                if (ts == null) continue;

                try {
                  final dt = ts.toDate();
                  final completed = data["completed"] == true;
                  if (!completed &&
                      now.isBefore(dt.add(const Duration(hours: 12)))) {
                    lastKnownTripId = tripDoc.id;
                    return tripDoc.id;
                  }
                } catch (_) {
                  continue;
                }
              }
            }

            if (fallbackJoinedTripId != null) {
              lastKnownTripId = fallbackJoinedTripId;
              return fallbackJoinedTripId;
            }

            try {
              final ownedSnap = await ownedSnapFuture;

              if (ownedSnap.docs.isNotEmpty) {
                QueryDocumentSnapshot<Map<String, dynamic>>? bestDoc;
                DateTime? bestDate;

                for (final doc in ownedSnap.docs) {
                  final data = doc.data();
                  if (data["completed"] == true) continue;
                  final ts = data["dateTime"];
                  if (ts == null) continue;
                  try {
                    final dt = ts.toDate();
                    if (!now.isBefore(dt.add(const Duration(hours: 12))))
                      continue;
                    if (bestDate == null || dt.isAfter(bestDate)) {
                      bestDate = dt;
                      bestDoc = doc;
                    }
                  } catch (_) {
                    continue;
                  }
                }

                if (bestDoc != null) {
                  lastKnownTripId = bestDoc.id;
                  return bestDoc.id;
                }

                lastKnownTripId = ownedSnap.docs.first.id;
                return ownedSnap.docs.first.id;
              }
            } catch (_) {}

            return lastKnownTripId;
          } catch (_) {
            return lastKnownTripId;
          }
        })
        .distinct();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _activeTripStream,
      builder: (context, snap) {
        final tripId = snap.data;

        return Scaffold(
          body: IndexedStack(
            index: index,
            children: [
              const HomeScreen(),
              const MyTripsScreen(),
              DriversScreen(onBack: () => setState(() => index = 0)),
              ChatScreen(tripId: tripId),
            ],
          ),
          extendBody: true,
          bottomNavigationBar: _footerNav(context),
        );
      },
    );
  }

  Widget _footerNav(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = context.rs;

    final items = const [
      _NavItem(
        label: 'Home',
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
      ),
      _NavItem(
        label: 'My Trips',
        icon: Icons.route_outlined,
        selectedIcon: Icons.route_rounded,
      ),
      _NavItem(
        label: 'Drivers',
        icon: Icons.local_taxi_outlined,
        selectedIcon: Icons.local_taxi_rounded,
      ),
      _NavItem(
        label: 'Chat',
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum_rounded,
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(r(16), r(8), r(16), r(10)),
        child: Container(
          height: r(74),
          padding: EdgeInsets.symmetric(horizontal: r(10), vertical: r(8)),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0B1724).withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(r(28)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 28,
                offset: const Offset(0, 12),
                color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _footerNavItem(
                    context,
                    item: items[i],
                    selected: index == i,
                    onTap: () => setState(() => index = i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerNavItem(
    BuildContext context, {
    required _NavItem item,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = context.rs;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r(22)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: r(2)),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.brandOrange.withValues(alpha: isDark ? 0.18 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(r(22)),
            boxShadow: selected && isDark
                ? [
                    BoxShadow(
                      color: AppTheme.brandOrange.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                color: selected
                    ? AppTheme.brandOrange
                    : theme.colorScheme.onSurface.withValues(
                        alpha: isDark ? 0.78 : 0.68,
                      ),
                size: r(24),
              ),
              SizedBox(height: r(4)),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? AppTheme.brandOrange
                      : theme.colorScheme.onSurface.withValues(
                          alpha: isDark ? 0.78 : 0.68,
                        ),
                  fontSize: r(11),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
