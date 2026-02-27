import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/home/screens/home_screen.dart';
import '../features/trips/screens/my_trips_screen.dart';
import '../features/drivers/screens/drivers_screen.dart';
import '../features/chat/screens/chat_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int index = 0;

  final user = FirebaseAuth.instance.currentUser;
  final db = FirebaseFirestore.instance;
  late final Stream<String?> _activeTripStream;

  @override
  void initState() {
    super.initState();
    _activeTripStream = activeTripStream();
  }

  /// ⭐ STREAM → ACTIVE TRIP ID (simplified and more reliable)
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
        String? fallbackJoinedTripId;

        // Check joined trips first
        for (final doc in snap.docs) {
          try {
            final tid = doc.data()["tripId"] as String?;
            if (tid == null) continue;

            final tripDoc = await db.collection("trips").doc(tid).get();
            if (!tripDoc.exists) continue;
            fallbackJoinedTripId ??= tid;

            final ts = tripDoc.data()?["dateTime"];
            if (ts == null) continue;

            DateTime dt = ts.toDate();
            if (dt.isAfter(now)) {
              lastKnownTripId = tid;
              return tid; // First active trip found
            }
          } catch (e) {
            continue; // Skip errors and try next
          }
        }

        if (fallbackJoinedTripId != null) {
          lastKnownTripId = fallbackJoinedTripId;
          return fallbackJoinedTripId;
        }

        // Check owned trips if no joined trip
        try {
          final ownedSnap = await db
              .collection("trips")
              .where("ownerId", isEqualTo: user!.uid)
              .get();

          if (ownedSnap.docs.isNotEmpty) {
            QueryDocumentSnapshot<Map<String, dynamic>>? bestDoc;
            DateTime? bestDate;

            for (final doc in ownedSnap.docs) {
              final ts = doc.data()["dateTime"];
              if (ts == null) continue;
              try {
                final dt = ts.toDate();
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

            // Final fallback: if trips exist but dateTime is missing/invalid.
            lastKnownTripId = ownedSnap.docs.first.id;
            return ownedSnap.docs.first.id;
          }
        } catch (e) {
          // Fallback if query fails
        }

        return lastKnownTripId;
      } catch (e) {
        return lastKnownTripId;
      }
    });
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

              /// ⭐ SAFE CHAT SCREEN – tripId may be null
              ChatScreen(tripId: tripId),
            ],
          ),

          bottomNavigationBar: NavigationBar(
            height: 70,
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
