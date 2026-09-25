# Parkplatz-Merker – Plan „Widget: Wo steht mein Auto?“

Neues Homescreen-Widget **„Mein Auto“** (zusätzlich zum kleinen „Hier geparkt“-Widget):

```
┌──────────────────────────────────────┐
│ [Karte   ]  Dein Auto steht           │
│ [ mit 🚗 ]  seit 14:32                 │
│ [        ]  Hauptstraße 5, Musterstadt │
│             📝 Parkhaus Ebene 3        │
│ © OSM       [Navigation] [Hier geparkt]│
└──────────────────────────────────────┘
```
- Tippen auf Karte/Text → App öffnen. „Navigation“ → Fußweg in Google Maps.
  „Hier geparkt“ → wie das kleine Widget.
- Kein Parkplatz → „Noch kein Parkplatz gemerkt“.

## Kernproblem: Aktualisierung ohne geöffnete App
Die Erkennung (reine Dart-Logik) lief bisher nur bei geöffneter App. Neu:
ein **Hintergrund-Lauf** startet kurz eine unsichtbare Flutter-Engine mit dem
Einstiegspunkt `backgroundMain()`, die genau dasselbe tut wie die App beim
Öffnen (`AppController.refresh()`) und danach das Widget aktualisiert.

### Wann läuft der Hintergrund-Lauf?
- `TripService.stopEverything()` → `BackgroundRunner.schedule(ctx, 60_000L, 7)` und
  `schedule(ctx, 16 * 60_000L, 8)` (nach 16 min greift „ohne Gehen trotzdem Parkplatz“).
- Nach einem `manual`-Ereignis aus Widget/Kachel (`TripService.onManual`) →
  `schedule(ctx, 3_000L, 9)`.
- NICHT, wenn die App gerade sichtbar ist (`MainActivity.visible == true`) – dann macht
  die App es selbst (15-s-Takt).

## Kotlin

### `BackgroundRunner.kt` – `object BackgroundRunner`
```kotlin
fun schedule(ctx: Context, delayMs: Long, requestCode: Int)
    // PendingIntent.getBroadcast(ctx, requestCode, Intent(ctx, BackgroundRunReceiver::class.java),
    //     FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE)
    // val at = System.currentTimeMillis() + delayMs
    // am = AlarmManager; wenn API < 31 || am.canScheduleExactAlarms():
    //     am.setExactAndAllowWhileIdle(RTC_WAKEUP, at, pi) sonst am.setAndAllowWhileIdle(RTC_WAKEUP, at, pi)
    // in try/catch; Fehler → EventLog.info

@Volatile private var engine: FlutterEngine? = null

/** Startet die Hintergrund-Engine; [done] genau einmal (Ende oder Zeitlimit 25 s). Main-Thread! */
fun run(ctx: Context, done: () -> Unit)
    // if (MainActivity.visible || engine != null) { done(); return }
    // val app = ctx.applicationContext
    // val loader = FlutterInjector.instance().flutterLoader()
    // loader.startInitialization(app); loader.ensureInitializationComplete(app, null)
    // val e = FlutterEngine(app)          // registriert Plugins automatisch
    // engine = e
    // val finished = AtomicBoolean(false)
    // val finish = { if (!finished.getAndSet(true)) { handler.removeCallbacks(timeout); try { e.destroy() } catch (_: Exception) {}; engine = null; done() } }
    // val timeout = Runnable { EventLog.info(app, "Hintergrund-Lauf: Zeitlimit"); finish() }
    // MethodChannel(e.dartExecutor.binaryMessenger, "parkplatz_merker/native")
    //     .setMethodCallHandler(BackgroundHandler(app) { finish() })
    // e.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "backgroundMain"))
    // handler.postDelayed(timeout, 25_000L)
    // alles in try/catch → bei Fehler EventLog.info + finish()
```
(`timeout` vor `finish` deklarieren bzw. als `lateinit var`/Feld lösen – Kotlin erlaubt
keinen Vorwärtsbezug in lokalen Lambdas.)

### `BackgroundRunReceiver.kt`
```kotlin
class BackgroundRunReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Handler(Looper.getMainLooper()).post {
            BackgroundRunner.run(context) { pending.finish() }
        }
    }
}
```
Manifest: `<receiver android:name=".BackgroundRunReceiver" android:exported="false"/>`.

### `BackgroundHandler.kt` – `class BackgroundHandler(ctx, onDone: () -> Unit) : MethodChannel.MethodCallHandler`
Nur diese Methoden (sonst `result.notImplemented()`), gleiche Formate wie MainActivity:
- `drainEvents` → `EventLog.drain(ctx)`
- `getConfig` → `Config.getConfig()`
- `registerTransitions` → `result.success(mapOf("ok" to true, "error" to null))` (nichts tun)
- `getLastLocation` → wie MainActivity (`LocationHelper.last`)
- `reverseGeocode` → `Geo.reverse(ctx, lat, lng) { text -> Handler(main).post { result.success(text) } }`
- `updateWidget` → `CarWidget.save(ctx, call.arguments)`; `result.success(null)`
- `backgroundDone` → `result.success(null)`; `onDone()`

### `Geo.kt` – `object Geo`
`reverseGeocode`/`addressText` aus MainActivity hierher verschieben:
`fun reverse(ctx: Context, lat: Double, lng: Double, done: (String?) -> Unit)`.
MainActivity ruft danach `Geo.reverse(this, lat, lng) { runOnUiThread { result.success(it) } }`.

### `MainActivity`
- `companion object { @Volatile var visible = false }`; `onResume` → `visible = true`,
  `onPause` → `visible = false` (jeweils `super` aufrufen).
- Neue Methode `updateWidget` → `CarWidget.save(this, call.arguments)`; `result.success(null)`.
- `backgroundDone` → `result.success(null)` (in der sichtbaren App ohne Wirkung).

### `CarWidget.kt` – `object CarWidget` + `class CarWidgetProvider : AppWidgetProvider()`
Gespeichert in SharedPreferences `"car_widget"`, Schlüssel `spot` = JSON-String oder fehlt.
```kotlin
fun save(ctx: Context, args: Any?)
    // args ist Map<*, *>? (null = kein Parkplatz). JSONObject mit
    //   time (Long), lat, lng, acc (Double), address (String?), note (String?), source (String?)
    // Zahlen: (m["time"] as? Number)?.toLong() usw.
    // speichern (oder entfernen), dann updateAll(ctx)

fun updateAll(ctx: Context)
    // ids = AppWidgetManager.getInstance(ctx).getAppWidgetIds(ComponentName(ctx, CarWidgetProvider::class.java))
    // für jede ID: views bauen (build(ctx)) und updateAppWidget
    // Karte: Datei filesDir/widget_map.png + Prefs "map_key" = "%.5f,%.5f" (Locale.US) der Position.
    //   Passt die Datei zur Position → setImageViewBitmap(BitmapFactory.decodeFile(...)).
    //   Sonst Platzhalter (R.drawable.ic_car auf Hintergrund) und MapSnapshot.render(...) in
    //   einem Thread starten; danach auf dem Main-Thread erneut updateAll.

fun build(ctx: Context): RemoteViews   // Layout R.layout.car_widget
    // Ohne Parkplatz: title = "Noch kein Parkplatz gemerkt", Adresse/Notiz ausblenden (View.GONE),
    //   Navigation ausblenden.
    // Mit Parkplatz: title = "Dein Auto steht"; since = Zeittext (unten);
    //   address (oder "%.5f, %.5f"), note (GONE wenn leer).
    // Klicks: widget_body/widget_map → MainActivity (PendingIntent.getActivity, requestCode 10, IMMUTABLE)
    //   btn_nav → Intent(ACTION_VIEW, Uri.parse("google.navigation:q=$ll&mode=w")).setPackage("com.google.android.apps.maps")
    //     (ll mit Locale.US!). Ist Google Maps nicht installiert (packageManager.getLaunchIntentForPackage == null)
    //     → geo:$ll?q=${Uri.encode("$ll(Mein Auto)")} ohne Paket. requestCode 11, IMMUTABLE|UPDATE_CURRENT.
    //   btn_park → ParkHereActivity mit source=widget (requestCode 12).

fun sinceText(time: Long): String
    // wie Dart sinceText: gleicher Tag "seit 14:32", gestern "seit gestern, 14:32",
    // sonst "seit Mo., 22.09., 14:32" (Wochentage Mo. Di. Mi. Do. Fr. Sa. So.; Calendar benutzen)

class CarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        CarWidget.updateAll(context)
    }
}
```
Manifest wie `ParkWidgetProvider`, aber `@xml/car_widget_info`, Label „Mein Auto“.
`res/xml/car_widget_info.xml`: `minWidth="250dp"`, `minHeight="110dp"`,
`targetCellWidth="4"`, `targetCellHeight="2"`, `resizeMode="horizontal|vertical"`,
`updatePeriodMillis="1800000"` (Zeittext aktualisieren), `initialLayout="@layout/car_widget"`,
`previewLayout="@layout/car_widget"`, `widgetCategory="home_screen"`,
`description="@string/car_widget_description"` („Zeigt, wo dein Auto steht“).

`res/layout/car_widget.xml` (nur RemoteViews-taugliche Views: LinearLayout, FrameLayout,
ImageView, TextView, Button): Hintergrund `@drawable/widget_bg` (bereits da; Farbe auf
`#E61E1E2E` ändern, Ecken 16dp), Innenabstand 8dp, horizontal:
- links FrameLayout `widget_map_box` 96dp×96dp: ImageView `widget_map` (scaleType centerCrop),
  unten TextView „© OpenStreetMap“ (8sp, weiß, halbtransparenter Hintergrund).
- rechts LinearLayout `widget_body` vertikal (layout_weight 1, marginStart 10dp):
  TextView `widget_title` (13sp, #CCFFFFFF), `widget_since` (18sp fett, weiß),
  `widget_address` (13sp, weiß, maxLines 2, ellipsize end), `widget_note` (12sp, #CCFFFFFF,
  maxLines 1), dann horizontales LinearLayout mit zwei Buttons `btn_nav` („Navigation“) und
  `btn_park` („Hier geparkt“), je 12sp, `android:background="@drawable/widget_button_bg"`
  (neue Shape: Farbe #33FFFFFF, Ecken 12dp), Textfarbe weiß, Höhe 36dp.

### `MapSnapshot.kt` – `object MapSnapshot`
```kotlin
/** Zeichnet 256×256 px Karte (Zoom 16) mit Auto-Punkt in der Mitte. Netzwerk → nur im Hintergrund-Thread! */
fun render(lat: Double, lng: Double): Bitmap?
    // z = 16; n = 1 shl z
    // px = (lng + 180.0) / 360.0 * n * 256
    // latRad = Math.toRadians(lat); py = (1 - ln(tan(latRad) + 1/cos(latRad)) / PI) / 2 * n * 256
    // left = px - 128; top = py - 128; tx0 = floor(left/256).toInt(); ty0 = floor(top/256).toInt()
    // Bitmap 256×256 ARGB_8888, Canvas; für tx in tx0..tx0+1, ty in ty0..ty0+1:
    //   tile = download("https://tile.openstreetmap.org/$z/$tx/$ty.png") ?: return null
    //   canvas.drawBitmap(tile, (tx*256 - left).toFloat(), (ty*256 - top).toFloat(), null)
    // Mittelpunkt: weißer Kreis r=14, darin Kreis r=11 Farbe #3F51B5 (Indigo)
download(url): HttpURLConnection, connectTimeout/readTimeout 8000,
    setRequestProperty("User-Agent", "ParkplatzMerker/1.0 (Android; com.klaasotte.parkplatz_merker)"),
    BitmapFactory.decodeStream; in try/finally disconnect; Fehler → null
```

## Dart
- `main.dart`:
  ```dart
  @pragma('vm:entry-point')
  Future<void> backgroundMain() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final c = AppController();
      await c.initialize(background: true);
    } catch (e) {
      debugPrint('backgroundMain: $e');
    } finally {
      await NativeBridge.backgroundDone();
    }
  }
  ```
- `AppController.initialize({bool background = false})`: bei `background` KEINEN Timer
  starten und nicht `registerTransitions` aufrufen; sonst wie bisher.
- `AppController._doRefresh()`: am Ende (nach Adresse) `await NativeBridge.updateWidget(latest)`
  – aber nur, wenn sich die Widget-Daten seit dem letzten Aufruf geändert haben (Vergleich über
  `jsonEncode` der Map, im Controller gemerkt). Map: `time, lat, lng, acc, address, note,
  source` (= `sourceLabel`) oder `null`.
- Auch nach `setNote`, `deleteSpot` → Widget aktualisieren (gleiche Hilfsfunktion `_syncWidget()`).
- `resumedRefresh()`: vorher `_events`, `_spots`, `_deletedIds` **neu von der Platte laden**
  (der Hintergrund-Lauf kann sie inzwischen geändert haben), dann `refresh()`.
- `NativeBridge.updateWidget(Map<String, dynamic>? spot)`, `NativeBridge.backgroundDone()`
  (Fehler abfangen wie bei den anderen).

## README
Abschnitt „Widget ‚Mein Auto‘“: hinzufügen (lange drücken → Widgets → Parkplatz-Merker →
„Mein Auto“), was es zeigt, dass es sich nach dem Aussteigen nach ca. 1 Minute von selbst
aktualisiert.

## Prüfen
`flutter analyze` ohne Fehler/Warnungen, `flutter test` grün, Kotlin Zeile für Zeile.
