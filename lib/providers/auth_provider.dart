import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  static const String _googleWebClientId =
      "202225012572-p5hn6o4kqcb0o4l3ikvtbajgqip9eghq.apps.googleusercontent.com";
  static const String _googleServerClientId =
      "202225012572-p5hn6o4kqcb0o4l3ikvtbajgqip9eghq.apps.googleusercontent.com";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _googleWebClientId : null,
    serverClientId: _googleServerClientId,
  );
  static const String adminEmail = "admin@vitapstudent.ac.in";
  static const String allowedEmailDomain = "@vitapstudent.ac.in";

  User? get user => _auth.currentUser;

  bool get isLoggedIn => user != null;

  bool isAdminEmail(String? email) {
    return email?.trim().toLowerCase() == adminEmail;
  }

  bool get shouldBypassVerificationForCurrentUser => isAdminEmail(user?.email);

  /// Allow college domains
  bool _isCollegeEmail(String email) {
    final e = email.trim().toLowerCase();
    return e.endsWith(allowedEmailDomain);
  }

  Future<String?> signIn(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    try {
      if (!_isCollegeEmail(normalizedEmail)) {
        return "Use $allowedEmailDomain email only";
      }

      final cred = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: normalizedPassword,
      );

      await cred.user?.reload();
      final current = _auth.currentUser;
      if (current != null &&
          !current.emailVerified &&
          !isAdminEmail(current.email)) {
        try {
          await current.sendEmailVerification();
        } on FirebaseAuthException catch (e) {
          await _auth.signOut();
          return e.message ??
              "Email not verified. Could not resend verification email.";
        } catch (_) {
          await _auth.signOut();
          return "Email not verified. Could not resend verification email.";
        }
        await _auth.signOut();
        return "Please verify your email first. Verification mail has been sent.";
      }

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
        return "Use $allowedEmailDomain email only";
      }

      final cred = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: normalizedPassword,
      );
      final createdUser = cred.user;
      if (createdUser == null) {
        await _auth.signOut();
        return "Account created but verification email could not be sent. Please try signing in again.";
      }
      if (!isAdminEmail(createdUser.email)) {
        await createdUser.sendEmailVerification();
        await _auth.signOut();
      }

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

  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return "Google sign-in cancelled";
      }

      final email = googleUser.email.trim().toLowerCase();
      if (!_isCollegeEmail(email)) {
        await _googleSignIn.signOut();
        return "Use $allowedEmailDomain Google account only";
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final signedInUser = userCredential.user;
      final signedInEmail = signedInUser?.email?.trim().toLowerCase();

      if (signedInEmail == null || !_isCollegeEmail(signedInEmail)) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        return "Use $allowedEmailDomain Google account only";
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google FirebaseAuthException: code=${e.code}, message=${e.message}');
      switch (e.code) {
        case "account-exists-with-different-credential":
          return "An account already exists with a different sign-in method";
        case "invalid-credential":
          return "Google sign-in failed. Try again";
        case "user-disabled":
          return "This account has been disabled";
        default:
          return e.message ?? "Google sign-in failed";
      }
    } on PlatformException catch (e) {
      debugPrint('Google PlatformException: code=${e.code}, message=${e.message}, details=${e.details}');
      if (e.code == "sign_in_canceled") {
        return "Google sign-in cancelled";
      }
      return e.message ?? "Google sign-in failed (${e.code})";
    } catch (e) {
      debugPrint('Google sign-in unexpected error: $e');
      return "Google sign-in failed";
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return "Enter your email";
    if (!_isCollegeEmail(normalizedEmail)) {
      return "Use $allowedEmailDomain email only";
    }

    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "invalid-email":
          return "Invalid email format";
        case "user-not-found":
          return "No account found for this email";
        case "too-many-requests":
          return "Too many attempts. Try again later";
        default:
          return e.message ?? "Failed to send reset email";
      }
    } catch (_) {
      return "Failed to send reset email";
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return "Please login again";
    }
    final email = user.email;
    if (email == null || email.trim().isEmpty) {
      return "Account email not available";
    }

    final current = currentPassword.trim();
    final updated = newPassword.trim();

    if (current.isEmpty || updated.isEmpty) {
      return "Fill all password fields";
    }
    if (updated.length < 6) {
      return "New password should be at least 6 characters";
    }
    if (current == updated) {
      return "New password must be different from current password";
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim().toLowerCase(),
        password: current,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(updated);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "wrong-password":
        case "invalid-credential":
          return "Current password is incorrect";
        case "weak-password":
          return "New password is too weak";
        case "requires-recent-login":
          return "Please logout and login again, then retry";
        default:
          return e.message ?? "Failed to change password";
      }
    } catch (_) {
      return "Failed to change password";
    }
  }

  /// ⭐ IMPORTANT — force router rebuild after profile save
  void refresh() {
    notifyListeners();
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    notifyListeners();
  }
}
