import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_profile_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';
import '../../../utils/transport_icons.dart';
import 'manage_requests_screen.dart';
import 'trip_detail_screen.dart';
import 'trip_merge_requests_screen.dart';

class MyTripsScreen extends StatelessWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Please sign in to view your trips.",
            style: theme.textTheme.titleMedium,
          ),
        ),
      );
    }

    final uid = user.uid;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MergeRequestPromptListener(uid: uid),
                Padding(
                  padding: EdgeInsets.fromLTRB(r(22), r(18), r(22), r(14)),
                  child: Row(
                    children: [
                      Icon(
                        Icons.route_rounded,
                        color: AppTheme.brandOrange,
                        size: r(28),
                      ),
                      SizedBox(width: r(8)),
                      Expanded(
                        child: Text(
                          "My Trips",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: r(32),
                            letterSpacing: -1.1,
                          ),
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("users")
                            .doc(uid)
                            .collection("tripMergeRequests")
                            .snapshots(),
                        builder: (context, snapshot) {
                          final pending = snapshot.data?.docs.where((doc) {
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                return data["status"] == "pending";
                              }).length ??
                              0;
                          return Badge(
                            isLabelVisible: pending > 0,
                            label: Text("$pending"),
                            child: TextButton.icon(
                              icon: Icon(Icons.merge_rounded, size: r(19)),
                              label: const Text("Merge trips"),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TripMergeRequestsScreen(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r(16)),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r(10),
                      vertical: r(8),
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111B25) : Colors.white,
                      borderRadius: BorderRadius.circular(r(20)),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.08,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.16 : 0.06,
                          ),
                          blurRadius: r(16),
                          offset: Offset(0, r(7)),
                        ),
                      ],
                    ),
                    child: const TabBar(
                      dividerColor: Colors.transparent,
                      indicatorColor: AppTheme.brandOrange,
                      labelColor: AppTheme.brandOrange,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(icon: Icon(Icons.home_outlined), text: "Hosting"),
                        Tab(icon: Icon(Icons.groups_outlined), text: "Joined"),
                        Tab(
                          icon: Icon(Icons.calendar_month_outlined),
                          text: "Pending",
                        ),
                        Tab(icon: Icon(Icons.history_rounded), text: "History"),
                        Tab(icon: Icon(Icons.people_alt_outlined), text: "People"),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: r(12)),
                Expanded(
                  child: TabBarView(
                    children: [
                      _hosting(uid, context),
                      _joined(uid, context),
                      _pending(uid, context),
                      _history(uid, context),
                      _people(uid, context),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    String tripId,
    Map<String, dynamic> data, {
    VoidCallback? onTap,
    bool showHostActions = false,
  }) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    final tripIcon = destinationTransportIcon(data["to"]?.toString());
    final tripDateTime = _tripDateTime(data);
    final ownerId = (data["ownerId"] ?? "").toString();
    if (ownerId.isNotEmpty) {
      context.read<UserProfileProvider>().listenToUserProfile(ownerId);
    }
    final ownerProfile = ownerId.isNotEmpty
        ? context.watch<UserProfileProvider>().getUserProfile(ownerId)
        : null;
    final ownerName =
        (ownerProfile?["displayName"] ??
                ownerProfile?["name"] ??
                data["ownerName"] ??
                "")
            .toString();
    final status = _status(data);
    final tint = _destinationColor(data["to"]?.toString(), status.$1);

    return InkWell(
      borderRadius: BorderRadius.circular(r(22)),
      onTap:
          onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TripDetailScreen(tripId: tripId, data: data),
              ),
            );
          },
      child: Container(
        height: showHostActions ? null : r(150),
        margin: EdgeInsets.fromLTRB(r(16), r(8), r(16), r(12)),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF101B25) : Colors.white,
          borderRadius: BorderRadius.circular(r(22)),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : const Color(0xFFEAE5DE),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: r(18),
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              offset: Offset(0, r(8)),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: r(58),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        tint.withValues(alpha: isDark ? 0.22 : 0.10),
                        tint.withValues(alpha: isDark ? 0.06 : 0.03),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(r(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: r(54),
                        height: r(54),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [tint, tint.withValues(alpha: 0.78)],
                          ),
                          borderRadius: BorderRadius.circular(r(14)),
                        ),
                        child: Icon(tripIcon, color: Colors.white, size: r(28)),
                      ),
                      SizedBox(width: r(14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${data["from"]} → ${data["to"]}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: r(16),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: r(8)),
                            _metaLine(
                              context,
                              Icons.person_outline_rounded,
                              "Host: $ownerName",
                            ),
                            if (tripDateTime != null)
                              _metaLine(
                                context,
                                Icons.calendar_today_rounded,
                                "Date & Time: ${_formatTripDateTime(tripDateTime)}",
                              ),
                          ],
                        ),
                      ),
                      _statusPill(context, status.$2, status.$1),
                    ],
                  ),
                  if (showHostActions) ...[
                    SizedBox(height: r(12)),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ManageRequestsScreen(tripId: tripId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_search),
                          label: const Text("Manage Requests"),
                        ),
                        SizedBox(width: r(10)),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("tripRequests")
                              .where("tripId", isEqualTo: tripId)
                              .where("status", isEqualTo: "pending")
                              .snapshots(),
                          builder: (_, reqSnap) {
                            final count = reqSnap.data?.docs.length ?? 0;
                            return Chip(
                              avatar: const Icon(
                                Icons.pending_actions,
                                size: 16,
                              ),
                              label: Text("$count pending"),
                            );
                          },
                        ),
                      ],
                    ),
                  ] else ...[
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          "View Details",
                          style: TextStyle(
                            color: tint,
                            fontWeight: FontWeight.w800,
                            fontSize: r(12.5),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, color: tint),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaLine(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final r = context.rs;
    return Padding(
      padding: EdgeInsets.only(top: r(2)),
      child: Row(
        children: [
          Icon(
            icon,
            size: r(14),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
          ),
          SizedBox(width: r(7)),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                fontSize: r(11.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, String text, _TripStatus status) {
    final r = context.rs;
    final color = switch (status) {
      _TripStatus.completed => Colors.green,
      _TripStatus.cancelled => Colors.redAccent,
      _TripStatus.upcoming => AppTheme.brandOrange,
    };
    final icon = switch (status) {
      _TripStatus.completed => Icons.check_circle_outline_rounded,
      _TripStatus.cancelled => Icons.cancel_outlined,
      _TripStatus.upcoming => Icons.schedule_rounded,
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r(9), vertical: r(6)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(r(18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: r(13)),
          SizedBox(width: r(4)),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: r(10.5),
            ),
          ),
        ],
      ),
    );
  }

  (_TripStatus, String) _status(Map<String, dynamic> data) {
    if (data["cancelled"] == true || data["status"] == "cancelled") {
      return (_TripStatus.cancelled, "Cancelled");
    }
    if (isPast(data)) return (_TripStatus.completed, "Completed");
    return (_TripStatus.upcoming, "Upcoming");
  }

  Color _destinationColor(String? destination, _TripStatus status) {
    if (status == _TripStatus.cancelled) return Colors.redAccent;
    final value = (destination ?? "").toLowerCase();
    if (value.contains("railway")) return const Color(0xFF7C4DFF);
    if (value.contains("city")) return const Color(0xFF28A745);
    if (value.contains("hospital")) return AppTheme.brandOrange;
    if (value.contains("bus")) return const Color(0xFF7C4DFF);
    return AppTheme.brandOrange;
  }

  Widget _hosting(String uid, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("trips")
          .where("ownerId", isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final active = snap.data!.docs
            .where((e) => e.exists && e.data() != null)
            .where((e) => isActive(e.data() as Map<String, dynamic>))
            .toList();
        if (active.isEmpty) {
          return const Center(child: Text("No active hosted trips"));
        }
        return ListView(
          padding: EdgeInsets.only(bottom: context.rs(96)),
          children: active.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return _card(context, doc.id, d, showHostActions: true);
          }).toList(),
        );
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
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final parts = snap.data!.docs;
        if (parts.isEmpty) return const Center(child: Text("No joined trips"));
        return FutureBuilder<List<DocumentSnapshot>>(
          future: _fetchTrips(parts),
          builder: (_, tripSnap) {
            if (!tripSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final trips = tripSnap.data!
                .where((e) => e.exists && e.data() != null)
                .where((e) => isActive(e.data() as Map<String, dynamic>))
                .toList();
            if (trips.isEmpty) {
              return const Center(child: Text("No active joined trips"));
            }
            return ListView(
              padding: EdgeInsets.only(bottom: context.rs(96)),
              children: trips.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return _card(context, doc.id, d);
              }).toList(),
            );
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
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
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
                .toList();
            return ListView(
              padding: EdgeInsets.only(bottom: context.rs(96)),
              children: trips.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return _card(context, doc.id, d);
              }).toList(),
            );
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
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
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
              padding: EdgeInsets.only(bottom: context.rs(96)),
              children: historyDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _card(
                  context,
                  doc.id,
                  data,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TripDetailScreen(tripId: doc.id, data: data),
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
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final participantDocs = snap.data!.docs;
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchPeople(uid, participantDocs),
          builder: (_, peopleSnap) {
            if (!peopleSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final people = peopleSnap.data!;
            if (people.isEmpty) {
              return const Center(
                child: Text("No people found from your trips"),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(r(16), r(8), r(16), r(96)),
              itemCount: people.length,
              itemBuilder: (_, i) {
                final person = people[i];
                final name = (person["name"] ?? "User").toString();
                final tripsTogether = (person["tripsTogether"] ?? 0) as int;
                return Container(
                  margin: EdgeInsets.only(bottom: r(10)),
                  padding: EdgeInsets.all(r(14)),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF101B25)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(r(18)),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.brandOrange,
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
    final ownerTripsFuture = db
        .collection("trips")
        .where("ownerId", isEqualTo: uid)
        .get();
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
        final existing =
            peopleById[ownerId] ??
            {"userId": ownerId, "name": ownerName, "tripsTogether": 0};
        existing["tripsTogether"] =
            ((existing["tripsTogether"] ?? 0) as int) + 1;
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
        final existing =
            peopleById[userId] ??
            {
              "userId": userId,
              "name": (data["name"] ?? "User").toString(),
              "tripsTogether": 0,
            };
        existing["name"] = (data["name"] ?? existing["name"] ?? "User")
            .toString();
        existing["tripsTogether"] =
            ((existing["tripsTogether"] ?? 0) as int) + 1;
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

  Future<List<DocumentSnapshot>> _fetchTrips(
    List<QueryDocumentSnapshot> source,
  ) async {
    final db = FirebaseFirestore.instance;
    final futures = source.map((d) {
      final tripId = d["tripId"];
      return db.collection("trips").doc(tripId).get();
    });
    return Future.wait(futures);
  }
}

enum _TripStatus { completed, upcoming, cancelled }

class _MergeRequestPromptListener extends StatefulWidget {
  const _MergeRequestPromptListener({required this.uid});

  final String uid;

  @override
  State<_MergeRequestPromptListener> createState() =>
      _MergeRequestPromptListenerState();
}

class _MergeRequestPromptListenerState
    extends State<_MergeRequestPromptListener> {
  final Set<String> _shownRequestIds = {};
  bool _dialogOpen = false;

  Future<void> _respond(String requestId, bool accepted) async {
    await FirebaseFirestore.instance
        .collection("tripMergeRequests")
        .doc(requestId)
        .collection("acceptances")
        .doc(widget.uid)
        .set({
          "accepted": accepted,
          "createdAt": FieldValue.serverTimestamp(),
        });
  }

  void _showNextRequest(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> requests,
  ) {
    if (_dialogOpen) return;
    final pending = requests.where((doc) {
      return doc.data()["status"] == "pending" &&
          !_shownRequestIds.contains(doc.id);
    }).toList();
    if (pending.isEmpty) return;

    final request = pending.first;
    _shownRequestIds.add(request.id);
    _dialogOpen = true;
    final data = request.data();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Merge matching trips?"),
          content: Text(
            "Another host has a trip to ${data["destination"] ?? "the same destination"} "
            "at the same time. Merge the trips if both hosts accept?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Reject"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Accept"),
            ),
          ],
        ),
      );

      if (accepted != null) {
        try {
          await _respond(request.id, accepted);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  accepted
                      ? "Accepted. Waiting for the other host."
                      : "Rejected. Both trips will remain unchanged.",
                ),
              ),
            );
          }
        } catch (_) {
          _shownRequestIds.remove(request.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not save your response.")),
            );
          }
        }
      }
      _dialogOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(widget.uid)
          .collection("tripMergeRequests")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _showNextRequest(snapshot.data!.docs);
        }
        return const SizedBox.shrink();
      },
    );
  }
}
