import test from 'node:test';
import assert from 'node:assert/strict';
import { toVcf, parseVcf, parseContacts, mergeContacts, matches, sortContacts, telHref, normalizeContact } from '../web/contacts.js';

const anna = normalizeContact({ name: 'Anna Müller', role: 'Einsatzleiterin', org: 'RHS Osnabrück', call: 'Rettungshund 1/1', phone: '0171 234 56 78', email: 'anna@example.org', note: 'Hund: Kira; Zweitnr. abends' });

test('vCard: hin und zurück bleibt alles erhalten (auch ; , und Umlaute)', () => {
  const back = parseVcf(toVcf([anna]));
  assert.equal(back.length, 1);
  for (const k of ['name', 'role', 'org', 'call', 'phone', 'email', 'note']) assert.equal(back[0][k], anna[k], k);
});

test('vCard aus dem Handy: gefaltete Zeilen, item-Präfix, Quoted-Printable, mehrere Nummern', () => {
  const v = [
    'BEGIN:VCARD', 'VERSION:2.1', 'N;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:M=C3=BCller;J=C3=B6rg;;;',
    'TEL;CELL:+49 171 111', 'TEL;WORK:0541 222', 'item1.EMAIL;TYPE=INTERNET:joerg@exa', ' mple.org', 'END:VCARD',
    'BEGIN:VCARD', 'VERSION:3.0', 'FN:Leitstelle', 'TEL:112', 'END:VCARD',
  ].join('\r\n');
  const list = parseVcf(v);
  assert.equal(list.length, 2);
  assert.equal(list[0].name, 'Jörg Müller');
  assert.equal(list[0].phone, '+49 171 111');
  assert.equal(list[0].phone2, '0541 222');
  assert.equal(list[0].email, 'joerg@example.org');
  assert.equal(list[1].name, 'Leitstelle');
});

test('JSON-Import, Zusammenführen ohne Doppelte', () => {
  const list = parseContacts(JSON.stringify({ contacts: [anna, { name: 'Bernd' }] }));
  assert.equal(list.length, 2);
  const m = mergeContacts([anna], list);
  assert.equal(m.added, 1);
  assert.equal(m.list.length, 2);
});

test('Suche, Sortierung, tel:-Link', () => {
  assert.ok(matches(anna, 'anna kira'));
  assert.ok(matches(anna, '017123456'));
  assert.ok(matches(anna, 'rettungshund'));
  assert.ok(!matches(anna, 'polizei'));
  assert.deepEqual(sortContacts([{ name: 'Zora' }, { name: 'ärztin' }, { name: 'Bernd' }]).map((c) => c.name), ['ärztin', 'Bernd', 'Zora']);
  assert.equal(telHref('0171 234-56/78'), 'tel:01712345678');
});
