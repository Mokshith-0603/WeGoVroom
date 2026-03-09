import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, Map<String, dynamic>> _userProfiles = {};

  Map<String, dynamic>? getUserProfile(String userId) {
    return _userProfiles[userId];
  }

  void listenToUserProfile(String userId) {
    if (_userProfiles.containsKey(userId)) return; // Already listening

    _db.collection('users').doc(userId).snapshots().listen((doc) {
      if (doc.exists) {
        _userProfiles[userId] = doc.data() ?? {};
        notifyListeners();
      }
    });
  }

  void updateCurrentUserProfile(Map<String, dynamic> updates) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).update(updates);
    // The listener will notify
  }

  void clear() {
    _userProfiles.clear();
    notifyListeners();
  }
}
