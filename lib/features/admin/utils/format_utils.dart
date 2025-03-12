import 'package:intl/intl.dart';

class FormatUtils {
  /// Format tanggal ISO 8601 menjadi string yang lebih user-friendly
  static String formatDate(String? dateStr,
      {String format = 'dd MMM yyyy, HH:mm'}) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat(format).format(date);
    } catch (e) {
      return '-';
    }
  }

  /// Format angka menjadi format mata uang Rupiah
  static String formatCurrency(num? value) {
    if (value == null) return 'Rp 0';
    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return format.format(value);
  }

  /// Format nomor telepon ke format internasional Indonesia
  static String formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    // Ubah format 08xx... menjadi +628xx...
    if (phone.startsWith('0')) {
      return '+62${phone.substring(1)}';
    }
    // Tambahkan +62 jika belum ada kode negara
    if (!phone.startsWith('+')) {
      return '+62$phone';
    }
    return phone;
  }

  /// Format WhatsApp URL
  static String formatWhatsAppUrl(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    final formattedPhone = phone.startsWith('0')
        ? '62${phone.substring(1)}'
        : phone.startsWith('+')
            ? phone.substring(1)
            : phone;
    return 'https://wa.me/$formattedPhone';
  }
}
