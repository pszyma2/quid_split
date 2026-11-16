import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
// Upewnij się, że masz qr_flutter w pubspec.yaml

class FriendTransferScreen extends StatefulWidget {
  final String currentUserId; // Docelowo przekażemy tu ID zalogowanego użytkownika

  const FriendTransferScreen({
    super.key, 
    this.currentUserId = 'mock_user_id', // Na czas testów
  });

  @override
  State<FriendTransferScreen> createState() => _FriendTransferScreenState();
}

class _FriendTransferScreenState extends State<FriendTransferScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _sortCodeController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _generatedQrPayload;

  // Nasz fioletowy motyw z ekranu głównego
  final Color _primaryColor = const Color(0xFF8B5CF6);

  Future<void> _validateAndGenerate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedQrPayload = null;
    });

    final amountText = _amountController.text.trim();
    final sortCode = _sortCodeController.text.trim();
    final accountNum = _accountController.text.trim();

    if (amountText.isEmpty || sortCode.isEmpty || accountNum.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields.';
        _isLoading = false;
      });
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid amount.';
        _isLoading = false;
      });
      return;
    }

    // TWARDY ZAMEK KWOTOWY: Maksymalnie £20
    if (amount > 20.00) {
      setState(() {
        _errorMessage = 'Amount exceeds £20. Please use "Quick Split" for larger transfers.';
        _isLoading = false;
      });
      return;
    }

    try {
      // TWARDY ZAMEK ILOŚCIOWY: Sprawdzamy limit 10 darmowych przelewów w bazie
      DocumentReference userRef = _firestore.collection('users').doc(widget.currentUserId);
      DocumentSnapshot userDoc = await userRef.get();

      if (!userDoc.exists) {
        // Zabezpieczenie na wypadek braku dokumentu w fazie testów
        await userRef.set({'free_transfers_remaining': 10});
        userDoc = await userRef.get();
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final int remainingTransfers = data['free_transfers_remaining'] ?? 0;

      if (remainingTransfers > 0) {
        // Odejmujemy jeden przelew z puli darmowych
        await userRef.update({
          'free_transfers_remaining': FieldValue.increment(-1)
        });

        // Generujemy brytyjski standard Open Banking (Paym/EMVCo) dla banku
        final String bankingPayload = 'uk.co.openbanking://pay?sc=$sortCode&acc=$accountNum&amt=$amountText';

        setState(() {
          _generatedQrPayload = bankingPayload;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'You have reached your limit of 10 free transfers this month. Please use "Quick Split".';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Database connection error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _sortCodeController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Friend Transfer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Free Bank Transfer',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Direct via Open Banking. Max £20 per transaction. Generates a secure QR code for your friend\'s banking app.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              if (_generatedQrPayload == null) ...[
                // Wprowadzanie danych, jeśli QR jeszcze nie został wygenerowany
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (£) - Max £20',
                    prefixIcon: const Icon(Icons.currency_pound),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _sortCodeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Sort Code (e.g. 123456)',
                    prefixIcon: const Icon(Icons.account_balance),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Account Number',
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _validateAndGenerate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Generate Free QR Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ] else ...[
                // Wyświetlanie gotowego kodu QR
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Scan in your Banking App',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      QrImageView(
                        data: _generatedQrPayload!,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '0% Commission. Instant Transfer.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _generatedQrPayload = null;
                      _amountController.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: _primaryColor, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Done / Reset',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}