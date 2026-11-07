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
def hear(f):
    raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', f, '-ac', '1', '-ar', '16000', '-f', 's16le', '-'], capture_output=True).stdout
    segs, _ = asr.transcribe(np.frombuffer(raw, np.int16).astype(np.float32) / 32768, language='de', beam_size=5)
    return ' '.join(s.text for s in segs).strip()

for key, text in texts.items():
    if only and key not in only: continue
    wav = os.path.join(build, f'tts_{key}.wav')
    best = None
    for n in range(4):
        tmp = wav + f'.try{n}.wav'
        t = time.time()
        tts.tts_to_file(text=text, speaker=speaker, language='de', file_path=tmp, split_sentences=True)
        heard = hear(tmp)
        e = wer(text, heard)
        print(f'{key} Versuch {n + 1}: Fehler {e:.2f} ({time.time() - t:.0f} s) | {heard}', flush=True)
        if best is None or e < best[0]: best = (e, tmp)
        if e <= 0.08: break
    shutil.copy(best[1], wav)
    for n in range(4):
        p = wav + f'.try{n}.wav'
        if os.path.exists(p): os.remove(p)
    with open(wav + '.txt', 'w', encoding='utf-8') as f:
        f.write(text)
