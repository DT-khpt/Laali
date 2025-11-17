// lib/services/firebase_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;

  FirebaseService._internal() {
    debugPrint('✅ Firebase Service initialized');
  }

  // ---------- Auth ----------
  User? get currentUser => _auth.currentUser;

  // Simple anonymous sign-in
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      debugPrint('✅ Anonymous user created: ${userCredential.user?.uid}');
      return userCredential.user;
    } catch (e) {
      debugPrint('❌ Anonymous sign-in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async => await _auth.signOut();

  // ---------- User Profile (Simplified) ----------
  Future<void> createUserProfile({
    required String username,
    required DateTime lmpDate,
    bool isAnonymous = false
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user authenticated');

    try {
      // Store everything in one document - much simpler!
      await _firestore.collection('users').doc(user.uid).set({
        'username': username,
        'lmp_date': Timestamp.fromDate(lmpDate),
        'is_anonymous': isAnonymous,
        'created_at': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ User profile created: $username');
    } catch (e) {
      debugPrint('❌ createUserProfile error: $e');
      rethrow;
    }
  }

  // Get user profile with LMP date
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('❌ getUserProfile error: $e');
      return null;
    }
  }

  // ---------- Visit Notes (For voice conversations) ----------
  Future<void> saveVisitNote(String transcript) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('visit_notes').add({
        'user_id': user.uid,
        'transcript': transcript,
        'created_at': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Visit note saved');
    } catch (e) {
      debugPrint('❌ Error saving visit note: $e');
    }
  }

  // Get recent visit notes for dashboard
  Future<List<Map<String, dynamic>>> getRecentVisitNotes({int limit = 5}) async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final query = await _firestore
          .collection('visit_notes')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error getting recent visit notes: $e');
      return [];
    }
  }

  // ---------- Simple Data Getters ----------
  Future<String?> getUsername() async {
    final profile = await getUserProfile();
    return profile?['username'] as String?;
  }

  Future<DateTime?> getLmpDate() async {
    final profile = await getUserProfile();
    final timestamp = profile?['lmp_date'] as Timestamp?;
    return timestamp?.toDate();
  }

  // Check if user exists
  Future<bool> userExists() async {
    final profile = await getUserProfile();
    return profile != null;
  }
}