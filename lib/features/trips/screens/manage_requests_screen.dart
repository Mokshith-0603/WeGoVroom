import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManageRequestsScreen extends StatelessWidget {
  final String tripId;

  const ManageRequestsScreen({super.key, required this.tripId});

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _userStats(String userId) async {
    final userDoc = await _db.collection("users").doc(userId).get();
    final userData = userDoc.data() ?? const <String, dynamic>{};

    final reviews = await _db
        .collection("tripReviews")
        .where("revieweeId", isEqualTo: userId)
        .get();
    var sum = 0.0;
    for (final doc in reviews.docs) {
      final rating = (doc.data()["rating"] as num?)?.toDouble() ?? 0.0;
      sum += rating;
    }
    final count = reviews.docs.length;
    final avg = count == 0 ? 0.0 : sum / count;

    return {
      "displayName": (userData["displayName"] ?? userData["name"] ?? "User")
          .toString(),
      "email": (userData["email"] ?? "").toString(),
      "gender": (userData["gender"] ?? "Not set").toString(),
      "avgRating": avg,
      "ratingCount": count,
      "avatar": userData["avatar"] ?? 0,
    };
  }

  Future<void> approve(BuildContext context, String requestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.runTransaction((tx) async {
        final reqRef = _db.collection("tripRequests").doc(requestId);
        final reqSnap = await tx.get(reqRef);
        if (!reqSnap.exists) throw Exception("Request not found");

        final req = reqSnap.data() ?? const <String, dynamic>{};
        if ((req["status"] ?? "pending") != "pending") {
          throw Exception("Request already processed");
        }

        final tripRef = _db.collection("trips").doc(tripId);
        final tripSnap = await tx.get(tripRef);
        if (!tripSnap.exists) throw Exception("Trip not found");

        final trip = tripSnap.data() ?? const <String, dynamic>{};
        final ownerId = (trip["ownerId"] ?? "").toString();
        if (ownerId != uid) throw Exception("Only host can approve");
        if (trip["completed"] == true)
          throw Exception("Trip already completed");

        final joined = (trip["joined"] as num?)?.toInt() ?? 1;
        final maxPeople = (trip["maxPeople"] as num?)?.toInt() ?? 4;
        if (joined >= maxPeople) throw Exception("Trip is full");

        final reqUserId = (req["userId"] ?? "").toString();
        if (reqUserId.isEmpty) throw Exception("Invalid requester");

        final existingPart = await _db
            .collection("tripParticipants")
            .where("tripId", isEqualTo: tripId)
            .where("userId", isEqualTo: reqUserId)
            .limit(1)
            .get();
        if (existingPart.docs.isNotEmpty) {
          tx.update(reqRef, {
            "status": "approved",
            "decidedAt": FieldValue.serverTimestamp(),
            "decidedBy": uid,
          });
          return;
        }

        final participantRef = _db.collection("tripParticipants").doc();
        tx.set(participantRef, {
          "tripId": tripId,
          "userId": reqUserId,
          "name": (req["name"] ?? "User").toString(),
          "avatar": req["avatar"] ?? 0,
          "isHost": false,
          "createdAt": FieldValue.serverTimestamp(),
        });

        tx.update(tripRef, {"joined": FieldValue.increment(1)});
        tx.update(reqRef, {
          "status": "approved",
          "decidedAt": FieldValue.serverTimestamp(),
          "decidedBy": uid,
        });
      });

      final reqDoc = await _db.collection("tripRequests").doc(requestId).get();
      final req = reqDoc.data() ?? const <String, dynamic>{};
      final reqUserId = (req["userId"] ?? "").toString();
      if (reqUserId.isNotEmpty) {
        try {
          await _db.collection("notifications").add({
            "userId": reqUserId,
            "message": "Your request to join this trip was approved",
            "type": "trip_request_approved",
            "tripId": tripId,
            "actorId": uid,
            "actorName": "Host",
            "createdAt": FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Request approved")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Approve failed: $e")));
      }
    }
  }

  Future<void> reject(BuildContext context, String requestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final reqRef = _db.collection("tripRequests").doc(requestId);
      final reqDoc = await reqRef.get();
      final data = reqDoc.data() ?? const <String, dynamic>{};
      final userId = (data["userId"] ?? "").toString();

      await reqRef.update({
        "status": "rejected",
        "decidedAt": FieldValue.serverTimestamp(),
        "decidedBy": uid,
      });

      if (userId.isNotEmpty) {
        try {
          await _db.collection("notifications").add({
            "userId": userId,
            "message": "Your request to join this trip was rejected",
            "type": "trip_request_rejected",
            "tripId": tripId,
            "actorId": uid,
            "actorName": "Host",
            "createdAt": FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Request rejected")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Reject failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Join Requests")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection("tripRequests")
            .where("tripId", isEqualTo: tripId)
            .where("status", isEqualTo: "pending")
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No pending requests"));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final reqDoc = docs[i];
              final req = reqDoc.data() as Map<String, dynamic>;
              final userId = (req["userId"] ?? "").toString();
              final fallbackName = (req["name"] ?? "User").toString();
              final fallbackEmail = (req["email"] ?? "").toString();

              return FutureBuilder<Map<String, dynamic>>(
                future: _userStats(userId),
                builder: (_, userSnap) {
                  final info = userSnap.data ?? const <String, dynamic>{};
                  final name = (info["displayName"] ?? fallbackName).toString();
                  final email = (info["email"] ?? fallbackEmail).toString();
                  final gender = (info["gender"] ?? "Not set").toString();
                  final avgRating = (info["avgRating"] as double?) ?? 0.0;
                  final ratingCount = (info["ratingCount"] as int?) ?? 0;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(blurRadius: 8, color: Colors.black12),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xffff7a00),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(email.isEmpty ? "No email" : email),
                        ),
                        const SizedBox(height: 6),
                        Text("Gender: $gender"),
                        const SizedBox(height: 4),
                        Text(
                          ratingCount == 0
                              ? "Reviews: No reviews yet"
                              : "Reviews: ${avgRating.toStringAsFixed(1)}/5 ($ratingCount)",
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => reject(context, reqDoc.id),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text("Reject"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => approve(context, reqDoc.id),
                                child: const Text("Accept"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
