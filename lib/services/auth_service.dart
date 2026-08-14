import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
  Future<void> sendPasswordResetEmail(String email) async {
  await FirebaseAuth.instance.sendPasswordResetEmail(
    email: email,
  );
}
Future<void> sendEmailVerification() async {
  await _auth.currentUser?.sendEmailVerification();
}
  // Sign up with email and password
 Future<UserCredential> signUp(String email, String password) async {
  final credential = await _auth.createUserWithEmailAndPassword(
    email: email.trim(),
    password: password,
  );

  await credential.user?.sendEmailVerification();

  return credential;
}


Future<void> changePassword({
  required String currentPassword,
  required String newPassword,
}) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    throw Exception("User not logged in");
  }

  final credential = EmailAuthProvider.credential(
    email: user.email!,
    password: currentPassword,
  );

  await user.reauthenticateWithCredential(credential);
  await user.updatePassword(newPassword);
}
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Change password (requires recent login)
  Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
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
}
