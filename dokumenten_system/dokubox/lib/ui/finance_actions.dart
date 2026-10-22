import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../data/finance.dart';

/// Schnellaktionen für Rechnungen und Einreichungen, gemeinsam genutzt von
/// Detailansicht und „Offene Posten".

Future<void> markPaid(BuildContext context, Document doc) async {
  await services.repository.markPaid(doc.id);
  await services.notifications.syncDocument(doc.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${doc.docNumber} als bezahlt markiert'),
    ));
  }
}

/// Nächster sinnvoller Schritt einer Einreichung.
String? nextClaimStatus(String status) => switch (status) {
      ClaimStatus.toSubmit => ClaimStatus.submitted,
      ClaimStatus.submitted => ClaimStatus.reimbursed,
      _ => null,
    };

String claimActionLabel(String status) => switch (status) {
      ClaimStatus.toSubmit => 'Eingereicht',
      ClaimStatus.submitted => 'Erstattet',
      _ => '',
    };

/// Setzt den Status einer Einreichung. Bei „erstattet" wird optional der
/// erhaltene Betrag abgefragt (Teil-Erstattungen sind häufig).
Future<void> advanceClaim(
    BuildContext context, Claim claim, String status) async {
  int? reimbursed;
  var finalStatus = status;
  if (status == ClaimStatus.reimbursed) {
    final result = await _askReimbursement(context, claim);
    if (result == null) return;
    reimbursed = result.cents;
    finalStatus = result.status;
  }
  final finance = await FinanceSettings.load();
  await services.repository.setClaimStatus(
    claim.id,
    finalStatus,
    reimbursedCents: reimbursed,
    followUpWeeks: finance.followUpWeeks,
  );
  await services.notifications.syncDocument(claim.documentId);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${claim.target}: $finalStatus'),
    ));
  }
}

Future<({int? cents, String status})?> _askReimbursement(
    BuildContext context, Claim claim) async {
  final controller = TextEditingController();
  var status = ClaimStatus.reimbursed;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Erstattung ${claim.target}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Erstatteter Betrag (optional)',
                suffixText: '€',
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: ClaimStatus.reimbursed, label: Text('voll')),
                ButtonSegment(value: ClaimStatus.partly, label: Text('teilweise')),
                ButtonSegment(
                    value: ClaimStatus.rejected, label: Text('abgelehnt')),
              ],
              selected: {status},
              onSelectionChanged: (s) => setState(() => status = s.first),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
  final text = controller.text;
  controller.dispose();
  if (ok != true) return null;
  return (cents: parseEuro(text), status: status);
}

/// "überfällig seit 3 Tagen", "heute fällig", "in 5 Tagen".
String dueLabel(DateTime due, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final days = DateUtils.dateOnly(due).difference(today).inDays;
  if (days < 0) return 'überfällig seit ${-days} ${days == -1 ? 'Tag' : 'Tagen'}';
  if (days == 0) return 'heute fällig';
  if (days == 1) return 'morgen fällig';
  return 'fällig in $days Tagen';
}

bool isOverdue(Document doc) =>
    doc.paymentStatus == PaymentStatus.open &&
    doc.dueDate != null &&
    DateUtils.dateOnly(doc.dueDate!)
        .isBefore(DateUtils.dateOnly(DateTime.now()));
