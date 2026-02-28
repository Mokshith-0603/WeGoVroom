import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageRequestsScreen extends StatelessWidget {
  final String tripId;

  const ManageRequestsScreen({super.key, required this.tripId});

  Future<void> approve(String requestId) async {
    final db = FirebaseFirestore.instance;

    final req =
        await db.collection("tripRequests").doc(requestId).get();

    final data = req.data()!;

    // create participant entry
    await db.collection("tripParticipants").add({
      "tripId": data["tripId"],
      "userId": data["userId"],
    });

    // bump joined count
    await db.collection("trips").doc(tripId).update({
      "joined": FieldValue.increment(1),
    });

    // mark request approved
    await req.reference.update({"status": "approved"});

    // notify participant (non-blocking if caller has no notifications permission)
    try {
      await db.collection('notifications').add({
        'userId': data['userId'],
        'message': 'Your request to join this trip was approved',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> reject(String requestId) async {
    final db = FirebaseFirestore.instance;

    final req =
        await db.collection("tripRequests").doc(requestId).get();

    final data = req.data()!;

    await req.reference.update({"status": "rejected"});

    try {
      await db.collection('notifications').add({
        'userId': data['userId'],
        'message': 'Your request to join this trip was rejected',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Requests")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
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
            return const Center(child: Text("No requests"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final r = docs[i];

              return ListTile(
                title: Text(r["userId"]),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => approve(r.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => reject(r.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
