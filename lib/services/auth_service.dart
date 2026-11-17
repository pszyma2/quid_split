import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. POBIERANIE AKTUALNEGO ID ---
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // --- 2. GENEROWANIE KLUCZA ---
  String _generateRecoveryKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String key = '';
    for (int i = 0; i < 16; i++) {
      key += chars[random.nextInt(chars.length)];
    }
    
    // Rozbite na krótkie linie, żeby interfejs tego nie uciął!
    String p1 = key.substring(0, 4);
    String p2 = key.substring(4, 8);
    String p3 = key.substring(8, 12);
    String p4 = key.substring(12, 16);
    
    return '$p1-$p2-$p3-$p4';
  }

  // --- 3. REJESTRACJA NOWEGO UŻYTKOWNIKA ---
  Future<void> registerNewUser(String displayName) async {
    UserCredential credential = await _auth.signInAnonymously();
    String uid = credential.user!.uid;
    String recoveryKey = _generateRecoveryKey();

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'displayName': displayName,
      'recoveryKey': recoveryKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- 4. WYSZUKIWANIE PO KLUCZU (NAPRAWIONE) ---
  Future<Map<String, dynamic>?> findUserByRecoveryKey(String key) async {
    String cleanKey = key.replaceAll(RegExp(r'[-\s]'), '').toUpperCase();
    if (cleanKey.length != 16) return null;

    // Rozbite na krótkie linie dla bezpieczeństwa
    String p1 = cleanKey.substring(0, 4);
    String p2 = cleanKey.substring(4, 8);
    String p3 = cleanKey.substring(8, 12);
    String p4 = cleanKey.substring(12, 16);
    String formattedKey = '$p1-$p2-$p3-$p4';

    final querySnapshot = await _firestore
        .collection('users')
        .where('recoveryKey', isEqualTo: formattedKey)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }
    return querySnapshot.docs.first.data();
  }

  // --- 5. PRZYWRACANIE KONTA (NAPRAWIONE ADMIN ID) ---
  Future<void> restoreAccount(String recoveryKey) async {
    final oldUserData = await findUserByRecoveryKey(recoveryKey);
    if (oldUserData == null) {
      throw Exception('Invalid Recovery Key. Account not found.');
    }

    String oldUid = oldUserData['uid'];
    String displayName = oldUserData['displayName'];
    String originalKey = oldUserData['recoveryKey'];

    UserCredential credential = await _auth.signInAnonymously();
    String newUid = credential.user!.uid;

    await _firestore.collection('users').doc(newUid).set({
      'uid': newUid,
      'displayName': displayName,
      'recoveryKey': originalKey,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final groupsSnapshot = await _firestore
        .collection('groups')
        .where('members', arrayContains: oldUid)
        .get();

    if (groupsSnapshot.docs.isNotEmpty) {
      WriteBatch batch = _firestore.batch();
      for (var doc in groupsSnapshot.docs) {
        final data = doc.data();
        List<dynamic> members = data['members'] ?? [];
        members.remove(oldUid);
        if (!members.contains(newUid)) {
          members.add(newUid);
        }
        
        Map<String, dynamic> updates = {'members': members};
        
        // NAPRAWA ADMINA: Jeśli stare ID było adminem, zrób adminem nowe ID
        if (data['adminId'] == oldUid) {
          updates['adminId'] = newUid;
        }

        batch.update(doc.reference, updates);
      }
      await batch.commit();
    }

    await _firestore.collection('users').doc(oldUid).delete();
  }

  // --- 6. POBIERANIE IMIENIA UŻYTKOWNIKA ---
  Future<String> getUserName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['displayName'] ?? 'Unknown';
      }
    } catch (e) {
      print("Error fetching user name: $e");
    }
    return 'Unknown';
  }

  // --- 7. WYLOGOWANIE UŻYTKOWNIKA (DODANE) ---
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // --- 8. USUWANIE KONTA (DODANE) ---
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Usuwamy dane z Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        // Usuwamy konto anonimowe z Firebase Auth
        await user.delete();
      } catch (e) {
        throw Exception('Failed to delete account: $e');
      }
    }
  }
}