# Legt Musik (CC0, John Bartmann, Wikimedia Commons) unter die Untertitel-Fassung.
# Aufruf: python3 musik.py <Musikordner>
import json, subprocess, sys
M = sys.argv[1].rstrip('/') + '/'
probe = lambda f: float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], capture_output=True, text=True).stdout)
order = json.load(open('rec-einsatz/order.json'))
off = 0; at = {}
for o in order:
    at[o['id']] = off
    off += probe(f"build-ut/{o['id']}.mp4")
total = off
X = 3.0  # Überblendung
t1 = probe(M + 'above-the-clouds.mp3')
b1 = min(at['t6'], t1 - X / 2 - 0.5)      # Spannung ab 16:41 (oder etwas früher, falls das erste Stück endet)
b2 = at['dual-fund']                        # Erleichterung ab dem Fund
sec = [('above-the-clouds.mp3', 0, b1 + X / 2), ('broken-suspense.mp3', b1 - X / 2, b2 + X / 2), ('Heart_of_Acceptance.mp3', b2 - X / 2, total)]
inp, fc, labels = [], [], []
for i, (f, a, b) in enumerate(sec):
    L = b - a; tl = probe(M + f)
    assert tl >= L - 0.1, f'{f} zu kurz ({tl:.1f} < {L:.1f})'
    inp += ['-i', M + f]
    fin = 1.5 if i == 0 else X; fout = 5.0 if i == len(sec) - 1 else X
    fc.append(f"[{i+1}:a]atrim=0:{L:.2f},asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo,loudnorm=I=-18:TP=-2,afade=t=in:d={fin},afade=t=out:st={L-fout:.2f}:d={fout},adelay={int(a*1000)}|{int(a*1000)}[m{i}]")
    labels.append(f'[m{i}]')
    print(f, 'von', round(a, 1), 'bis', round(b, 1))
fc.append(f"{''.join(labels)}amix=inputs={len(sec)}:normalize=0:duration=longest,atrim=0:{total:.2f},loudnorm=I=-16:TP=-1.5:LRA=11[a]")
subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', 'RHS-Einsatz-Scheuen-Untertitel-ohne-Ton.mp4', *inp, '-filter_complex', ';'.join(fc),
                '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-shortest', '-movflags', '+faststart',
                'RHS-Einsatz-Scheuen-Musik-Untertitel.mp4'], check=True)
print('fertig', round(probe('RHS-Einsatz-Scheuen-Musik-Untertitel.mp4'), 1), 's')
