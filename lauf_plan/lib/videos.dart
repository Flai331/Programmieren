import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Erklärvideos: YouTube-Suche nach der richtigen Ausführung.
// Bewusst eine Suche statt fester Video-Links – die gehen nie kaputt,
// auch wenn einzelne Videos gelöscht werden.
// Nur für das Beintraining (Beine A + B).
// Schlüssel = Übungsname aus dem Plan.
const Map<String, String> exerciseVideos = {
  // Beine A
  'Kniebeuge (Langhantel)': 'Kniebeuge Langhantel richtige Ausführung',
  'Rumänisches Kreuzheben': 'Rumänisches Kreuzheben richtige Ausführung',
  'Bulgarian Split Squat': 'Bulgarian Split Squat richtige Ausführung',
  'Wadenheben einbeinig halten': 'Wadenheben einbeinig Achillessehne isometrisch',
  'Copenhagen Plank': 'Copenhagen Plank Adduktoren Anleitung',
  // Beine B
  'Hip Thrust': 'Hip Thrust Langhantel richtige Ausführung',
  'Einbeiniges Kreuzheben (KH)': 'Einbeiniges Kreuzheben Kurzhantel Ausführung',
  'Monster Walks mit Band': 'Monster Walks Miniband Ausführung',
  'Tibialis Raises': 'Tibialis Raises an der Wand Anleitung',
  'Finisher': 'Schlitten schieben Sled Push Technik',
};

Uri videoUri(String query) => Uri.https(
    'www.youtube.com', '/results', {'search_query': query});

Future<void> openVideo(BuildContext context, String exerciseName) async {
  final query = exerciseVideos[exerciseName];
  if (query == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  var ok = false;
  try {
    ok = await launchUrl(videoUri(query), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) {
    messenger?.showSnackBar(
        const SnackBar(content: Text('Video konnte nicht geöffnet werden.')));
  }
}

class VideoButton extends StatelessWidget {
  final String exerciseName;
  const VideoButton({super.key, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => openVideo(context, exerciseName),
      icon: const Icon(Icons.smart_display_outlined),
      label: const Text('Erklärvideo ansehen'),
    );
  }
}
