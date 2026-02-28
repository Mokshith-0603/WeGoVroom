import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> data;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    required this.data,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final db = FirebaseFirestore.instance;

  bool loading = false;
  bool joinedAlready = false;

  @override
  void initState() {
    super.initState();
    checkIfJoined();
  }

  Future<void> checkIfJoined() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final snap = await db
        .collection("tripParticipants")
        .where("tripId", isEqualTo: widget.tripId)
        .where("userId", isEqualTo: user.uid)
        .get();

    if (snap.docs.isNotEmpty) {
      setState(() => joinedAlready = true);
    }
  }

  Future<bool> _hasActiveOtherTrip(String uid) async {
    final parts = await db
        .collection("tripParticipants")
        .where("userId", isEqualTo: uid)
        .get();

    final now = DateTime.now();
    for (final p in parts.docs) {
      final tripId = p["tripId"];
      if (tripId == widget.tripId) continue;
      final tripDoc = await db.collection("trips").doc(tripId).get();
      if (!tripDoc.exists) continue;
      final data = tripDoc.data()!;
      final ts = data["dateTime"];
      if (ts == null) continue;
      DateTime dt;
      try {
        dt = ts.toDate();
      } catch (_) {
        continue;
      }
      if (dt.isAfter(now)) return true;
    }
    return false;
  }

  Future<void> handleJoin(Map<String, dynamic> trip) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => loading = true);

    try {
      if (await _hasActiveOtherTrip(user.uid)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You already have an active trip")),
        );
        setState(() => loading = false);
        return;
      }

      final userDoc = await db.collection("users").doc(user.uid).get();
      final u = userDoc.data() ?? {};

      final name = u["displayName"] ?? u["name"] ?? "User";
      final avatar = u["avatar"] ?? 0;

      await db.runTransaction((tx) async {
        final ref = db.collection("trips").doc(widget.tripId);
        final snap = await tx.get(ref);

        final data = snap.data()!;
        final joined = data["joined"] ?? 1;
        final max = data["maxPeople"] ?? 4;

        if (joined >= max) throw Exception("Trip full");
        tx.update(ref, {"joined": joined + 1});
      });

      await db.collection("tripParticipants").add({
        "tripId": widget.tripId,
        "userId": user.uid,
        "name": name,
        "avatar": avatar,
        "isHost": false,
        "createdAt": FieldValue.serverTimestamp(),
      });

      try {
        await db.collection("notifications").add({
          "userId": trip["ownerId"],
          "message": "$name joined your trip",
          "createdAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      setState(() => joinedAlready = true);
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  Future<void> deleteTrip() async {
    await db.collection("trips").doc(widget.tripId).delete();
    if (mounted) Navigator.pop(context);
  }

  String _reviewDocId(String reviewerId, String revieweeId) {
    return "${widget.tripId}_${reviewerId}_$revieweeId";
  }

  Future<void> _openReviewDialog({
    required String reviewerId,
    required String reviewerName,
    required String revieweeId,
    required String revieweeName,
  }) async {
    final docId = _reviewDocId(reviewerId, revieweeId);
    final existing = await db.collection("tripReviews").doc(docId).get();
    final existingData = existing.data();

    double rating = ((existingData?["rating"] ?? 5) as num).toDouble();
    final commentController = TextEditingController(
      text: (existingData?["comment"] ?? "") as String,
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Review $revieweeName"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Rating: ${rating.toStringAsFixed(0)}/5"),
                  Slider(
                    value: rating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: rating.toStringAsFixed(0),
                    onChanged: (v) => setDialogState(() => rating = v),
                  ),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "Write your feedback...",
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await db.collection("tripReviews").doc(docId).set({
                      "tripId": widget.tripId,
                      "reviewerId": reviewerId,
                      "reviewerName": reviewerName,
                      "revieweeId": revieweeId,
                      "revieweeName": revieweeName,
                      "rating": rating.toInt(),
                      "comment": commentController.text.trim(),
                      "createdAt": FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _participantsSection({
    required String ownerId,
    required bool allowReview,
    required String? currentUserId,
    required String ownerName,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection("tripParticipants")
          .where("tripId", isEqualTo: widget.tripId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox();
        }

        final docs = [...snap.data!.docs];
        docs.sort((a, b) {
          if (a["userId"] == ownerId) return -1;
          if (b["userId"] == ownerId) return 1;
          return 0;
        });

        String reviewerName = "User";
        if (currentUserId != null) {
          if (currentUserId == ownerId) {
            reviewerName = ownerName;
          }
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data["userId"] == currentUserId) {
              reviewerName = data["name"] ?? "User";
              break;
            }
          }
        }

        final canCurrentUserReview = currentUserId != null &&
            (currentUserId == ownerId ||
                docs.any((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data["userId"] == currentUserId;
                }));

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Participants",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...docs.map((p) {
                final data = p.data() as Map<String, dynamic>;
                final name = data["name"] ?? "User";
                final participantId = data["userId"] as String?;
                final isHost = participantId == ownerId;
                final showReviewButton = allowReview &&
                    canCurrentUserReview &&
                    participantId != null &&
                    participantId != currentUserId;

                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xffff7a00),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(name),
                  subtitle: isHost ? const Text("Host") : null,
                  trailing: showReviewButton
                      ? TextButton(
                          onPressed: () => _openReviewDialog(
                            reviewerId: currentUserId,
                            reviewerName: reviewerName,
                            revieweeId: participantId,
                            revieweeName: name,
                          ),
                          child: const Text("Review"),
                        )
                      : null,
                );
              })
            ],
          ),
        );
      },
    );
  }

  Widget _reviewsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection("tripReviews")
          .where("tripId", isEqualTo: widget.tripId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Reviews", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("No reviews yet"),
              ],
            ),
          );
        }

        final docs = [...snap.data!.docs];
        docs.sort((a, b) {
          final da = ((a.data() as Map<String, dynamic>)["createdAt"] as Timestamp?)
              ?.toDate();
          final dbb = ((b.data() as Map<String, dynamic>)["createdAt"] as Timestamp?)
              ?.toDate();
          if (da == null && dbb == null) return 0;
          if (da == null) return 1;
          if (dbb == null) return -1;
          return dbb.compareTo(da);
        });

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Reviews", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...docs.map((doc) {
                final r = doc.data() as Map<String, dynamic>;
                final reviewer = r["reviewerName"] ?? "User";
                final reviewee = r["revieweeName"] ?? "User";
                final rating = r["rating"] ?? 0;
                final comment = (r["comment"] ?? "").toString();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("$reviewer -> $reviewee"),
                  subtitle: comment.isEmpty ? null : Text(comment),
                  trailing: Text("$rating/5"),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection("trips").doc(widget.tripId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.data() == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final d = snap.data!.data() as Map<String, dynamic>;
        final isCreator = user != null && user.uid == d["ownerId"];

        final joined = d["joined"] ?? 1;
        final max = d["maxPeople"] ?? 4;
        final seatsLeft = max - joined;

        DateTime? dt;
        try {
          dt = d["dateTime"]?.toDate();
        } catch (_) {}

        final expired = dt != null ? DateTime.now().isAfter(dt) : false;
        final completed = d["completed"] == true;
        final allowReview = completed;
        final dateText = dt != null ? "${dt.day}/${dt.month}/${dt.year}" : "";
        final timeText = dt != null ? TimeOfDay.fromDateTime(dt).format(context) : "";

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final secondary = scheme.secondary;
        final bg = theme.scaffoldBackgroundColor;

        return Scaffold(
          backgroundColor: bg,
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
                color: bg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Row(
                      children: [
                        Text(
                          "WeGoVroom",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: secondary,
                          ),
                        ),
                        const Spacer(),
                        if (isCreator)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: deleteTrip,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      "${d["from"]} -> ${d["to"]}",
                      style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 16),
                    _card(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: theme.iconTheme.color,
                              ),
                              const SizedBox(width: 6),
                              Text(dateText),
                              const Spacer(),
                              Text(timeText),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.currency_rupee, color: Colors.green[700]),
                              Text("${d["cost"]}/person"),
                              const Spacer(),
                              Text(
                                "$joined/$max joined",
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.red[700]),
                              const SizedBox(width: 6),
                              Expanded(child: Text(d["meetingPoint"] ?? "")),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _participantsSection(
                      ownerId: d["ownerId"],
                      allowReview: allowReview,
                      currentUserId: user?.uid,
                      ownerName: d["ownerName"] ?? "Host",
                    ),
                    const SizedBox(height: 16),
                    _reviewsSection(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: (() {
            if (isCreator && !expired) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () async {
                      await db.collection("trips").doc(widget.tripId).update({
                        "dateTime": FieldValue.serverTimestamp(),
                        "completed": true,
                      });
                    },
                    child: const Text(
                      "Complete Trip",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }

            if (!isCreator && !expired) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: (loading || seatsLeft <= 0 || joinedAlready)
                        ? null
                        : () => handleJoin(d),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            joinedAlready ? "Joined" : "Join Trip",
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              );
            }

            return null;
          })(),
        );
      },
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black12)],
      ),
      child: child,
    );
  }
}
