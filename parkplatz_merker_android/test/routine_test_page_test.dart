import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:parkplatz_merker/controller.dart';
import 'package:parkplatz_merker/logic/models.dart';
import 'package:parkplatz_merker/pages/routine_test_page.dart';
import 'package:parkplatz_merker/storage.dart';

class FakeAppController extends ChangeNotifier implements AppController {
  @override
  Storage get storage => Storage();

  @override
  bool get ready => true;

  @override
  List<RawEvent> get events => [];

  @override
  List<ParkingSpot> get spots => [];

  @override
  ParkingSpot? get latest => null;

  @override
  LocSample? get myLocation => null;

  @override
  bool get tripRunning => false;

  @override
  Map<String, dynamic> get config => {
        'deviceMode': 'none',
        'launchApps': [],
        'volumeEnabled': false,
        'volumeRestore': true,
      };

  @override
  ParkingSpot? spotById(String id) => null;

  @override
  Future<void> initialize({bool background = false}) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> reloadConfig() async {}

  @override
  Future<void> updateConfig({
    bool? activityEnabled,
    bool? chargerEnabled,
    String? deviceMode,
    String? deviceAddress,
    String? deviceName,
    String? launchPackage,
    String? launchLabel,
    bool? closeOnGone,
    String? closeActionTitle,
    int? closeActionIndex,
    String? closeWidget,
    bool? forceStopFallback,
    List<Map<String, dynamic>>? launchApps,
    bool? volumeEnabled,
    int? volMusic,
    int? volRing,
    int? volNotification,
    String? ringerMode,
    bool? volumeRestore,
  }) async {}

  @override
  Future<void> pausedRefresh() async {}

  @override
  Future<void> resumedRefresh() async {}

  @override
  Future<String?> parkHere() async => null;

  @override
  Future<void> deleteSpot(String id) async {}

  @override
  Future<void> setNote(String spotId, String note) async {}

  @override
  Future<void> setPhoto(String spotId, String photoPath) async {}

  @override
  Future<void> removePhoto(String spotId) async {}

  @override
  Future<String?> setReminder(String spotId, DateTime until) async => null;

  @override
  Future<void> clearReminder(String spotId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('RoutineTestPage rendert ohne Exception und zeigt „Test starten"', (tester) async {
    final controller = FakeAppController();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: const RoutineTestPage(),
        ),
      ),
    );

    expect(find.text('Ganze Routine testen'), findsOneWidget);
    expect(find.text('Test starten'), findsOneWidget);
    expect(find.text('Abstand zwischen den Suchen'), findsOneWidget);

    // Keine Exception beim Rendern
    expect(tester.takeException(), isNull);
  });
}
