// lib/services/payment_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentService {
  // Twój bezpieczny klucz testowy (Secret Key)
  String stripeSecret = 'TUTAJ_BEDZIE_KLUCZ_STRIPE';
  final String _stripeSecretKey = 'TUTAJ_BEDZIE_FAŁSZYWY_KLUCZ';
  Future<String> generatePaymentLink({
    required double amount,
    required String title,
    required String toUser,
  }) async {
    print('🔧 [PaymentService] Rozpoczynam połączenie ze Stripe...');

    // Stripe przyjmuje kwoty w najmniejszej jednostce (np. pensy zamiast funtów).
    // Dlatego mnożymy kwotę przez 100. Np. £10.50 to 1050 pensów.
    final int amountInPence = (amount * 100).round();

    try {
      // Uderzamy prosto w API Checkout Sessions firmy Stripe
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/checkout/sessions'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          // Na razie ustawiamy płatność kartą (w ustawieniach Stripe odblokujemy Open Banking)
          
          'line_items[0][price_data][currency]': 'gbp',
          'line_items[0][price_data][product_data][name]': 'Zrzutka: $title (od $toUser)',
          'line_items[0][price_data][unit_amount]': amountInPence.toString(),
          'line_items[0][quantity]': '1',
          'mode': 'payment',
          // Gdzie przekierować klienta po udanej lub anulowanej płatności
          'success_url': 'https://pagstudio.app/success.html', 
          'cancel_url': 'https://pagstudio.app',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String checkoutUrl = data['url'];
        
        print('✅ [PaymentService] Sukces! Wygenerowano prawdziwy link: $checkoutUrl');
        return checkoutUrl;
      } else {
        print('❌ [PaymentService] Błąd serwera Stripe: ${response.body}');
        throw Exception('Błąd generowania linku: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PaymentService] Błąd sieci: $e');
      throw Exception('Nie udało się połączyć ze Stripe');
    }
  }
}