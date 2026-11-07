# Erzeugt die Sprecherspur mit XTTS v2 (Coqui, Lizenz: Coqui Public Model License – nur nicht-kommerziell).
# Klaas hat der Lizenz zugestimmt. Aufruf:
#   COQUI_TOS_AGREED=1 HF_HUB_DISABLE_XET=1 python xtts_sprecher.py sprecher-einsatz.json build-einsatz "Damien Black"
# Legt build-einsatz/tts_<id>.wav (+ .txt) an; compose.js nimmt diese Dateien dann statt der Piper-Stimme.
# Jeder Satz wird mit Whisper gegengelesen; erfindet das Modell Wörter, wird er neu gesprochen (bis zu 4 Versuche, der beste bleibt).
import json, os, re, shutil, subprocess, sys, time
import numpy as np
from TTS.api import TTS
from faster_whisper import WhisperModel

narr, build, speaker = sys.argv[1], sys.argv[2], sys.argv[3]
only = sys.argv[4].split(',') if len(sys.argv) > 4 else None
texts = json.load(open(narr, encoding='utf-8'))
os.makedirs(build, exist_ok=True)
tts = TTS('tts_models/multilingual/multi-dataset/xtts_v2')
asr = WhisperModel('medium', device='cpu', compute_type='int8')

NUM = re.compile(r'^(\d+|ein|eins|zwei|drei|vier|fünf|sechs|sieben|acht|neun|zehn|elf|zwölf|\w*zehn|\w*zig|\w*und\w*zig|hundert|uhr)$')
def words(s):
    return [w for w in re.sub(r'[^a-zäöüß0-9 ]', ' ', s.lower()).split() if not NUM.match(w) and len(w) > 1]
def wer(ref, hyp):
    a, b = words(ref), words(hyp)
    if not a: return 0.0
    d = list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(b) + 1):
            cur = d[j]
            d[j] = min(d[j] + 1, d[j - 1] + 1, prev + (a[i - 1] != b[j - 1]))
            prev = cur
    return d[-1] / len(a)
def pcm16k(f):
    raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', f, '-ac', '1', '-ar', '16000', '-f', 's16le', '-'], capture_output=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768
def hear(f, words_out=False):
    segs, _ = asr.transcribe(pcm16k(f), language='de', beam_size=5, word_timestamps=words_out)
    segs = list(segs)
    txt = ' '.join(s.text for s in segs).strip()
    if not words_out: return txt
    return txt, [w for s in segs for w in (s.words or [])]
def norm1(w): return re.sub(r'[^a-zäöüß0-9]', '', w.lower())
def similar(a, b):
    a, b = norm1(a), norm1(b)
    if not a or not b: return False
    if a == b or a.startswith(b[:4]) or b.startswith(a[:4]): return True
    return False

SR = 24000
def sentence(text, tmp):
    """Einen Satz ohne Schlusspunkt sprechen und alles nach dem letzten echten Wort abschneiden."""
    say = re.sub(r'[.…]+$', '', text.strip())
    wav = tts.tts(text=say, speaker=speaker, language='de', split_sentences=False)
    import soundfile as sf
    sf.write(tmp, np.array(wav, dtype=np.float32), SR)
    heard, ws = hear(tmp, True)
    ref = [w for w in re.sub(r'[^\wäöüß ]', ' ', say).split() if w]
    last = ref[-1] if ref else ''
    cut = None
    for w in ws:
        if similar(w.word, last): cut = w.end
    if cut is not None:
        a = np.array(wav, dtype=np.float32)[: int((cut + 0.18) * SR)]
        sf.write(tmp, a, SR)
        heard = hear(tmp)
    return heard

for key, text in texts.items():
    if only and key not in only: continue
    wav = os.path.join(build, f'tts_{key}.wav')
    parts = [p for p in re.split(r'(?<=[.!?…])\s+', text.strip()) if p]
    files = []
    for i, part in enumerate(parts):
        best = None
        for n in range(4):
            tmp = wav + f'.s{i}.t{n}.wav'
            t = time.time()
            heard = sentence(part, tmp)
            e = wer(part, heard)
            print(f'{key}[{i}] Versuch {n + 1}: Fehler {e:.2f} ({time.time() - t:.0f} s) | {heard}', flush=True)
            if best is None or e < best[0]: best = (e, tmp)
            if e <= 0.05: break
        files.append(best[1])
    # Sätze mit kurzer Pause aneinanderhängen
    import soundfile as sf
    gap = np.zeros(int(0.32 * SR), dtype=np.float32)
    out = []
    for i, fpath in enumerate(files):
        a, _ = sf.read(fpath, dtype='float32')
        out.append(a)
        if i < len(files) - 1: out.append(gap)
    sf.write(wav, np.concatenate(out), SR)
    for p in os.listdir(build):
        if p.startswith(f'tts_{key}.wav.s'): os.remove(os.path.join(build, p))
    with open(wav + '.txt', 'w', encoding='utf-8') as f:
        f.write(text)
