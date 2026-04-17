import 'package:flutter_test/flutter_test.dart';
import 'package:rechnungsgenerator_app/utils/utils.dart';

void main() {
  group('AppUtils Tests', () {
    group('formatDate', () {
      test('formatDate formats DateTime correctly', () {
        final date = DateTime(2026, 4, 17);
        final formatted = AppUtils.formatDate(date);

        expect(formatted, '17.04.2026');
      });

      test('formatDate with single digit day and month', () {
        final date = DateTime(2026, 1, 5);
        final formatted = AppUtils.formatDate(date);

        expect(formatted, '05.01.2026');
      });
    });

    group('parseDate', () {
      test('parseDate parses German format correctly', () {
        const dateString = '17.04.2026';
        final parsed = AppUtils.parseDate(dateString);

        expect(parsed, isNotNull);
        expect(parsed?.day, 17);
        expect(parsed?.month, 4);
        expect(parsed?.year, 2026);
      });

      test('parseDate with invalid format returns null', () {
        const dateString = '2026-04-17';
        final parsed = AppUtils.parseDate(dateString);

        expect(parsed, isNull);
      });

      test('parseDate with invalid date returns null', () {
        const dateString = 'invalid-date';
        final parsed = AppUtils.parseDate(dateString);

        expect(parsed, isNull);
      });
    });

    group('calculateTax', () {
      test('calculateTax with 19% tax rate', () {
        const subtotal = 100.0;
        const taxRate = 19.0;
        final tax = AppUtils.calculateTax(subtotal, taxRate);

        expect(tax, closeTo(19.0, 0.01));
      });

      test('calculateTax with 7% tax rate', () {
        const subtotal = 100.0;
        const taxRate = 7.0;
        final tax = AppUtils.calculateTax(subtotal, taxRate);

        expect(tax, closeTo(7.0, 0.01));
      });

      test('calculateTax with zero tax rate', () {
        const subtotal = 100.0;
        const taxRate = 0.0;
        final tax = AppUtils.calculateTax(subtotal, taxRate);

        expect(tax, 0.0);
      });

      test('calculateTax with decimal subtotal', () {
        const subtotal = 123.45;
        const taxRate = 19.0;
        final tax = AppUtils.calculateTax(subtotal, taxRate);

        expect(tax, closeTo(23.46, 0.01));
      });
    });

    group('calculateTotal', () {
      test('calculateTotal with subtotal and tax', () {
        const subtotal = 100.0;
        const tax = 19.0;
        final total = AppUtils.calculateTotal(subtotal, tax);

        expect(total, 119.0);
      });

      test('calculateTotal with zero tax', () {
        const subtotal = 100.0;
        const tax = 0.0;
        final total = AppUtils.calculateTotal(subtotal, tax);

        expect(total, 100.0);
      });

      test('calculateTotal with decimal values', () {
        const subtotal = 123.45;
        const tax = 23.46;
        final total = AppUtils.calculateTotal(subtotal, tax);

        expect(total, closeTo(146.91, 0.01));
      });
    });

    group('formatCurrency', () {
      test('formatCurrency formats double with comma separator', () {
        const value = 123.45;
        final formatted = AppUtils.formatCurrency(value);

        expect(formatted, contains(','));
        expect(formatted, contains('€'));
      });

      test('formatCurrency with whole number contains 00', () {
        const value = 100.0;
        final formatted = AppUtils.formatCurrency(value);

        expect(formatted, contains('00'));
        expect(formatted, contains('€'));
      });

      test('formatCurrency with large number contains thousand separator', () {
        const value = 1234.56;
        final formatted = AppUtils.formatCurrency(value);

        expect(formatted, contains('1'));
        expect(formatted, contains(','));
        expect(formatted, contains('€'));
      });
    });

    group('generateInvoiceNumber', () {
      test('generateInvoiceNumber generates valid format', () {
        final number = AppUtils.generateInvoiceNumber('RG', 0);
        final year = DateTime.now().year;

        expect(number, 'RG-$year-0001');
      });

      test('generateInvoiceNumber increments number', () {
        final num1 = AppUtils.generateInvoiceNumber('RG', 0);
        final num2 = AppUtils.generateInvoiceNumber('RG', 1);
        final year = DateTime.now().year;

        expect(num1, 'RG-$year-0001');
        expect(num2, 'RG-$year-0002');
      });

      test('generateInvoiceNumber with different prefix', () {
        final number = AppUtils.generateInvoiceNumber('INV', 99);
        final year = DateTime.now().year;

        expect(number, 'INV-$year-0100');
      });
    });
  });
}
