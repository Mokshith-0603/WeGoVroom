import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> tripsStream() {
    return _db
        .collection("trips")
        .orderBy("dateTime")
        .snapshots();
  }

  Future<void> joinTrip(String tripId, int joined, int maxPeople) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final seatsLeft = maxPeople - joined;
    if (seatsLeft <= 0) throw Exception("Trip full");

    final participantDoc =
        _db.collection("tripParticipants").doc("${tripId}_${user.uid}");

    final exists = await participantDoc.get();
    if (exists.exists) return; // prevent duplicate

    final batch = _db.batch();

    batch.set(participantDoc, {
      "tripId": tripId,
      "userId": user.uid,
      "joinedAt": DateTime.now(),
    });

    final tripRef = _db.collection("trips").doc(tripId);

    batch.update(tripRef, {
      "joined": FieldValue.increment(1),
    });

    await batch.commit();
  }
}