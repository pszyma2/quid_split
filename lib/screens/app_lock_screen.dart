import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'terms_screen.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String _authStatus = 'Secured connection';

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
        _authStatus = 'Authenticating...';
      });

      authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access QuidSplit',
      );
    } catch (e) {
      debugPrint('Error authenticating: $e');
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _authStatus = 'Authentication error. Try again.';
        });
      }
      return;
    }

    if (authenticated && mounted) {
      await _checkTermsAndNavigate();
    } else if (mounted) {
      setState(() {
        _isAuthenticating = false;
        _authStatus = 'Authentication failed. Try again.';
      });
    }
  }

  Future<void> _checkTermsAndNavigate() async {
    bool hasAcceptedTerms = false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 5));
        final data = doc.data();
        hasAcceptedTerms = data?['termsAccepted'] == true;
      }
    } catch (e) {
      debugPrint('Error checking terms acceptance: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            hasAcceptedTerms ? const HomeScreen() : const TermsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Color(0xFF10B981)),
            const SizedBox(height: 24),
            const Text(
              'QuidSplit Locked',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _authStatus,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 40),
            if (_isAuthenticating)
              const CircularProgressIndicator(color: Color(0xFF10B981))
            else
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint, color: Colors.white),
                label: const Text(
                  'Unlock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}