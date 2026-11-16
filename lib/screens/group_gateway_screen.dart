import 'package:flutter/material.dart';
import '../services/group_service.dart'; 
import 'group_dashboard_screen.dart';

class GroupGatewayScreen extends StatefulWidget {
  final String currentUserId;

  const GroupGatewayScreen({
    super.key,
    this.currentUserId = 'mock_user_id', // Tymczasowe ID na czas testów bez logowania
  });

  @override
  State<GroupGatewayScreen> createState() => _GroupGatewayScreenState();
}

class _GroupGatewayScreenState extends State<GroupGatewayScreen> {
  final TextEditingController _pinController = TextEditingController();
  final GroupService _groupService = GroupService();
  
  bool _isLoading = false;
  String? _errorMessage;

  final Color _primaryColor = const Color(0xFF10B981); // Nasza komercyjna zieleń

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _createNewGroup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String groupId = await _groupService.createGroup('New Group', widget.currentUserId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );
        // Przejście do Kokpitu Grupy po utworzeniu
        Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDashboardScreen(groupId: groupId)));
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup() async {
    final pin = _pinController.text.trim().toUpperCase();
    
    if (pin.length != 6) {
      setState(() => _errorMessage = 'PIN must be exactly 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String groupId = await _groupService.joinGroupWithPin(pin, widget.currentUserId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined group successfully!')),
        );
        // Przejście do Kokpitu Grupy po dołączeniu
        Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDashboardScreen(groupId: groupId)));
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Group Setup',
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
        child: _isLoading 
          ? Center(
              child: CircularProgressIndicator(color: _primaryColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Opcja 1: Założenie nowej grupy
                  const Text(
                    'Start a New Group',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a new group to track shared expenses and settle up later.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _createNewGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Create New Group',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Kreska oddzielająca
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Opcja 2: Dołączenie do istniejącej
                  const Text(
                    'Join Existing Group',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the 6-character PIN provided by the group creator.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Pole na PIN
                  TextField(
                    controller: _pinController,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: 'XXXXXX',
                      filled: true,
                      fillColor: Colors.white,
                      counterText: '', // Ukrywa licznik znaków pod polem
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Błędy (jeśli są)
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  ElevatedButton(
                    onPressed: _joinGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A), // Ciemny kontrastowy
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Join Group',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}