import '../extract/extractors.dart';

/// GiroCode (EPC-QR, EPC069-12, Version 002) für eine SEPA-Überweisung.
/// Liefert den QR-Inhalt oder wirft [FormatException] mit verständlichem
/// Grund.
String buildGiroCode({
  required String name,
  required String iban,
  String? bic,
  int? amountCents,
  String reference = '',
}) {
  final cleanIban = iban.replaceAll(RegExp(r'\s'), '').toUpperCase();
  if (!isValidIban(cleanIban)) {
    throw const FormatException('IBAN ist ungültig.');
  }
  final payee = name.trim();
  if (payee.isEmpty) throw const FormatException('Empfänger fehlt.');
  if (amountCents != null && (amountCents < 1 || amountCents > 99999999999)) {
    throw const FormatException('Betrag ist ungültig.');
  }
  String cut(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
  final amount = amountCents == null
      ? ''
      : 'EUR${amountCents ~/ 100}.${(amountCents % 100).toString().padLeft(2, '0')}';
  return [
    'BCD',
    '002',
    '1', // UTF-8
    'SCT',
    (bic ?? '').replaceAll(' ', '').toUpperCase(),
    cut(payee, 70),
    cleanIban,
    amount,
    '', // Purpose
    '', // strukturierte Referenz
    cut(reference.replaceAll('\n', ' ').trim(), 140),
  ].join('\n');
}
