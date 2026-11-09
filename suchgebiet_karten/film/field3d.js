// 3D-Einsatzstelle für compose3d.js (läuft in der Seite, braucht three.min.js):
// Kartenbild als Boden, Bäume dort, wo die Karte Wald zeigt, Teams als Spielfiguren mit Weg, Drohne, Markierungen, Dämmerung.
/* global THREE */
window.field = (() => {
  const W = 1920, H = 1080, CANOPY = 27;
  let D, EV, renderer, scene, camera, ground, trees, treeInfo, treeState = '', hemi, sun, lines, tokens = {}, trails = {}, pins = {}, drone, beam, ring, ffTokens = [];
  const C = (h) => new THREE.Color(h);
  const cl = (v) => Math.max(0, Math.min(1, v));
  const ease = (k) => (k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2);
  const wx = (p) => new THREE.Vector3(p[0] - D.w / 2, 0, p[1] - D.h / 2);
  const along = (pts, u) => { // Punkt bei Anteil u (0..1) entlang der Punktfolge
    u = cl(u); const f = u * (pts.length - 1), i = Math.min(pts.length - 2, Math.floor(f)), k = f - i;
    return [pts[i][0] + (pts[i + 1][0] - pts[i][0]) * k, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * k];
  };
  const mix = (a, b, k) => [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k];
  const inPoly = (p, poly) => { let c = false; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const a = poly[i], b = poly[j]; if ((a[1] > p[1]) !== (b[1] > p[1]) && p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]) c = !c; } return c; };
  const centroid = (poly) => [poly.reduce((s, q) => s + q[0], 0) / poly.length, poly.reduce((s, q) => s + q[1], 0) / poly.length];
  const cellRect = (c) => { const g = D.grid; return [g.x0 + c[0] * g.cell, g.y0 + c[2] * g.cell, g.x0 + (c[1] + 1) * g.cell, g.y0 + (c[3] + 1) * g.cell]; };

  function token(color, withDog, scale = 1) {
    const g = new THREE.Group();
    const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.7, 0.7, CANOPY, 6), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.7 }));
    stem.position.y = CANOPY / 2; g.add(stem);
    const mat = new THREE.MeshLambertMaterial({ color, emissive: C(color).multiplyScalar(0.25) });
    const body = new THREE.Mesh(new THREE.CylinderGeometry(4.2, 5.4, 15, 14), mat); body.position.y = CANOPY + 8; g.add(body);
    const head = new THREE.Mesh(new THREE.SphereGeometry(4.2, 14, 10), new THREE.MeshLambertMaterial({ color: 0xffe0c0, emissive: 0x332a22 })); head.position.y = CANOPY + 20; g.add(head);
    const lamp = new THREE.Mesh(new THREE.SphereGeometry(2.2, 8, 6), new THREE.MeshBasicMaterial({ color: 0xfff3b0 })); lamp.position.set(0, CANOPY + 21, 4); g.add(lamp); g.userData.lamp = lamp;
    if (withDog) {
      const dm = new THREE.MeshLambertMaterial({ color: 0x6d4c41, emissive: 0x1f1510 });
      const dog = new THREE.Mesh(new THREE.BoxGeometry(9, 5, 4), dm); dog.position.set(10, CANOPY + 4, 4); g.add(dog);
      const dh = new THREE.Mesh(new THREE.BoxGeometry(4, 4, 3.4), dm); dh.position.set(15.5, CANOPY + 7, 4); g.add(dh);
    }
    g.scale.setScalar(scale);
    scene.add(g);
    return g;
  }
  function pin(color, h = 46) {
    const g = new THREE.Group();
    const m = new THREE.MeshLambertMaterial({ color, emissive: C(color).multiplyScalar(0.35) });
    const stem = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.2, h, 8), m); stem.position.y = h / 2; g.add(stem);
    const ball = new THREE.Mesh(new THREE.SphereGeometry(7, 16, 12), m); ball.position.y = h + 5; g.add(ball);
    scene.add(g);
    return g;
  }
  function ribbon(pts, color, width = 4.5) { // flaches Band entlang der Punkte, über den Baumkronen
    const pos = [], idx = [];
    for (let i = 0; i < pts.length; i++) {
      const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
      let nx = -(b[1] - a[1]), nz = b[0] - a[0]; const l = Math.hypot(nx, nz) || 1; nx = nx / l * width / 2; nz = nz / l * width / 2;
      const p = wx(pts[i]);
      pos.push(p.x - nx, CANOPY + 2, p.z - nz, p.x + nx, CANOPY + 2, p.z + nz);
      if (i) { const k = (i - 1) * 2; idx.push(k, k + 1, k + 2, k + 1, k + 3, k + 2); }
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); geo.setIndex(idx);
    const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color, side: THREE.DoubleSide }));
    m.userData.n = pts.length - 1; geo.setDrawRange(0, 0);
    scene.add(m);
    return m;
  }
  const setRibbon = (m, u) => m.geometry.setDrawRange(0, Math.floor(cl(u) * m.userData.n) * 6);
  function bar(a, b, color, y = CANOPY + 1, w = 3) { // Linie als schmaler Quader
    const va = wx(a), vb = wx(b), len = va.distanceTo(vb);
    const m = new THREE.Mesh(new THREE.BoxGeometry(len, 1.6, w), new THREE.MeshBasicMaterial({ color }));
    m.position.copy(va).add(vb).multiplyScalar(0.5); m.position.y = y; m.rotation.y = -Math.atan2(vb.z - va.z, vb.x - va.x);
    return m;
  }

  async function init(data, ev, mapUrl) {
    D = data; EV = ev;
    const g = D.grid; g.cols = Math.ceil((g.x1 - g.x0) / g.cell - 0.03); g.rows = Math.ceil((g.y1 - g.y0) / g.cell - 0.03);
    renderer = new THREE.WebGLRenderer({ canvas: document.getElementById('gl'), antialias: true, preserveDrawingBuffer: true });
    renderer.setSize(W, H, false);
    scene = new THREE.Scene();
    scene.fog = new THREE.Fog(0xcfe3f1, 2200, 6200);
    scene.background = C(0xcfe3f1);
    camera = new THREE.PerspectiveCamera(38, W / H, 5, 12000);
    hemi = new THREE.HemisphereLight(0xffffff, 0x8a9a7a, 0.95); scene.add(hemi);
    sun = new THREE.DirectionalLight(0xfff1d6, 0.75); sun.position.set(-600, 900, 500); scene.add(sun);
    // Boden: Kartenbild
    const img = await new Promise((res) => { const i = new Image(); i.onload = () => res(i); i.src = mapUrl; });
    const tex = new THREE.Texture(img); tex.needsUpdate = true; tex.anisotropy = 8; tex.colorSpace = THREE.SRGBColorSpace;
    ground = new THREE.Mesh(new THREE.PlaneGeometry(D.w, D.h), new THREE.MeshLambertMaterial({ map: tex }));
    ground.rotation.x = -Math.PI / 2; scene.add(ground);
    const far = new THREE.Mesh(new THREE.PlaneGeometry(30000, 30000), new THREE.MeshLambertMaterial({ color: 0xeef0e2 })); far.rotation.x = -Math.PI / 2; far.position.y = -2; scene.add(far);
    // Bäume: wo die Karte waldgrün ist
    const cv = document.createElement('canvas'); cv.width = D.w; cv.height = D.h; const cx = cv.getContext('2d'); cx.drawImage(img, 0, 0);
    const px = cx.getImageData(0, 0, D.w, D.h).data;
    let seed = 7; const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
    const list = [];
    const polys = { See: D.see, Bahn: D.bahndamm };
    for (let y = 8; y < D.h - 8; y += 16) for (let x = 8; x < D.w - 8; x += 16) {
      const X = Math.round(x + (rnd() - 0.5) * 11), Y = Math.round(y + (rnd() - 0.5) * 11), o = (Y * D.w + X) * 4;
      const r = px[o], gg = px[o + 1], b = px[o + 2];
      if (!(gg - b > 38 && r < 226 && gg > 200)) continue;
      let area = '';
      for (const [n, t] of Object.entries(D.teams)) if (t.cells) { const q = cellRect(t.cells); if (X >= q[0] && X < q[2] && Y >= q[1] && Y < q[3]) area = n; }
      if (!area) for (const [n, p] of Object.entries(polys)) if (inPoly([X, Y], p)) area = n;
      list.push({ x: X, y: Y, s: 0.75 + rnd() * 0.6, c: 0.82 + rnd() * 0.3, area });
    }
    treeInfo = list;
    const geo = new THREE.ConeGeometry(7.5, 26, 6); geo.translate(0, 13, 0);
    trees = new THREE.InstancedMesh(geo, new THREE.MeshLambertMaterial({ color: 0xffffff }), list.length);
    const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), sc = new THREE.Vector3();
    list.forEach((t, i) => { sc.set(t.s, t.s * (0.85 + (i % 7) * 0.05), t.s); m4.compose(wx([t.x, t.y]), q, sc); trees.setMatrixAt(i, m4); });
    scene.add(trees);
    // Rasterlinien über den Kronen
    lines = new THREE.Group();
    for (let c = 0; c <= g.cols; c++) lines.add(bar([g.x0 + c * g.cell, g.y0], [g.x0 + c * g.cell, g.y0 + g.rows * g.cell], 0xd32f2f));
    for (let r = 0; r <= g.rows; r++) lines.add(bar([g.x0, g.y0 + r * g.cell], [g.x0 + g.cols * g.cell, g.y0 + r * g.cell], 0xd32f2f));
    scene.add(lines);
    const loop = (poly, color) => { const gr = new THREE.Group(); poly.forEach((p, i) => gr.add(bar(p, poly[(i + 1) % poly.length], color, CANOPY + 1.5, 4))); scene.add(gr); return gr; };
    pins.seeLine = loop(D.see, 0xef6c00); pins.bahnLine = loop(D.bahndamm, 0xef6c00);
    // Figuren, Wege, Markierungen
    tokens.Anna = token(D.teams.Anna.color, true); tokens.Jonas = token(D.teams.Jonas.color, true); tokens.Mia = token(D.teams.Mia.color, true);
    for (let i = 0; i < 8; i++) ffTokens.push(token(D.teams.FF.color, false, 0.8));
    trails.Anna = ribbon([...D.walkAnna.slice(0, Math.round(D.walkAnna.length * 0.85)), ...D.toHeat.slice(1)], D.teams.Anna.color);
    trails.Jonas = ribbon(D.walkJonas, D.teams.Jonas.color); trails.Mia = ribbon(D.walkMia, D.teams.Mia.color); trails.Mia2 = ribbon(D.walkMia2, D.teams.Mia.color);
    pins.bort = pin(0x1565c0, 60); pins.bort.position.copy(wx(D.bort));
    pins.cap = pin(0xfbc02d); pins.cap.position.copy(wx(D.cap));
    pins.hut = pin(0xad1457); pins.hut.position.copy(wx(D.hut));
    pins.heat = pin(0xff6d00); pins.heat.position.copy(wx(D.heat));
    ring = new THREE.Mesh(new THREE.RingGeometry(16, 21, 40), new THREE.MeshBasicMaterial({ color: 0xff6d00, transparent: true, side: THREE.DoubleSide })); ring.rotation.x = -Math.PI / 2; ring.position.copy(wx(D.heat)); ring.position.y = CANOPY + 3; scene.add(ring);
    beam = new THREE.Mesh(new THREE.CylinderGeometry(9, 9, 420, 20, 1, true), new THREE.MeshBasicMaterial({ color: 0x69f0ae, transparent: true, opacity: 0.4, side: THREE.DoubleSide, depthWrite: false })); beam.position.copy(wx(D.heat)); beam.position.y = 210; scene.add(beam);
    drone = new THREE.Group();
    drone.add(new THREE.Mesh(new THREE.BoxGeometry(12, 3, 12), new THREE.MeshLambertMaterial({ color: 0x263238, emissive: 0x101518 })));
    for (const [dx, dz] of [[-9, -9], [9, -9], [-9, 9], [9, 9]]) { const r = new THREE.Mesh(new THREE.CylinderGeometry(6, 6, 0.8, 14), new THREE.MeshBasicMaterial({ color: 0x80deea, transparent: true, opacity: 0.75 })); r.position.set(dx, 2.5, dz); drone.add(r); }
    const cone = new THREE.Mesh(new THREE.ConeGeometry(38, 70, 20, 1, true), new THREE.MeshBasicMaterial({ color: 0x80deea, transparent: true, opacity: 0.16, side: THREE.DoubleSide, depthWrite: false })); cone.position.y = -37; drone.add(cone);
    scene.add(drone);
    return list.length;
  }

  // ---------- Zustand zur Filmzeit t ----------
  function positions(t) {
    const g = D.grid, P = {};
    const near = (k) => [D.bort[0] + [30, -10, 20, 0, -30][k], D.bort[1] + [20, 35, -30, -45, 5][k]];
    const go = (from, to, a, b) => mix(from, to, ease(cl((t - a) / (b - a))));
    const walk = (name, k, pts, uEnd, tEnd) => {
      if (t < EV.depart) return near(k);
      if (t < EV.search) return go(near(k), pts[0], EV.depart, EV.search);
      return along(pts, cl((t - EV.search) / (tEnd - EV.search)) * uEnd);
    };
    // Anna: Schlangenlinie, dann zur Wärmequelle, zurück
    const aEnd = along(D.walkAnna, 0.85);
    P.Anna = t < EV.annaGo ? walk('Anna', 0, D.walkAnna, 0.85, EV.annaGo) : t < EV.back ? go(aEnd, D.heat, EV.annaGo, EV.fund - 1) : go(D.heat, near(0), EV.back, EV.home);
    P.uAnna = t < EV.search ? 0 : t < EV.annaGo ? cl((t - EV.search) / (EV.annaGo - EV.search)) * 0.8 : 0.8 + 0.2 * cl((t - EV.annaGo) / (EV.fund - 1 - EV.annaGo));
    P.Jonas = t < EV.back ? walk('Jonas', 1, D.walkJonas, 1, EV.back) : go(along(D.walkJonas, 1), near(1), EV.back, EV.home);
    P.uJonas = t < EV.search ? 0 : cl((t - EV.search) / (EV.back - EV.search));
    const mEnd = along(D.walkMia, 1);
    if (t < EV.miaDone) P.Mia = walk('Mia', 2, D.walkMia, 1, EV.miaDone);
    else if (t < EV.mia2) P.Mia = mEnd;
    else if (t < EV.mia2 + 8) P.Mia = go(mEnd, D.walkMia2[0], EV.mia2, EV.mia2 + 8);
    else if (t < EV.back) P.Mia = along(D.walkMia2, cl((t - EV.mia2 - 8) / (EV.back - EV.mia2 - 8)));
    else P.Mia = go(along(D.walkMia2, 1), near(2), EV.back, EV.home);
    P.uMia = t < EV.search ? 0 : cl((t - EV.search) / (EV.miaDone - EV.search));
    P.uMia2 = cl((t - EV.mia2 - 8) / (EV.back - EV.mia2 - 8));
    // Feuerwehr-Kette: streift die Reihen 4–5 von West nach Ost ab
    const fr = cellRect(D.teams.FF.cells), fy = (k) => fr[1] + 10 + (fr[3] - fr[1] - 20) * k / 7;
    let fxp;
    if (t < EV.depart) fxp = null; else if (t < EV.ff) fxp = -1; else fxp = fr[0] + (fr[2] - fr[0]) * cl((t - EV.ff) / (EV.ffDone - EV.ff));
    P.FF = ffTokens.map((_, k) => {
      const start = [fr[0], fy(k)], home = [D.bort[0] - 60 + k * 9, D.bort[1] + 60];
      if (fxp === null) return home;
      if (fxp === -1) return go(home, start, EV.depart, EV.ff);
      const cur = [fxp, fy(k)];
      return t < EV.back ? cur : go([fr[2], fy(k)], home, EV.back, EV.home);
    });
    // Drohne: Bahnen über den Feldern G–H, dann über der Wärmequelle
    const dr = cellRect(D.teams.Drohne.cells), lanes = [];
    for (let i = 0; i <= 6; i++) { const y = dr[1] + (dr[3] - dr[1]) * i / 6; lanes.push(i % 2 ? [dr[2] - 8, y] : [dr[0] + 8, y], i % 2 ? [dr[0] + 8, y] : [dr[2] - 8, y]); }
    if (t < EV.ff) P.Drohne = go(D.bort, lanes[0], EV.depart, EV.ff);
    else if (t < EV.heat - 6) P.Drohne = along(lanes, ((t - EV.ff) / 55) % 1);
    else if (t < EV.back) P.Drohne = go(along(lanes, ((EV.heat - 6 - EV.ff) / 55) % 1), D.heat, EV.heat - 6, EV.heat - 1);
    else P.Drohne = go(D.heat, D.bort, EV.back, EV.home);
    return P;
  }

  function colorTrees(t, dusk) {
    const g = [], add = (n, on, done) => g.push(n + (done ? 'D' : on ? '1' : '0'));
    const on = { Anna: t > EV.fills, Jonas: t > EV.fills + 2.5, FF: t > EV.fills + 5, Drohne: t > EV.fills + 7.5, See: t > EV.see, Bahn: t > EV.bahn };
    const done = { See: t > EV.miaDone, FF: t > EV.ffDone, Anna: false, Jonas: false, Drohne: false, Bahn: false };
    for (const n of Object.keys(on)) add(n, on[n], done[n]);
    const key = g.join('');
    if (key === treeState) return;
    treeState = key;
    const base = C(0x5f9e4f), col = new THREE.Color(), tint = { Anna: C(D.teams.Anna.color), Jonas: C(D.teams.Jonas.color), FF: C(D.teams.FF.color), Drohne: C(D.teams.Drohne.color), See: C(D.teams.Mia.color), Bahn: C(D.teams.Mia.color) }, ok = C(0x2e7d32);
    treeInfo.forEach((tr, i) => {
      col.copy(base).multiplyScalar(tr.c);
      if (tr.area && on[tr.area]) col.lerp(done[tr.area] ? ok : tint[tr.area], done[tr.area] ? 0.55 : 0.62);
      trees.setColorAt(i, col);
    });
    trees.instanceColor.needsUpdate = true;
  }

  // st: { t, cam: { a, b, k }, lt }  ->  Beschriftungen als Bildschirmpunkte
  function update(st) {
    const t = st.t, P = positions(t);
    const dusk = cl((t - EV.dusk) / 18);
    // Licht
    const day = C(0xcfe3f1), night = C(0x1a2540), bg = day.clone().lerp(night, dusk);
    scene.background = bg; scene.fog.color = bg;
    hemi.intensity = 0.95 - 0.42 * dusk; hemi.color.copy(C(0xffffff)).lerp(C(0x7f9cff), dusk);
    sun.intensity = 0.75 - 0.5 * dusk; sun.color.copy(C(0xfff1d6)).lerp(C(0xff9a5a), Math.min(1, dusk * 2));
    colorTrees(t, dusk);
    lines.visible = t > EV.grid;
    lines.children.forEach((b, i) => { b.visible = t > EV.grid + i * 0.08; });
    pins.seeLine.visible = t > EV.see; pins.bahnLine.visible = t > EV.bahn;
    // Figuren
    const show = t > 1;
    for (const n of ['Anna', 'Jonas', 'Mia']) { const v = wx(P[n]); tokens[n].position.set(v.x, 0, v.z); tokens[n].visible = show; tokens[n].userData.lamp.visible = dusk > 0.3; }
    ffTokens.forEach((tk, k) => { const v = wx(P.FF[k]); tk.position.set(v.x, 0, v.z); tk.visible = show; tk.userData.lamp.visible = dusk > 0.3; });
    setRibbon(trails.Anna, P.uAnna); setRibbon(trails.Jonas, P.uJonas); setRibbon(trails.Mia, P.uMia); setRibbon(trails.Mia2, P.uMia2);
    const dv = wx(P.Drohne); drone.position.set(dv.x, 95 + Math.sin(t * 2) * 3, dv.z); drone.rotation.y = t * 0.6; drone.visible = t > EV.depart && t < EV.home;
    const pop = (o, at) => { const k = cl((t - at) / 0.6); o.visible = k > 0; o.scale.setScalar(k > 0 ? 0.3 + 0.7 * (1 - Math.pow(1 - k, 3)) : 1); };
    pop(pins.cap, EV.cap); pop(pins.hut, EV.hut); pop(pins.heat, EV.heat);
    ring.visible = t > EV.heat; const rs = 1 + ((t * 0.7) % 1) * 1.6; ring.scale.setScalar(rs); ring.material.opacity = 0.9 * (1 - ((t * 0.7) % 1)); ring.material.color.set(t > EV.fund ? 0x69f0ae : 0xff6d00);
    beam.visible = t > EV.fund; beam.material.opacity = 0.28 + 0.14 * Math.sin(t * 4);
    // Kamera
    const g = D.grid, focus = {
      bort: D.bort, grid: [g.x0 + g.cols * g.cell / 2, g.y0 + g.rows * g.cell / 2], cap: D.cap, hut: D.hut, heat: D.heat, bahndamm: centroid(D.bahndamm), see: centroid(D.see),
      Anna: P.Anna, Jonas: P.Jonas, Mia: P.Mia, mid: mix(D.bort, [g.x0 + g.cols * g.cell / 2, g.y0 + g.rows * g.cell / 2], 0.5),
    };
    const res = (c) => ({ p: focus[c.focus] || focus.grid, dist: c.dist, elev: c.elev, az: c.az, fx: c.fx, fy: c.fy });
    const a = res(st.cam.a), b = res(st.cam.b), k = st.cam.k, L = (x, y) => x + (y - x) * k;
    const tp = mix(a.p, b.p, k), dist = L(a.dist, b.dist), elev = L(a.elev, b.elev) * Math.PI / 180, az = L(a.az, b.az) * Math.PI / 180, fx = L(a.fx, b.fx), fy = L(a.fy, b.fy);
    const tv = wx(tp); tv.y = 12;
    camera.position.set(tv.x + Math.sin(az) * Math.cos(elev) * dist, tv.y + Math.sin(elev) * dist, tv.z + Math.cos(az) * Math.cos(elev) * dist);
    camera.lookAt(tv);
    camera.setViewOffset(W, H, (0.5 - fx) * W, (0.5 - fy) * H, W, H);
    camera.updateProjectionMatrix();
    renderer.render(scene, camera);
    // Beschriftungen
    const out = [], v = new THREE.Vector3();
    const lab = (id, text, p, y, color, vis = true) => {
      if (!vis) return;
      v.copy(wx(p)); v.y = y; v.project(camera);
      if (v.z > 1 || v.z < -1) return;
      out.push({ id, text, x: (v.x * 0.5 + 0.5) * W, y: (-v.y * 0.5 + 0.5) * H, color });
    };
    lab('bort', '🚐 B-Ort · Einsatzleitung', D.bort, 78, '#1565c0');
    lab('Anna', 'Anna & Rex', P.Anna, CANOPY + 34, D.teams.Anna.color, show);
    lab('Jonas', 'Jonas & Luna', P.Jonas, CANOPY + 34, D.teams.Jonas.color, show);
    lab('Mia', 'Mia & Balu', P.Mia, CANOPY + 34, D.teams.Mia.color, show);
    lab('FF', '🚒 Feuerwehr-Kette', P.FF[0], CANOPY + 30, D.teams.FF.color, show && t > EV.depart);
    lab('Drohne', '🚁 Drohne', P.Drohne, 118, D.teams.Drohne.color, drone.visible);
    lab('cap', '🧢 Mütze gefunden', D.cap, 62, '#b58900', t > EV.cap);
    lab('hut', '🏚️ Jagdhütte: Zeugenhinweis', D.hut, 62, '#ad1457', t > EV.hut);
    lab('heat', t > EV.fund ? '✅ Herr K. gefunden' : '🔥 Wärmequelle', D.heat, 64, t > EV.fund ? '#2e7d32' : '#e65100', t > EV.heat);
    lab('see', t > EV.miaDone ? 'See ✅ abgesucht' : 'Gebiet See', centroid(D.see), CANOPY + 12, '#ef6c00', t > EV.see && t < EV.back);
    lab('bahn', 'Bahndamm Ost', centroid(D.bahndamm), CANOPY + 12, '#ef6c00', t > EV.bahn && t < EV.back);
    return out;
  }
  return { init, update };
})();
