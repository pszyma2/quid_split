import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _isRestoring = false; // Przełącznik trybów

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your display name.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.registerNewUser(name);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreProfile() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Recovery Key.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.restoreAccount(key);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          )
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14142B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _isRestoring ? Icons.vpn_key_outlined : Icons.account_circle_outlined,
                size: 80,
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 32),
              Text(
                _isRestoring ? 'Restore Account' : 'Welcome',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _isRestoring 
                    ? 'Paste your 16-character recovery key.' 
                    : 'How should your friends call you?',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // POLA TEKSTOWE ZALEŻNE OD TRYBU
              if (!_isRestoring)
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Display Name (e.g. Paul)',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                )
              else
                TextField(
                  controller: _keyController,
                  style: const TextStyle(color: Colors.white, letterSpacing: 2),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'XXXX-XXXX-XXXX-XXXX',
                    hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 1),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                ),
                
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : (_isRestoring ? _restoreProfile : _createProfile),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _isRestoring ? 'Restore' : 'Continue',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),
              
              // PRZYCISK PRZEŁĄCZAJĄCY TRYB
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRestoring = !_isRestoring;
                  });
                },
                child: Text(
                  _isRestoring 
                      ? "I don't have a key. Create new account." 
                      : "Already have an account? Restore via Key",
                  style: const TextStyle(color: Colors.white54),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}