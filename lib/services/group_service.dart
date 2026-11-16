import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'debt_calculator.dart'; // Podpinamy nasz mózg matematyczny

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _generatePin() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<String> createGroup(String groupName, String adminId) async {
    final String pin = _generatePin();
    
    final docRef = await _firestore.collection('groups').add({
      'name': groupName,
      'pin': pin,
      'adminId': adminId,
      'members': [adminId], 
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<String> joinGroupWithPin(String pin, String userId) async {
    final querySnapshot = await _firestore
        .collection('groups')
        .where('pin', isEqualTo: pin.toUpperCase())
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Group with this PIN not found.');
    }

    final groupDoc = querySnapshot.docs.first;
    final groupData = groupDoc.data();

    if (groupData['status'] == 'closed') {
      throw Exception('This trip has already been settled and closed.');
    }

    List<dynamic> members = groupData['members'] ?? [];
    if (members.contains(userId)) {
      return groupDoc.id;
    }

    await _firestore.collection('groups').doc(groupDoc.id).update({
      'members': FieldValue.arrayUnion([userId])
    });

    return groupDoc.id;
  }

  // NOWY MODUŁ: Dodawanie "wirtualnego" użytkownika (Tryb Księgowego)
  Future<void> addGhostUserToGroup({
    required String groupId, 
    required String ghostName, 
    required String currentUserId,
  }) async {
    try {
      // 1. Generujemy bezpieczne, unikalne ID dla "Ducha"
      final String ghostId = 'ghost_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

      // 2. Wrzucamy Ducha do naszej głównej kartoteki użytkowników
      await _firestore.collection('users').doc(ghostId).set({
        'uid': ghostId,
        'displayName': ghostName,
        'isGhost': true, // Flaga oznaczająca wirtualne konto
        'createdBy': currentUserId, // Zapisujemy, kto jest "Księgowym"
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Dodajemy wygenerowane ID do tablicy członków w konkretnej grupie
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([ghostId])
      });

    } catch (e) {
      throw Exception('Failed to add friend: $e');
    }
  }

  // NOWY SILNIK ROZLICZAJĄCY I ZAPISUJĄCY WYNIK W GRUPIE
  Future<void> settleGroup(String groupId, String currentUserId) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();

    if (!groupDoc.exists) throw Exception('Group does not exist.');
    
    final groupData = groupDoc.data()!;
    if (groupData['adminId'] != currentUserId) {
      throw Exception('Only the administrator can close and settle the trip.');
    }
    if (groupData['status'] == 'closed') {
      throw Exception('Group is already settled.');
    }

    // 1. Pobieramy oficjalną listę członków
    List<String> allMembers = List<String>.from(groupData['members'] ?? []);

    // 2. Pobieramy wszystkie wydatki
    final expensesSnapshot = await groupRef.collection('expenses').get();
    
    // 3. PANCERNA POPRAWKA: Sumujemy wydatki i ZMUSZAMY system 
    // do wciągnięcia na listę każdego, kto dorzucił paragon.
    Map<String, double> userTotalPayments = {};
    for (var doc in expensesSnapshot.docs) {
      final data = doc.data();
      final String paidBy = data['paidBy'];
      final double amount = (data['amount'] as num).toDouble();
      
      // Jeśli płatnika nie ma na oficjalnej liście grupy, dopisujemy go w locie
      if (!allMembers.contains(paidBy)) {
        allMembers.add(paidBy);
      }
      
      userTotalPayments[paidBy] = (userTotalPayments[paidBy] ?? 0.0) + amount;
    }

    // 4. Odpalamy nasz algorytm zachłanny
    final transfers = DebtCalculator.calculateMinimalTransfers(
      userTotalPayments: userTotalPayments,
      allMemberIds: allMembers,
    );

    // 5. Konwertujemy wynik na format przyjazny dla Firebase
    final settlementData = transfers.map((t) => {
      'fromUserId': t.fromUserId,
      'toUserId': t.toUserId,
      'amount': t.amount,
    }).toList();

    // 6. Zapisujemy wyniki w chmurze i zamykamy kłódkę
    await groupRef.update({
      'status': 'closed',
      'settlement': settlementData,
      'settledAt': FieldValue.serverTimestamp(),
    });
  }
}