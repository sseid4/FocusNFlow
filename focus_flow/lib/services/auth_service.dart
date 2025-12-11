import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String allowedDomain = '@student.gsu.edu';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Validate GSU email
  bool isValidGSUEmail(String email) {
    return email.toLowerCase().endsWith(allowedDomain);
  }

  // Sign up with email and password
  Future<UserCredential?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      // Validate GSU domain
      if (!isValidGSUEmail(email)) {
        throw FirebaseAuthException(
          code: 'invalid-email-domain',
          message: 'Please use your GSU email (@student.gsu.edu)',
        );
      }

      // Create user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Send verification email
      await credential.user?.sendEmailVerification();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Validate GSU domain
      if (!isValidGSUEmail(email)) {
        throw FirebaseAuthException(
          code: 'invalid-email-domain',
          message: 'Please use your GSU email (@student.gsu.edu)',
        );
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      if (!isValidGSUEmail(email)) {
        throw FirebaseAuthException(
          code: 'invalid-email-domain',
          message: 'Please use your GSU email (@student.gsu.edu)',
        );
      }

      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email-domain':
        return 'Please use your GSU email (@student.gsu.edu)';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return e.message ?? 'An error occurred. Please try again';
    }
  }
}
