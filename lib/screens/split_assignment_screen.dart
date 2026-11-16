import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'payment_summary_screen.dart';

class ParticipantItem {
  final TextEditingController nameController;
  final TextEditingController amountController;

  ParticipantItem({
    required this.nameController,
    required this.amountController,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class SplitAssignmentScreen extends StatefulWidget {
  final String title;
  final double totalAmount;

  const SplitAssignmentScreen({
    super.key,
    required this.title,
    required this.totalAmount,
  });

  @override
  State<SplitAssignmentScreen> createState() => _SplitAssignmentScreenState();
}

class _SplitAssignmentScreenState extends State<SplitAssignmentScreen> {
  final List<ParticipantItem> _participants = [];
  double _remainingAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _remainingAmount = widget.totalAmount;
    _addParticipant(initialName: 'Me');
  }

  @override
  void dispose() {
    for (var participant in _participants) {
      participant.dispose();
    }
    super.dispose();
  }

  void _addParticipant({String initialName = ''}) {
    final newItem = ParticipantItem(
      nameController: TextEditingController(text: initialName),
      amountController: TextEditingController(),
    );

    newItem.amountController.addListener(_calculateRemaining);

    setState(() {
      _participants.add(newItem);
    });
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants[index].dispose();
      _participants.removeAt(index);
    });
    _calculateRemaining();
  }

  void _calculateRemaining() {
    double currentSum = 0.0;
    for (var item in _participants) {
      final amount = double.tryParse(item.amountController.text) ?? 0.0;
      currentSum += amount;
    }
    
    setState(() {
      _remainingAmount = widget.totalAmount - currentSum;
    });
  }

  void _generateReceipt() {
    if (_remainingAmount != 0) return;
    
    bool hasEmptyNames = _participants.any((p) => p.nameController.text.trim().isEmpty);
    if (hasEmptyNames) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter names for all participants.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final List<Map<String, dynamic>> finalParticipants = _participants.map((p) {
      return {
        'name': p.nameController.text.trim(),
        'amount': double.tryParse(p.amountController.text) ?? 0.0,
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSummaryScreen(
          title: widget.title,
          totalAmount: widget.totalAmount,
          participants: finalParticipants,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOverLimit = _remainingAmount < 0;
    final isPerfectlySplit = _remainingAmount == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total to split',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '£${widget.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Remaining',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '£${_remainingAmount.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isOverLimit
                            ? Colors.redAccent
                            : (isPerfectlySplit ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _participants.length,
                itemBuilder: (context, index) {
                  return _buildParticipantCard(index);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton.icon(
                onPressed: _addParticipant,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add Person'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB), width: 2),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isPerfectlySplit ? _generateReceipt : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isPerfectlySplit ? 'Generate Receipt' : 'Split the remaining £${_remainingAmount.abs().toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantCard(int index) {
    final participant = _participants[index];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: participant.nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Name (e.g. Gerwazy)',
                hintStyle: TextStyle(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: participant.amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF10B981),
              ),
              decoration: InputDecoration(
                prefixText: '£ ',
                prefixStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                ),
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (_participants.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                onPressed: () => _removeParticipant(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }
}