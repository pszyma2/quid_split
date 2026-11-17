import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart'; 
import '../services/group_service.dart';
import '../services/auth_service.dart'; 

class GroupDashboardScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupDashboardScreen({
    super.key,
    required this.groupId,
    this.currentUserId = 'mock_user_id', 
  });

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupService _groupService = GroupService();
  final AuthService _authService = AuthService(); 
  final Color _primaryColor = const Color(0xFF10B981);

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _personNameController = TextEditingController();

  bool _isSettling = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _personNameController.dispose();
    super.dispose();
  }

  Future<void> _addGhostUser() async {
    final name = _personNameController.text.trim();
    if (name.isEmpty) return;

    try {
      await _groupService.addGhostUserToGroup(
        groupId: widget.groupId,
        ghostName: name,
        currentUserId: widget.currentUserId,
      );
      
      _personNameController.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name added to the group!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding person: $e')),
        );
      }
    }
  }

  void _showAddPersonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Person'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add someone who doesn\'t have the app. You can assign expenses to them later.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _personNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Friend\'s Name (e.g., Aga)',
                prefixIcon: Icon(Icons.person),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: _addGhostUser,
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddExpenseDialog(List<dynamic> memberIds) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, String> membersMap = {};
    for (String id in memberIds) {
      if (id == widget.currentUserId) {
        membersMap[id] = 'You';
      } else {
        membersMap[id] = await _authService.getUserName(id);
      }
    }

    if (mounted) Navigator.pop(context); 

    // ZMIANA BŁĘDU: Kuloodporne sprawdzenie dla Dropdownu
    String? selectedPayerId;
    if (membersMap.containsKey(widget.currentUserId)) {
      selectedPayerId = widget.currentUserId;
    } else if (membersMap.isNotEmpty) {
      selectedPayerId = membersMap.keys.first;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Add New Expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'What for? (e.g., Pizza, Taxi)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (£)',
                    prefixIcon: Icon(Icons.currency_pound),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Who paid?',
                    prefixIcon: Icon(Icons.person),
                  ),
                  value: selectedPayerId,
                  isExpanded: true,
                  items: membersMap.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedPayerId = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                onPressed: () => _addExpense(selectedPayerId ?? widget.currentUserId),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _addExpense(String payerId) async {
    final amountText = _amountController.text.trim();
    final title = _titleController.text.trim();

    if (amountText.isEmpty || title.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    try {
      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses')
          .add({
        'title': title,
        'amount': amount,
        'paidBy': payerId, 
        'timestamp': FieldValue.serverTimestamp(),
      });

      _amountController.clear();
      _titleController.clear();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding expense: $e')),
        );
      }
    }
  }

  Future<void> _showEditExpenseDialog(
    String expenseId,
    String currentTitle,
    double currentAmount,
    String currentPaidBy,
    List<dynamic> memberIds,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, String> membersMap = {};
    for (String id in memberIds) {
      if (id == widget.currentUserId) {
        membersMap[id] = 'You';
      } else {
        membersMap[id] = await _authService.getUserName(id);
      }
    }

    if (mounted) Navigator.pop(context);

    final TextEditingController editTitleController = TextEditingController(text: currentTitle);
    final TextEditingController editAmountController = TextEditingController(text: currentAmount.toString());
    
    // ZMIANA BŁĘDU: Kuloodporne sprawdzenie dla edycji
    String? selectedPayerId;
    if (membersMap.containsKey(currentPaidBy)) {
      selectedPayerId = currentPaidBy;
    } else if (membersMap.isNotEmpty) {
      selectedPayerId = membersMap.keys.first;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Edit / Delete Expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editTitleController,
                  decoration: const InputDecoration(labelText: 'What for?'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: editAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (£)',
                    prefixIcon: Icon(Icons.currency_pound),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Who paid?',
                    prefixIcon: Icon(Icons.person),
                  ),
                  value: selectedPayerId,
                  isExpanded: true,
                  items: membersMap.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedPayerId = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  try {
                    await _firestore
                        .collection('groups')
                        .doc(widget.groupId)
                        .collection('expenses')
                        .doc(expenseId)
                        .delete();

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense deleted successfully')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error deleting expense: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                onPressed: () async {
                  final title = editTitleController.text.trim();
                  final amount = double.tryParse(editAmountController.text.trim());

                  if (title.isEmpty || amount == null || amount <= 0 || selectedPayerId == null) return;

                  try {
                    await _firestore
                        .collection('groups')
                        .doc(widget.groupId)
                        .collection('expenses')
                        .doc(expenseId)
                        .update({
                      'title': title,
                      'amount': amount,
                      'paidBy': selectedPayerId,
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense updated successfully')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating expense: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _settleGroup() async {
    setState(() => _isSettling = true);
    try {
      await _groupService.settleGroup(widget.groupId, widget.currentUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group settled successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error settling group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSettling = false);
    }
  }

  Future<void> _showPaymentQRCode(String creditorId, String creditorName, double amount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = await _firestore.collection('users').doc(creditorId).get();
      if (mounted) Navigator.pop(context); 

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$creditorName is a guest and doesn\'t have an account.')),
          );
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final sortCode = data['sortCode'] ?? '';
      final accountNumber = data['accountNumber'] ?? '';

      if (sortCode.isEmpty || accountNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$creditorName hasn\'t added their bank details securely yet.')),
          );
        }
        return;
      }

      final displaySortCode = '${sortCode.substring(0, 2)}-${sortCode.substring(2, 4)}-${sortCode.substring(4, 6)}';
      final qrPayload = "paym://payment?name=${Uri.encodeComponent(creditorName)}&sc=$sortCode&acc=$accountNumber&amt=$amount";

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Pay $creditorName', 
              textAlign: TextAlign.center, 
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Scan with your banking app', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 200.0,
                    foregroundColor: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '£${amount.toStringAsFixed(2)}', 
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _primaryColor)
                ),
                const SizedBox(height: 8),
                Text(
                  'SC: $displaySortCode\nACC: $accountNumber', 
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFF64748B)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  Widget _buildSettlementResults(List<dynamic> settlement, bool isAdmin) {
    if (settlement.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Text(
          'Group settled! Everyone is even.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Final Settlement',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          ...settlement.map((s) {
            final double amount = (s['amount'] as num).toDouble();
            final String fromId = s['fromUserId'];
            final String toId = s['toUserId'];
            
            final bool isPaid = s['isPaid'] ?? false; 

            Future<String> resolveName(String id) async {
              if (id == widget.currentUserId) return 'You';
              return await _authService.getUserName(id);
            }

            return FutureBuilder<List<String>>(
              future: Future.wait([resolveName(fromId), resolveName(toId)]),
              builder: (context, snapshot) {
                String fromName = '...';
                String toName = '...';

                if (snapshot.hasData) {
                  fromName = snapshot.data![0];
                  toName = snapshot.data![1];
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isPaid ? Colors.grey.shade50 : Colors.green.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isPaid ? Colors.grey.shade300 : Colors.green.shade200,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isPaid ? Icons.check_circle : Icons.payment, 
                      color: isPaid ? Colors.grey : Colors.green
                    ),
                    title: Text(
                      '$fromName must pay $toName', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: isPaid ? TextDecoration.lineThrough : null,
                        color: isPaid ? Colors.grey.shade600 : Colors.black,
                      )
                    ),
                    subtitle: isPaid 
                      ? Text('Settled', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold))
                      : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isPaid)
                          IconButton(
                            icon: Icon(Icons.qr_code_scanner, color: _primaryColor),
                            tooltip: 'Pay via QR Code',
                            onPressed: () => _showPaymentQRCode(toId, toName, amount),
                          ),
                        Text(
                          '£${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isPaid ? Colors.grey.shade500 : Colors.green,
                            decoration: isPaid ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (isAdmin)
                          Checkbox(
                            value: isPaid,
                            activeColor: Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (bool? newValue) async {
                              if (newValue != null) {
                                try {
                                  await _groupService.toggleDebtPaymentStatus(
                                    widget.groupId, 
                                    fromId, 
                                    toId, 
                                    newValue
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Group Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.hasError) return const Center(child: Text('Error loading group data.'));
          if (groupSnapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _primaryColor));

          final groupData = groupSnapshot.data?.data() as Map<String, dynamic>?;
          if (groupData == null) return const Center(child: Text('Group not found.'));

          final bool isClosed = groupData['status'] == 'closed';
          final bool isAdmin = groupData['adminId'] == widget.currentUserId;
          final List<dynamic> settlementData = groupData['settlement'] ?? [];
          final List<dynamic> members = groupData['members'] as List<dynamic>? ?? [];

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFF0F172A),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('Group PIN', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      groupData['pin'] ?? 'ERROR',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 8,
                      ),
                    ),
                    if (isClosed)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                        child: const Text('SETTLED & CLOSED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('expenses')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, expenseSnapshot) {
                    if (expenseSnapshot.hasError) return const Center(child: Text('Error loading expenses.'));
                    if (expenseSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    final expenses = expenseSnapshot.data?.docs ?? [];
                    if (expenses.isEmpty) {
                      return const Center(
                        child: Text('No expenses yet. Add the first one!', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expDoc = expenses[index];
                        final expenseId = expDoc.id; 
                        final expData = expDoc.data() as Map<String, dynamic>;
                        
                        final amount = expData['amount'] ?? 0.0;
                        final title = expData['title'] ?? 'Unknown';
                        final String paidById = expData['paidBy'] ?? widget.currentUserId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            onTap: () {
                              if (!isClosed) {
                                _showEditExpenseDialog(
                                  expenseId,
                                  title,
                                  amount,
                                  paidById,
                                  members,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Cannot edit expenses in a settled group.')),
                                );
                              }
                            },
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: _primaryColor.withValues(alpha: 0.1),
                              child: Icon(Icons.receipt_long, color: _primaryColor),
                            ),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            
                            subtitle: FutureBuilder<String>(
                              future: paidById == widget.currentUserId 
                                  ? Future.value('You') 
                                  : _authService.getUserName(paidById),
                              builder: (context, snapshot) {
                                final name = snapshot.data ?? '...';
                                return Text(!isClosed ? 'Paid by: $name (Tap to edit)' : 'Paid by: $name');
                              },
                            ),
                            
                            trailing: Text(
                              '£${amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              
              if (isClosed)
                _buildSettlementResults(settlementData, isAdmin)
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showAddPersonDialog,
                                icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
                                label: const Text('Add Person', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 19, 45, 105),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showAddExpenseDialog(members),
                                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                                label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor, 
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _isSettling ? null : _settleGroup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 205, 3, 77),
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isSettling
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Settle Up Group', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}