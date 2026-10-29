import test from 'node:test';
import assert from 'node:assert/strict';
import {
  dirName, beaufort, approach, parseCurrent, parseForecast, circularMean, sunTimes, windLines, windChanged,
} from '../web/weather.js';

test('Richtung, Beaufort, Ansatz gegen den Wind', () => {
  assert.equal(dirName(0), 'N');
  assert.equal(dirName(225), 'SW');
  assert.equal(dirName(359), 'N');
  assert.equal(dirName(-90), 'W');
  assert.equal(beaufort(0), 0);
  assert.equal(beaufort(15), 3);
  assert.equal(beaufort(40), 6);
  // Wind aus Südwest -> Start im Nordosten, gegen den Wind Richtung Südwest
  assert.match(approach(225), /Nordost-Seite.*Richtung Südwest/);
});

test('Bright-Sky-Antworten lesen', () => {
  const c = parseCurrent({
    weather: { source_id: 7, timestamp: '2026-10-29T13:30:00+00:00', wind_direction_10: 230, wind_speed_10: 14.8, wind_gust_speed_10: 31, temperature: 11.2, precipitation_60: 0.2, icon: 'cloudy' },
    sources: [{ id: 7, station_name: 'Osnabrück', distance: 12345 }],
  });
  assert.equal(c.from, 230);
  assert.equal(c.kmh, 14.8);
  assert.equal(c.gust, 31);
  assert.equal(c.station, 'Osnabrück');
  assert.ok(Math.abs(c.km - 12.3) < 0.1);
  // Ausweichfelder (_30) werden genommen, wenn _10 fehlt
  assert.equal(parseCurrent({ weather: { wind_direction_30: 90, wind_speed_30: 5 }, sources: [] }).from, 90);
  assert.equal(parseCurrent(null), null);
  const f = parseForecast({ weather: [{ timestamp: '2026-10-29T15:00:00+00:00', wind_direction: 270, wind_speed: 20, precipitation_probability: 40 }] });
  assert.equal(f[0].from, 270);
  assert.equal(f[0].prob, 40);
});

test('Kompass-Mittelwert über 0°, Sonnenuntergang plausibel', () => {
  assert.ok(Math.abs(circularMean([350, 10, 0]) - 0) < 1 || Math.abs(circularMean([350, 10, 0]) - 360) < 1);
  assert.ok(Math.abs(circularMean([80, 100]) - 90) < 0.01);
  // Osnabrück, 21. Juni: Untergang ca. 21:50 MESZ = 19:50 UTC
  const s = sunTimes(new Date(Date.UTC(2026, 5, 21, 12)), 52.27, 8.05);
  const set = new Date(s.set);
  assert.ok(Math.abs(set.getUTCHours() * 60 + set.getUTCMinutes() - (19 * 60 + 50)) < 15, set.toISOString());
});

test('Windprotokoll: Zeilen und deutliche Änderung', () => {
  const lines = windLines({ wind: [{ t: Date.UTC(2026, 9, 29, 13, 20), from: 225, strength: 'medium', src: 'gemessen' }, { t: Date.UTC(2026, 9, 29, 13, 30), from: 230, kmh: 15, gust: 30, station: 'Osnabrück', src: 'DWD' }] });
  assert.match(lines[0], /gemessen: aus SW \(225°\), mittel/);
  assert.match(lines[1], /DWD Osnabrück: aus SW \(230°\), 15 km\/h, Böen 30 \(Bft 3\)/);
  assert.equal(windChanged(null, { from: 0, kmh: 5 }), true);
  assert.equal(windChanged({ from: 350, kmh: 10 }, { from: 20, kmh: 12 }), false);
  assert.equal(windChanged({ from: 350, kmh: 10 }, { from: 60, kmh: 12 }), true);
  assert.equal(windChanged({ from: 200, kmh: 5 }, { from: 200, kmh: 25 }), true);
});
