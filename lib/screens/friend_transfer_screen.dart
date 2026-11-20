import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FriendTransferScreen extends StatefulWidget {
  final String? currentUserId;

  const FriendTransferScreen({
    super.key,
    this.currentUserId,
  });

  @override
  State<FriendTransferScreen> createState() => _FriendTransferScreenState();
}

class _FriendTransferScreenState extends State<FriendTransferScreen> {
  final TextEditingController _amountController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _monthlyLimit = 5;
  static const double _maxAmount = 20.00;
  final Color _primaryColor = const Color(0xFF8B5CF6);

  bool _isInitialLoading = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _generatedQrPayload;
  String? _generatedAmountText;

  String _savedPaymentLink = '';
  String _savedProvider = '';
  int _remainingTransfers = _monthlyLimit;

  String? get _resolvedUserId {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) return authUid;
    if (widget.currentUserId != null && widget.currentUserId != 'mock_user_id') {
      return widget.currentUserId;
    }
    return null;
  }

  String get _currentMonthKey {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  @override
  void initState() {
    super.initState();
    _loadUserTransferData();
  }

  Future<void> _loadUserTransferData() async {
    final uid = _resolvedUserId;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'User session not found. Please restart the app.';
          _isInitialLoading = false;
        });
      }
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final link = (data['paymentLink'] ?? '').toString().trim();
        final provider = (data['paymentProvider'] ?? '').toString().trim();
        final storedMonth = (data['freeTransfersMonth'] ?? '').toString().trim();
        final int usedThisMonth = storedMonth == _currentMonthKey
            ? ((data['freeTransfersUsed'] ?? 0) as num).toInt()
            : 0;

        if (mounted) {
          setState(() {
            _savedPaymentLink = link;
            _savedProvider = provider;
            _remainingTransfers = (_monthlyLimit - usedThisMonth).clamp(0, _monthlyLimit);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Database connection error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  String _buildQrLink(String baseLink, double amount) {
    final cleanLink = baseLink.endsWith('/') ? baseLink.substring(0, baseLink.length - 1) : baseLink;
    final lower = cleanLink.toLowerCase();
    final formattedAmount = amount.toStringAsFixed(2);

    if (lower.contains('monzo.me') || lower.contains('paypal.me')) {
      return '$cleanLink/$formattedAmount';
    }
    return cleanLink;
  }

  Future<void> _validateAndGenerate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedQrPayload = null;
      _generatedAmountText = null;
    });

    final uid = _resolvedUserId;
    if (uid == null) {
      setState(() {
        _errorMessage = 'User session not found.';
        _isLoading = false;
      });
      return;
    }

    if (_savedPaymentLink.isEmpty) {
      setState(() {
        _errorMessage = 'No payment link found. Add your Revolut, Starling, Monzo or PayPal link in Profile & Settings -> Bank Details.';
        _isLoading = false;
      });
      return;
    }

    final amountText = _amountController.text.trim().replaceAll(',', '.');
    if (amountText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an amount.';
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

    if (amount > _maxAmount) {
      setState(() {
        _errorMessage = 'Amount exceeds £20. Please use "Quick Split" for larger or commercial transfers.';
        _isLoading = false;
      });
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await userRef.get();
      final data = userDoc.exists ? (userDoc.data() as Map<String, dynamic>) : <String, dynamic>{};

      final storedMonth = (data['freeTransfersMonth'] ?? '').toString().trim();
      final int currentUsed = storedMonth == _currentMonthKey
          ? ((data['freeTransfersUsed'] ?? 0) as num).toInt()
          : 0;

      if (currentUsed >= _monthlyLimit) {
        setState(() {
          _remainingTransfers = 0;
          _errorMessage = 'You have reached your limit of $_monthlyLimit free transfers this month. Please use "Quick Split".';
          _isLoading = false;
        });
        return;
      }

      final int updatedUsed = currentUsed + 1;
      await userRef.set(
        {
          'freeTransfersMonth': _currentMonthKey,
          'freeTransfersUsed': updatedUsed,
        },
        SetOptions(merge: true),
      );

      final qrLink = _buildQrLink(_savedPaymentLink, amount);

      setState(() {
        _remainingTransfers = (_monthlyLimit - updatedUsed).clamp(0, _monthlyLimit);
        _generatedQrPayload = qrLink;
        _generatedAmountText = '£${amount.toStringAsFixed(2)}';
        _isLoading = false;
      });
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
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
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
                      'Direct transfer via your saved payment link. Max £20 per transaction, up to 5 free transfers per month.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _savedProvider.isNotEmpty
                                ? 'Active link: $_savedProvider'
                                : (_savedPaymentLink.isNotEmpty ? 'Active payment link' : 'No payment link set'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Left: $_remainingTransfers / $_monthlyLimit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _remainingTransfers > 0 ? _primaryColor : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_generatedQrPayload == null) ...[
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount (£) - Max £20',
                          hintText: '19.90',
                          prefixIcon: const Icon(Icons.currency_pound),
                          filled: true,
                          fillColor: Colors.white,
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
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
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
                              'Scan with Phone Camera',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _generatedAmountText ?? '',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 20),
                            QrImageView(
                              data: _generatedQrPayload!,
                              version: QrVersions.auto,
                              size: 240.0,
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F172A),
                            ),
                            const SizedBox(height: 20),
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
                            _generatedAmountText = null;
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