# Erzeugt die Sprecherspur mit XTTS v2 (Coqui, Lizenz: Coqui Public Model License – nur nicht-kommerziell).
# Klaas hat der Lizenz zugestimmt. Aufruf:
#   COQUI_TOS_AGREED=1 HF_HUB_DISABLE_XET=1 python xtts_sprecher.py sprecher-einsatz.json build-einsatz "Viktor Eka"
# Legt build-einsatz/tts_<id>.wav (+ .txt) an; compose.js nimmt diese Dateien dann statt der Piper-Stimme.
import json, os, sys, time
from TTS.api import TTS

narr, build, speaker = sys.argv[1], sys.argv[2], sys.argv[3]
texts = json.load(open(narr, encoding='utf-8'))
os.makedirs(build, exist_ok=True)
tts = TTS('tts_models/multilingual/multi-dataset/xtts_v2')
for key, text in texts.items():
    wav = os.path.join(build, f'tts_{key}.wav')
    t = time.time()
    tts.tts_to_file(text=text, speaker=speaker, language='de', file_path=wav, split_sentences=True)
    with open(wav + '.txt', 'w', encoding='utf-8') as f:
        f.write(text)
    print(key, round(time.time() - t, 1), 's', flush=True)
