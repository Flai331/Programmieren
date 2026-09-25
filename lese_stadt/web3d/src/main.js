// 3D-Stadtansicht der Lese-Stadt.
//
// Die App lädt diese Seite in einer WebView und schickt den Stadtzustand als
// JSON an `LeseStadt.update(json)`. Antippen meldet die Seite über den
// JavaScript-Kanal `Flutter` zurück: {"typ":"tap","x":…,"y":…} in Feldern.
//
// Koordinaten: Feld (x, y) der App liegt in three.js bei (x + 0.5, 0, y + 0.5),
// ein Feld ist eine Einheit groß, +Y zeigt nach oben.

import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import * as SkeletonUtils from 'three/examples/jsm/utils/SkeletonUtils.js';
import { MeshoptDecoder } from 'three/examples/jsm/libs/meshopt_decoder.module.js';

const MODELLE = 'models/';

// ------------------------------------------------------------------ Grundgerüst

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0xbfd9ef, 30, 90);

const camera = new THREE.PerspectiveCamera(35, window.innerWidth / window.innerHeight, 0.1, 300);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.minPolarAngle = THREE.MathUtils.degToRad(20);
controls.maxPolarAngle = THREE.MathUtils.degToRad(72);
controls.minDistance = 3;
controls.maxDistance = 60;
controls.screenSpacePanning = false;

const himmel = new THREE.HemisphereLight(0xcfe6ff, 0x5b6b3a, 0.9);
scene.add(himmel);
const sonne = new THREE.DirectionalLight(0xfff2dd, 2.6);
sonne.castShadow = true;
sonne.shadow.mapSize.set(2048, 2048);
sonne.shadow.bias = -0.0004;
sonne.shadow.normalBias = 0.02;
scene.add(sonne);
scene.add(sonne.target);

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

// ------------------------------------------------------------------ Texturen

function rauschTextur(basis, variation, flecken, punkte) {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const g = c.getContext('2d');
  g.fillStyle = basis;
  g.fillRect(0, 0, 256, 256);
  const rnd = mulberry(7);
  // Nahtlos: Flecken werden auch über den Rand gespiegelt gezeichnet.
  for (let i = 0; i < flecken; i++) {
    const x = rnd() * 256, y = rnd() * 256, r = 6 + rnd() * 26;
    g.fillStyle = variation[Math.floor(rnd() * variation.length)];
    g.globalAlpha = 0.18 + rnd() * 0.2;
    for (const dx of [-256, 0, 256]) for (const dy of [-256, 0, 256]) {
      g.beginPath();
      g.arc(x + dx, y + dy, r, 0, Math.PI * 2);
      g.fill();
    }
  }
  g.globalAlpha = 1;
  for (let i = 0; i < punkte; i++) {
    g.fillStyle = variation[Math.floor(rnd() * variation.length)];
    g.fillRect(rnd() * 256, rnd() * 256, 1 + rnd() * 2, 2 + rnd() * 3);
  }
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}

function pflasterTextur() {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const g = c.getContext('2d');
  g.fillStyle = '#6d6a64';
  g.fillRect(0, 0, 256, 256);
  const rnd = mulberry(3);
  const n = 8;
  for (let r = 0; r < n; r++) {
    for (let s = 0; s < n; s++) {
      const off = r % 2 ? 16 : 0;
      const v = 130 + Math.floor(rnd() * 40);
      g.fillStyle = `rgb(${v},${v - 4},${v - 10})`;
      g.beginPath();
      g.roundRect(s * 32 + off + 2 - (off && s === n - 1 ? 256 : 0), r * 32 + 2, 28, 28, 6);
      g.fill();
    }
  }
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}

function mulberry(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const grasTex = rauschTextur('#5c7a3e', ['#526f36', '#667f45', '#6f8a4b', '#4b6532', '#7a8a4e'], 160, 2500);
const wieseTex = rauschTextur('#617a42', ['#56703a', '#6b8249', '#74874f'], 120, 1200);
const pflasterTex = pflasterTextur();

// ------------------------------------------------------------------ Modelle

const loader = new GLTFLoader();
loader.setMeshoptDecoder(MeshoptDecoder);
const cache = new Map();

function lade(name) {
  if (!cache.has(name)) {
    cache.set(name, new Promise((resolve) => {
      loader.load(MODELLE + name + '.glb', (gltf) => {
        gltf.scene.traverse((o) => {
          if (o.isMesh) {
            o.castShadow = true;
            o.receiveShadow = true;
            if (o.material?.name === 'glas') glasMaterialien.add(o.material);
          }
        });
        resolve(gltf);
      }, undefined, () => resolve(null));
    }));
  }
  return cache.get(name);
}

const glasMaterialien = new Set();
const geistMaterial = new THREE.MeshStandardMaterial({
  color: 0xdfe8ff, transparent: true, opacity: 0.35, roughness: 0.6, depthWrite: false,
});

// ------------------------------------------------------------------ Stadt

const stadt = new THREE.Group();
scene.add(stadt);
let zustand = null;
let kameraGesetzt = false;
const gebaeudeObjekte = new Map(); // "x,y" -> {name, objekt}
let bodenGruppe = null;
let markierung = null;
let bauFelder = null;
let laternen = [];
const laternenLichter = [];
const lampenMaterial = new THREE.MeshStandardMaterial({ color: 0xfff1c4, emissive: 0xffc56b, emissiveIntensity: 0 });

function feld(x, y) {
  return new THREE.Vector3(x + 0.5, 0, y + 0.5);
}

function baueBoden(z) {
  if (bodenGruppe) stadt.remove(bodenGruppe);
  bodenGruppe = new THREE.Group();

  const aussen = new THREE.Mesh(
    new THREE.PlaneGeometry(400, 400),
    new THREE.MeshStandardMaterial({ map: wieseTex, roughness: 1 }),
  );
  wieseTex.repeat.set(200, 200);
  aussen.rotation.x = -Math.PI / 2;
  aussen.position.set(z.size / 2, -0.03, z.size / 2);
  aussen.receiveShadow = true;
  bodenGruppe.add(aussen);

  const tex = grasTex.clone();
  tex.needsUpdate = true;
  tex.repeat.set(z.size / 2, z.size / 2);
  const flaeche = new THREE.Mesh(
    new THREE.BoxGeometry(z.size, 0.06, z.size),
    new THREE.MeshStandardMaterial({ map: tex, roughness: 1 }),
  );
  flaeche.position.set(z.size / 2, -0.03, z.size / 2);
  flaeche.receiveShadow = true;
  bodenGruppe.add(flaeche);

  const strasseMat = new THREE.MeshStandardMaterial({ map: pflasterTex, roughness: 0.95 });
  const strasseGeo = new THREE.BoxGeometry(1, 0.02, 1);
  for (const [x, y] of z.strassen) {
    const m = new THREE.Mesh(strasseGeo, strasseMat);
    m.position.copy(feld(x, y)).setY(0.005);
    m.receiveShadow = true;
    bodenGruppe.add(m);
  }

  for (const v of z.viertel) {
    const tex2 = grasTex.clone();
    tex2.needsUpdate = true;
    tex2.repeat.set(v.breite / 2, v.hoehe / 2);
    const m = new THREE.Mesh(
      new THREE.BoxGeometry(v.breite, 0.06, v.hoehe),
      new THREE.MeshStandardMaterial({ map: tex2, color: new THREE.Color(v.farbe).lerp(new THREE.Color(0xffffff), 0.7), roughness: 1 }),
    );
    m.position.set(v.x0 + v.breite / 2, -0.028, v.y0 + v.hoehe / 2);
    m.receiveShadow = true;
    bodenGruppe.add(m);
  }
  stadt.add(bodenGruppe);
}

async function setzeGebaeude(z) {
  const soll = new Map();
  for (const g of z.gebaeude) soll.set(`${g.x},${g.y}`, g);

  for (const [key, alt] of gebaeudeObjekte) {
    const neu = soll.get(key);
    if (!neu || neu.modell !== alt.name || !!neu.geist !== alt.geist) {
      stadt.remove(alt.objekt);
      gebaeudeObjekte.delete(key);
    }
  }
  const auftraege = [];
  for (const [key, g] of soll) {
    if (gebaeudeObjekte.has(key)) continue;
    gebaeudeObjekte.set(key, { name: g.modell, geist: !!g.geist, objekt: new THREE.Group() });
    auftraege.push(lade(g.modell).then((gltf) => {
      const eintrag = gebaeudeObjekte.get(key);
      if (!gltf || !eintrag || eintrag.name !== g.modell) return;
      const obj = gltf.scene.clone(true);
      if (g.geist) {
        obj.traverse((o) => {
          if (o.isMesh) {
            o.material = geistMaterial;
            o.castShadow = false;
          }
        });
      }
      obj.position.copy(feld(g.x, g.y));
      obj.rotation.y = (g.drehung || 0) * Math.PI / 2;
      eintrag.objekt = obj;
      stadt.add(obj);
    }));
  }
  await Promise.all(auftraege);
}

function setzeLaternen(z) {
  for (const l of laternen) stadt.remove(l);
  laternen = [];
  laternenLichter.length = 0;
  lade('laterne').then((gltf) => {
    if (!gltf) return;
    const strassen = z.strassen.filter((_, i) => i % 3 === 0);
    for (const [x, y] of strassen) {
      const l = gltf.scene.clone(true);
      l.position.copy(feld(x, y)).add(new THREE.Vector3(0.42, 0, 0.42));
      // Leuchtende Glühbirne; echtes Licht nur für die ersten Laternen,
      // viele Punktlichter wären auf dem Handy zu langsam.
      const birne = new THREE.Mesh(new THREE.SphereGeometry(0.03, 10, 8), lampenMaterial);
      birne.position.set(0, 0.36, 0);
      l.add(birne);
      if (laternenLichter.length < 6) {
        const licht = new THREE.PointLight(0xffc56b, 0, 2.2, 1.6);
        licht.position.set(0, 0.36, 0);
        l.add(licht);
        laternenLichter.push(licht);
      }
      stadt.add(l);
      laternen.push(l);
    }
  });
}

function setzeMarkierung(z) {
  if (markierung) scene.remove(markierung);
  markierung = null;
  if (z.highlight) {
    markierung = new THREE.Mesh(
      new THREE.RingGeometry(0.46, 0.52, 4, 1),
      new THREE.MeshBasicMaterial({ color: 0xffa726, side: THREE.DoubleSide }),
    );
    markierung.rotation.x = -Math.PI / 2;
    markierung.rotation.z = Math.PI / 4;
    markierung.position.copy(feld(z.highlight[0], z.highlight[1])).setY(0.03);
    scene.add(markierung);
  }
  if (bauFelder) scene.remove(bauFelder);
  bauFelder = null;
  if (z.placing) {
    const belegt = new Set(z.gebaeude.map((g) => `${g.x},${g.y}`));
    const geo = new THREE.PlaneGeometry(0.94, 0.94);
    const mat = new THREE.MeshBasicMaterial({ color: 0xffeb3b, transparent: true, opacity: 0.28, depthWrite: false });
    bauFelder = new THREE.Group();
    for (let x = 0; x < z.size; x++) {
      for (let y = 0; y < z.size; y++) {
        if (belegt.has(`${x},${y}`)) continue;
        const m = new THREE.Mesh(geo, mat);
        m.rotation.x = -Math.PI / 2;
        m.position.copy(feld(x, y)).setY(0.02);
        bauFelder.add(m);
      }
    }
    scene.add(bauFelder);
  }
}

// ------------------------------------------------------------------ Tageszeit

let stundeBasis = 12;
let stundeSeit = performance.now();

function stunde() {
  return (stundeBasis + (performance.now() - stundeSeit) / 3600000) % 24;
}

const HIMMEL = [
  [0, 0x0d1530], [5, 0x1d2a52], [6.5, 0xf2b38a], [8, 0xbfd9ef], [17, 0xbfd9ef],
  [19, 0xf0a070], [20.5, 0x2a2f5a], [22, 0x0d1530], [24, 0x0d1530],
];

function farbeZu(tabelle, h) {
  for (let i = 1; i < tabelle.length; i++) {
    if (h <= tabelle[i][0]) {
      const [h0, c0] = tabelle[i - 1];
      const [h1, c1] = tabelle[i];
      return new THREE.Color(c0).lerp(new THREE.Color(c1), (h - h0) / (h1 - h0));
    }
  }
  return new THREE.Color(tabelle[0][1]);
}

function istArbeitszeit(h) {
  return h >= 7 && h < 18;
}

function aktualisiereLicht() {
  const h = stunde();
  const z = zustand;
  const mitte = new THREE.Vector3((z?.size ?? 10) / 2, 0, (z?.size ?? 10) / 2);
  // Sonne geht um 6 Uhr im Osten auf und um 20 Uhr im Westen unter.
  const tag = (h - 6) / 14;
  const hoehe = Math.sin(Math.PI * THREE.MathUtils.clamp(tag, 0, 1));
  const winkel = Math.PI * (0.15 + 0.7 * THREE.MathUtils.clamp(tag, 0, 1));
  const nacht = hoehe < 0.08;
  const r = 30;
  if (nacht) {
    sonne.position.set(mitte.x - 12, 22, mitte.z + 8);
    sonne.color.set(0x9fb4ff);
    sonne.intensity = 0.7;
    himmel.intensity = 0.55;
    himmel.color.set(0x5a6a9a);
  } else {
    sonne.position.set(mitte.x + Math.cos(winkel) * r, 4 + hoehe * 26, mitte.z - Math.sin(winkel) * r * 0.6);
    const abend = 1 - Math.min(1, hoehe * 2.5);
    sonne.color.set(0xfff2dd).lerp(new THREE.Color(0xff9a55), abend);
    sonne.intensity = 0.8 + 2.2 * Math.min(1, hoehe * 1.6);
    himmel.intensity = 0.45 + 0.5 * hoehe;
    himmel.color.set(0xcfe6ff);
  }
  sonne.target.position.copy(mitte);
  const s = (z?.size ?? 10) * 0.9 + 4;
  const cam = sonne.shadow.camera;
  cam.left = -s; cam.right = s; cam.top = s; cam.bottom = -s; cam.near = 1; cam.far = 90;
  cam.updateProjectionMatrix();

  const bg = farbeZu(HIMMEL, h);
  scene.background = bg;
  scene.fog.color.copy(bg);

  // Fenster leuchten nachts, wenn in den letzten Tagen viel gelesen wurde;
  // sonst nur vereinzelt schwach.
  const leuchten = nacht || h < 7 || h >= 19;
  for (const l of laternenLichter) l.intensity = leuchten ? 1.6 : 0;
  lampenMaterial.emissiveIntensity = leuchten ? 3 : 0;
  for (const m of glasMaterialien) {
    m.emissive = m.emissive || new THREE.Color();
    m.emissive.set(0xffb24d);
    m.emissiveIntensity = leuchten ? (z?.lichter ? 2.2 : 0.5) : 0;
  }
  return { h, nacht };
}

// ------------------------------------------------------------------ Menschen

const menschen = [];
let menschVorlage = null;
lade('mensch').then((g) => {
  if (!g) return;
  menschVorlage = g;
  const box = new THREE.Box3().setFromObject(g.scene);
  menschSkala = MENSCH_HOEHE / Math.max(0.001, box.max.y - box.min.y);
  if (zustand) setzeMenschen(zustand);
});

const MENSCH_HOEHE = 0.3; // Felder; ein Haus ist etwa 0,6 hoch
let menschSkala = 1;

const KLEIDUNG = [0x3f6e3a, 0x8c2f2a, 0x2f4f7a, 0x7a5a2f, 0x5a3f6e, 0xb88a3a, 0x3a6e6a];

function neuerMensch(farbe) {
  const obj = SkeletonUtils.clone(menschVorlage.scene);
  obj.traverse((o) => {
    if (o.isMesh) {
      o.castShadow = true;
      if (o.material?.name === 'hemd') {
        o.material = o.material.clone();
        o.material.color.set(farbe);
      }
    }
  });
  obj.scale.setScalar(menschSkala);
  // Das Modell blickt nach +Z, so wie lookAt und die Laufrichtung es
  // erwarten (die Schuhspitzen zeigen dorthin).
  obj.traverse((o) => { if (o.name === 'hammer') o.visible = false; });
  const huelle = new THREE.Group();
  huelle.add(obj);
  const mixer = new THREE.AnimationMixer(obj);
  const clips = {};
  for (const c of menschVorlage.animations) clips[c.name] = mixer.clipAction(c);
  stadt.add(huelle);
  return { obj: huelle, mixer, clips, aktiv: null };
}

function spiele(m, name) {
  const clip = m.clips[name] || Object.values(m.clips)[0];
  if (m.aktiv === clip) return;
  m.obj.traverse((o) => { if (o.name === 'hammer') o.visible = name === 'haemmern'; });
  if (m.aktiv) m.aktiv.fadeOut(0.25);
  clip.reset().fadeIn(0.25).play();
  m.aktiv = clip;
}

function begehbar(z) {
  const belegt = new Set(z.gebaeude.filter((g) => !g.begehbar).map((g) => `${g.x},${g.y}`));
  return (x, y) => x >= 0 && y >= 0 && x < z.size && y < z.size && !belegt.has(`${x},${y}`);
}

function weg(z, von, nach) {
  // Breitensuche auf dem Feldraster über freie Felder.
  const frei = begehbar(z);
  const key = (p) => p[0] + ',' + p[1];
  const vorher = new Map([[key(von), null]]);
  const q = [von];
  while (q.length) {
    const p = q.shift();
    if (p[0] === nach[0] && p[1] === nach[1]) break;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const n = [p[0] + dx, p[1] + dy];
      if (!frei(n[0], n[1]) || vorher.has(key(n))) continue;
      vorher.set(key(n), p);
      q.push(n);
    }
  }
  if (!vorher.has(key(nach))) return null;
  const pfad = [];
  for (let p = nach; p; p = vorher.get(key(p))) pfad.unshift(p);
  return pfad;
}

function zufallsFeld(z, rnd) {
  const frei = begehbar(z);
  const strassen = z.strassen.filter(([x, y]) => frei(x, y));
  for (let i = 0; i < 40; i++) {
    const p = strassen.length && rnd() < 0.6
      ? strassen[Math.floor(rnd() * strassen.length)]
      : [Math.floor(rnd() * z.size), Math.floor(rnd() * z.size)];
    if (frei(p[0], p[1])) return p;
  }
  return null;
}

function nachbarFeld(z, [x, y]) {
  const frei = begehbar(z);
  for (const [dx, dy] of [[0, 1], [1, 0], [-1, 0], [0, -1]]) {
    if (frei(x + dx, y + dy)) return [x + dx, y + dy, dx, dy];
  }
  return null;
}

function setzeMenschen(z) {
  for (const m of menschen) stadt.remove(m.obj);
  menschen.length = 0;
  if (!menschVorlage) return;
  const h = stunde();
  const rnd = mulberry(11);
  const arbeit = istArbeitszeit(h);
  const nachts = h < 6 || h >= 22;

  // Arbeiter an Baustellen und Arbeitsplätzen – nur während der Arbeitszeit.
  if (arbeit) {
    for (const b of z.baustellen) {
      for (let i = 0; i < 2; i++) {
        const n = nachbarFeld(z, b);
        if (!n) continue;
        const m = neuerMensch(i ? 0x8a6a3a : 0x2f4f7a);
        const seitlich = (i - 0.5) * 0.4;
        m.obj.position.set(b[0] + 0.5 + n[2] * 0.62 + (n[3] ? seitlich : 0), 0, b[1] + 0.5 + n[3] * 0.62 + (n[2] ? seitlich : 0));
        m.obj.lookAt(b[0] + 0.5, 0, b[1] + 0.5);
        spiele(m, 'haemmern');
        m.mixer.update(rnd() * 2);
        menschen.push(m);
      }
    }
    for (const a of z.arbeitsplaetze) {
      const n = nachbarFeld(z, a);
      if (!n) continue;
      const m = neuerMensch(0xe8e2d4);
      m.obj.position.set(a[0] + 0.5 + n[2] * 0.58, 0, a[1] + 0.5 + n[3] * 0.58);
      m.obj.lookAt(a[0] + 0.5 + n[2] * 2, 0, a[1] + 0.5 + n[3] * 2);
      spiele(m, 'stehen');
      menschen.push(m);
    }
  }

  // Spaziergänger: je nach Leseaktivität, nachts kaum jemand.
  let anzahl = [2, 5, 10, 16][z.belebung] ?? 4;
  if (nachts) anzahl = Math.min(anzahl, z.lichter ? 3 : 1);
  for (let i = 0; i < anzahl; i++) {
    const start = zufallsFeld(z, rnd);
    if (!start) break;
    const m = neuerMensch(KLEIDUNG[i % KLEIDUNG.length]);
    m.obj.position.copy(feld(start[0], start[1]));
    m.laeufer = { feld: start, pfad: [], pause: rnd() * 3, rnd: mulberry(100 + i) };
    menschen.push(m);
  }
}

function bewegeLaeufer(m, dt) {
  const l = m.laeufer;
  if (!l || !zustand) return;
  if (l.pause > 0) {
    l.pause -= dt;
    spiele(m, 'stehen');
    return;
  }
  if (!l.pfad.length) {
    const ziel = zufallsFeld(zustand, l.rnd);
    const pfad = ziel && weg(zustand, l.feld, ziel);
    if (!pfad || pfad.length < 2) {
      l.pause = 1 + l.rnd() * 2;
      return;
    }
    l.pfad = pfad.slice(1);
  }
  const ziel = feld(l.pfad[0][0], l.pfad[0][1]);
  const d = ziel.clone().sub(m.obj.position);
  const tempo = 0.55;
  if (d.length() < tempo * dt) {
    m.obj.position.copy(ziel);
    l.feld = l.pfad.shift();
    if (!l.pfad.length) l.pause = 2 + l.rnd() * 5;
  } else {
    d.normalize();
    m.obj.position.addScaledVector(d, tempo * dt);
    m.obj.rotation.y = Math.atan2(d.x, d.z);
  }
  spiele(m, 'gehen');
}

// ------------------------------------------------------------------ Antippen

const raycaster = new THREE.Raycaster();
const bodenEbene = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
let druck = null;

renderer.domElement.addEventListener('pointerdown', (e) => {
  druck = { x: e.clientX, y: e.clientY, t: performance.now() };
});
renderer.domElement.addEventListener('pointerup', (e) => {
  if (!druck) return;
  const weit = Math.hypot(e.clientX - druck.x, e.clientY - druck.y);
  const lange = performance.now() - druck.t;
  druck = null;
  if (weit > 8 || lange > 500) return;
  const ndc = new THREE.Vector2(
    (e.clientX / window.innerWidth) * 2 - 1,
    -(e.clientY / window.innerHeight) * 2 + 1,
  );
  raycaster.setFromCamera(ndc, camera);
  // Erst Gebäude treffen (auch hohe Türme), sonst den Boden.
  const treffer = raycaster.intersectObjects([...gebaeudeObjekte.values()].map((g) => g.objekt), true)[0];
  const p = treffer ? treffer.object.getWorldPosition(new THREE.Vector3()) : raycaster.ray.intersectPlane(bodenEbene, new THREE.Vector3());
  if (!p) return;
  melde({ typ: 'tap', x: Math.floor(p.x), y: Math.floor(p.z) });
});

function melde(nachricht) {
  const text = JSON.stringify(nachricht);
  if (window.Flutter?.postMessage) window.Flutter.postMessage(text);
  else console.log('an Flutter:', text);
}

// ------------------------------------------------------------------ Schnittstelle

window.LeseStadt = {
  // Für Tests: Kamera auf einen Punkt richten.
  kamera(px, py, pz, zx, zy, zz) {
    camera.position.set(px, py, pz);
    controls.target.set(zx, zy, zz);
    controls.update();
  },
  async update(json) {
    const z = typeof json === 'string' ? JSON.parse(json) : json;
    const alt = zustand;
    zustand = z;
    if (typeof z.stunde === 'number') {
      stundeBasis = z.stunde;
      stundeSeit = performance.now();
    }
    if (!kameraGesetzt) {
      kameraGesetzt = true;
      const m = z.size / 2;
      controls.target.set(m, 0, m);
      camera.position.set(m + z.size * 0.42, z.size * 0.45, m + z.size * 0.42);
      controls.update();
    }
    const bodenNeu = !alt || alt.size !== z.size ||
      JSON.stringify(alt.strassen) !== JSON.stringify(z.strassen) ||
      JSON.stringify(alt.viertel) !== JSON.stringify(z.viertel);
    if (bodenNeu) {
      baueBoden(z);
      setzeLaternen(z);
    }
    setzeMarkierung(z);
    await setzeGebaeude(z);
    const menschenNeu = !alt || alt.belebung !== z.belebung ||
      JSON.stringify(alt.baustellen) !== JSON.stringify(z.baustellen) ||
      JSON.stringify(alt.arbeitsplaetze) !== JSON.stringify(z.arbeitsplaetze) ||
      JSON.stringify(alt.gebaeude.map((g) => [g.x, g.y])) !== JSON.stringify(z.gebaeude.map((g) => [g.x, g.y]));
    if (menschenNeu) setzeMenschen(z);
    melde({ typ: 'bereit' });
  },
};

// ------------------------------------------------------------------ Schleife

const uhr = new THREE.Clock();
let letzteStunde = -1;
let letztesBild = 0;

function schleife(t) {
  requestAnimationFrame(schleife);
  if (document.hidden) return;
  // Höchstens 30 Bilder pro Sekunde, das schont den Akku.
  if (t - letztesBild < 32) return;
  letztesBild = t;
  const dt = Math.min(uhr.getDelta(), 0.1);
  controls.update();
  const { h } = aktualisiereLicht();
  // Zu jeder vollen Stunde Arbeiter und Spaziergänger neu verteilen.
  const volle = Math.floor(h);
  if (zustand && letzteStunde !== -1 && volle !== letzteStunde) setzeMenschen(zustand);
  letzteStunde = volle;
  for (const m of menschen) {
    bewegeLaeufer(m, dt);
    m.mixer.update(dt);
  }
  renderer.render(scene, camera);
}
requestAnimationFrame(schleife);
