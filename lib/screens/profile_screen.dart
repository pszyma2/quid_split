import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'welcome_screen.dart'; // Potrzebne do powrotu po usunięciu konta

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _userName = 'Loading...';
  String _recoveryKey = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (uid == null) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      setState(() {
        _userName = doc.data()?['displayName'] ?? 'Unknown';
        _recoveryKey = doc.data()?['recoveryKey'] ?? 'No key found';
      });
    }
  }

  // --- FAZA 1: ZWYKŁE PYTANIE ---
  void _showDeleteWarningStep1() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('Are you sure you want to delete your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Anuluj -> nic się nie dzieje
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context); // Zamykamy pierwsze okno
              _showDeleteWarningStep2(); // Otwieramy drugą, ostateczną bramkę
            },
            child: const Text('Yes, proceed', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- FAZA 2: BRAMKA BEZ POWROTU ---
  void _showDeleteWarningStep2() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FINAL WARNING', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Confirming this will permanently delete your account. You will lose access to all your trips, debts, and history. This action CANNOT be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Anuluj -> uratowany
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _deleteAccountAndExit, // EGZEKUCJA
            child: const Text('PERMANENTLY DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccountAndExit() async {
    if (uid == null) return;
    try {
      // 1. Kasujemy dokument profilu z bazy
      await _firestore.collection('users').doc(uid).delete();
      // 2. Kasujemy anonimowe konto systemowe Authentication
      await FirebaseAuth.instance.currentUser?.delete();

      if (mounted) {
        // Czyścimy całą historię nawigacji i wyrzucamy na ekran powitalny
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Profile & Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Display Name', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 8),
            Text(_userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            
            const Text('Recovery Key', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _recoveryKey, 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF10B981)),
                    onPressed: () async { // <-- DODANE async
                      // Czekamy, aż system fizycznie zapisze dane w schowku
                      await Clipboard.setData(ClipboardData(text: _recoveryKey)); 
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recovery Key copied to clipboard!'),
                            behavior: SnackBarBehavior.floating, // Wygląda bardziej premium
                            backgroundColor: Color(0xFF10B981), // Zielony akcent sukcesu
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Keep this key safe. You will need it to restore your account if you change your phone.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Spacer(), // Wypycha przycisk usuwania na sam dół ekranu
            
            // --- NOWY PRZYCISK: BEZPIECZNE WYLOGOWANIE ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut(); 
                  
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.black87), // Ciemna ikona na jasne tło
                label: const Text('Log Out', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black26, width: 1.5), // Widoczna, szara ramka
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
              
            const SizedBox(height: 16), // Odstęp między przyciskami
              
              // --- TWÓJ OBECNY CZERWONY PRZYCISK USUWANIA KONTA ---
              // (Zostaje bez zmian poniżej)

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showDeleteWarningStep1,
                icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                label: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}