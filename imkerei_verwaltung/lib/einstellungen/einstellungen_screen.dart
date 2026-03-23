// ═══════════════════════════════════════════════════════════════
//  Einstellungen Screen
//  lib/einstellungen/einstellungen_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../utils/storage_service.dart';

class EinstellungenScreen extends StatelessWidget {
  const EinstellungenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _abschnittTitel('App Info'),
          _infoKarte(),
          const SizedBox(height: 20),
          _abschnittTitel('Daten'),
          _datenverwaltung(context),
          const SizedBox(height: 20),
          _abschnittTitel('Hinweise'),
          _hinweise(),
        ],
      ),
    );
  }

  Widget _abschnittTitel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _infoKarte() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🐝', style: TextStyle(fontSize: 32)),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Imkerei Verwaltung',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: AppColors.textHint, height: 24),
          const Text(
            'Verwalte deine Bienenvölker, Inspektionen, Ernten und Behandlungen – alles lokal auf deinem Gerät gespeichert.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _datenverwaltung(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading:
                const Icon(Icons.delete_forever, color: AppColors.red),
            title: const Text('Alle Daten löschen',
                style: TextStyle(color: AppColors.red)),
            subtitle: const Text('Unwiderruflich alle gespeicherten Daten löschen',
                style: TextStyle(color: AppColors.textHint, fontSize: 12)),
            onTap: () => _allesDatenLoeschen(context),
          ),
        ],
      ),
    );
  }

  Widget _hinweise() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HinweisZeile(
            Icons.lock,
            'Datenschutz',
            'Alle Daten bleiben lokal auf deinem Gerät. Keine Cloud, kein Server.',
          ),
          SizedBox(height: 10),
          _HinweisZeile(
            Icons.vapora_lock,
            'Varroakontrolle',
            'Ab 3% Varroa-Befall sollte eine Behandlung eingeleitet werden.',
          ),
          SizedBox(height: 10),
          _HinweisZeile(
            Icons.water_drop,
            'Honig-Wassergehalt',
            'Honig mit über 18% Wassergehalt kann zu gären beginnen – immer nachmessen!',
          ),
          SizedBox(height: 10),
          _HinweisZeile(
            Icons.star,
            'Königin-Markierung',
            'International: Weiß (1/6), Gelb (2/7), Rot (3/8), Grün (4/9), Blau (5/0)',
          ),
        ],
      ),
    );
  }

  Future<void> _allesDatenLoeschen(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Alle Daten löschen',
            style: TextStyle(color: AppColors.red)),
        content: const Text(
          'Alle Völker, Standorte, Inspektionen, Ernten und Behandlungen werden unwiderruflich gelöscht!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Alles löschen',
                  style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.saveVoelker([]);
      await StorageService.saveStandorte([]);
      await StorageService.saveInspektionen([]);
      await StorageService.saveErnten([]);
      await StorageService.saveBehandlungen([]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alle Daten gelöscht.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }
}

class _HinweisZeile extends StatelessWidget {
  final IconData icon;
  final String titel;
  final String text;

  const _HinweisZeile(this.icon, this.titel, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.honey, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titel,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              Text(text,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
