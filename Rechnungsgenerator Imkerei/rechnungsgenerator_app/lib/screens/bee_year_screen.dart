import 'package:flutter/material.dart';
import '../utils/feedback_service.dart';
import 'hive_list_screen.dart';
import 'season_screen.dart';

/// Imkerei-Tab: Umschalter zwischen dem Völkerbestand und den saisonalen
/// Arbeitslisten.
///
/// Beides gehört fachlich zusammen und teilt sich deshalb einen Tab – die
/// Navigationsleiste ist mit neun Einträgen schon gut gefüllt.
class BeeYearScreen extends StatefulWidget {
  const BeeYearScreen({Key? key}) : super(key: key);

  @override
  State<BeeYearScreen> createState() => _BeeYearScreenState();
}

class _BeeYearScreenState extends State<BeeYearScreen> {
  bool _showSeason = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Völker'),
                icon: Icon(Icons.hive_outlined, size: 18),
              ),
              ButtonSegment(
                value: true,
                label: Text('Saison'),
                icon: Icon(Icons.event_note_outlined, size: 18),
              ),
            ],
            selected: {_showSeason},
            onSelectionChanged: (s) {
              setState(() => _showSeason = s.first);
              FeedbackService.logScreenLoad(
                  _showSeason ? 'Saison' : 'Völker');
            },
          ),
        ),
        Expanded(
          // Key je Ansicht: beim Umschalten wird neu geladen, damit eine
          // gerade erfasste Maßnahme sofort in der Saison-Liste auftaucht.
          child: _showSeason
              ? const SeasonScreen(key: ValueKey('saison'))
              : const HiveListScreen(key: ValueKey('voelker')),
        ),
      ],
    );
  }
}
