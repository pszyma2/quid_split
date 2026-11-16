import 'package:flutter/material.dart';
import 'quick_split_screen.dart';
import 'friend_transfer_screen.dart';
import 'group_gateway_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'QuidSplit',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'How would you like to split?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 56),
              _buildMainActionCard(
                context: context,
                title: 'Scan Bill',
                subtitle: 'Use camera to scan pub or restaurant receipt',
                icon: Icons.document_scanner_rounded,
                primaryColor: const Color(0xFF2563EB),
                onTap: () {
                  
                },
              ),
              const SizedBox(height: 24),
              _buildMainActionCard(
                context: context,
                title: 'Quick Split',
                subtitle: 'Enter amount manually for instant share',
                icon: Icons.calculate_rounded,
                primaryColor: const Color(0xFF10B981),
                onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const GroupGatewayScreen(),
    ),
  );
},
              ),
              const SizedBox(height: 24),
              _buildMainActionCard(
                context: context,
                title: 'Friend Transfer',
                subtitle: 'Free direct bank transfer via QR (Max £20)',
                icon: Icons.handshake_rounded,
                primaryColor: const Color(0xFF8B5CF6),
               onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const FriendTransferScreen(),
    ),
  );
},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      shadowColor: primaryColor.withValues(alpha: 0.15),
      elevation: 12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: primaryColor.withValues(alpha: 0.1),
        highlightColor: primaryColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 42,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}