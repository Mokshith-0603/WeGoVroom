import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/responsive.dart';
import '../../../utils/transport_icons.dart';
import 'trip_detail_screen.dart';

class MyTripsScreen extends StatelessWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secondary = scheme.secondary;
    final bg = theme.scaffoldBackgroundColor;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            "My Trips",
            style: theme.textTheme.headlineMedium?.copyWith(color: Colors.black),
          ),
          iconTheme: const IconThemeData(color: Colors.black),
          bottom: TabBar(
            isScrollable: context.isTablet,
            labelColor: secondary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: secondary,
            tabs: const [
              Tab(text: "Hosting"),
              Tab(text: "Joined"),
              Tab(text: "Pending"),
              Tab(text: "History"),
              Tab(text: "People"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _hosting(uid, context),
            _joined(uid, context),
            _pending(uid, context),
            _history(uid, context),
            _people(uid, context),
          ],
        ),
      ),
    );
  }

  DateTime? _tripDateTime(Map<String, dynamic> data) {
    final raw = data["dateTime"];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  String _formatTripDateTime(DateTime dt) {
    return DateFormat("dd MMM yyyy, hh:mm a").format(dt);
  }

  bool isActive(Map<String, dynamic> data) {
    if (data["completed"] == true) return false;
    final dt = _tripDateTime(data);
    if (dt == null) return false;
    return DateTime.now().isBefore(dt.add(const Duration(hours: 12)));
  }

  bool isPast(Map<String, dynamic> data) {
    if (data["completed"] == true) return true;
    final dt = _tripDateTime(data);
    if (dt == null) return false;
    return !DateTime.now().isBefore(dt.add(const Duration(hours: 12)));
  }

  Widget _card(
    BuildContext context,
    Map<String, dynamic> data, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    final r = context.rs;
    final tripIcon = destinationTransportIcon(data["to"]?.toString());
    final tripDateTime = _tripDateTime(data);

    return InkWell(
      borderRadius: BorderRadius.circular(r(18)),
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r(16), vertical: r(8)),
        padding: EdgeInsets.all(r(16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r(18)),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(tripIcon, color: secondary),
                SizedBox(width: r(8)),
                Expanded(
                  child: Text(
                    "${data["from"]} -> ${data["to"]}",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: r(4)),
            Text(
              "Host: ${data["ownerName"] ?? ""}",
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
            if (tripDateTime != null) ...[
              SizedBox(height: r(2)),
              Text(
                "Date & Time: ${_formatTripDateTime(tripDateTime)}",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hosting(String uid, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("trips")
          .where("ownerId", isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final active = snap.data!.docs
            .where((e) => e.exists && e.data() != null)
            .map((e) => e.data() as Map<String, dynamic>)
            .where(isActive)
            .toList();

        if (active.isEmpty) {
          return const Center(child: Text("No active hosted trips"));
        }

        return ListView(children: active.map((d) => _card(context, d)).toList());
      },
    );
  }

  Widget _joined(String uid, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("tripParticipants")
          .where("userId", isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final parts = snap.data!.docs;
        if (parts.isEmpty) {
          return const Center(child: Text("No joined trips"));
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: _fetchTrips(parts),
          builder: (_, tripSnap) {
            if (!tripSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final trips = tripSnap.data!
                .where((e) => e.exists && e.data() != null)
                .map((e) => e.data() as Map<String, dynamic>)
                .where(isActive)
                .toList();

            if (trips.isEmpty) {
              return const Center(child: Text("No active joined trips"));
            }

            return ListView(children: trips.map((d) => _card(context, d)).toList());
          },
        );
      },
    );
  }

  Widget _pending(String uid, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("tripRequests")
          .where("userId", isEqualTo: uid)
          .where("status", isEqualTo: "pending")
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final reqs = snap.data!.docs;
        if (reqs.isEmpty) {
          return const Center(child: Text("No pending requests"));
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: _fetchTrips(reqs),
          builder: (_, tripSnap) {
            if (!tripSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final trips = tripSnap.data!
                .where((s) => s.exists && s.data() != null)
                .map((e) => e.data() as Map<String, dynamic>)
                .toList();

            return ListView(children: trips.map((d) => _card(context, d)).toList());
          },
        );
      },
    );
  }

  Widget _history(String uid, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("tripParticipants")
          .where("userId", isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final participantDocs = snap.data!.docs;

        return FutureBuilder<List<DocumentSnapshot>>(
          future: _fetchHistoryTrips(uid, participantDocs),
          builder: (_, historySnap) {
            if (!historySnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final historyDocs = historySnap.data!;
            if (historyDocs.isEmpty) {
              return const Center(child: Text("No trip history"));
            }

            return ListView(
              children: historyDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _card(
                  context,
                  data,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripDetailScreen(
                          tripId: doc.id,
                          data: data,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _people(String uid, BuildContext context) {
    final r = context.rs;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("tripParticipants")
          .where("userId", isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final participantDocs = snap.data!.docs;

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchPeople(uid, participantDocs),
          builder: (_, peopleSnap) {
            if (!peopleSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final people = peopleSnap.data!;
            if (people.isEmpty) {
              return const Center(child: Text("No people found from your trips"));
            }

            return ListView.builder(
              padding: EdgeInsets.all(r(12)),
              itemCount: people.length,
              itemBuilder: (_, i) {
                final person = people[i];
                final name = (person["name"] ?? "User").toString();
                final tripsTogether = (person["tripsTogether"] ?? 0) as int;

                return Container(
                  margin: EdgeInsets.only(bottom: r(10)),
                  padding: EdgeInsets.all(r(14)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(r(16)),
                    boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xffff7a00),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text("Trips together: $tripsTogether"),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<DocumentSnapshot>> _fetchHistoryTrips(
    String uid,
    List<QueryDocumentSnapshot> participantDocs,
  ) async {
    final db = FirebaseFirestore.instance;
    final ownerTripsFuture = db.collection("trips").where("ownerId", isEqualTo: uid).get();
    final joinedTripsFuture = _fetchTrips(participantDocs);

    final ownerTrips = await ownerTripsFuture;
    final joinedTrips = await joinedTripsFuture;

    final byId = <String, DocumentSnapshot>{};
    for (final doc in ownerTrips.docs) {
      byId[doc.id] = doc;
    }
    for (final doc in joinedTrips) {
      byId[doc.id] = doc;
    }

    final filtered = byId.values.where((doc) {
      if (!doc.exists || doc.data() == null) return false;
      final data = doc.data() as Map<String, dynamic>;
      final completed = data["completed"] == true;
      return completed || isPast(data);
    }).toList();

    filtered.sort((a, b) {
      final ad = _tripDateTime(a.data() as Map<String, dynamic>);
      final bd = _tripDateTime(b.data() as Map<String, dynamic>);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return filtered;
  }

  Future<List<Map<String, dynamic>>> _fetchPeople(
    String uid,
    List<QueryDocumentSnapshot> participantDocs,
  ) async {
    final db = FirebaseFirestore.instance;
    final historyTrips = await _fetchHistoryTrips(uid, participantDocs);
    if (historyTrips.isEmpty) return const [];

    final peopleById = <String, Map<String, dynamic>>{};

    for (final tripDoc in historyTrips) {
      if (!tripDoc.exists || tripDoc.data() == null) continue;
      final tripData = tripDoc.data() as Map<String, dynamic>;
      final tripId = tripDoc.id;

      final ownerId = (tripData["ownerId"] ?? "").toString();
      final ownerName = (tripData["ownerName"] ?? "Host").toString();
      if (ownerId.isNotEmpty && ownerId != uid) {
        final existing = peopleById[ownerId] ?? {
          "userId": ownerId,
          "name": ownerName,
          "tripsTogether": 0,
        };
        existing["tripsTogether"] = ((existing["tripsTogether"] ?? 0) as int) + 1;
        peopleById[ownerId] = existing;
      }

      final partSnap = await db
          .collection("tripParticipants")
          .where("tripId", isEqualTo: tripId)
          .get();
      for (final part in partSnap.docs) {
        final data = part.data();
        final userId = (data["userId"] ?? "").toString();
        if (userId.isEmpty || userId == uid) continue;

        final existing = peopleById[userId] ?? {
          "userId": userId,
          "name": (data["name"] ?? "User").toString(),
          "tripsTogether": 0,
        };
        existing["name"] = (data["name"] ?? existing["name"] ?? "User").toString();
        existing["tripsTogether"] = ((existing["tripsTogether"] ?? 0) as int) + 1;
        peopleById[userId] = existing;
      }
    }

    final people = peopleById.values.toList();
    people.sort((a, b) {
      final ta = (a["tripsTogether"] ?? 0) as int;
      final tb = (b["tripsTogether"] ?? 0) as int;
      if (ta != tb) return tb.compareTo(ta);
      final na = (a["name"] ?? "").toString().toLowerCase();
      final nb = (b["name"] ?? "").toString().toLowerCase();
      return na.compareTo(nb);
    });
    return people;
  }

  Future<List<DocumentSnapshot>> _fetchTrips(List<QueryDocumentSnapshot> source) async {
    final db = FirebaseFirestore.instance;
    final futures = source.map((d) {
      final tripId = d["tripId"];
      return db.collection("trips").doc(tripId).get();
    });
    return Future.wait(futures);
  }
}
