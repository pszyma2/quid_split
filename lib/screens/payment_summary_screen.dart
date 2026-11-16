import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quid_split/services/payment_service.dart';

class PaymentSummaryScreen extends StatelessWidget {
  final String title;
  final List < Map < String, dynamic > > participants;
  final double totalAmount;

  const PaymentSummaryScreen({
    super.key,
    required this.title,
    required this.participants,
    required this.totalAmount,
  });

  void _showQrCode(BuildContext context, String name, double amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.only(top: 8, left: 24, right: 24, bottom: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Scan to pay',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B).withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '£${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'for $title',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 40),
            
            // --- TUTAJ WJEŻDŻA NASZ NOWY SILNIK (FutureBuilder) ---
            FutureBuilder<String>(
              future: PaymentService().generatePaymentLink(
                amount: amount,
                title: title,
                toUser: 'Paweł', // Tutaj w przyszłości wejdą dane z konta
              ),
              builder: (context, snapshot) {
                // 1. Oczekiwanie na serwer (kręcimy kółkiem)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 336, // Zbliżona wysokość QR kodu i przycisku, żeby UI nie skakało
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  );
                } 
                // 2. Błąd połączenia
                else if (snapshot.hasError) {
                  return const SizedBox(
                    height: 336,
                    child: Center(
                      child: Text(
                        'Błąd połączenia z serwerem płatności.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                } 
                // 3. Sukces! Mamy link, wyświetlamy QR i przycisk Share
                else if (snapshot.hasData) {
                  final paymentLink = snapshot.data!;
                  
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: QrImageView(
                          data: paymentLink, // Prawdziwy link z serwera
                          version: QrVersions.auto,
                          size: 240.0,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0F172A),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final String message = '🧾 QuidSplit Receipt\n\nHi $name, your split for "$title" is £${amount.toStringAsFixed(2)}.\n\nTap to pay:\n$paymentLink\n\nThanks!';
                            Share.share(message);
                          },
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text('Send Receipt via WhatsApp'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF2563EB), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
            // --- KONIEC FutureBuilder ---
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Collection',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Total for',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Text(
                      '£${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Tap person to show QR code',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final person = participants[index];
                  final name = person['name'] as String;
                  final amount = person['amount'] as double;
                  
                  final isMe = name.toLowerCase() == 'me';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 2,
                      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.05),
                      child: InkWell(
                        onTap: isMe ? null : () => _showQrCode(context, name, amount),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isMe 
                                      ? const Color(0xFFF1F5F9) 
                                      : const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    isMe ? Icons.check_circle_rounded : Icons.qr_code_2_rounded,
                                    color: isMe ? const Color(0xFF94A3B8) : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Text(
                                '£${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isMe ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}