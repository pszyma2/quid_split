import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_dashboard_screen.dart';
import 'group_gateway_screen.dart';

class MyGroupsScreen extends StatefulWidget {
  const MyGroupsScreen({super.key});

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color _primaryColor = const Color(0xFF10B981);
  final Color _darkColor = const Color(0xFF0F172A);

  String get _safeUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _showRenameGroupDialog(String groupId, String currentName) async {
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameGroupDialog(
        initialName: currentName,
        primaryColor: _primaryColor,
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    try {
      await _firestore.collection('groups').doc(groupId).update({
        'name': newName,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group renamed to "$newName".')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error renaming group: $e')),
        );
      }
    }
  }

  void _showDeleteGroupConfirmation(String groupId, String groupName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$groupName"?'),
        content: const Text(
          'This will permanently delete this closed trip and all its expenses from the archive. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore.collection('groups').doc(groupId).delete();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trip deleted from archive.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting trip: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
                  color: Colors.grey.shade300,
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
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final data = group.data() as Map<String, dynamic>;
            final groupName = data['name'] ?? 'Unknown Trip';
            final pin = data['pin'] ?? '---';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              elevation: 0,
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: isClosed
                      ? Colors.grey.shade100
                      : _primaryColor.withValues(alpha: 0.1),
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
                  ),
                ),
                subtitle: Text(
                  'PIN: $pin',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: Colors.grey.shade600),
                      tooltip: 'Rename Group',
                      onPressed: () {
                        _showRenameGroupDialog(group.id, groupName);
                      },
                    ),
                    if (isClosed)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Delete Group',
                        onPressed: () {
                          _showDeleteGroupConfirmation(group.id, groupName);
                        },
                      )
                    else
                      const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
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
          backgroundColor: _primaryColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'My Group Trips',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.local_fire_department), text: 'Active Trips'),
              Tab(icon: Icon(Icons.inventory_2), text: 'Archive'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGroupList(false),
            _buildGroupList(true),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupGatewayScreen(currentUserId: _safeUserId),
              ),
            );
          },
          backgroundColor: _darkColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'New / Join',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _RenameGroupDialog extends StatefulWidget {
  final String initialName;
  final Color primaryColor;

  const _RenameGroupDialog({
    required this.initialName,
    required this.primaryColor,
  });

  @override
  State<_RenameGroupDialog> createState() => _RenameGroupDialogState();
}

class _RenameGroupDialogState extends State<_RenameGroupDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Group'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Enter new group name',
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: widget.primaryColor, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: widget.primaryColor),
          onPressed: () {
            final newName = _controller.text.trim();
            if (newName.isEmpty) return;
            Navigator.pop(context, newName);
          },
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}