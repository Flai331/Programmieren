// v125: Kamerawahl für den QR-Scanner. facingMode 'environment' landet auf Android oft bei der Ultraweitwinkel-Kamera
// (unscharf im Nahbereich) – darum nach der ersten Freigabe alle Rückkameras nach ihrem Namen bewerten.
// Reine Logik ohne DOM, testbar.
export const CAM_KEY = 'sgk-cam';

const FRONT = /\b(front|user|selfie|vorder)|facing front/i;
const BACK = /\b(back|rear|environment|rück|rueck|hinten)|facing back/i;
const BAD = [[/ultra/i, 40], [/wide|weit/i, 30], [/0[.,]5\s*x?/i, 35], [/tele|zoom/i, 25], [/depth|tiefe/i, 100], [/macro|makro/i, 30], [/mono|infrared|\bir\b/i, 60]];

// Punktzahl einer Kamera aus dem Namen (höher = besser, Frontkamera sehr niedrig)
export function scoreCamera(label) {
  const l = String(label || '');
  if (FRONT.test(l)) return -1000;
  let s = 0;
  if (BACK.test(l)) s += 10;
  const m = /camera2?\s*(\d+)/i.exec(l);
  if (m) s += Number(m[1]) === 0 ? 30 : -Number(m[1]); // „camera2 0, facing back“ ist die Hauptkamera
  for (const [re, pen] of BAD) if (re.test(l)) s -= pen;
  return s;
}

// Videoeingänge, beste zuerst; Frontkameras nur, wenn es nichts anderes gibt (dann nach hinten)
export function rankCameras(devices) {
  const cams = (devices || []).filter((d) => d && d.kind === 'videoinput');
  return cams.map((d, i) => ({ d, i, s: scoreCamera(d.label) })).sort((a, b) => b.s - a.s || a.i - b.i).map((x) => x.d);
}
// Rückkameras (ohne Front), beste zuerst – Auswahlliste für „🔄 Kamera wechseln“
export const backCameras = (devices) => rankCameras(devices).filter((d) => scoreCamera(d.label) > -1000);

// Gemerkte Kamera, wenn es sie noch gibt, sonst die beste Rückkamera; ohne Kamera null
export function pickCamera(devices, savedId = '') {
  const list = backCameras(devices);
  return list.find((d) => savedId && d.deviceId === savedId) || list[0] || null;
}
// Nächste Kamera reihum
export function nextCamera(devices, currentId) {
  const list = backCameras(devices);
  if (!list.length) return null;
  const i = list.findIndex((d) => d.deviceId === currentId);
  return list[(i + 1) % list.length];
}
// getUserMedia-Vorgabe für eine bestimmte Kamera: scharf genug zum Lesen, wenn möglich dauerhaft fokussieren
export const cameraConstraints = (deviceId) => ({
  video: { deviceId: { exact: deviceId }, width: { ideal: 1920 }, height: { ideal: 1080 } }, audio: false,
});
// Dauerfokus nur, wenn die Kamera ihn kennt (track.getCapabilities().focusMode)
export const wantsContinuousFocus = (caps) => !!caps && Array.isArray(caps.focusMode) && caps.focusMode.includes('continuous');
