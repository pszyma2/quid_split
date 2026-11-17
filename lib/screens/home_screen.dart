import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quick_split_screen.dart';
import 'friend_transfer_screen.dart';
import 'group_gateway_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String get _safeUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 19, 40, 88),
        elevation: 0,
        title: const Text(
          'QuidSplit', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What do you need to do?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to split or transfer money today.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),

              // Opcja 1: Quick Split (Teraz Pomarańczowy)
              _buildFeatureCard(
                context: context,
                title: 'Quick Split',
                subtitle: 'Split a one-off bill (e.g. dinner, pub round) on the spot.',
                icon: Icons.receipt_long,
                color: const Color(0xFFF59E0B), // Zmieniono na pomarańczowy
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QuickSplitScreen()),
                  );
                },
              ),
              
              const SizedBox(height: 16),

              // Opcja 2: Friend Transfer (Zostaje Fioletowy)
              _buildFeatureCard(
                context: context,
                title: 'Free Bank Transfer',
                subtitle: 'Generate a QR code for a direct transfer up to £20.',
                icon: Icons.qr_code_scanner,
                color: const Color(0xFF8B5CF6), 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FriendTransferScreen(currentUserId: _safeUserId),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Opcja 3: Group Trips (Teraz Zielony)
              _buildFeatureCard(
                context: context,
                title: 'Group Trips',
                subtitle: 'Create or join a group for ongoing trip expenses.',
                icon: Icons.flight_takeoff,
                color: const Color(0xFF10B981), // Zmieniono na zielony
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupGatewayScreen(currentUserId: _safeUserId),
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

  // ZMIENIONE: Funkcja budująca kafelki z cieniem i kolorowym tłem
  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        // Lekkie zabarwienie tła w kolorze przypisanym do opcji zamiast czystej bieli
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        // Subtelna obwódka jak w rozliczeniach (Group Dashboard)
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          // Miękki cień pod spodem, leciutko wpadający w kolor kafelka
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Strzałka w kolorze przypisanym do przycisku
                Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}