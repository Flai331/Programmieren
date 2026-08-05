import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'build_info.dart';
import 'home_screen.dart';
import 'lock_status.dart';
import 'riegel_channel.dart';
import 'secrets.dart';
import 'setup_wizard.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Die obersten Zeilen eines Stack-Trace. Mehr passt ohnehin nicht in ein
/// Notion-Textfeld, und der Ursprung steht oben.
String _firstFrames(StackTrace? stack, [int lines = 6]) {
  if (stack == null) return '(kein Stack)';
  return stack.toString().split('\n').take(lines).join('\n');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FeedbackService.configure(
    notionToken: Secrets.notionToken,
    notionDbId: Secrets.notionDatabaseId,
    appName: 'Riegel',
    supportEmail: Secrets.supportEmail,
    buildNumber: kBuildNumber,
  );
  FeedbackService.setNavigatorKey(navigatorKey);

  // Abstürze landen im Protokoll und öffnen den Melde-Dialog. Bewusst nicht
  // `logError` — das verschickt von selbst, und eine App, die das Handy
  // zusperrt, soll nicht unaufgefordert ins Netz funken. Gesendet wird erst,
  // wenn im Dialog auf Senden getippt wird.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FeedbackService.log('Flutter-Fehler: ${details.exceptionAsString()}');
    FeedbackService.log('Stack: ${_firstFrames(details.stack)}');
    FeedbackService.showAutoErrorDialog();
  };

  // Alles, was außerhalb des Widget-Baums fliegt.
  PlatformDispatcher.instance.onError = (error, stack) {
    FeedbackService.log('Fehler: $error');
    FeedbackService.log('Stack: ${_firstFrames(stack)}');
    FeedbackService.showAutoErrorDialog();
    return true;
  };

  runApp(const RiegelApp());
}

class RiegelApp extends StatelessWidget {
  const RiegelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riegel',
      navigatorKey: navigatorKey,
      navigatorObservers: [FeedbackService.screenObserver],
      theme: buildRiegelTheme(),
      home: const _Entry(),
    );
  }
}

/// Entscheidet beim Start zwischen Einrichtung und Hauptscreen.
class _Entry extends StatefulWidget {
  const _Entry();

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  final _channel = const RiegelChannel();
  LockStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await _channel.getState();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Scaffold(
        backgroundColor: RiegelColors.bgBase,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return status.setupComplete
        ? const HomeScreen()
        : SetupWizard(onFinished: _load);
  }
}
