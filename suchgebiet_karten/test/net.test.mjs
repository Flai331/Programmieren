import test from 'node:test';
import assert from 'node:assert/strict';
import { fetchT } from '../web/net.js';

// hängende Verbindung: fetch antwortet nie, bricht aber über das Signal ab
const hang = (url, opts) => new Promise((_, rej) => {
  if (opts.signal.aborted) rej(new Error('abgebrochen'));
  opts.signal.addEventListener('abort', () => rej(new Error('abgebrochen')));
});

test('fetchT: bricht nach der Zeit ab', async () => {
  const t0 = Date.now();
  await assert.rejects(fetchT('x', {}, 30, hang), /abgebrochen/);
  assert.ok(Date.now() - t0 < 1000);
});

test('fetchT: normale Antwort kommt durch, Optionen bleiben erhalten', async () => {
  let got;
  const ok = async (url, opts) => { got = [url, opts]; return { ok: true }; };
  const r = await fetchT('u', { method: 'POST' }, 1000, ok);
  assert.equal(r.ok, true);
  assert.equal(got[1].method, 'POST');
  assert.ok(got[1].signal);
});

test('fetchT: fremdes Signal bricht ebenfalls ab', async () => {
  const ctl = new AbortController();
  const p = fetchT('x', { signal: ctl.signal }, 5000, hang);
  ctl.abort();
  await assert.rejects(p, /abgebrochen/);
  // schon abgebrochen -> sofort
  await assert.rejects(fetchT('x', { signal: ctl.signal }, 5000, hang), /abgebrochen/);
});
