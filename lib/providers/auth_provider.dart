import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get user => _auth.currentUser;

  bool get isLoggedIn => user != null;

  /// Allow college domains
  bool _isCollegeEmail(String email) {
    return email.endsWith("@vitapstudent.ac.in") ||
        email.endsWith("@vit.ac.in") ||
        email.endsWith("@vitstudent.ac.in");
  }

  Future<String?> signIn(String email, String password) async {
    try {
      if (!_isCollegeEmail(email)) {
        return "Use college email only";
      }

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      if (!_isCollegeEmail(email)) {
        return "Use college email only";
      }

      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// ⭐ IMPORTANT — force router rebuild after profile save
  void refresh() {
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }
}
