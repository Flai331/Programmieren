import test from 'node:test';
import assert from 'node:assert/strict';
import { parseKml } from '../web/gpx.js';

const KML = `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>Suche</name>
<Placemark><name>Fundort</name><Point><coordinates>10.08,52.62,0</coordinates></Point></Placemark>
<Placemark><name>Weg</name><LineString><coordinates>10.06,52.61 10.07,52.615 10.08,52.62</coordinates></LineString></Placemark>
<Placemark><name>Gebiet A</name><Polygon><outerBoundaryIs><LinearRing><coordinates>
10.06,52.61,0 10.09,52.61,0 10.09,52.63,0 10.06,52.63,0 10.06,52.61,0
</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark>
</Document></kml>`;

test('parseKml: Punkte, Linien und Flächen', () => {
  const g = parseKml(KML);
  assert.deepEqual(g.waypoints, [{ name: 'Fundort', lat: 52.62, lon: 10.08 }]);
  assert.equal(g.tracks.length, 2);
  assert.equal(g.tracks[0].name, 'Weg');
  assert.equal(g.tracks[0].pts.length, 3);
  assert.ok(!g.tracks[0].closed);
  assert.equal(g.tracks[1].name, 'Gebiet A');
  assert.equal(g.tracks[1].closed, true);
  assert.equal(g.tracks[1].pts.length, 4); // Schlusspunkt entfernt
  assert.deepEqual(g.tracks[1].pts[0], [52.61, 10.06]);
});

test('parseKml: keine KML-Datei', () => {
  assert.throws(() => parseKml('<gpx></gpx>'));
});
