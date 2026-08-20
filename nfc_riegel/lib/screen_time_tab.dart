import 'package:flutter/material.dart';

import 'riegel_channel.dart';
import 'screen_time.dart';
import 'theme.dart';

/// Tagesnutzung ab Mitternacht. Zweiter Reiter des Hauptschirms.
class ScreenTimeTab extends StatefulWidget {
  const ScreenTimeTab({
    super.key,
    this.channel = const RiegelChannel(),
    this.tabIndex,
  });

  final RiegelChannel channel;

  /// Eigener Platz in der umgebenden [TabBar]. Ist er gesetzt, liest der Reiter
  /// bei jedem Betreten neu. Ohne Angabe — etwa im Test — entfällt das.
  final int? tabIndex;

  @override
  State<ScreenTimeTab> createState() => _ScreenTimeTabState();
}

class _ScreenTimeTabState extends State<ScreenTimeTab>
    with WidgetsBindingObserver {
  bool _granted = false;
  List<AppUsage>? _apps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  TabController? _tabs;

  /// Der Lebenszyklus-Horcher allein genügt nicht: kommt die App aus dem
  /// Hintergrund zurück, während dieser Reiter schon gebaut ist, blieben die
  /// alten Zahlen stehen. Am Gerät waren es drei Abfragen hintereinander
  /// dieselben, obwohl die Nutzung gewachsen war. Beim Betreten neu lesen ist
  /// verlässlich — und ohnehin das, was man erwartet.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.tabIndex == null) return;
    final controller = DefaultTabController.maybeOf(context);
    if (controller == _tabs) return;
    _tabs?.removeListener(_onTabChanged);
    _tabs = controller;
    _tabs?.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final controller = _tabs;
    if (controller == null || controller.indexIsChanging) return;
    if (controller.index == widget.tabIndex) _refresh();
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Die Berechtigung wird auf einem Systemschirm erteilt. Beim Zurückkommen
  /// neu lesen — sonst stünde der Hinweis noch da, obwohl der Zugriff längst
  /// erlaubt ist, und man müsste die App schließen und wieder öffnen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final granted = await widget.channel.usageAccessGranted();
    final apps = granted ? await widget.channel.screenTimeToday() : <AppUsage>[];
    if (mounted) {
      setState(() {
        _granted = granted;
        _apps = apps;
      });
    }
  }

  Future<void> _requestAccess() => widget.channel.openUsageAccessSettings();

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    if (apps == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_granted) {
      return _AccessHint(onRequest: _requestAccess);
    }

    // Eine App zaehlt als erwaehnenswert, wenn sie vorn *oder* hinten ueber
    // einer Minute liegt. Ein Radiowecker, den man nie ansieht, gehoert in die
    // Liste — bisher fiel er heraus.
    final lang = apps
        .where(
          (a) => a.duration >= kUsageThreshold || a.background >= kUsageThreshold,
        )
        .toList();
    final kurz = apps.length - lang.length;
    final summe = apps.fold<Duration>(
      Duration.zero,
      (acc, a) => acc + a.duration,
    );
    final summeHintergrund = apps.fold<Duration>(
      Duration.zero,
      (acc, a) => acc + a.background,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        // Ohne dieses Physics-Objekt zieht sich eine kurze Liste nicht herunter
        // — und kurz ist sie an einem ruhigen Tag genau dann, wenn man
        // nachsehen will, ob schon etwas zusammengekommen ist.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(RiegelSpacing.s4),
        children: [
          Text('HEUTE', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: RiegelSpacing.s2),
          Text(
            formatUsage(summe),
            style: const TextStyle(
              fontFamily: kMonoFamily,
              fontSize: 34,
              color: RiegelColors.fg1,
            ),
          ),
          // Nicht in die grosse Zahl eingerechnet: Screenzeit ist Zeit am
          // Schirm. Musik im Hintergrund gehoert daneben, nicht hinein.
          if (summeHintergrund >= kUsageThreshold) ...[
            const SizedBox(height: RiegelSpacing.s1),
            Text(
              '+ ${formatUsage(summeHintergrund)} im Hintergrund',
              style: const TextStyle(
                fontFamily: kMonoFamily,
                fontSize: 13,
                color: RiegelColors.fg3,
              ),
            ),
          ],
          const SizedBox(height: RiegelSpacing.s6),
          if (lang.isEmpty)
            const Text('Heute noch keine App länger als eine Minute benutzt.'),
          for (final app in lang)
            Padding(
              padding: const EdgeInsets.only(bottom: RiegelSpacing.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      app.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: RiegelColors.fg1,
                      ),
                    ),
                  ),
                  const SizedBox(width: RiegelSpacing.s3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        // Ein Strich statt „0 min": die App war heute nur im
                        // Hintergrund taetig, und das steht in der Zeile darunter.
                        app.duration >= kUsageThreshold
                            ? formatUsage(app.duration)
                            : '–',
                        style: const TextStyle(
                          fontFamily: kMonoFamily,
                          fontSize: 13,
                          color: RiegelColors.fg2,
                        ),
                      ),
                      if (app.background >= kUsageThreshold)
                        Text(
                          '+ ${formatUsage(app.background)} Hintergrund',
                          style: const TextStyle(
                            fontFamily: kMonoFamily,
                            fontSize: 11,
                            color: RiegelColors.fg3,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (kurz > 0) ...[
            const SizedBox(height: RiegelSpacing.s2),
            Text(
              '$kurz weitere unter 1 Minute',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Solange die Sonderberechtigung fehlt, gibt es nichts anzuzeigen — also auch
/// keine leere Liste, sondern nur den Weg dorthin.
class _AccessHint extends StatelessWidget {
  const _AccessHint({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(RiegelSpacing.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Riegel darf die Nutzungsdaten noch nicht lesen. Ohne sie gibt es '
            'keine Screenzeit.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: RiegelColors.fg2),
          ),
          const SizedBox(height: RiegelSpacing.s4),
          FilledButton(
            onPressed: onRequest,
            child: const Text('Zugriff erlauben'),
          ),
        ],
      ),
    );
  }
}
