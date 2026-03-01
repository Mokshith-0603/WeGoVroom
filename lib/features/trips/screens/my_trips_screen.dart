import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../utils/responsive.dart';
import '../../../utils/transport_icons.dart';
import 'trip_detail_screen.dart';

class MyTripsScreen extends StatelessWidget {
  const MyTripsScreen({super.key});

  DateTime? _tripDateTime(Map<String, dynamic> data) {
    final raw = data['dateTime'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  String _formatTripDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  bool isActive(Map<String, dynamic> data) {
    final dt = _tripDateTime(data);
    if (dt == null) return false;
    return DateTime.now().isBefore(dt);
  }

  bool isPast(Map<String, dynamic> data) {
    final dt = _tripDateTime(data);
    if (dt == null) return false;
    return DateTime.now().isAfter(dt);
  }

  Widget _card(
    BuildContext context,
    Map<String, dynamic> data, {
    VoidCallback? onTap,
  }) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final r = context.rs;
    final tripIcon = destinationTransportIcon(data['to']?.toString());
    final tripDateTime = _tripDateTime(data);

    return InkWell(
      borderRadius: BorderRadius.circular(r(18)),
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r(16), vertical: r(8)),
        padding: EdgeInsets.all(r(16)),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(r(18)),
          border: Border.all(color: secondary.withValues(alpha: 0.35)),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
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
                    '${data['from']} -> ${data['to']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: r(6)),
            Text(
              'Host: ${data['ownerName'] ?? ''}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (tripDateTime != null) ...[
              SizedBox(height: r(2)),
              Text(
                'Date & Time: ${_formatTripDateTime(tripDateTime)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hosting(String uid, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('trips').where('ownerId', isEqualTo: uid).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final active = snap.data!.docs
            .where((e) => e.exists && e.data() != null)
            .map((e) => e.data() as Map<String, dynamic>)
            .where(isActive)
            .toList();

        if (active.isEmpty) return const Center(child: Text('No active hosted trips'));

        return ListView(children: active.map((d) => _card(context, d)).toList());
      },
    );
  }

  Widget _joined(String uid, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tripParticipants')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final parts = snap.data!.docs;
        if (parts.isEmpty) return const Center(child: Text('No joined trips'));

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

            if (trips.isEmpty) return const Center(child: Text('No active joined trips'));

            return ListView(children: trips.map((d) => _card(context, d)).toList());
          },
        );
      },
    );
  }

  Widget _pending(String uid, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tripRequests')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final reqs = snap.data!.docs;
        if (reqs.isEmpty) return const Center(child: Text('No pending requests'));

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
      stream: FirebaseFirestore.instance.collection('trips').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final pastDocs = snap.data!.docs
            .where((e) => e.exists && e.data() != null)
            .where((e) => isPast(e.data() as Map<String, dynamic>))
            .toList();

        if (pastDocs.isEmpty) return const Center(child: Text('No trip history'));

        return ListView(
          children: pastDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _card(
              context,
              data,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TripDetailScreen(tripId: doc.id, data: data),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<DocumentSnapshot>> _fetchTrips(List<QueryDocumentSnapshot> source) async {
    final db = FirebaseFirestore.instance;
    final futures = source.map((d) {
      final tripId = d['tripId'];
      return db.collection('trips').doc(tripId).get();
    });
    return Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final secondary = Theme.of(context).colorScheme.secondary;
    final r = context.rs;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          toolbarHeight: r(58),
          title: const Text(
            'My Trips',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: secondary,
            unselectedLabelColor: Colors.white60,
            indicatorColor: secondary,
            tabs: const [
              Tab(text: 'Hosting'),
              Tab(text: 'Joined'),
              Tab(text: 'Pending'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _hosting(uid, context),
            _joined(uid, context),
            _pending(uid, context),
            _history(uid, context),
          ],
        ),
      ),
    );
  }
}
