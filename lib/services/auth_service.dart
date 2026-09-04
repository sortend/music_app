import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Auth. Keeps the rest of the app decoupled
/// from the Firebase SDK directly.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> register(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user?.uid;
    if (uid != null) {
      try {
        await _db.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // The account itself exists at this point, so a failed profile write
        // must not surface as "registration failed" — that would leave the
        // user unable to register *or* log in.
        debugPrint('Could not save the user profile document: $e');
      }
    }
    return cred;
  }

  Future<void> signOut() => _auth.signOut();
}
