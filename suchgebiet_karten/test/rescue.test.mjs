import test from 'node:test';
import assert from 'node:assert/strict';
import { parseRescue, mergeRescue, nearest, compass, inBounds, distance } from '../web/rescue.js';

test('GPX-Wegpunkte', () => {
  const g = '<?xml version="1.0"?><gpx><wpt lat="52.1234" lon="8.0456"><name>OS-1234</name></wpt><wpt lat="52.2" lon="8.1"><name><![CDATA[OS-1235]]></name></wpt></gpx>';
  const p = parseRescue(g);
  assert.deepEqual(p, [{ n: 'OS-1234', lat: 52.1234, lon: 8.0456 }, { n: 'OS-1235', lat: 52.2, lon: 8.1 }]);
});

test('KML: Name oder Nummer aus ExtendedData', () => {
  const k = '<kml><Document><Placemark><name>HI-0001</name><Point><coordinates>9.95,52.15,0</coordinates></Point></Placemark>'
    + '<Placemark><ExtendedData><SchemaData><SimpleData name="RP_NR">HI-0002</SimpleData></SchemaData></ExtendedData><Point><coordinates>9.96,52.16</coordinates></Point></Placemark></Document></kml>';
  const p = parseRescue(k);
  assert.equal(p.length, 2);
  assert.equal(p[1].n, 'HI-0002');
  assert.equal(p[1].lat, 52.16);
});

test('CSV: Semikolon, Dezimalkomma, deutsche Spaltennamen; UTM-Spalten', () => {
  const c = 'RP_NR;Breite;Länge;Bemerkung\nNI-OS-001;52,2701;8,0477;Parkplatz\nNI-OS-002;52,28;8,05;\n';
  const p = parseRescue(c);
  assert.equal(p.length, 2);
  assert.deepEqual(p[0], { n: 'NI-OS-001', lat: 52.2701, lon: 8.0477 });
  const u = 'Nummer,Ostwert,Nordwert\nX-1,32435000,5791000\n';
  const q = parseRescue(u);
  assert.ok(Math.abs(q[0].lat - 52.26) < 0.02 && Math.abs(q[0].lon - 8.05) < 0.03, JSON.stringify(q));
});

test('Zusammenführen, nächster Punkt, Richtung, Ausschnitt', () => {
  const a = [{ n: 'A', lat: 52, lon: 8 }, { n: 'B', lat: 52.1, lon: 8 }];
  const m = mergeRescue(a, [{ n: 'B', lat: 52.2, lon: 8 }, { n: 'C', lat: 53, lon: 9 }]);
  assert.equal(m.length, 3);
  assert.equal(m.find((p) => p.n === 'B').lat, 52.2);
  const r = nearest(m, 52.19, 8.001);
  assert.equal(r.p.n, 'B');
  assert.ok(r.m > 1000 && r.m < 1200);
  assert.equal(compass(r.deg), 'N');
  assert.equal(inBounds(m, { north: 52.5, south: 51.9, west: 7.9, east: 8.1 }).length, 2);
  assert.ok(Math.abs(distance(52, 8, 53, 8) - 111195) < 100);
});

test('Rettungspunkte: alle im Raster/Umriss (auch große) plus 3 km um die Mitte', async () => {
  const { rescueNear } = await import('../web/rescue.js');
  const pts = [
    { n: 'mitte', lat: 52.29, lon: 8.02 },
    { n: '2,5km', lat: 52.3125, lon: 8.02 },
    { n: '3,5km', lat: 52.3215, lon: 8.02 },
    { n: 'großes-raster-ecke', lat: 52.205, lon: 7.81 }, // im großen Raster, aber > 3 km von dessen Mitte
    { n: 'umriss-rand', lat: 52.405, lon: 8.27 }, // im großen Umriss, weit von der Mitte
    { n: 'weit', lat: 53, lon: 9 },
  ];
  const shapes = [
    { rect: { north: 52.30, south: 52.28, west: 8.00, east: 8.04 } },
    { rect: { north: 52.30, south: 52.20, west: 7.80, east: 7.95 } },
    { pts: [[52.40, 8.10], [52.42, 8.10], [52.42, 8.28], [52.40, 8.28]] },
  ];
  const r = rescueNear(pts, shapes, 3);
  assert.deepEqual(r.map((p) => p.n).sort(), ['2,5km', 'großes-raster-ecke', 'mitte', 'umriss-rand']);
  assert.deepEqual(rescueNear(pts, [], 3), []);
});
