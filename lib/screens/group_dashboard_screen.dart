import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/group_service.dart';
import '../services/auth_service.dart'; // Podpięty serwis do tłumaczenia imion

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
  final AuthService _authService = AuthService(); // Inicjalizacja serwisu
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

  // --- LOGIKA DODAWANIA WIRTUALNEGO ZNAJOMEGO ---
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
  // ----------------------------------------------

  Future<void> _addExpense() async {
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
        'paidBy': widget.currentUserId,
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

  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: _addExpense,
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementResults(List<dynamic> settlement) {
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

            // Funkcja pomocnicza tłumacząca ID na Imię
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
                  color: Colors.green.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.green.shade200),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.payment, color: Colors.green),
                    title: Text('$fromName must pay $toName', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text(
                      '£${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.green,
                      ),
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
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
            builder: (context, snapshot) {
              final isClosed = snapshot.data?.get('status') == 'closed';
              if (isClosed) return const SizedBox.shrink();
              
              return IconButton(
                icon: const Icon(Icons.person_add_alt_1),
                tooltip: 'Add Person',
                onPressed: _showAddPersonDialog,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.hasError) {
            return const Center(child: Text('Error loading group data.'));
          }
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _primaryColor));
          }

          final groupData = groupSnapshot.data?.data() as Map<String, dynamic>?;
          if (groupData == null) {
            return const Center(child: Text('Group not found.'));
          }

          final bool isClosed = groupData['status'] == 'closed';
          final bool isAdmin = groupData['adminId'] == widget.currentUserId;
          final List<dynamic> settlementData = groupData['settlement'] ?? [];

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFF0F172A),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Group PIN',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      groupData['pin'] ?? 'ERROR',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    if (isClosed)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'SETTLED & CLOSED',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
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
                    if (expenseSnapshot.hasError) {
                      return const Center(child: Text('Error loading expenses.'));
                    }
                    if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final expenses = expenseSnapshot.data?.docs ?? [];

                    if (expenses.isEmpty) {
                      return const Center(
                        child: Text(
                          'No expenses yet. Add the first one!',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expData = expenses[index].data() as Map<String, dynamic>;
                        final amount = expData['amount'] ?? 0.0;
                        final title = expData['title'] ?? 'Unknown';
                        final paidBy = expData['paidBy'] == widget.currentUserId 
                            ? 'You' 
                            : 'Someone'; // Tutaj też będziemy podmieniać w przyszłości

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: _primaryColor.withValues(alpha: 0.1),
                              child: Icon(Icons.receipt_long, color: _primaryColor),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('Paid by: $paidBy'),
                            trailing: Text(
                              '£${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (isClosed)
                _buildSettlementResults(settlementData)
              else if (isAdmin)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSettling ? null : _settleGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSettling
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Settle Up Group',
                            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          final isClosed = snapshot.data?.get('status') == 'closed';
          if (isClosed) return const SizedBox.shrink();
          
          return FloatingActionButton.extended(
            onPressed: _showAddExpenseDialog,
            backgroundColor: _primaryColor,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
          );
        },
      ),
    );
  }
}