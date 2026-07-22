import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../../services/trip_link_service.dart';
import '../../../theme/app_theme.dart';
import '../../profile/widgets/avatar_utils.dart';
import 'manage_requests_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> data;

  const TripDetailScreen({super.key, required this.tripId, required this.data});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final db = FirebaseFirestore.instance;
  final List<int> _maxPeopleOptions = [2, 3, 4, 5, 6];

  bool loading = false;
  bool joinedAlready = false;
  bool hasPendingRequest = false;
  String? pendingRequestId;

  Future<void> _shareTrip(
    Map<String, dynamic> trip, {
    bool whatsappOnly = false,
  }) async {
    try {
      if (whatsappOnly) {
        final opened = await TripLinkService.instance.shareTripToWhatsApp(
          tripId: widget.tripId,
          trip: trip,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not open WhatsApp")),
          );
        }
        return;
      }

      await TripLinkService.instance.shareTrip(
        tripId: widget.tripId,
        trip: trip,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not share trip link")),
      );
    }
  }

  Widget _buildParticipantTile({
    required QueryDocumentSnapshot p,
    required String ownerId,
    required String? currentUserId,
    required bool allowReview,
    required bool allowHostRemove,
    required bool canCurrentUserReview,
    required bool loading,
    required String reviewerName,
    required Map<String, dynamic> tripData,
  }) {
    final data = p.data() as Map<String, dynamic>;
    final participantId = data["userId"] as String?;
    final isHost = participantId == ownerId;
    final showReviewButton =
        allowReview &&
        canCurrentUserReview &&
        participantId != null &&
        participantId != currentUserId;
    final canRemove =
        allowHostRemove && participantId != null && participantId != ownerId;

    if (participantId == null) {
      return ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xffff7a00),
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(data["name"] ?? "User"),
      );
    }

    final profile = context.watch<UserProfileProvider>().getUserProfile(
      participantId,
    );
    final displayName =
        (profile?["displayName"] ?? profile?["name"] ?? data["name"] ?? "User")
            .toString();
    final avatarIdx = normalizeAvatarIndex(
      profile?["avatar"] ?? data["avatar"],
    );
    final gender = (profile?["gender"] ?? "Not set").toString();

    return ListTile(
      onTap: () => _openUserReviewsBottomSheet(
        revieweeId: participantId,
        revieweeName: displayName,
      ),
      leading: CircleAvatar(
        backgroundColor: const Color(0xffff7a00),
        child: buildAvatar(avatarIdx, radius: 20),
      ),
      title: Text(displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHost) const Text("Host"),
          if (gender.isNotEmpty && gender != "Not set")
            Text(
              "Gender: $gender",
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canRemove)
            IconButton(
              tooltip: "Remove user",
              icon: const Icon(Icons.person_remove, color: Colors.red),
              onPressed: loading
                  ? null
                  : () => _openRemoveParticipantDialog(
                      participantRef: p.reference,
                      participantUserId: participantId,
                      participantName: displayName,
                      trip: tripData,
                    ),
            ),
          showReviewButton
              ? TextButton(
                  onPressed: () => _openReviewDialog(
                    reviewerId: currentUserId!,
                    reviewerName: reviewerName,
                    revieweeId: participantId,
                    revieweeName: displayName,
                  ),
                  child: const Text("Review"),
                )
              : const Text("View"),
        ],
      ),
    );
  }

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
      setState(() {
        joinedAlready = true;
        hasPendingRequest = false;
        pendingRequestId = null;
      });
    }

    final pendingSnap = await db
        .collection("tripRequests")
        .where("tripId", isEqualTo: widget.tripId)
        .where("userId", isEqualTo: user.uid)
        .where("status", isEqualTo: "pending")
        .limit(1)
        .get();

    if (pendingSnap.docs.isNotEmpty) {
      setState(() {
        hasPendingRequest = true;
        pendingRequestId = pendingSnap.docs.first.id;
      });
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
      final completed = data["completed"] == true;
      if (!completed && now.isBefore(dt.add(const Duration(hours: 12))))
        return true;
    }
    return false;
  }

  Future<void> handleJoin(Map<String, dynamic> trip) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    DateTime? tripStart;
    try {
      tripStart = (trip["dateTime"] as Timestamp?)?.toDate();
    } catch (_) {}
    if (tripStart != null && !DateTime.now().isBefore(tripStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Join time has ended for this trip")),
      );
      return;
    }

    final isPublicTrip = trip["isPublic"] != false;
    if (!isPublicTrip) {
      if (hasPendingRequest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Join request already sent")),
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

        final existingReqSnap = await db
            .collection("tripRequests")
            .where("tripId", isEqualTo: widget.tripId)
            .where("userId", isEqualTo: user.uid)
            .where("status", isEqualTo: "pending")
            .limit(1)
            .get();

        if (existingReqSnap.docs.isNotEmpty) {
          if (mounted) {
            setState(() {
              hasPendingRequest = true;
              pendingRequestId = existingReqSnap.docs.first.id;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Join request already sent")),
            );
          }
          return;
        }

        final userDoc = await db.collection("users").doc(user.uid).get();
        final u = userDoc.data() ?? const <String, dynamic>{};
        final name = (u["displayName"] ?? u["name"] ?? "User").toString();
        final avatar = (u["avatar"] ?? 0) as Object;
        final email = (user.email ?? "").trim().toLowerCase();

        final reqRef = await db.collection("tripRequests").add({
          "tripId": widget.tripId,
          "hostId": trip["ownerId"],
          "ownerId": trip["ownerId"],
          "userId": user.uid,
          "name": name,
          "avatar": avatar,
          "email": email,
          "status": "pending",
          "createdAt": FieldValue.serverTimestamp(),
        });

        try {
          await db.collection("notifications").add({
            "userId": trip["ownerId"],
            "message": "$name requested to join your trip",
            "type": "trip_request",
            "tripId": widget.tripId,
            "actorId": user.uid,
            "actorName": name,
            "isRead": false,
            "createdAt": FieldValue.serverTimestamp(),
          });
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          hasPendingRequest = true;
          pendingRequestId = reqRef.id;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Request sent to host")));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Failed to send request: $e")));
        }
      } finally {
        if (mounted) setState(() => loading = false);
      }
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
        final participantRef = db
            .collection("tripParticipants")
            .doc("${widget.tripId}_${user.uid}");
        final snap = await tx.get(ref);
        final participantSnap = await tx.get(participantRef);

        final data = snap.data()!;
        DateTime? startTime;
        try {
          startTime = (data["dateTime"] as Timestamp?)?.toDate();
        } catch (_) {}
        if (startTime != null && !DateTime.now().isBefore(startTime)) {
          throw Exception("Join time ended");
        }
        if (data["completed"] == true) {
          throw Exception("Trip already completed");
        }
        if (participantSnap.exists) {
          return;
        }
        final joined = data["joined"] ?? 1;
        final max = data["maxPeople"] ?? 4;

        if (joined >= max) throw Exception("Trip full");
        tx.set(participantRef, {
          "tripId": widget.tripId,
          "userId": user.uid,
          "name": name,
          "avatar": avatar,
          "isHost": false,
          "createdAt": FieldValue.serverTimestamp(),
        });
      });

      try {
        await db.collection("notifications").add({
          "userId": trip["ownerId"],
          "message": "$name joined your trip",
          "type": "trip_joined",
          "tripId": widget.tripId,
          "actorId": user.uid,
          "actorName": name,
          "isRead": false,
          "createdAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      setState(() {
        joinedAlready = true;
        hasPendingRequest = false;
        pendingRequestId = null;
      });
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to join trip: $e")));
      }
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
                    const SnackBar(
                      content: Text("Please provide a reason to leave"),
                    ),
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

      await participantDoc.reference.delete();

      try {
        await db.collection("notifications").add({
          "userId": trip["ownerId"],
          "message": "$userName left your trip. Reason: $reason",
          "type": "trip_left",
          "tripId": widget.tripId,
          "actorId": user.uid,
          "actorName": userName,
          "isRead": false,
          "createdAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (mounted) {
        setState(() => joinedAlready = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("You have left the trip")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to leave trip: $e")));
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _openRemoveParticipantDialog({
    required DocumentReference participantRef,
    required String participantUserId,
    required String participantName,
    required Map<String, dynamic> trip,
  }) async {
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Remove $participantName"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Please provide a reason for removing this participant.",
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Reason",
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
                    const SnackBar(content: Text("Reason is required")),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                await _removeParticipant(
                  participantRef: participantRef,
                  participantUserId: participantUserId,
                  participantName: participantName,
                  trip: trip,
                  reason: reason,
                );
              },
              child: const Text("Remove"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeParticipant({
    required DocumentReference participantRef,
    required String participantUserId,
    required String participantName,
    required Map<String, dynamic> trip,
    required String reason,
  }) async {
    setState(() => loading = true);
    try {
      await participantRef.delete();

      try {
        await db.collection("tripKickLogs").add({
          "tripId": widget.tripId,
          "userId": participantUserId,
          "userName": participantName,
          "reason": reason,
          "removedAt": FieldValue.serverTimestamp(),
          "removedBy": context.read<AuthProvider>().user?.uid,
        });
      } catch (_) {}

      try {
        final actorName = trip["ownerName"]?.toString() ?? "Host";
        await db.collection("notifications").add({
          "userId": participantUserId,
          "message":
              "You were removed from trip by $actorName. Reason: $reason",
          "type": "trip_removed",
          "tripId": widget.tripId,
          "actorId": context.read<AuthProvider>().user?.uid,
          "actorName": actorName,
          "isRead": false,
          "createdAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Participant removed")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to remove participant: $e")),
        );
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> deleteTrip() async {
    final user = context.read<AuthProvider>().user;
    final ownerId = (widget.data["ownerId"] ?? "").toString();
    final isAdmin = context.read<AuthProvider>().isAdminEmail(user?.email);
    final canDeleteTrip = user != null && (user.uid == ownerId || isAdmin);

    if (!canDeleteTrip) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You cannot delete this trip")),
        );
      }
      return;
    }

    try {
      await db.collection("trips").doc(widget.tripId).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to delete trip: $e")));
      }
    }
  }

  DateTime? _parseTripDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Future<void> _openEditTripDialog(Map<String, dynamic> trip) async {
    final fromController = TextEditingController(
      text: (trip["from"] ?? "").toString(),
    );
    final toController = TextEditingController(
      text: (trip["to"] ?? "").toString(),
    );
    final meetingController = TextEditingController(
      text: (trip["meetingPoint"] ?? "").toString(),
    );
    final costController = TextEditingController(
      text: (trip["cost"] ?? 0).toString(),
    );
    final descController = TextEditingController(
      text: (trip["description"] ?? "").toString(),
    );

    final joined = (trip["joined"] as num?)?.toInt() ?? 1;
    final currentMax = (trip["maxPeople"] as num?)?.toInt() ?? 4;
    int maxPeople = _maxPeopleOptions.contains(currentMax) ? currentMax : 4;
    if (maxPeople < joined) {
      maxPeople = joined > 6 ? 6 : joined;
    }

    DateTime? selectedDateTime = _parseTripDateTime(trip["dateTime"]);
    DateTime? selectedDate = selectedDateTime;
    TimeOfDay? selectedTime = selectedDateTime != null
        ? TimeOfDay.fromDateTime(selectedDateTime)
        : null;

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
                        decoration: const InputDecoration(
                          labelText: "Departure point",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: toController,
                        decoration: const InputDecoration(
                          labelText: "Destination",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: meetingController,
                        decoration: const InputDecoration(
                          labelText: "Meeting point",
                        ),
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
                        decoration: const InputDecoration(
                          labelText: "Max people",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Cost per person",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Description",
                        ),
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

                    if (from.isEmpty ||
                        to.isEmpty ||
                        selectedDate == null ||
                        selectedTime == null) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text("Fill required fields")),
                      );
                      return;
                    }

                    if (maxPeople < joined) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Max people cannot be less than $joined",
                          ),
                        ),
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

  Map<String, dynamic> _reviewSummaryFromDocs(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (docs.isEmpty) {
      return {"count": 0, "avg": 0.0};
    }

    double total = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += ((data["rating"] ?? 0) as num).toDouble();
    }

    return {"count": docs.length, "avg": total / docs.length};
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
                  final da =
                      ((a.data() as Map<String, dynamic>)["createdAt"]
                              as Timestamp?)
                          ?.toDate();
                  final dbb =
                      ((b.data() as Map<String, dynamic>)["createdAt"]
                              as Timestamp?)
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
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
                                final review =
                                    docs[i].data() as Map<String, dynamic>;
                                final reviewer =
                                    review["reviewerName"] ?? "User";
                                final rating = review["rating"] ?? 0;
                                final comment = (review["comment"] ?? "")
                                    .toString();

                                return ListTile(
                                  title: Text("$reviewer - $rating/5"),
                                  subtitle: comment.isEmpty
                                      ? null
                                      : Text(comment),
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
    required bool allowHostRemove,
    required Map<String, dynamic> tripData,
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

        final profileProvider = context.read<UserProfileProvider>();
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final participantId = data["userId"]?.toString() ?? "";
          if (participantId.isNotEmpty) {
            profileProvider.listenToUserProfile(participantId);
          }
        }

        String reviewerName = "User";
        if (currentUserId != null) {
          if (currentUserId == ownerId) {
            reviewerName = ownerName;
          }
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data["userId"] == currentUserId) {
              final liveProfile = profileProvider.getUserProfile(currentUserId);
              reviewerName =
                  (liveProfile?["displayName"] ??
                          liveProfile?["name"] ??
                          data["name"] ??
                          "User")
                      .toString();
              break;
            }
          }
        }

        final canCurrentUserReview =
            currentUserId != null &&
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
                return _buildParticipantTile(
                  p: p,
                  ownerId: ownerId,
                  currentUserId: currentUserId,
                  allowReview: allowReview,
                  allowHostRemove: allowHostRemove,
                  canCurrentUserReview: canCurrentUserReview,
                  loading: loading,
                  reviewerName: reviewerName,
                  tripData: tripData,
                );
              }),
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
          final da =
              ((a.data() as Map<String, dynamic>)["createdAt"] as Timestamp?)
                  ?.toDate();
          final dbb =
              ((b.data() as Map<String, dynamic>)["createdAt"] as Timestamp?)
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
              const Text(
                "Reviews",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
        final auth = context.read<AuthProvider>();
        final isCreator = user != null && user.uid == d["ownerId"];
        final isAdmin = auth.isAdminEmail(user?.email);
        final canDeleteTrip = isCreator || isAdmin;

        final joined = d["joined"] ?? 1;
        final max = d["maxPeople"] ?? 4;
        final seatsLeft = max - joined;

        DateTime? dt;
        try {
          dt = d["dateTime"]?.toDate();
        } catch (_) {}

        final autoEnded = dt != null
            ? !DateTime.now().isBefore(dt.add(const Duration(hours: 12)))
            : false;
        final completed = d["completed"] == true;
        final tripEnded = completed || autoEnded;
        final joinWindowClosed = dt != null
            ? !DateTime.now().isBefore(dt)
            : false;
        final isPublicTrip = d["isPublic"] != false;
        final allowReview = tripEnded;
        final dateText = dt != null ? "${dt.day}/${dt.month}/${dt.year}" : "";
        final timeText = dt != null
            ? TimeOfDay.fromDateTime(dt).format(context)
            : "";

        final theme = Theme.of(context);
        final secondary = AppTheme.brandOrange;
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF070D12), Color(0xFF0D1013)]
                    : const [Color(0xFFFFFEFC), Color(0xFFF8F5F0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 120),
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.ios_share_rounded,
                                color: AppTheme.brandOrange,
                              ),
                              tooltip: "Share trip link",
                              onPressed: () => _shareTrip(d),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.chat_rounded,
                                color: Color(0xFF25D366),
                              ),
                              tooltip: "Share on WhatsApp",
                              onPressed: () => _shareTrip(
                                d,
                                whatsappOnly: true,
                              ),
                            ),
                            if (isCreator && !tripEnded)
                              IconButton(
                                icon: const Icon(
                                  Icons.group_add,
                                  color: AppTheme.brandOrange,
                                ),
                                tooltip: "Manage requests",
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ManageRequestsScreen(
                                        tripId: widget.tripId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            if (isCreator && !tripEnded)
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: AppTheme.brandOrange,
                                ),
                                onPressed: () => _openEditTripDialog(d),
                              ),
                            if (canDeleteTrip)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: deleteTrip,
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        RichText(
                          text: TextSpan(
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                            children: const [
                              TextSpan(
                                text: "WeGo",
                                style: TextStyle(color: AppTheme.brandOrange),
                              ),
                              TextSpan(text: "Vroom"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "${d["from"]} → ${d["to"]}",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 27,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _tripHero(context),
                        const SizedBox(height: 20),
                        _card(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: _infoItem(Icons.calendar_today, dateText)),
                            Expanded(child: _infoItem(Icons.schedule, timeText)),
                          ]),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: _infoItem(
                                isPublicTrip ? Icons.public : Icons.lock_outline,
                                isPublicTrip ? "Public trip" : "Private trip",
                              ),
                            ),
                            Expanded(
                              child: _infoItem(
                                Icons.currency_rupee,
                                "${d["cost"]}/person",
                                color: Colors.green,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 14),
                          _infoItem(
                            Icons.groups_rounded,
                            "$joined / $max joined",
                            color: Colors.green,
                          ),
                          const Divider(height: 28),
                          _infoItem(
                            Icons.location_on,
                            (d["meetingPoint"] ?? "").toString(),
                            subtitle: "Pickup point",
                            color: Colors.redAccent,
                          ),
                          if ((d["description"] ?? "")
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
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
                    const SizedBox(height: 18),
                    if (isCreator && !tripEnded)
                      _disclaimerCard(
                        context,
                        "If you don't complete this trip manually, it will be completed automatically 12 hours after the selected trip time.",
                      ),
                    if (autoEnded && !completed) ...[
                      const SizedBox(height: 18),
                      _disclaimerCard(
                        context,
                        "This trip has reached 12 hours after the selected time and is treated as completed.",
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (isCreator && !isPublicTrip && !tripEnded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ManageRequestsScreen(
                                    tripId: widget.tripId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_search),
                            label: const Text("Manage Join Requests"),
                          ),
                        ),
                      ),
                    _participantsSection(
                      ownerId: d["ownerId"],
                      allowReview: allowReview,
                      currentUserId: user?.uid,
                      ownerName: d["ownerName"] ?? "Host",
                      allowHostRemove: isCreator && !tripEnded,
                      tripData: d,
                    ),
                    const SizedBox(height: 18),
                    _reviewsSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: (() {
            Widget wrap(Widget child) {
              return Container(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1013) : const Color(0xFFFFFEFC),
                ),
                child: SizedBox(height: 58, child: child),
              );
            }

            final buttonShape = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            );

            if (isCreator && !tripEnded) {
              return wrap(
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondary,
                    foregroundColor: Colors.white,
                    shape: buttonShape,
                  ),
                  onPressed: () async {
                    await db.collection("trips").doc(widget.tripId).update({
                      "completed": true,
                      "completedAt": FieldValue.serverTimestamp(),
                    });
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Complete Trip",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.check_circle_outline),
                    ],
                  ),
                ),
              );
            }

            if (!isCreator && !tripEnded) {
              final canJoinAction = isPublicTrip
                  ? !loading && seatsLeft > 0 && !joinWindowClosed
                  : !loading && !joinWindowClosed && !hasPendingRequest;
              return wrap(
                joinedAlready
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[300],
                          foregroundColor: Colors.white,
                          shape: buttonShape,
                        ),
                        onPressed: loading ? null : () => _openLeaveTripDialog(d),
                        child: loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "Leave Trip",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondary,
                          foregroundColor: Colors.white,
                          shape: buttonShape,
                        ),
                        onPressed: canJoinAction ? () => handleJoin(d) : null,
                        child: loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                joinWindowClosed
                                    ? "Join Closed"
                                    : (isPublicTrip
                                          ? "Join Trip"
                                          : (hasPendingRequest
                                                ? "Request Sent"
                                                : "Request to Join")),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
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

  Widget _tripHero(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF101B25), Color(0xFF151719)]
              : const [Color(0xFFFFF1E4), Color(0xFFFFFBF7)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            child: Icon(
              Icons.location_on,
              color: AppTheme.brandOrange,
              size: 44,
            ),
          ),
          Positioned(
            right: 22,
            child: Icon(
              Icons.location_on,
              color: Colors.indigoAccent,
              size: 44,
            ),
          ),
          Icon(
            Icons.route_rounded,
            color: AppTheme.brandOrange.withValues(alpha: 0.24),
            size: 118,
          ),
          Icon(
            Icons.directions_bus_rounded,
            color: AppTheme.brandOrange,
            size: 66,
          ),
        ],
      ),
    );
  }

  Widget _infoItem(
    IconData icon,
    String text, {
    String? subtitle,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.72);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: tint, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _disclaimerCard(BuildContext context, String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.08 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.brandOrange.withValues(alpha: isDark ? 0.28 : 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.brandOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: "Disclaimer:\n",
                    style: TextStyle(
                      color: AppTheme.brandOrange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: message),
                ],
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101B25) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : const Color(0xFFEAE5DE),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
