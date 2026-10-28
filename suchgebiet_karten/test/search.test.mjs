import test from 'node:test';
import assert from 'node:assert/strict';
import { parseQuery } from '../web/search.js';

test('Suche erkennt Feld, Koordinaten und Adresse', () => {
  assert.deepEqual(parseQuery('c4'), { type: 'cell', c: 2, r: 3 });
  assert.deepEqual(parseQuery('50.12, 8.61'), { type: 'coords', lat: 50.12, lon: 8.61 });
  assert.deepEqual(parseQuery('50,12 8,61'), { type: 'coords', lat: 50.12, lon: 8.61 });
  assert.deepEqual(parseQuery('50.12;8.61'), { type: 'coords', lat: 50.12, lon: 8.61 });
  assert.deepEqual(parseQuery('Hauptstraße 5, Bielefeld'), { type: 'address', q: 'Hauptstraße 5, Bielefeld' });
  assert.equal(parseQuery('   '), null);
  assert.equal(parseQuery('95.1, 8.6').type, 'address');
});

test('Photon-Treffer werden lesbar aufbereitet', async () => {
  const { photonPlace } = await import('../web/search.js');
  const r = photonPlace({
    geometry: { coordinates: [8.53, 52.02] },
    properties: { name: 'Wanderparkplatz Hünenburg', osm_value: 'parking', postcode: '33619', city: 'Bielefeld', state: 'Nordrhein-Westfalen', country: 'Deutschland', extent: [8.52, 52.03, 8.54, 52.01] },
  });
  assert.equal(r.name, 'Wanderparkplatz Hünenburg');
  assert.equal(r.sub, 'Parkplatz · 33619 Bielefeld, Nordrhein-Westfalen');
  assert.deepEqual(r.bounds, [52.01, 52.03, 8.52, 8.54]);
  const a = photonPlace({ geometry: { coordinates: [8, 50] }, properties: { street: 'Waldweg', housenumber: '5', city: 'Musterstadt' } });
  assert.equal(a.name, 'Waldweg 5');
});

test('Kreuzungen erkennen, normale Adressen bleiben Adressen', async () => {
  const { parseCorner } = await import('../web/search.js');
  assert.deepEqual(parseQuery('Hauptstraße Ecke Bahnhofstraße, Celle'), { type: 'corner', a: 'Hauptstraße', b: 'Bahnhofstraße', place: 'Celle' });
  assert.deepEqual(parseCorner('Ecke Hauptstr./Bahnhofstr.'), { a: 'Hauptstr.', b: 'Bahnhofstr.', place: '' });
  assert.deepEqual(parseCorner('Kreuzung Lindenweg und Am Markt in Celle'), { a: 'Lindenweg', b: 'Am Markt', place: 'Celle' });
  assert.deepEqual(parseCorner('Lindenallee & Bahnhofstr.'), { a: 'Lindenallee', b: 'Bahnhofstr.', place: '' });
  assert.deepEqual(parseCorner('Celle, Hauptstraße/Mühlenweg'), { a: 'Hauptstraße', b: 'Mühlenweg', place: 'Celle' });
  for (const q of ['Frankfurt/Main', 'Halle/Saale', 'Hauptstraße 12/14, Celle', 'Bahnhofstraße 5, Frankfurt/Main', 'Ecke Hauptstraße', 'Eckernförder Straße 3']) {
    assert.equal(parseQuery(q).type, 'address', q);
  }
});

test('Straßennamen-Muster finden Schreibvarianten', async () => {
  const { streetPattern } = await import('../web/search.js');
  const hits = (typed, name) => new RegExp(`^(${streetPattern(typed)})$`, 'i').test(name);
  assert.ok(hits('Hauptstr.', 'Hauptstraße'));
  assert.ok(hits('hauptstrasse', 'Hauptstraße'));
  assert.ok(hits('Bahnhof Straße', 'Bahnhofstraße'));
  assert.ok(hits('karl marx str', 'Karl-Marx-Straße'));
  assert.ok(hits('Schlossallee', 'Schloßallee'));
  assert.ok(hits('muehlenweg', 'Mühlenweg'));
  assert.ok(hits('Mühlenweg', 'Mühlenweg'));
  assert.ok(hits('große straße', 'Große Straße'));
  assert.ok(!hits('Hauptstraße', 'Alte Hauptstraße'));
  // nur Zeichen, die auch die Overpass API (POSIX) versteht: kein Backslash, kein Anführungszeichen, kein Punkt als Joker
  for (const n of ['St. Annen-Str.', 'Am "Markt"', 'Weg\\1']) assert.ok(!/[\\"]|(^|[^[])\.(?!\])/.test(streetPattern(n)), n);
});

test('Overpass-Antwort: nahe Punkte zusammengefasst, Ort und Namen, genaue Treffer zuerst', async () => {
  const { cornerResults, cornerQuery, cornerBox } = await import('../web/search.js');
  const json = { elements: [
    // zweispurige Kreuzung: zwei Punkte 30 m auseinander
    { type: 'node', id: 1, lat: 52.6250, lon: 10.0800 },
    { type: 'way', id: 11, tags: { name: 'Hauptstraße', highway: 'primary' } },
    { type: 'way', id: 12, tags: { name: 'Bahnhofstraße', highway: 'residential' } },
    { type: 'area', id: 3600000001, tags: { name: 'Celle', admin_level: '8', boundary: 'administrative' } },
    { type: 'area', id: 3600000002, tags: { name: 'Landkreis Celle', admin_level: '6', boundary: 'administrative' } },
    { type: 'area', id: 3600000003, tags: { name: 'Neustadt', admin_level: '10', boundary: 'administrative' } },
    { type: 'node', id: 2, lat: 52.6252, lon: 10.0804 },
    { type: 'way', id: 11, tags: { name: 'Hauptstraße', highway: 'primary' } },
    // zweite Kreuzung weiter weg, Name nur ähnlich
    { type: 'node', id: 3, lat: 52.70, lon: 10.20 },
    { type: 'way', id: 13, tags: { name: 'Alte Hauptstraße' } },
    { type: 'way', id: 14, tags: { name: 'Bahnhofstraße' } },
    { type: 'area', id: 3600000004, tags: { name: 'Wietze', admin_level: '8' } },
  ] };
  const list = cornerResults(json, 'Hauptstr.', 'bahnhofstrasse', { lat: 52.7, lon: 10.2 });
  assert.equal(list.length, 2);
  assert.equal(list[0].name, 'Hauptstraße / Bahnhofstraße'); // genau, obwohl weiter weg
  assert.equal(list[0].sub, 'Kreuzung · Neustadt, Celle');
  assert.ok(Math.abs(list[0].lat - 52.6251) < 1e-6);
  assert.equal(list[1].name, 'Alte Hauptstraße / Bahnhofstraße');
  assert.equal(list[1].sub, 'Kreuzung · Wietze');
  assert.equal(cornerResults({ elements: [] }, 'a', 'b').length, 0);
  const q = cornerQuery('^(a)$', '^(b)$', cornerBox({ lat: 52.6, lon: 10.1 }, null));
  assert.match(q, /way\[highway\]\[name~"\^\(a\)\$",i\]\(52\.51000,9\.96000,52\.69000,10\.24000\)->\.a;/);
  assert.match(q, /node\(w\.a\)\(w\.b\)->\.x;/);
  const box = cornerBox({ lat: 52.62, lon: 10.08 }, [52.55, 52.70, 9.95, 10.20]);
  assert.ok(box.south < 52.55 && box.north > 52.70 && box.west < 9.95 && box.east > 10.20);
});

test('Kreuzungssuche: Ersatzserver bei Überlastung, dann Namensanfang', async () => {
  const { searchCorner } = await import('../web/search.js');
  const calls = [];
  const replies = [
    { ok: true, json: { elements: [], remark: 'runtime error: Query timed out in "query" at line 2 after 26 seconds.' } },
    { ok: true, json: { elements: [] } }, // Ersatzserver: kein genauer Treffer
    { ok: true, json: { elements: [{ type: 'node', id: 1, lat: 52, lon: 10 }, { type: 'way', id: 2, tags: { name: 'Bahnhofstraße' } }, { type: 'way', id: 3, tags: { name: 'Kirchweg' } }] } },
  ];
  const old = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.push([new URL(url).hostname, /name~"([^"]*)"/.exec(decodeURIComponent(init.body.slice(5)))[1]]);
    const r = replies.shift();
    return { ok: r.ok, status: 200, json: async () => r.json };
  };
  try {
    const list = await searchCorner('Bahnhof', 'Kirchweg', { south: 51.9, north: 52.1, west: 9.9, east: 10.1 }, { lat: 52, lon: 10 });
    assert.deepEqual(list.map((r) => r.name), ['Bahnhofstraße / Kirchweg']);
    assert.deepEqual(calls, [
      ['overpass-api.de', '^(bahnhof)$'],
      ['overpass.kumi.systems', '^(bahnhof)$'],
      ['overpass-api.de', '(^|[- ])(bahnhof)'],
    ]);
  } finally {
    globalThis.fetch = old;
  }
});
