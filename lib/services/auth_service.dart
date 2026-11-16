import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generuje 16-znakowy klucz odzyskiwania w formacie XXXX-XXXX-XXXX-XXXX
  String _generateRecoveryKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String key = '';
    for (int i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) key += '-';
      key += chars[random.nextInt(chars.length)];
    }
    return key;
  }

  /// Tworzy całkowicie nowe, anonimowe konto i zapisuje profil w bazie
  Future<String> registerNewUser(String displayName) async {
    // 1. Ciche logowanie w tle (Firebase generuje unikalne UID)
    UserCredential credential = await _auth.signInAnonymously();
    String uid = credential.user!.uid;

    // 2. Generujemy unikalny klucz awaryjny dla Pawła/Zenka
    String recoveryKey = _generateRecoveryKey();

    // 3. Tworzymy wpis w globalnej kartotece 'users'
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'displayName': displayName,
      'recoveryKey': recoveryKey,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return uid;
  }

  /// Sprawdza, czy ktoś jest już zalogowany na tym telefonie
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Wyszukuje użytkownika po kluczu odzyskiwania (przyda się później do migracji konta)
  Future<Map<String, dynamic>?> findUserByRecoveryKey(String key) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('recoveryKey', isEqualTo: key.replaceAll('-', '').toUpperCase())
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }
    return querySnapshot.docs.first.data();
  }

  /// Błyskawicznie pobiera imię na podstawie surowego ID z Firebase
  Future<String> getUserName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['displayName'] ?? 'Someone';
      }
      return 'Someone';
    } catch (e) {
      return 'Someone';
    }
  }
}