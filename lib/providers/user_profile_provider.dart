import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, Map<String, dynamic>> _userProfiles = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _subscriptions = {};

  Map<String, dynamic>? getUserProfile(String userId) {
    return _userProfiles[userId];
  }

  void setCachedUserProfile(String userId, Map<String, dynamic> updates) {
    _userProfiles[userId] = {
      ...?_userProfiles[userId],
      ...updates,
    };
    notifyListeners();
  }

  void listenToUserProfile(String userId) {
    if (_subscriptions.containsKey(userId)) return;

    _subscriptions[userId] = _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            _userProfiles[userId] = doc.data() ?? {};
            notifyListeners();
            return;
          }

          if (_userProfiles.remove(userId) != null) {
            notifyListeners();
          }
        });
  }

  Future<void> updateCurrentUserProfile(Map<String, dynamic> updates) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setCachedUserProfile(user.uid, updates);
    await _db.collection('users').doc(user.uid).update(updates);
  }

  Future<void> clear() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _userProfiles.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }
}
