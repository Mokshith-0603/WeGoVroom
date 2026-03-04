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
  final List<int> _maxPeopleOptions = [2, 3, 4, 5, 6];

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

    final isPublicTrip = trip["isPublic"] != false;
    final invitedIds = ((trip["invitedUserIds"] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    final invitedEmails = ((trip["invitedUserEmails"] as List?) ?? const [])
        .map((e) => e.toString().trim().toLowerCase())
        .toSet();
    final ownerId = trip["ownerId"]?.toString();
    final isInvited = invitedIds.contains(user.uid);
    final isEmailInvited = (user.email != null) &&
        invitedEmails.contains(user.email!.trim().toLowerCase());
    final canJoinPrivate = isPublicTrip || user.uid == ownerId || isInvited || isEmailInvited;
    if (!canJoinPrivate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This is a private trip. You are not invited.")),
      );
      return;
    }

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
          "type": "trip_joined",
          "tripId": widget.tripId,
          "actorId": user.uid,
          "actorName": name,
          "createdAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      setState(() => joinedAlready = true);
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  Future<void> _openLeaveTripDialog(Map<String, dynamic> trip) async {
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Leave Trip"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Please tell why you want to leave this trip."),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Your reason",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text("Please provide a reason to leave")),
                  );
                  return;
                }

                Navigator.pop(dialogContext);
                await _leaveTrip(trip, reason);
              },
              child: const Text("Leave"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _leaveTrip(Map<String, dynamic> trip, String reason) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => loading = true);
    try {
      final participantSnap = await db
          .collection("tripParticipants")
          .where("tripId", isEqualTo: widget.tripId)
          .where("userId", isEqualTo: user.uid)
          .limit(1)
          .get();

      if (participantSnap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You are not part of this trip")),
          );
        }
        setState(() => loading = false);
        return;
      }

      final participantDoc = participantSnap.docs.first;
      final participantData = participantDoc.data();
      final userName = (participantData["name"] ?? "User").toString();

      await db.runTransaction((tx) async {
        final tripRef = db.collection("trips").doc(widget.tripId);
        final tripSnap = await tx.get(tripRef);
        final tripData = tripSnap.data() ?? const <String, dynamic>{};
        final joined = (tripData["joined"] as num?)?.toInt() ?? 1;
        final nextJoined = (joined - 1) < 1 ? 1 : (joined - 1);

        tx.delete(participantDoc.reference);
        tx.update(tripRef, {"joined": nextJoined});
      });

      try {
        await db.collection("tripLeaveLogs").add({
          "tripId": widget.tripId,
          "userId": user.uid,
          "userName": userName,
          "reason": reason,
          "leftAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      try {
        // Visible to host/participants via regular chat stream.
        await db.collection("tripMessages").add({
          "tripId": widget.tripId,
          "senderId": user.uid,
          "senderName": userName,
          "senderAvatar": participantData["avatar"] ?? 0,
          "text": "$userName left the trip. Reason: $reason",
          "createdAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      try {
        await db.collection("notifications").add({
          "userId": trip["ownerId"],
          "message": "$userName left your trip. Reason: $reason",
          "type": "trip_left",
          "tripId": widget.tripId,
          "actorId": user.uid,
          "actorName": userName,
          "createdAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (mounted) {
        setState(() => joinedAlready = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You have left the trip")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to leave trip: $e")),
        );
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> deleteTrip() async {
    await db.collection("trips").doc(widget.tripId).delete();
    if (mounted) Navigator.pop(context);
  }

  DateTime? _parseTripDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Future<void> _openEditTripDialog(Map<String, dynamic> trip) async {
    final fromController = TextEditingController(text: (trip["from"] ?? "").toString());
    final toController = TextEditingController(text: (trip["to"] ?? "").toString());
    final meetingController =
        TextEditingController(text: (trip["meetingPoint"] ?? "").toString());
    final costController = TextEditingController(text: (trip["cost"] ?? 0).toString());
    final descController =
        TextEditingController(text: (trip["description"] ?? "").toString());

    final joined = (trip["joined"] as num?)?.toInt() ?? 1;
    final currentMax = (trip["maxPeople"] as num?)?.toInt() ?? 4;
    int maxPeople = _maxPeopleOptions.contains(currentMax) ? currentMax : 4;
    if (maxPeople < joined) {
      maxPeople = joined > 6 ? 6 : joined;
    }

    DateTime? selectedDateTime = _parseTripDateTime(trip["dateTime"]);
    DateTime? selectedDate = selectedDateTime;
    TimeOfDay? selectedTime =
        selectedDateTime != null ? TimeOfDay.fromDateTime(selectedDateTime) : null;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Trip"),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: fromController,
                        decoration: const InputDecoration(labelText: "Departure point"),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: toController,
                        decoration: const InputDecoration(labelText: "Destination"),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: meetingController,
                        decoration: const InputDecoration(labelText: "Meeting point"),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2100),
                                  initialDate: selectedDate ?? DateTime.now(),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                              child: Text(
                                selectedDate == null
                                    ? "Select date"
                                    : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: dialogContext,
                                  initialTime: selectedTime ?? TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedTime = picked);
                                }
                              },
                              child: Text(
                                selectedTime == null
                                    ? "Select time"
                                    : selectedTime!.format(dialogContext),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: maxPeople,
                        items: _maxPeopleOptions
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text("$e people"),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() => maxPeople = v);
                        },
                        decoration: const InputDecoration(labelText: "Max people"),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Cost per person"),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: "Description"),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final from = fromController.text.trim();
                    final to = toController.text.trim();
                    final meetingPoint = meetingController.text.trim();
                    final cost = int.tryParse(costController.text.trim()) ?? 0;

                    if (from.isEmpty || to.isEmpty || selectedDate == null || selectedTime == null) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text("Fill required fields")),
                      );
                      return;
                    }

                    if (maxPeople < joined) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text("Max people cannot be less than $joined")),
                      );
                      return;
                    }

                    final updatedDateTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );

                    await db.collection("trips").doc(widget.tripId).update({
                      "from": from,
                      "to": to,
                      "meetingPoint": meetingPoint,
                      "dateTime": updatedDateTime,
                      "maxPeople": maxPeople,
                      "cost": cost,
                      "description": descController.text.trim(),
                    });

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
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

  Map<String, dynamic> _reviewSummaryFromDocs(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return {
        "count": 0,
        "avg": 0.0,
      };
    }

    double total = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += ((data["rating"] ?? 0) as num).toDouble();
    }

    return {
      "count": docs.length,
      "avg": total / docs.length,
    };
  }

  Future<void> _openUserReviewsBottomSheet({
    required String revieweeId,
    required String revieweeName,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection("tripReviews")
                  .where("revieweeId", isEqualTo: revieweeId)
                  .snapshots(),
              builder: (_, snap) {
                final docs = List<QueryDocumentSnapshot>.from(
                  snap.data?.docs ?? const [],
                );
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

                final summary = _reviewSummaryFromDocs(docs);
                final reviewCount = summary["count"] as int;
                final avgRating = (summary["avg"] as double);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Text(
                        "$revieweeName Reviews",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        reviewCount == 0
                            ? "No reviews yet"
                            : "${avgRating.toStringAsFixed(1)}/5 from $reviewCount reviews",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: reviewCount == 0
                          ? const Center(child: Text("No reviews yet"))
                          : ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (_, i) {
                                final review = docs[i].data() as Map<String, dynamic>;
                                final reviewer = review["reviewerName"] ?? "User";
                                final rating = review["rating"] ?? 0;
                                final comment = (review["comment"] ?? "").toString();

                                return ListTile(
                                  title: Text("$reviewer - $rating/5"),
                                  subtitle: comment.isEmpty ? null : Text(comment),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
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
                  onTap: participantId == null
                      ? null
                      : () => _openUserReviewsBottomSheet(
                            revieweeId: participantId,
                            revieweeName: name,
                          ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xffff7a00),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isHost) const Text("Host"),
                      if (participantId != null)
                        StreamBuilder<QuerySnapshot>(
                          stream: db
                              .collection("tripReviews")
                              .where("revieweeId", isEqualTo: participantId)
                              .snapshots(),
                          builder: (_, reviewSnap) {
                            final summary = _reviewSummaryFromDocs(
                              List<QueryDocumentSnapshot>.from(
                                reviewSnap.data?.docs ?? const [],
                              ),
                            );
                            final reviewCount = summary["count"] as int;
                            final avgRating = (summary["avg"] as double);

                            if (reviewCount == 0) {
                              return Text(
                                "No reviews yet",
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              );
                            }

                            return Text(
                              "${avgRating.toStringAsFixed(1)}/5 from $reviewCount reviews",
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                            );
                          },
                        ),
                    ],
                  ),
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
                      : const Text("View"),
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
              const SizedBox(height: 4),
              Text(
                "Trip reviews (for this trip)",
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
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
        final isPublicTrip = d["isPublic"] != false;
        final invitedIds = ((d["invitedUserIds"] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet();
        final invitedEmails = ((d["invitedUserEmails"] as List?) ?? const [])
            .map((e) => e.toString().trim().toLowerCase())
            .toSet();
        final isEmailInvited = user?.email != null &&
            invitedEmails.contains(user!.email!.trim().toLowerCase());
        final canJoinByInvite = user != null &&
            (isPublicTrip ||
                user.uid == d["ownerId"] ||
                invitedIds.contains(user.uid) ||
                isEmailInvited);
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
                        if (isCreator && !completed && !expired)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xffff7a00)),
                            onPressed: () => _openEditTripDialog(d),
                          ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          if ((d["description"] ?? "").toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              "Description",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text((d["description"] ?? "").toString()),
                          ],
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
                  child: joinedAlready
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: loading ? null : () => _openLeaveTripDialog(d),
                          child: loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "Leave Trip",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: (loading || seatsLeft <= 0 || !canJoinByInvite)
                              ? null
                              : () => handleJoin(d),
                          child: loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  canJoinByInvite ? "Join Trip" : "Invite Only",
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

