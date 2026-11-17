import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _sortCodeController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasSavedDetails = false;

  String _savedSortCode = '';
  String _savedAccountNumber = '';

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  Future<void> _loadBankDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final sc = data['sortCode'] ?? '';
        final ac = data['accountNumber'] ?? '';

        if (sc.isNotEmpty && ac.isNotEmpty) {
          setState(() {
            _savedSortCode = sc;
            _savedAccountNumber = ac;
            _hasSavedDetails = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading bank details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDetails() async {
    final sortCode = _sortCodeController.text.trim();
    final accountNumber = _accountNumberController.text.trim();

    if (sortCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sort code must be 6 digits.')));
      return;
    }
    if (accountNumber.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account number must be 8 digits.')));
      return;
    }

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      await _firestore.collection('users').doc(user!.uid).update({
        'sortCode': sortCode,
        'accountNumber': accountNumber,
      });

      setState(() {
        _savedSortCode = sortCode;
        _savedAccountNumber = accountNumber;
        _hasSavedDetails = true;
        _sortCodeController.clear();
        _accountNumberController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank details securely encrypted and saved.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDeleteDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Bank Details?'),
        content: const Text('This will permanently delete your receiving account details from the secure database. You will need to enter them again to receive payments via QR code.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final user = FirebaseAuth.instance.currentUser;
              try {
                await _firestore.collection('users').doc(user!.uid).update({
                  'sortCode': FieldValue.delete(),
                  'accountNumber': FieldValue.delete(),
                });
                setState(() {
                  _hasSavedDetails = false;
                  _savedSortCode = '';
                  _savedAccountNumber = '';
                });
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank details removed.')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Funkcja maskująca numer konta i sort code
  String _maskAccountNumber(String acc) {
    if (acc.length < 4) return acc;
    return '**** **** ${acc.substring(acc.length - 4)}';
  }

  String _formatSortCode(String sc) {
    if (sc.length != 6) return sc;
    return '${sc.substring(0, 2)}-${sc.substring(2, 4)}-${sc.substring(4, 6)}';
  }

  @override
  void dispose() {
    _sortCodeController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Bank Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF10B981), // Zielony motyw finansowy
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Wiadomość budująca zaufanie
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('100% Safe & Secure', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 16)),
                                SizedBox(height: 6),
                                Text(
                                  'QuidSplit never touches your money. We only use these details to generate a standard UK Paym QR code so friends can pay you back directly through their own banking app.',
                                  style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Logika wyświetlania: Formularz ALBO Ukryte dane
                    if (_hasSavedDetails) ...[
                      const Text('Your Receiving Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SORT CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(_formatSortCode(_savedSortCode), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Divider(),
                            ),
                            const Text('ACCOUNT NUMBER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(_maskAccountNumber(_savedAccountNumber), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        onPressed: _confirmDeleteDetails,
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Remove Bank Details', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ] else ...[
                      const Text('Add Account Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _sortCodeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Sort Code',
                          hintText: '123456',
                          counterText: '',
                          prefixIcon: const Icon(Icons.account_balance),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 8,
                        decoration: InputDecoration(
                          labelText: 'Account Number',
                          hintText: '12345678',
                          counterText: '',
                          prefixIcon: const Icon(Icons.numbers),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Securely Save Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}