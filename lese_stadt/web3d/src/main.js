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
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

const MODELLE = 'models/';

// ------------------------------------------------------------------ Grundgerüst

const renderer = new THREE.WebGLRenderer({ antialias: true });
// Volle Handy-Auflösung (3x) kostet viel Leistung und bringt wenig.
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
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
sonne.shadow.mapSize.set(1536, 1536);
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
const kiesTex = rauschTextur('#8a7556', ['#7a6548', '#9a8664', '#6e5a40', '#a8946f'], 140, 3000);
const gehwegTex = rauschTextur('#8f887c', ['#857e72', '#9a9387', '#7c756a'], 80, 800);

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

const RICHTUNGEN = [[0, -1], [1, 0], [0, 1], [-1, 0]];
let pfadFelder = new Set(); // "x,y" der Trampelpfade (begehbar, bebaubar)
let strassenFelder = new Set();

function kachel(geos, x, y, bx, bz, lx, lz, hoehe, oben = 0) {
  const g = new THREE.BoxGeometry(lx, hoehe, lz);
  g.translate(x + bx, oben + hoehe / 2, y + bz);
  geos.push(g);
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
  // Flach statt als Platte, sonst zeichnet sich die Kante als Linie ab.
  const flaeche = new THREE.Mesh(
    new THREE.PlaneGeometry(z.size, z.size),
    new THREE.MeshStandardMaterial({ map: tex, roughness: 1 }),
  );
  flaeche.rotation.x = -Math.PI / 2;
  flaeche.position.set(z.size / 2, -0.002, z.size / 2);
  flaeche.receiveShadow = true;
  bodenGruppe.add(flaeche);

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

  // Straßen: Kopfsteinpflaster, an Seiten ohne Anschluss ein erhöhter
  // Gehweg mit Bordstein – so entsteht ein durchgehendes Straßennetz.
  strassenFelder = new Set(z.strassen.map(([x, y]) => `${x},${y}`));
  const pflaster = [];
  const gehweg = [];
  for (const [x, y] of z.strassen) {
    kachel(pflaster, x, y, 0.5, 0.5, 1, 1, 0.02);
    RICHTUNGEN.forEach(([dx, dy]) => {
      if (strassenFelder.has(`${x + dx},${y + dy}`)) return;
      const b = 0.16;
      if (dx) kachel(gehweg, x, y, dx > 0 ? 1 - b / 2 : b / 2, 0.5, b, 1, 0.03);
      else kachel(gehweg, x, y, 0.5, dy > 0 ? 1 - b / 2 : b / 2, 1, b, 0.03);
    });
  }
  const ptex = pflasterTex.clone();
  ptex.needsUpdate = true;
  ptex.repeat.set(2, 2);
  for (const [geos, mat] of [
    [pflaster, new THREE.MeshStandardMaterial({ map: ptex, roughness: 0.95 })],
    [gehweg, new THREE.MeshStandardMaterial({ map: gehwegTex, roughness: 0.9 })],
  ]) {
    if (!geos.length) continue;
    const m = new THREE.Mesh(mergeGeometries(geos), mat);
    m.receiveShadow = true;
    bodenGruppe.add(m);
  }

  bauePfade(z);
  stadt.add(bodenGruppe);
}

// Trampelpfade: von der Tür jedes Gebäudes zur nächsten Straße (oder, solange
// es keine gibt, zur Stadtmitte). Sie belegen kein Feld, man kann darauf bauen.
function bauePfade(z) {
  pfadFelder = new Set();
  const gebaut = new Set(z.gebaeude.map((g) => `${g.x},${g.y}`));
  const frei = (x, y) => x >= 0 && y >= 0 && x < z.size && y < z.size && !gebaut.has(`${x},${y}`);
  const mitte = [Math.floor(z.size / 2), Math.floor(z.size / 2)];
  const ziele = strassenFelder.size ? strassenFelder : new Set([`${mitte[0]},${mitte[1]}`]);
  const stuecke = [];
  const verbinde = (a, b) => {
    const ax = a[0] + 0.5, ay = a[1] + 0.5, bx = b[0] + 0.5, by = b[1] + 0.5;
    const lx = Math.abs(ax - bx) + 0.22, ly = Math.abs(ay - by) + 0.22;
    kachel(stuecke, (ax + bx) / 2, (ay + by) / 2, 0, 0, lx, ly, 0.012);
  };
  for (const g of z.gebaeude) {
    if (g.geist || g.x >= z.size || g.y >= z.size) continue;
    // Tür zeigt nach +y (Süden); von dort aus suchen, sonst von einer Seite.
    const starts = [[g.x, g.y + 1], [g.x + 1, g.y], [g.x - 1, g.y], [g.x, g.y - 1]].filter(([x, y]) => frei(x, y) || ziele.has(`${x},${y}`));
    if (!starts.length) continue;
    const start = starts[0];
    const key = (p) => `${p[0]},${p[1]}`;
    const vorher = new Map([[key(start), null]]);
    const q = [start];
    let ende = null;
    while (q.length && !ende) {
      const p = q.shift();
      if (ziele.has(key(p)) || pfadFelder.has(key(p))) { ende = p; break; }
      if (vorher.size > 200) break;
      for (const [dx, dy] of RICHTUNGEN) {
        const n = [p[0] + dx, p[1] + dy];
        if (vorher.has(key(n))) continue;
        if (!frei(n[0], n[1]) && !ziele.has(key(n))) continue;
        vorher.set(key(n), p);
        q.push(n);
      }
    }
    if (!ende) continue;
    const pfad = [];
    for (let p = ende; p; p = vorher.get(key(p))) pfad.unshift(p);
    verbinde([g.x, g.y], pfad[0]);
    for (let i = 0; i < pfad.length; i++) {
      if (!strassenFelder.has(key(pfad[i]))) pfadFelder.add(key(pfad[i]));
      if (i > 0) verbinde(pfad[i - 1], pfad[i]);
    }
  }
  if (!stuecke.length) return;
  const ktex = kiesTex.clone();
  ktex.needsUpdate = true;
  ktex.repeat.set(0.5, 0.5);
  const m = new THREE.Mesh(mergeGeometries(stuecke), new THREE.MeshStandardMaterial({ map: ktex, roughness: 1 }));
  m.position.y = 0.001;
  m.receiveShadow = true;
  bodenGruppe.add(m);
}

// Wald rund um die Stadt, damit sie nicht auf einer endlosen Wiese steht.
let waldGruppe = null;
async function baueWald(z) {
  if (waldGruppe) stadt.remove(waldGruppe);
  waldGruppe = new THREE.Group();
  stadt.add(waldGruppe);
  const vorlagen = (await Promise.all(['baum', 'baum2'].map(lade))).filter(Boolean);
  if (!vorlagen.length) return;
  const sperre = (x, y) => {
    if (x > -1.5 && y > -1.5 && x < z.size + 0.5 && y < z.size + 0.5) return true;
    for (const v of z.viertel) {
      if (x > v.x0 - 1.5 && y > v.y0 - 1.5 && x < v.x0 + v.breite + 0.5 && y < v.y0 + v.hoehe + 0.5) return true;
    }
    return z.strassen.some(([sx, sy]) => Math.abs(sx - x) < 1.5 && Math.abs(sy - y) < 1.5);
  };
  const rnd = mulberry(99);
  const breite = 7;
  const plaetze = vorlagen.map(() => []);
  let maxX = z.size, maxY = z.size;
  for (const v of z.viertel) { maxX = Math.max(maxX, v.x0 + v.breite); maxY = Math.max(maxY, v.y0 + v.hoehe); }
  for (let x = -breite; x < maxX + breite; x += 0.8) {
    for (let y = -breite; y < maxY + breite; y += 0.8) {
      const px = x + (rnd() - 0.5) * 0.7, py = y + (rnd() - 0.5) * 0.7;
      if (sperre(px, py)) continue;
      // Am Waldrand lichter, weiter draußen dichter.
      const rand = Math.max(-px, -py, px - maxX, py - maxY);
      if (rnd() > 0.35 + Math.min(0.5, rand * 0.12)) continue;
      plaetze[Math.floor(rnd() * vorlagen.length)].push([px, py, 0.8 + rnd() * 0.7, rnd() * Math.PI * 2]);
    }
  }
  vorlagen.forEach((gltf, i) => {
    gltf.scene.updateMatrixWorld(true);
    gltf.scene.traverse((o) => {
      if (!o.isMesh) return;
      const n = plaetze[i].length;
      const inst = new THREE.InstancedMesh(o.geometry, o.material, n);
      const m = new THREE.Matrix4();
      plaetze[i].forEach(([x, y, s, r], k) => {
        m.compose(new THREE.Vector3(x, 0, y), new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), r), new THREE.Vector3(s, s, s));
        inst.setMatrixAt(k, m.multiply(o.matrixWorld));
      });
      inst.instanceMatrix.needsUpdate = true;
      inst.computeBoundingSphere();
      inst.computeBoundingBox();
      inst.castShadow = false;
      inst.receiveShadow = true;
      waldGruppe.add(inst);
    });
  });
}

// ------------------------------------------------------------------ Deko

const DEKO_HAUS = ['p_beet', 'p_busch', 'p_blumen', 'p_zaun'];
const DEKO_ARBEIT = ['p_fass', 'p_kisten', 'p_karren', 'p_heu'];
const DEKO_NATUR = ['p_busch', 'p_felsen', 'p_blumen', 'p_busch', 'baum'];
let dekoGruppe = null;

function hash(x, y, salz = 0) {
  let h = (x * 374761393 + y * 668265263 + salz * 982451653) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

async function setzeDeko(z) {
  if (dekoGruppe) stadt.remove(dekoGruppe);
  dekoGruppe = new THREE.Group();
  stadt.add(dekoGruppe);
  const belegt = new Map(z.gebaeude.map((g) => [`${g.x},${g.y}`, g]));
  // Pro Sorte eine Liste von Plätzen; gezeichnet wird gebündelt (Instancing),
  // das spart auf dem Handy viele einzelne Zeichenaufrufe.
  const plaetze = new Map();
  const setze = (name, x, y, dx, dz, dreh, skala = 1) => {
    if (!plaetze.has(name)) plaetze.set(name, []);
    plaetze.get(name).push(new THREE.Matrix4().compose(
      new THREE.Vector3(x + 0.5 + dx, 0, y + 0.5 + dz),
      new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), dreh),
      new THREE.Vector3(skala, skala, skala),
    ));
  };
  for (let x = 0; x < z.size; x++) {
    for (let y = 0; y < z.size; y++) {
      const k = `${x},${y}`;
      if (belegt.has(k) || strassenFelder.has(k)) continue;
      const nachbarn = RICHTUNGEN.map(([dx, dy]) => belegt.get(`${x + dx},${y + dy}`)).filter(Boolean);
      const r = hash(x, y);
      const dreh = Math.floor(hash(x, y, 1) * 4) * Math.PI / 2;
      const jx = (hash(x, y, 2) - 0.5) * 0.4, jz = (hash(x, y, 3) - 0.5) * 0.4;
      const auf = pfadFelder.has(k);
      const wohnen = nachbarn.some((g) => /^(haus|reihe_)/.test(g.modell) && !g.geist);
      const arbeit = nachbarn.some((g) => z.arbeitsplaetze.some(([ax, ay]) => ax === g.x && ay === g.y));
      const anStrasse = RICHTUNGEN.some(([dx, dy]) => strassenFelder.has(`${x + dx},${y + dy}`));
      if (auf) {
        // Auf Pfaden nur am Rand etwas Kleines.
        if (r < 0.2) setze(r < 0.1 ? 'p_blumen' : 'p_busch', x, y, 0.36, 0.36, dreh, 0.8);
      } else if (wohnen && r < 0.55) {
        setze(DEKO_HAUS[Math.floor(hash(x, y, 4) * DEKO_HAUS.length)], x, y, jx * 0.3, jz * 0.3, dreh);
        if (hash(x, y, 5) < 0.5) setze('p_zaun', x, y, 0, 0, dreh);
      } else if (arbeit && r < 0.6) {
        setze(DEKO_ARBEIT[Math.floor(hash(x, y, 4) * DEKO_ARBEIT.length)], x, y, jx, jz, dreh);
      } else if (anStrasse && r < 0.14) {
        setze('p_bank', x, y, 0, 0, dreh);
      } else if (r < 0.22) {
        const n = DEKO_NATUR[Math.floor(hash(x, y, 4) * DEKO_NATUR.length)];
        setze(n, x, y, jx, jz, dreh, n === 'baum' ? 0.6 + hash(x, y, 6) * 0.4 : 1);
      }
    }
  }
  const gruppe = dekoGruppe;
  await Promise.all([...plaetze].map(async ([name, liste]) => {
    const gltf = await lade(name);
    if (!gltf || gruppe !== dekoGruppe) return;
    gltf.scene.updateMatrixWorld(true);
    gltf.scene.traverse((o) => {
      if (!o.isMesh) return;
      const inst = new THREE.InstancedMesh(o.geometry, o.material, liste.length);
      liste.forEach((m, k) => inst.setMatrixAt(k, m.clone().multiply(o.matrixWorld)));
      inst.instanceMatrix.needsUpdate = true;
      inst.computeBoundingSphere();
      inst.castShadow = true;
      inst.receiveShadow = true;
      gruppe.add(inst);
    });
  }));
}

// ------------------------------------------------------------------ Rauch

// Schornsteine in Modellkoordinaten (x, Höhe, z).
const SCHORNSTEINE = {
  haus: [-0.12, 0.64, 0.1],
  haus_b: [0.1, 0.79, -0.08],
  haus_c: [0.12, 0.76, -0.05],
  baeckerei3d: [0.14, 0.88, 0.1],
  wassermuehle3d: [-0.3, 0.82, 0.12],
};
const rauchQuellen = [];
const rauchTex = (() => {
  const c = document.createElement('canvas');
  c.width = c.height = 64;
  const g = c.getContext('2d');
  const r = g.createRadialGradient(32, 32, 2, 32, 32, 30);
  r.addColorStop(0, 'rgba(235,235,235,0.9)');
  r.addColorStop(1, 'rgba(235,235,235,0)');
  g.fillStyle = r;
  g.fillRect(0, 0, 64, 64);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
})();

function neueRauchQuelle(pos) {
  const wolken = [];
  for (let i = 0; i < 7; i++) {
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: rauchTex, transparent: true, depthWrite: false, opacity: 0 }));
    sp.userData.alter = i / 7;
    wolken.push(sp);
    stadt.add(sp);
  }
  return { pos, wolken };
}

function bewegeRauch(dt, nacht) {
  for (const q of rauchQuellen) {
    for (const sp of q.wolken) {
      let a = sp.userData.alter + dt / 5;
      if (a > 1) a -= 1;
      sp.userData.alter = a;
      sp.position.set(q.pos.x + a * 0.25, q.pos.y + a * 0.6, q.pos.z - a * 0.1);
      const s = 0.06 + a * 0.22;
      sp.scale.set(s, s, s);
      sp.material.opacity = (1 - a) * (nacht ? 0.25 : 0.5);
    }
  }
}

async function setzeGebaeude(z) {
  const soll = new Map();
  for (const g of z.gebaeude) soll.set(`${g.x},${g.y}`, g);

  for (const [key, alt] of gebaeudeObjekte) {
    const neu = soll.get(key);
    if (!neu || neu.modell !== alt.name || !!neu.geist !== alt.geist) {
      stadt.remove(alt.objekt);
      if (alt.rauch) {
        for (const sp of alt.rauch.wolken) stadt.remove(sp);
        rauchQuellen.splice(rauchQuellen.indexOf(alt.rauch), 1);
      }
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
      obj.userData.feld = [g.x, g.y];
      eintrag.objekt = obj;
      stadt.add(obj);
      const sch = !g.geist && SCHORNSTEINE[g.modell];
      if (sch) {
        eintrag.rauch = neueRauchQuelle(new THREE.Vector3(g.x + 0.5 + sch[0], sch[1], g.y + 0.5 + sch[2]));
        rauchQuellen.push(eintrag.rauch);
      }
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
      l.position.copy(feld(x, y)).add(new THREE.Vector3(0.42, 0.045, 0.42));
      // Leuchtende Glühbirne; echtes Licht nur für die ersten Laternen,
      // viele Punktlichter wären auf dem Handy zu langsam.
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

let vorschau = null;
const vorschauMaterial = new THREE.MeshStandardMaterial({
  color: 0x9cff8a, transparent: true, opacity: 0.6, roughness: 0.6, depthWrite: false,
});

async function setzeVorschau(z) {
  const v = z.vorschau;
  const schluessel = v ? `${v.modell}@${v.x},${v.y}` : null;
  if (vorschau?.schluessel === schluessel) return;
  if (vorschau) scene.remove(vorschau.obj);
  vorschau = null;
  if (!v) return;
  vorschau = { schluessel, obj: new THREE.Group() };
  const gltf = await lade(v.modell);
  if (!gltf || vorschau?.schluessel !== schluessel) return;
  const obj = gltf.scene.clone(true);
  obj.traverse((o) => { if (o.isMesh) { o.material = vorschauMaterial; o.castShadow = false; } });
  obj.position.copy(feld(v.x, v.y));
  vorschau.obj = obj;
  scene.add(obj);
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

const HAARE = [0x2b1a10, 0x4a2e18, 0x6b4a2a, 0x1a1410, 0x8a6a3a, 0x9a9a92];
let menschZaehler = 0;

function neuerMensch(farbe) {
  const obj = SkeletonUtils.clone(menschVorlage.scene);
  const nr = menschZaehler++;
  obj.traverse((o) => {
    if (o.isMesh) {
      // Schatten der kleinen Figuren kosten viel und sieht man kaum.
      o.castShadow = false;
      if (o.material?.name === 'hemd') {
        o.material = o.material.clone();
        o.material.color.set(farbe);
      } else if (o.material?.name === 'haare') {
        o.material = o.material.clone();
        o.material.color.set(HAARE[nr % HAARE.length]);
      }
    }
  });
  obj.scale.setScalar(menschSkala * (0.9 + mulberry(nr + 7)() * 0.2));
  // Das Modell blickt nach +Z, so wie lookAt und die Laufrichtung es
  // erwarten (die Schuhspitzen zeigen dorthin).
  obj.traverse((o) => { if (o.name === 'hammer') o.visible = false; });
  const huelle = new THREE.Group();
  huelle.add(obj);
  if (mulberry(nr + 31)() < 0.55) setzeHut(huelle, obj, nr);
  const mixer = new THREE.AnimationMixer(obj);
  const clips = {};
  for (const c of menschVorlage.animations) clips[c.name] = mixer.clipAction(c);
  stadt.add(huelle);
  return { obj: huelle, mixer, clips, aktiv: null };
}

const HUTFARBEN = [0x5a3f2a, 0x3a3a3a, 0xc9a86a, 0x6b2f2a, 0x2f3f5a];

// Hut auf den Kopf. Er sitzt an der Hülle (nicht am Knochen), das Wippen
// des Kopfes beim Gehen ist so klein, dass man es nicht vermisst.
function setzeHut(huelle, obj, nr) {
  huelle.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(obj);
  const mat = new THREE.MeshStandardMaterial({ color: HUTFARBEN[nr % HUTFARBEN.length], roughness: 0.9 });
  const hut = new THREE.Group();
  const h = MENSCH_HOEHE;
  const krempe = new THREE.Mesh(new THREE.CylinderGeometry(h * 0.1, h * 0.1, h * 0.01, 14), mat);
  const krone = new THREE.Mesh(new THREE.CylinderGeometry(h * 0.055, h * 0.065, h * 0.07, 12), mat);
  krone.position.y = h * 0.035;
  hut.add(krempe, krone);
  hut.position.set(0, box.max.y - huelle.position.y - h * 0.025, h * 0.01);
  huelle.add(hut);
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
  return (x, y) => (strassenFelder.has(`${x},${y}`) ||
    (x >= 0 && y >= 0 && x < z.size && y < z.size)) && !belegt.has(`${x},${y}`);
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
  const wege = [...pfadFelder].map((k) => k.split(',').map(Number));
  const strassen = [...z.strassen, ...wege].filter(([x, y]) => frei(x, y));
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

  // Träger bringen Mehl und Brot zwischen Mühle, Bäckerei und Markt hin
  // und her, am Markt stehen Händler und Kundschaft.
  if (arbeit) {
    (z.lieferungen || []).forEach(([ax, ay, bx, by, ware], i) => {
      const von = nachbarFeld(z, [ax, ay]);
      const nach = nachbarFeld(z, [bx, by]);
      if (!von || !nach) return;
      const m = neuerMensch(ware === 'korb' ? 0xe8e2d4 : 0x7a6a4a);
      m.last = setzeLast(m.obj, ware);
      const rnd2 = mulberry(300 + i);
      m.obj.position.copy(feld(von[0], von[1]));
      m.laeufer = { feld: [von[0], von[1]], pfad: [], pause: rnd2() * 4, rnd: rnd2,
        route: [[nach[0], nach[1]], [von[0], von[1]]], hin: true };
      menschen.push(m);
    });
    for (const g of z.gebaeude.filter((g) => g.modell === 'marktplatz')) {
      for (let i = 0; i < 3; i++) {
        const w = (i / 3) * Math.PI * 2 + 0.4;
        const m = neuerMensch(KLEIDUNG[(i + 3) % KLEIDUNG.length]);
        m.obj.position.set(g.x + 0.5 + Math.cos(w) * 0.3, 0, g.y + 0.5 + Math.sin(w) * 0.3);
        m.obj.lookAt(g.x + 0.5, 0, g.y + 0.5);
        spiele(m, 'stehen');
        m.mixer.update(rnd() * 2);
        menschen.push(m);
      }
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

const LAST_FARBEN = { sack: 0xd8c8a0, korb: 0x8a5a2a, brot: 0xc0843a };

// Mehlsack auf der Schulter oder Brotkorb vor dem Bauch.
function setzeLast(huelle, ware) {
  const h = MENSCH_HOEHE;
  const last = new THREE.Group();
  const mat = (f) => new THREE.MeshStandardMaterial({ color: f, roughness: 0.95 });
  if (ware === 'korb') {
    const korb = new THREE.Mesh(new THREE.CylinderGeometry(h * 0.1, h * 0.075, h * 0.07, 10), mat(LAST_FARBEN.korb));
    last.add(korb);
    for (let i = 0; i < 3; i++) {
      const brot = new THREE.Mesh(new THREE.SphereGeometry(h * 0.04, 8, 6), mat(LAST_FARBEN.brot));
      brot.scale.set(1.5, 0.8, 1);
      brot.position.set((i - 1) * h * 0.05, h * 0.045, (i % 2) * h * 0.02);
      last.add(brot);
    }
    last.position.set(0, h * 0.5, h * 0.11);
  } else {
    const sack = new THREE.Mesh(new THREE.SphereGeometry(h * 0.09, 10, 8), mat(LAST_FARBEN.sack));
    sack.scale.set(1.4, 0.8, 0.9);
    last.add(sack);
    last.position.set(h * 0.05, h * 0.86, -h * 0.02);
  }
  huelle.add(last);
  return last;
}

function bewegeLaeufer(m, dt) {
  const l = m.laeufer;
  if (!l || !zustand) return;
  if (l.pause > 0) {
    l.pause -= dt;
    spiele(m, 'stehen');
    return;
  }
  if (!l.pfad.length && l.route) {
    // Träger: abwechselnd zum Ziel (mit Ware) und zurück (ohne).
    const ziel = l.route[l.hin ? 0 : 1];
    const pfad = weg(zustand, l.feld, ziel);
    if (!pfad || pfad.length < 2) {
      l.hin = !l.hin;
      l.pause = 2;
      return;
    }
    l.pfad = pfad.slice(1);
    if (m.last) m.last.visible = l.hin;
    l.hin = !l.hin;
  }
  if (!l.pfad.length) {
    const markt = zustand.gebaeude.find((g) => g.modell === 'marktplatz');
    const ziel = markt && l.rnd() < 0.3 ? [markt.x, markt.y] : zufallsFeld(zustand, l.rnd);
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
  // Beim Bauen zählt der Boden; sonst zuerst Gebäude (auch hohe Türme).
  let ziel = null;
  if (!zustand?.placing) {
    const treffer = raycaster.intersectObjects([...gebaeudeObjekte.values()].map((g) => g.objekt), true)[0];
    for (let o = treffer?.object; o && !ziel; o = o.parent) ziel = o.userData?.feld;
  }
  if (!ziel) {
    const p = raycaster.ray.intersectPlane(bodenEbene, new THREE.Vector3());
    if (!p) return;
    ziel = [Math.floor(p.x), Math.floor(p.z)];
  }
  // Sofort sichtbar machen, welches Feld getroffen wurde.
  setzeMarkierung({ ...zustand, highlight: ziel });
  melde({ typ: 'tap', x: ziel[0], y: ziel[1] });
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
    const lageNeu = bodenNeu || !alt ||
      JSON.stringify(alt.gebaeude.map((g) => [g.x, g.y, g.modell, g.geist])) !==
      JSON.stringify(z.gebaeude.map((g) => [g.x, g.y, g.modell, g.geist]));
    if (lageNeu) {
      baueBoden(z);
      setzeDeko(z);
    }
    if (bodenNeu) {
      setzeLaternen(z);
      baueWald(z);
    }
    setzeMarkierung(z);
    setzeVorschau(z);
    await setzeGebaeude(z);
    const menschenNeu = !alt || alt.belebung !== z.belebung ||
      JSON.stringify(alt.baustellen) !== JSON.stringify(z.baustellen) ||
      JSON.stringify(alt.arbeitsplaetze) !== JSON.stringify(z.arbeitsplaetze) ||
      JSON.stringify(alt.lieferungen) !== JSON.stringify(z.lieferungen) ||
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
  const { h, nacht } = aktualisiereLicht();
  bewegeRauch(dt, nacht);
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
