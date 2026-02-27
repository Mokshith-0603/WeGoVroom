import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<String?> getDisplayName(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();
    return doc.data()?["displayName"];
  }
}