import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Normalise a phone number to digits-only with country code.
///
/// - Strips spaces, dashes, parentheses, and the leading `+`.
/// - If the number starts with `0`, replaces it with `963` (Syria default).
/// - Returns `null` when the result is too short to be valid.
String? normalizePhone(String raw) {
  // Keep digits only
  String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

  if (digits.isEmpty) return null;

  // Replace leading 0 with Syria country code
  if (digits.startsWith('0')) {
    digits = '963${digits.substring(1)}';
  }

  // Must be at least 10 digits (country code + local)
  if (digits.length < 10) return null;

  return digits;
}

/// Open WhatsApp directly to a specific chat with a pre-filled message.
///
/// Returns `true` if WhatsApp opened successfully, `false` otherwise.
Future<bool> openWhatsAppChat({
  required String phone,
  required String message,
}) async {
  final normalized = normalizePhone(phone);
  if (normalized == null) return false;

  final encoded = Uri.encodeComponent(message);
  final uri = Uri.parse('https://wa.me/$normalized?text=$encoded');

  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    return launched;
  } catch (_) {
    return false;
  }
}

/// Build a formatted order message for WhatsApp.
String buildOrderMessage({
  required String pharmacyName,
  required String representativeName,
  required int orderId,
  required String orderDate,
  required List<Map<String, dynamic>> items,
  bool pricingEnabled = false,
  String currencySymbol = '\$',
  String currencyMode = 'usd',
  double exchangeRate = 1.0,
}) {
  final buffer = StringBuffer();

  buffer.writeln('📋 *طلبية جديدة*');
  buffer.writeln('━━━━━━━━━━━━━━');
  buffer.writeln('🏥 الصيدلية: *$pharmacyName*');
  if (representativeName.isNotEmpty) {
    buffer.writeln('👤 المندوب: *$representativeName*');
  }
  buffer.writeln('🔢 رقم الطلبية: #$orderId');
  buffer.writeln('📅 التاريخ: $orderDate');
  buffer.writeln('━━━━━━━━━━━━━━');
  buffer.writeln('');

  double grandTotal = 0;

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    final name = item['medicine_name'] ?? 'غير معروف';
    final company = item['company_name'] ?? '';
    final qty = (item['qty'] as num?)?.toInt() ?? 0;
    final giftQty = (item['gift_qty'] as num?)?.toInt() ?? 0;
    final isGift = (item['is_gift'] as int? ?? 0) == 1;
    final priceUsd = (item['price_usd'] as num?)?.toDouble() ?? 0.0;

    double displayPrice = priceUsd;
    if (pricingEnabled && currencyMode == 'syp') {
      displayPrice = priceUsd * exchangeRate;
    }
    final lineTotal = displayPrice * qty;
    if (!isGift) grandTotal += lineTotal;

    buffer.write('${i + 1}. *$name*');
    if (company.isNotEmpty) buffer.write(' — $company');
    buffer.writeln('');
    buffer.write('   الكمية: $qty');
    if (isGift) {
      buffer.write('  🎁 هدية');
    } else if (giftQty > 0) {
      buffer.write('  🎁 هدية: $giftQty');
    }
    if (pricingEnabled && !isGift) {
      buffer.write('  💰 ${lineTotal.toStringAsFixed(2)} $currencySymbol');
    }
    buffer.writeln('');
  }

  if (pricingEnabled && items.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('━━━━━━━━━━━━━━');
    buffer.writeln('💰 *المجموع: ${grandTotal.toStringAsFixed(2)} $currencySymbol*');
  }

  buffer.writeln('');
  buffer.writeln('— المندوب الذكي 📱');

  return buffer.toString();
}

/// Show a "WhatsApp not available" dialog.
void showWhatsAppUnavailableDialog(BuildContext context, {String? reason}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text('تنبيه', textDirection: TextDirection.rtl),
        ],
      ),
      content: Text(
        reason ?? 'تعذّر فتح واتساب.\nتأكد من تثبيت واتساب وتحديثه ثم أعد المحاولة.',
        textDirection: TextDirection.rtl,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

