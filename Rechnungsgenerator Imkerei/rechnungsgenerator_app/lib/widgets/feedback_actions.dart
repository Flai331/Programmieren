import 'package:flutter/material.dart';
import '../utils/feedback_service.dart';

/// Zwei AppBar-Buttons für jeden Screen:
///   🐛  Fehlerbericht öffnen
///   ⚡  Manueller Testfehler (löst Auto-Error-Dialog aus)
class FeedbackActions extends StatelessWidget {
  const FeedbackActions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Manueller Fehlerauslöser
        IconButton(
          icon: const Icon(Icons.electric_bolt_outlined),
          tooltip: 'Testfehler auslösen',
          onPressed: () {
            FeedbackService.logError(
              '⚡ Manueller Testfehler ausgelöst',
              context: 'FeedbackActions',
            );
            FeedbackService.showReportDialog(context, isAutoError: true);
          },
        ),
        // Fehlerbericht
        IconButton(
          icon: const Icon(Icons.bug_report_outlined),
          tooltip: 'Fehler melden',
          onPressed: () => FeedbackService.showReportDialog(context),
        ),
      ],
    );
  }
}
