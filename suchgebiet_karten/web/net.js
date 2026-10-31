// Netz-Aufruf mit Zeitgrenze: eine hängende Verbindung (Funkloch) blockiert sonst alles dahinter.
// Das Zeitlimit gilt auch für das Lesen der Antwort. Ein mitgegebenes Signal bricht ebenfalls ab.
export function fetchT(url, opts = {}, ms = 15000, f = fetch) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), ms);
  const { signal } = opts;
  if (signal) {
    if (signal.aborted) ctl.abort();
    else signal.addEventListener('abort', () => ctl.abort(), { once: true });
  }
  return f(url, { ...opts, signal: ctl.signal });
}
