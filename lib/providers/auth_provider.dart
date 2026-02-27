import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get user => _auth.currentUser;

  bool get isLoggedIn => user != null;

  /// Allow college domains
  bool _isCollegeEmail(String email) {
    final e = email.trim().toLowerCase();
    return e.endsWith("@vitapstudent.ac.in") ||
        e.endsWith("@vit.ac.in") ||
        e.endsWith("@vitstudent.ac.in");
  }

  Future<String?> signIn(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    try {
      if (!_isCollegeEmail(normalizedEmail)) {
        return "Use college email only";
      }

      await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: normalizedPassword,
      );

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "invalid-email":
          return "Invalid email format";
        case "user-not-found":
          return "No account found for this email";
        case "wrong-password":
        case "invalid-credential":
          return "Incorrect email or password";
        case "too-many-requests":
          return "Too many attempts. Try again later";
        default:
          return e.message ?? "Login failed";
      }
    } catch (_) {
      return "Login failed";
    }
  }

  Future<String?> signUp(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    try {
      if (!_isCollegeEmail(normalizedEmail)) {
        return "Use college email only";
      }

      await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: normalizedPassword,
      );

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "invalid-email":
          return "Invalid email format";
        case "email-already-in-use":
          return "This email is already registered";
        case "weak-password":
          return "Password should be at least 6 characters";
        default:
          return e.message ?? "Signup failed";
      }
    } catch (_) {
      return "Signup failed";
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
