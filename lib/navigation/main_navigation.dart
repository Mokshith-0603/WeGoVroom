import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/chat/screens/chat_screen.dart';
import '../features/drivers/screens/drivers_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/trips/screens/my_trips_screen.dart';
import '../features/trips/screens/trip_detail_screen.dart';
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
  bool _openedInitialTrip = false;

  @override
  void initState() {
    super.initState();
    _activeTripStream = activeTripStream();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openDeepLinkedTripIfAny();
    });
  }

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

  Future<void> _openDeepLinkedTripIfAny() async {
    if (_openedInitialTrip || !mounted) return;
    _openedInitialTrip = true;

    final tripId = widget.initialTripId ?? _tripIdFromUri(Uri.base);
    if (tripId == null || tripId.isEmpty) return;

    try {
      final tripDoc = await db.collection("trips").doc(tripId).get();
      if (!tripDoc.exists || tripDoc.data() == null || !mounted) return;
      final tripData = tripDoc.data() as Map<String, dynamic>;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripDetailScreen(tripId: tripId, data: tripData),
        ),
      );
    } catch (_) {}
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
              const DriversScreen(),
              ChatScreen(tripId: tripId),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            height: context.rs(70),
            selectedIndex: index,
            onDestinationSelected: (i) {
              setState(() => index = i);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: "Home",
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                label: "My Trips",
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_car_outlined),
                label: "Drivers",
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                label: "Chat",
              ),
            ],
          ),
        );
      },
    );
  }
}
