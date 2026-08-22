import 'package:intl/intl.dart';

class AppUtils {
  // ============ DATE FORMATTING ============

  static String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  static String formatDateISO(DateTime date) {
    return date.toIso8601String();
  }

  static DateTime? parseDate(String dateStr) {
    try {
      return DateFormat('dd.MM.yyyy').parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  // ============ CURRENCY FORMATTING ============

  static String formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'de_DE',
      symbol: '€',
      decimalDigits: 2,
    ).format(amount);
  }

  static String formatNumber(double number, {int? decimalDigits}) {
    final format = NumberFormat.decimalPattern('de_DE');
    if (decimalDigits != null) {
      format.minimumFractionDigits = decimalDigits;
      format.maximumFractionDigits = decimalDigits;
    }
    return format.format(number);
  }

  /// Zahl aus einer Nutzereingabe lesen – akzeptiert deutsche und englische
  /// Schreibweise ('12,5' wie '12.5'). Leere oder ungültige Eingabe → null.
  static double? parseNumber(String input) {
    final cleaned = input.trim().replaceAll(' ', '');
    if (cleaned.isEmpty) return null;
    // Beide Trennzeichen vorhanden: das letzte ist das Dezimaltrennzeichen.
    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');
    String normalized;
    if (lastComma >= 0 && lastDot >= 0) {
      normalized = lastComma > lastDot
          ? cleaned.replaceAll('.', '').replaceAll(',', '.')
          : cleaned.replaceAll(',', '');
    } else if (lastComma >= 0) {
      normalized = cleaned.replaceAll(',', '.');
    } else {
      normalized = cleaned;
    }
    return double.tryParse(normalized);
  }

  // ============ INVOICE OPERATIONS ============

  static String generateInvoiceNumber(String prefix, int lastNumber) {
    final number = lastNumber + 1;
    final year = DateTime.now().year;
    return '$prefix-$year-${number.toString().padLeft(4, '0')}';
  }

  static String? parseInvoiceNumber(String invoiceNumber) {
    // Returns just the numeric part if valid format
    final parts = invoiceNumber.split('-');
    if (parts.length == 3) {
      return parts[2]; // Return the numeric part
    }
    return null;
  }

  // ============ CALCULATION UTILITIES ============

  static double calculateTax(double subtotal, double taxRate) {
    return subtotal * (taxRate / 100);
  }

  static double calculateTotal(double subtotal, double tax) {
    return subtotal + tax;
  }

  static double calculateItemTotal(double quantity, double price) {
    return quantity * price;
  }

  // ============ STRING UTILITIES ============

  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String truncate(String text, int length) {
    if (text.length <= length) return text;
    return '${text.substring(0, length)}...';
  }

  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  static bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-()]{7,}$');
    return phoneRegex.hasMatch(phone);
  }

  static bool isValidIBAN(String iban) {
    return iban.replaceAll(RegExp(r'\s'), '').length >= 15;
  }

  // ============ LIST UTILITIES ============

  static List<T> removeDuplicates<T>(List<T> list) {
    return list.toSet().toList();
  }

  static List<T> sortByDate<T extends Comparable>(
    List<T> list, {
    bool ascending = true,
  }) {
    list.sort((a, b) => ascending ? a.compareTo(b) : b.compareTo(a));
    return list;
  }

  // ============ DISPLAY UTILITIES ============

  static String getAddressDisplay(
    String street,
    String zipcode,
    String city,
  ) {
    return '$street\n$zipcode $city';
  }

  static String getFullAddress(
    String name,
    String street,
    String zipcode,
    String city,
  ) {
    return '$name\n$street\n$zipcode $city';
  }

  // ============ FILE UTILITIES ============

  static String getFileExtension(String filename) {
    return filename.split('.').last;
  }

  static bool isImageFile(String filename) {
    final ext = getFileExtension(filename).toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ============ EXCEPTION HANDLING ============

  static String getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return error.toString();
  }
}
