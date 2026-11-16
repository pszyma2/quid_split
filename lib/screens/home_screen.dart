import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/group_service.dart';
import 'group_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? currentUserId; 
  
  const HomeScreen({
    super.key, 
    this.currentUserId, 
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupService _groupService = GroupService();
  
  final Color _primaryColor = const Color(0xFF10B981);
  final Color _darkColor = const Color(0xFF0F172A);

  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  String get _safeUserId => widget.currentUserId ?? 'mock_user_id';

  @override
  void dispose() {
    _groupNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _showCreateGroupDialog() {
    _groupNameController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Trip'),
        content: TextField(
          controller: _groupNameController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Trip Name (e.g. Kraków, Pub)',
            prefixIcon: Icon(Icons.flight_takeoff),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () async {
              final name = _groupNameController.text.trim();
              if (name.isEmpty) return;

              try {
                final groupId = await _groupService.createGroup(name, _safeUserId);
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDashboardScreen(
                        groupId: groupId,
                        currentUserId: _safeUserId,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    _pinController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Trip'),
        content: TextField(
          controller: _pinController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Enter 6-digit PIN',
            prefixIcon: Icon(Icons.vpn_key),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _darkColor),
            onPressed: () async {
              final pin = _pinController.text.trim().toUpperCase();
              if (pin.length != 6) return;

              try {
                final groupId = await _groupService.joinGroupWithPin(pin, _safeUserId);
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDashboardScreen(
                        groupId: groupId,
                        currentUserId: _safeUserId,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(bool isClosed) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .where('members', arrayContains: _safeUserId)
          .where('status', isEqualTo: isClosed ? 'closed' : 'open')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading groups'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }

        final groups = snapshot.data?.docs.toList() ?? [];
        groups.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); 
        });

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isClosed ? Icons.inventory_2_outlined : Icons.flight_takeoff, 
                  size: 64, 
                  color: Colors.grey.shade300
                ),
                const SizedBox(height: 16),
                Text(
                  isClosed ? 'Archive is empty.' : 'No active trips.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16), 
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final data = group.data() as Map<String, dynamic>;
            final groupName = data['name'] ?? 'Unknown Trip';
            final pin = data['pin'] ?? '---';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: isClosed ? Colors.grey.shade100 : _primaryColor.withValues(alpha: 0.1),
                  child: Icon(
                    isClosed ? Icons.inventory_2 : Icons.local_fire_department,
                    color: isClosed ? Colors.grey : _primaryColor,
                  ),
                ),
                title: Text(
                  groupName, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 18,
                    color: isClosed ? Colors.grey.shade600 : Colors.black,
                  )
                ),
                subtitle: Text('PIN: $pin', style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDashboardScreen(
                        groupId: group.id,
                        currentUserId: _safeUserId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: _darkColor,
          elevation: 0,
          title: const Text(
            'QuidSplit', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF10B981),
            indicatorWeight: 3,
            labelColor: Color(0xFF10B981),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.local_fire_department), text: 'Active'),
              Tab(icon: Icon(Icons.inventory_2), text: 'Archive'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Pływająca lista wyjazdów
            Expanded(
              child: TabBarView(
                children: [
                  _buildGroupList(false), 
                  _buildGroupList(true),  
                ],
              ),
            ),
            
            // NOWY PANCERNY PANEL KONTROLNY NA SAMYM DOLE (Styl taki sam jak w kokpicie grupy)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showCreateGroupDialog,
                        icon: const Icon(Icons.flight_takeoff, color: Colors.white, size: 20),
                        label: const Text('New Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor, 
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showJoinGroupDialog,
                        icon: const Icon(Icons.vpn_key, color: Colors.white, size: 20),
                        label: const Text('Join PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _darkColor, 
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}