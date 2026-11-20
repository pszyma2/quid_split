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
  final TextEditingController _paymentLinkController = TextEditingController();

  final List<String> _providers = ['Revolut', 'Starling', 'Monzo', 'PayPal'];
  String _selectedProvider = 'Revolut';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasSavedDetails = false;
  bool _isEditing = false;

  String _savedSortCode = '';
  String _savedAccountNumber = '';
  String _savedPaymentLink = '';
  String _savedProvider = '';

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  String _detectProvider(String link) {
    final lower = link.toLowerCase();
    if (lower.contains('starling')) return 'Starling';
    if (lower.contains('monzo')) return 'Monzo';
    if (lower.contains('paypal')) return 'PayPal';
    return 'Revolut';
  }

  String _getHintForProvider(String provider) {
    switch (provider) {
      case 'Starling':
        return 'https://settleup.starlingbank.com/yourname';
      case 'Monzo':
        return 'https://monzo.me/yourname';
      case 'PayPal':
        return 'https://paypal.me/yourname';
      case 'Revolut':
      default:
        return 'https://revolut.me/yourname';
    }
  }

  Future<void> _loadBankDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final sc = (data['sortCode'] ?? '').toString().trim();
        final ac = (data['accountNumber'] ?? '').toString().trim();
        final link = (data['paymentLink'] ?? '').toString().trim();
        final provider = (data['paymentProvider'] ?? '').toString().trim();

        if ((sc.isNotEmpty && ac.isNotEmpty) || link.isNotEmpty) {
          setState(() {
            _savedSortCode = sc;
            _savedAccountNumber = ac;
            _savedPaymentLink = link;
            _savedProvider = provider.isNotEmpty ? provider : (link.isNotEmpty ? _detectProvider(link) : '');
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

  void _startEditing() {
    setState(() {
      _sortCodeController.text = _savedSortCode;
      _accountNumberController.text = _savedAccountNumber;
      _paymentLinkController.text = _savedPaymentLink;
      _selectedProvider = _savedProvider.isNotEmpty ? _savedProvider : 'Revolut';
      _isEditing = true;
    });
  }

  Future<void> _saveDetails() async {
    final sortCode = _sortCodeController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    String paymentLink = _paymentLinkController.text.trim();

    final hasBankInput = sortCode.isNotEmpty || accountNumber.isNotEmpty;
    final hasLinkInput = paymentLink.isNotEmpty;

    if (!hasBankInput && !hasLinkInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your bank details or a payment link to save.')),
      );
      return;
    }

    if (hasBankInput) {
      if (sortCode.length != 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sort code must be 6 digits.')),
        );
        return;
      }
      if (accountNumber.length != 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account number must be 8 digits.')),
        );
        return;
      }
    }

    if (hasLinkInput) {
      if (!paymentLink.startsWith('http://') && !paymentLink.startsWith('https://')) {
        paymentLink = 'https://$paymentLink';
      }
      final uri = Uri.tryParse(paymentLink);
      if (uri == null || !uri.hasAuthority || !uri.host.contains('.')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid $_selectedProvider link.')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final Map<String, dynamic> updateData = {};
      if (hasBankInput) {
        updateData['sortCode'] = sortCode;
        updateData['accountNumber'] = accountNumber;
      } else {
        updateData['sortCode'] = FieldValue.delete();
        updateData['accountNumber'] = FieldValue.delete();
      }

      if (hasLinkInput) {
        updateData['paymentLink'] = paymentLink;
        updateData['paymentProvider'] = _selectedProvider;
      } else {
        updateData['paymentLink'] = FieldValue.delete();
        updateData['paymentProvider'] = FieldValue.delete();
      }

      await _firestore.collection('users').doc(user!.uid).set(
        updateData,
        SetOptions(merge: true),
      );

      setState(() {
        _savedSortCode = hasBankInput ? sortCode : '';
        _savedAccountNumber = hasBankInput ? accountNumber : '';
        _savedPaymentLink = hasLinkInput ? paymentLink : '';
        _savedProvider = hasLinkInput ? _selectedProvider : '';
        _hasSavedDetails = true;
        _isEditing = false;
        _sortCodeController.clear();
        _accountNumberController.clear();
        _paymentLinkController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment details securely saved.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDeleteDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Payment Details?'),
        content: const Text(
          'This will permanently delete your receiving bank details and payment link from the database. You can add them again at any time.',
        ),
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
                  'paymentLink': FieldValue.delete(),
                  'paymentProvider': FieldValue.delete(),
                });
                setState(() {
                  _hasSavedDetails = false;
                  _isEditing = false;
                  _savedSortCode = '';
                  _savedAccountNumber = '';
                  _savedPaymentLink = '';
                  _savedProvider = '';
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment details removed.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
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
    _paymentLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showSummary = _hasSavedDetails && !_isEditing;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Bank Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF10B981),
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
                                Text(
                                  '100% Safe & Secure',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 16),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'QuidSplit never touches your money. Your details are only shown to members of your groups so they can copy your UK bank details or scan your payment link QR code.',
                                  style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (showSummary) ...[
                      const Text(
                        'Your Receiving Details',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
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
                            if (_savedSortCode.isNotEmpty && _savedAccountNumber.isNotEmpty) ...[
                              const Text(
                                'SORT CODE',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatSortCode(_savedSortCode),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Divider(),
                              ),
                              const Text(
                                'ACCOUNT NUMBER',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _maskAccountNumber(_savedAccountNumber),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                            if (_savedSortCode.isNotEmpty && _savedPaymentLink.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Divider(),
                              ),
                            if (_savedPaymentLink.isNotEmpty) ...[
                              Text(
                                '${_savedProvider.toUpperCase()} PAYMENT LINK (QR)',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _savedPaymentLink,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _startEditing,
                        icon: const Icon(Icons.edit_outlined, color: Colors.white),
                        label: const Text(
                          'Edit / Add Payment Link',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _confirmDeleteDetails,
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text(
                          'Remove Payment Details',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'UK Bank Transfer (Optional)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 28),
                      const Text(
                        'Instant Payment Link for QR (Optional)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose your provider and paste your payment link to generate a scannable QR code.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _providers.map((provider) {
                          final isSelected = _selectedProvider == provider;
                          return ChoiceChip(
                            label: Text(
                              provider,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF10B981),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedProvider = provider);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _paymentLinkController,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: '$_selectedProvider Payment Link',
                          hintText: _getHintForProvider(_selectedProvider),
                          prefixIcon: const Icon(Icons.qr_code_2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Securely Save Details',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => _isEditing = false),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}