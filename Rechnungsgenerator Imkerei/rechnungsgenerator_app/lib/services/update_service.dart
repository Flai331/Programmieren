import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../build_info.dart';
import '../utils/feedback_service.dart';

/// Was über eine veröffentlichte Fassung bekannt ist.
class UpdateInfo {
  /// Die laufende Nummer aus dem Tag `build-<N>`.
  final int buildNumber;

  /// Der Tag selbst, so wie er bei GitHub steht.
  final String tag;

  /// Woher das Paket zu holen ist.
  final String downloadUrl;

  /// Größe in Bytes, 0 wenn GitHub sie nicht nennt.
  final int sizeInBytes;

  /// Die Release-Notizen. Das ist die Commit-Beschreibung, also der
  /// einzige Ort, an dem steht, was sich geändert hat.
  final String notes;

  const UpdateInfo({
    required this.buildNumber,
    required this.tag,
    required this.downloadUrl,
    required this.sizeInBytes,
    required this.notes,
  });

  bool isNewerThan(int installedBuild) => buildNumber > installedBuild;

  /// Für die Anzeige: „38 MB". Vor dem Herunterladen über Mobilfunk ist das
  /// die Zahl, die der Imker wissen will.
  String get readableSize {
    if (sizeInBytes <= 0) return 'Größe unbekannt';
    final mb = sizeInBytes / (1024 * 1024);
    if (mb < 10) return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
    return '${mb.round()} MB';
  }

  /// Aus der Antwort von `releases/latest` lesen.
  ///
  /// Rein und damit prüfbar — das ganze Zerlegen steckt hier, nicht im
  /// Netzaufruf. Gibt null zurück, wenn die Veröffentlichung nichts
  /// Installierbares hergibt; die Gründe stehen jeweils daneben.
  static UpdateInfo? fromRelease(Map<String, dynamic> release) {
    final rohtag = release['tag_name'];
    if (rohtag is! String) return null;
    final tag = rohtag.trim();

    // Nur `build-<N>`. Ein anders benannter Tag ist keine Fassung dieser
    // App — und eine Nummer zu erraten wäre schlimmer als nichts zu tun.
    final treffer = RegExp(r'^build-(\d+)$').firstMatch(tag);
    if (treffer == null) return null;
    final nummer = int.tryParse(treffer.group(1)!);
    if (nummer == null) return null;

    final anhaenge = release['assets'];
    if (anhaenge is! List) return null;
    final apks = anhaenge.whereType<Map>().where((anhang) {
      final name = anhang['name'];
      return name is String && name.toLowerCase().endsWith('.apk');
    }).toList();

    // Genau eines. Keines heißt: nichts zu installieren (etwa ein Release,
    // dem nur ein .aab anhängt). Mehrere heißt: Die Wahl wäre geraten, und
    // das falsche Paket zu installieren ist schlimmer, als zu sagen, dass
    // es nicht geht.
    if (apks.length != 1) return null;

    final url = apks.single['browser_download_url'];
    if (url is! String || url.isEmpty) return null;

    final groesse = apks.single['size'];
    final hinweise = release['body'];

    return UpdateInfo(
      buildNumber: nummer,
      tag: tag,
      downloadUrl: url,
      sizeInBytes: groesse is int ? groesse : 0,
      notes: hinweise is String ? hinweise.trim() : '',
    );
  }
}

/// Wie die Nachfrage ausgegangen ist.
enum UpdateStatus {
  /// Die installierte Fassung ist die neueste.
  upToDate,

  /// Es gibt eine neuere.
  available,

  /// Kein Netz. Im Bienenstand der häufigste Fall.
  offline,

  /// GitHub war erreichbar, hat aber nichts Installierbares.
  noRelease,

  /// Etwas anderes ging schief.
  failed,
}

/// Das Ergebnis einer Nachfrage, mitsamt dem Satz, der dazu angezeigt wird.
class UpdateCheck {
  final UpdateStatus status;
  final UpdateInfo? info;

  /// Klartext für die Anzeige. Ein nackter Socket-Fehler hilft niemandem.
  final String? detail;

  const UpdateCheck(this.status, {this.info, this.detail});
}

/// Wie die Übergabe an den System-Installer ausgegangen ist.
enum InstallOutcome {
  /// Android hat die Installation übernommen und fragt den Imker.
  started,

  /// Die Erlaubnis „unbekannte Apps installieren" fehlt. Die
  /// Systemeinstellung dafür wurde geöffnet.
  permissionNeeded,

  /// Kein Android — hier gibt es keinen Installer.
  unsupported,

  /// Fehlgeschlagen.
  failed,
}

/// Nachsehen, ob es eine neuere BeeBrain gibt, sie holen und installieren.
///
/// Gegen die öffentliche GitHub-API, ohne Zugangsschlüssel: Das Repository
/// ist öffentlich. Das ist wichtig, denn ein Token im APK ließe sich
/// auslesen.
///
/// Geprüft wird nur auf Knopfdruck. Keine Hintergrundabfrage: Die API
/// erlaubt ohne Token 60 Anfragen je Stunde und Adresse, und ein
/// überraschender Download von Dutzenden Megabyte am Bienenstand wäre eine
/// Zumutung.
class UpdateService {
  static const String releaseUrl =
      'https://api.github.com/repos/Flai331/Programmieren/releases/latest';

  /// Nach Kotlin, siehe MainActivity.kt. Absichtlich kein Fremdpaket: Dieses
  /// Projekt hat file_picker wegen AGP 9 ganz verloren und den Bau an
  /// connectivity_plus 5 fast. Fünfzig Zeilen eigenes Kotlin tragen dieses
  /// Risiko nicht.
  static const MethodChannel _kanal = MethodChannel('beebrain/installer');

  /// GitHub weist Anfragen ohne User-Agent ab. Nur der App-Name und die
  /// Fassung — nichts über den Benutzer.
  static String get _userAgent => 'BeeBrain/$kBuildNumber';

  /// Nachsehen, ob etwas Neueres veröffentlicht ist.
  ///
  /// [installedBuild] ist herausziehbar, damit sich das Vergleichen prüfen
  /// lässt, ohne die Konstante im Quelltext zu ändern.
  Future<UpdateCheck> check({int installedBuild = kBuildNumber}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final anfrage = await client.getUrl(Uri.parse(releaseUrl));
      anfrage.headers
          .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      anfrage.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final antwort = await anfrage.close().timeout(const Duration(seconds: 20));

      if (antwort.statusCode == HttpStatus.notFound) {
        await antwort.drain();
        return const UpdateCheck(
          UpdateStatus.noRelease,
          detail: 'Es ist noch keine Fassung veröffentlicht.',
        );
      }
      if (antwort.statusCode == HttpStatus.forbidden ||
          antwort.statusCode == 429) {
        await antwort.drain();
        return const UpdateCheck(
          UpdateStatus.failed,
          detail: 'GitHub hat vorläufig genug Anfragen bekommen. '
              'In einer Stunde geht es wieder.',
        );
      }
      if (antwort.statusCode != HttpStatus.ok) {
        await antwort.drain();
        return UpdateCheck(
          UpdateStatus.failed,
          detail: 'GitHub antwortete mit ${antwort.statusCode}.',
        );
      }

      final text = await antwort.transform(utf8.decoder).join();
      final daten = jsonDecode(text);
      if (daten is! Map<String, dynamic>) {
        return const UpdateCheck(
          UpdateStatus.failed,
          detail: 'Unerwartete Antwort von GitHub.',
        );
      }

      final info = UpdateInfo.fromRelease(daten);
      if (info == null) {
        return const UpdateCheck(
          UpdateStatus.noRelease,
          detail: 'Der neuesten Veröffentlichung hängt kein installierbares '
              'Paket an.',
        );
      }

      return info.isNewerThan(installedBuild)
          ? UpdateCheck(UpdateStatus.available, info: info)
          : UpdateCheck(UpdateStatus.upToDate, info: info);
    } on SocketException {
      return const UpdateCheck(
        UpdateStatus.offline,
        detail: 'Keine Verbindung zu GitHub.',
      );
    } on TimeoutException {
      return const UpdateCheck(
        UpdateStatus.offline,
        detail: 'GitHub hat nicht geantwortet.',
      );
    } catch (e, s) {
      FeedbackService.logError(
        'Update-Prüfung fehlgeschlagen: $e',
        context: 'UpdateService.check',
        stackTrace: s,
      );
      return UpdateCheck(UpdateStatus.failed, detail: '$e');
    } finally {
      client.close();
    }
  }

  /// Das Paket in das Zwischenverzeichnis laden. Gibt den Pfad zurück, oder
  /// null, wenn es nicht geklappt hat.
  ///
  /// [onProgress] bekommt den Anteil zwischen 0 und 1 — bei Dutzenden
  /// Megabyte über Mobilfunk ist ein Balken ohne Fortschritt kaum von einem
  /// Hänger zu unterscheiden.
  ///
  /// Eine abgebrochene Datei wird gelöscht. Ein halbes Paket zu installieren
  /// scheitert nur mit einer Meldung, die niemand deuten kann.
  Future<String?> download(
    UpdateInfo info, {
    void Function(double anteil, int geladen, int gesamt)? onProgress,
  }) async {
    final ordner = await getTemporaryDirectory();
    final datei = File('${ordner.path}/${info.tag}.apk');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    IOSink? senke;
    try {
      if (await datei.exists()) await datei.delete();

      final anfrage = await client.getUrl(Uri.parse(info.downloadUrl));
      anfrage.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final antwort = await anfrage.close();
      if (antwort.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Herunterladen scheiterte mit ${antwort.statusCode}',
          uri: Uri.parse(info.downloadUrl),
        );
      }

      // contentLength ist bei GitHub gesetzt; die Größe aus dem Release ist
      // der Rückfall.
      final gesamt =
          antwort.contentLength > 0 ? antwort.contentLength : info.sizeInBytes;
      var geladen = 0;
      senke = datei.openWrite();
      await for (final stueck in antwort) {
        senke.add(stueck);
        geladen += stueck.length;
        if (onProgress != null) {
          onProgress(
            gesamt > 0 ? (geladen / gesamt).clamp(0.0, 1.0) : 0.0,
            geladen,
            gesamt,
          );
        }
      }
      await senke.flush();
      await senke.close();
      senke = null;

      FeedbackService.logEvent('Fassung geladen', details: {
        'Tag': info.tag,
        'Bytes': geladen.toString(),
      });
      return datei.path;
    } catch (e, s) {
      FeedbackService.logError(
        'Herunterladen fehlgeschlagen: $e',
        context: 'UpdateService.download',
        stackTrace: s,
      );
      try {
        await senke?.close();
      } catch (_) {
        // Beim Aufräumen ist ein Fehlschlag ohne Folgen.
      }
      try {
        if (await datei.exists()) await datei.delete();
      } catch (_) {
        // dito
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// Das geladene Paket dem System-Installer übergeben.
  ///
  /// Installieren darf nur Android selbst, und es fragt den Imker dabei. Ab
  /// Android 8 braucht die App dafür die Erlaubnis „unbekannte Apps
  /// installieren"; fehlt sie, öffnet der Kotlin-Teil die zugehörige
  /// Systemeinstellung, statt stumm zu scheitern.
  Future<InstallOutcome> install(String apkPath) async {
    try {
      final ergebnis =
          await _kanal.invokeMethod<String>('install', {'path': apkPath});
      switch (ergebnis) {
        case 'started':
          return InstallOutcome.started;
        case 'permission':
          return InstallOutcome.permissionNeeded;
        default:
          return InstallOutcome.failed;
      }
    } on MissingPluginException {
      // Kein Android — etwa im Test oder auf dem Rechner.
      return InstallOutcome.unsupported;
    } on PlatformException catch (e, s) {
      FeedbackService.logError(
        'Installation fehlgeschlagen: ${e.message}',
        context: 'UpdateService.install',
        stackTrace: s,
      );
      return InstallOutcome.failed;
    }
  }
}
