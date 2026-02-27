import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TripRequestsScreen extends StatelessWidget {
  final String tripId;

  const TripRequestsScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Join Requests")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("tripRequests")
            .where("tripId", isEqualTo: tripId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No requests"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final req = docs[i];

              return ListTile(
                title: Text(req["userId"]),
                subtitle: Text(req["status"]),
              );
            },
          );
        },
      ),
    );
  }
}