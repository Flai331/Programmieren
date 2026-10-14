import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../controller.dart';
import '../native.dart';
import 'help_page.dart';

/// Parkplatz selbst eingeben: Adresse suchen oder Karte verschieben, dann speichern.
class EnterSpotPage extends StatefulWidget {
  const EnterSpotPage({super.key});

  @override
  State<EnterSpotPage> createState() => _EnterSpotPageState();
}

class _EnterSpotPageState extends State<EnterSpotPage> {
  final _map = MapController();
  final _query = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _searched = false;
  bool _saving = false;
  late LatLng _start;

  @override
  void initState() {
    super.initState();
    final controller = context.read<AppController>();
    final me = controller.myLocation;
    final last = controller.latest;
    if (me != null) {
      _start = LatLng(me.lat, me.lng);
    } else if (last != null) {
      _start = LatLng(last.lat, last.lng);
    } else {
      _start = const LatLng(51.1657, 10.4515); // Mitte Deutschlands
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final found = await NativeBridge.geocode(text);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searched = true;
      _results = found;
    });
    if (found.length == 1) _pick(found.first);
  }

  void _pick(Map<String, dynamic> r) {
    final lat = (r['lat'] as num?)?.toDouble();
    final lng = (r['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    _map.move(LatLng(lat, lng), 18);
    setState(() => _results = []);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final center = _map.camera.center;
    await context.read<AppController>().parkAt(center.latitude, center.longitude);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Parkplatz gespeichert')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppController>().myLocation;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parkplatz eingeben'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Anleitung',
            onPressed: () => HelpPage.show(context, HelpTopic.extras),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Adresse, z. B. Hauptstraße 5, Köln',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        tooltip: 'Suchen',
                        onPressed: _search,
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (_results.length > 1)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in _results)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(r['label'] as String? ?? ''),
                      onTap: () => _pick(r),
                    ),
                ],
              ),
            )
          else if (_searched && _results.isEmpty && !_searching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Nichts gefunden – oder du verschiebst einfach die Karte.'),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Verschieb die Karte, bis die Nadel auf deinem Auto steht.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _start,
                    initialZoom: me != null ? 17 : 6,
                    onTap: (_, point) => _map.move(point, _map.camera.zoom),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.klaasotte.parkplatz_merker',
                    ),
                    if (me != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(me.lat, me.lng),
                            width: 18,
                            height: 18,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const RichAttributionWidget(
                      attributions: [TextSourceAttribution('OpenStreetMap')],
                    ),
                  ],
                ),
                // Nadel fest in der Mitte; Spitze zeigt auf die Kartenmitte.
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 44),
                      child: Icon(
                        Icons.location_on,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.local_parking),
            label: const Text('Hier steht mein Auto'),
          ),
        ),
      ),
    );
  }
}
