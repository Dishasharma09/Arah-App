import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Sign up with email and password
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send password reset email with optional ActionCodeSettings
  Future<void> sendPasswordResetEmail(
    String email, {
    // Optional ActionCodeSettings for handling the link in-app
    // If null, behaves as before (sends generic reset link)
    ActionCodeSettings? actionCodeSettings,
  }) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
      actionCodeSettings: actionCodeSettings,
    );
  }

  // Change password (requires recent login)
  Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  // Change password securely with session revocation (via Cloud Function)
  Future<void> changePasswordSecure(String newPassword) async {
    try {
      final result = await _functions
          .httpsCallable('changePasswordSecure')
          .call(<String, dynamic>{'newPassword': newPassword});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseException(
        plugin: 'firebase-functions',
        code: e.code,
        message: e.message,
      );
    }
  }

  // Validate password strength (via Cloud Function)
  Future<Map<String, dynamic>> validatePasswordStrength(String password) async {
    try {
      final result = await _functions
          .httpsCallable('validatePasswordStrength')
          .call(<String, dynamic>{'password': password});
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseException(
        plugin: 'firebase-functions',
        code: e.code,
        message: e.message,
      );
    }
  }

  // Send email verification (via Cloud Function for consistency)
  Future<void> sendEmailVerification() async {
    try {
      final result = await _functions
          .httpsCallable('sendEmailVerification')
          .call(<String, dynamic>{});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseException(
        plugin: 'firebase-functions',
        code: e.code,
        message: e.message,
      );
    }
  }

  // Re-authenticate before sensitive operations
  Future<void> reauthenticate(String email, String password) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await _auth.currentUser?.reauthenticateWithCredential(credential);
  }

  // Delete account
  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }

  // Revoke refresh tokens for current user (sign out everywhere)
  Future<void> revokeRefreshTokens() async {
    try {
      final result = await _functions
          .httpsCallable('revokeRefreshTokens')
          .call(<String, dynamic>{});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseException(
        plugin: 'firebase-functions',
        code: e.code,
        message: e.message,
      );
    }
  }
}