import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  static const bool isPrototypeMode =
      false; // Set to false when Firebase is ready

  FirebaseAuth? _manualAuth;
  FirebaseFirestore? _manualDb;

  FirebaseAuth get _auth => _manualAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _manualDb ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges {
    if (isPrototypeMode) return Stream.value(null);
    return _auth.authStateChanges();
  }

  Future<UserModel?> getUserData(String uid) async {
    if (isPrototypeMode) return null;

    // Try finding by auth_uid first
    var query = await _db
        .collection('users')
        .where('auth_uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return UserModel.fromMap(query.docs.first.data());
    }

    // Fallback: Check if the UID itself is the document ID (for anonymous students later)
    var doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }

    return null;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // OTP Logic
  Future<bool> requestOTP(String userId) async {
    if (isPrototypeMode) {
      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate network
      return true; // Always succeed in prototype mode
    }

    try {
      // Check if user exists
      var userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      String userName = userDoc.data()?['name'] ?? 'Unknown Student';

      // Generate a random 6-digit OTP
      String otp = (100000 + (DateTime.now().millisecond * 899))
          .toString()
          .padLeft(6, '0')
          .substring(0, 6);

      await _db.collection('pending_otps').doc(userId).set({
        'name': userName,
        'requested_at': FieldValue.serverTimestamp(),
        'consumed': false,
        'otp': otp,
        'issued_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error requesting OTP: $e');
      return false;
    }
  }

  Future<bool> verifyOTP(String userId, String otp) async {
    if (isPrototypeMode) {
      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate network
      return otp == '1234'; // Universal demo OTP
    }

    try {
      var otpDoc = await _db.collection('pending_otps').doc(userId).get();
      if (!otpDoc.exists) return false;

      var data = otpDoc.data()!;
      if (data['otp'].toString() == otp && data['consumed'] == false) {
        await _db.collection('pending_otps').doc(userId).update({
          'consumed': true,
          'consumed_at': FieldValue.serverTimestamp(),
        });
        return true;
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
    }
    return false;
  }
}
