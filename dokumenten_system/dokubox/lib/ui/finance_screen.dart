import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../data/document_repository.dart';
import '../data/finance.dart';
import 'document_detail_screen.dart';
import 'finance_actions.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// Offene Posten: Rechnungen, die noch bezahlt werden müssen, und
/// Einreichungen (Krankenkasse, Beihilfe, Heilfürsorge …), die noch
/// einzureichen sind oder auf Erstattung warten.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Offene Posten'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.payments_outlined), text: 'Zu bezahlen'),
              Tab(
                  icon: Icon(Icons.local_hospital_outlined),
                  text: 'Erstattungen'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_PaymentsTab(), _ClaimsTab()],
        ),
      ),
    );
  }
}

void _openDocument(BuildContext context, String id) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: id)));

String _docLabel(Document doc) => doc.title.isEmpty ? doc.docNumber : doc.title;

class _Summary extends StatelessWidget {
  final String label;
  final int cents;
  final String? detail;

  const _Summary({required this.label, required this.cents, this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  if (detail != null)
                    Text(detail!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Text(formatEuro(cents),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Document>>(
      stream: services.repository.watchOpenPayments(),
      builder: (context, snapshot) {
        final docs = snapshot.data;
        if (docs == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (docs.isEmpty) {
          return const _Empty('Alles bezahlt. 🎉\n\nGescannte Rechnungen mit '
              'Status „zu bezahlen" erscheinen hier – mit Erinnerung vor '
              'der Fälligkeit.');
        }
        final total = docs.fold<int>(0, (s, d) => s + (d.amountCents ?? 0));
        final overdue = docs.where(isOverdue).length;
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Summary(
              label: '${docs.length} offene Rechnung(en)',
              cents: total,
              detail: overdue > 0 ? 'davon $overdue überfällig' : null,
            ),
            for (final doc in docs)
              ListTile(
                leading: Icon(
                  isOverdue(doc) ? Icons.warning_amber : Icons.receipt_long,
                  color: isOverdue(doc) ? theme.colorScheme.error : null,
                ),
                title: Text(_docLabel(doc)),
                subtitle: Text([
                  doc.docNumber,
                  if (doc.amountCents != null) formatEuro(doc.amountCents!),
                  if (doc.dueDate != null)
                    '${_dateFormat.format(doc.dueDate!)} · '
                        '${dueLabel(doc.dueDate!)}'
                  else
                    'ohne Fälligkeit',
                ].join(' · ')),
                subtitleTextStyle: isOverdue(doc)
                    ? theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error)
                    : null,
                trailing: FilledButton.tonal(
                  onPressed: () => markPaid(context, doc),
                  child: const Text('Bezahlt'),
                ),
                onTap: () => _openDocument(context, doc.id),
              ),
          ],
        );
      },
    );
  }
}

class _ClaimsTab extends StatelessWidget {
  const _ClaimsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OpenClaim>>(
      stream: services.repository.watchOpenClaims(),
      builder: (context, snapshot) {
        final claims = snapshot.data;
        if (claims == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (claims.isEmpty) {
          return const _Empty('Nichts einzureichen. 🎉\n\nArzt-, Zahnarzt- '
              'und Apothekenrechnungen werden automatisch erkannt. Wo du '
              'einreichst (Krankenkasse, Beihilfe, Heilfürsorge …), legst du '
              'in den Einstellungen fest.');
        }
        final pending = claims
            .where((c) => c.claim.status == ClaimStatus.submitted)
            .fold<int>(0, (s, c) => s + (c.document.amountCents ?? 0));
        final toSubmit =
            claims.where((c) => c.claim.status == ClaimStatus.toSubmit);
        final submitted =
            claims.where((c) => c.claim.status == ClaimStatus.submitted);
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Summary(
              label: 'Eingereicht, Erstattung ausstehend',
              cents: pending,
              detail: '${toSubmit.length} noch einzureichen',
            ),
            if (toSubmit.isNotEmpty) const _Header('Noch einreichen'),
            for (final c in toSubmit) _ClaimTile(c),
            if (submitted.isNotEmpty) const _Header('Warten auf Erstattung'),
            for (final c in submitted) _ClaimTile(c),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _ClaimTile extends StatelessWidget {
  final OpenClaim item;

  const _ClaimTile(this.item);

  @override
  Widget build(BuildContext context) {
    final claim = item.claim;
    final doc = item.document;
    final next = nextClaimStatus(claim.status);
    return ListTile(
      leading: const Icon(Icons.local_hospital_outlined),
      title: Text(_docLabel(doc)),
      subtitle: Text([
        claim.target,
        if (doc.amountCents != null) formatEuro(doc.amountCents!),
        if (claim.submittedAt != null)
          'eingereicht ${_dateFormat.format(claim.submittedAt!)}',
        if (doc.paymentStatus == PaymentStatus.open) 'noch nicht bezahlt',
      ].join(' · ')),
      trailing: next == null
          ? null
          : FilledButton.tonal(
              onPressed: () => advanceClaim(context, claim, next),
              child: Text(claimActionLabel(claim.status)),
            ),
      onTap: () => _openDocument(context, doc.id),
    );
  }
}
