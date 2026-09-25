"""Rendert die Gebäudebilder der Lese-Stadt mit Blender (bpy).

Jedes Gebäude wird als 3D-Modell auf einem 1×1-Feld gebaut und mit einer
isometrischen Kamera (Blickwinkel 30°, wie das 2:1-Raster der App) gerendert.
Der Hintergrund ist transparent, Schatten fallen über einen Schattenfänger.

Aufruf (Python mit dem Paket `bpy`, z. B. `pip install bpy==4.2.*`):

    python render_sprites.py <ausgabeordner> [name ...]

Ohne Namen werden alle Bilder gerendert. Pro Bild entsteht `<name>.webp`,
bei Gebäuden mit Fenstern zusätzlich `<name>_nacht.webp` mit erleuchteten
Fenstern. Bildformat: 320×480 px, die Feldmitte liegt bei (160, 384), ein
Feld ist 256 px breit.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

W, H = 320, 480
ANKER_Y = 384
TILE_PX = 256
SAMPLES = 40

TAN30 = math.tan(math.radians(30))


# --------------------------------------------------------------------------
# Szene


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = 'OPENIMAGEDENOISE'
    except TypeError:
        pass
    sc.cycles.max_bounces = 4
    sc.render.resolution_x = W
    sc.render.resolution_y = H
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.view_settings.view_transform = 'AgX'
    try:
        sc.view_settings.look = 'AgX - Punchy'
    except TypeError:
        pass
    return sc


def kamera(sc):
    cam_data = bpy.data.cameras.new('cam')
    cam_data.type = 'ORTHO'
    cam_data.sensor_fit = 'HORIZONTAL'
    breite = W / TILE_PX * math.sqrt(2)  # sichtbare Breite in Welteinheiten
    cam_data.ortho_scale = breite
    cam_data.clip_end = 100
    cam = bpy.data.objects.new('cam', cam_data)
    sc.collection.objects.link(cam)
    richtung = Vector((math.cos(math.radians(30)) / math.sqrt(2),
                       math.cos(math.radians(30)) / math.sqrt(2),
                       math.sin(math.radians(30))))
    oben = Vector((-math.sin(math.radians(30)) / math.sqrt(2),
                   -math.sin(math.radians(30)) / math.sqrt(2),
                   math.cos(math.radians(30))))
    px_pro_einheit = W / breite
    ziel = oben * ((ANKER_Y - H / 2) / px_pro_einheit)
    cam.location = ziel + richtung * 20
    cam.rotation_euler = (math.radians(60), 0, math.radians(135))
    sc.camera = cam


def licht(sc, nacht):
    world = bpy.data.worlds.new('welt')
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    if nacht:
        bg.inputs['Color'].default_value = (0.05, 0.07, 0.16, 1)
        bg.inputs['Strength'].default_value = 0.35
    else:
        bg.inputs['Color'].default_value = (0.62, 0.75, 0.95, 1)
        bg.inputs['Strength'].default_value = 0.4
    sc.world = world

    sonne = bpy.data.lights.new('sonne', 'SUN')
    sonne.angle = math.radians(4)
    if nacht:
        sonne.energy = 0.6
        sonne.color = (0.6, 0.7, 1.0)
    else:
        sonne.energy = 4.8
        sonne.color = (1.0, 0.95, 0.86)
    obj = bpy.data.objects.new('sonne', sonne)
    sc.collection.objects.link(obj)
    # Licht von links hinten oben (links im Bild = Welt +X/-Y).
    herkunft = Vector((1.0, -0.45, 1.15)).normalized()
    obj.rotation_euler = (-herkunft).to_track_quat('-Z', 'Y').to_euler()


def schattenfaenger(sc):
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
    ebene = bpy.context.active_object
    ebene.is_shadow_catcher = True
    return ebene


# --------------------------------------------------------------------------
# Materialien

_mats = {}
NACHT = False


def _principled(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    return m, nt, bsdf


def _coord(nt):
    tc = nt.nodes.new('ShaderNodeTexCoord')
    return tc.outputs['Object']


def mat(art, farbe=(0.8, 0.8, 0.8), rau=0.7, name=None):
    """art: putz, ziegel, dach, stein, holz, glas, metall, gold, gras, laub,
    wasser, pflaster, erde, leucht"""
    schluessel = name or f'{art}-{farbe}-{rau}-{NACHT}'
    if schluessel in _mats:
        return _mats[schluessel]
    m, nt, bsdf = _principled(schluessel)
    bsdf.inputs['Roughness'].default_value = rau
    col = (*farbe, 1)

    def noise_mix(scale, staerke, detail=4):
        noise = nt.nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = scale
        noise.inputs['Detail'].default_value = detail
        nt.links.new(_coord(nt), noise.inputs['Vector'])
        mix = nt.nodes.new('ShaderNodeMix')
        mix.data_type = 'RGBA'
        mix.inputs['Factor'].default_value = staerke
        mix.inputs['A'].default_value = col
        dunkler = tuple(c * 0.78 for c in farbe) + (1,)
        mix.inputs['B'].default_value = dunkler
        nt.links.new(noise.outputs['Fac'], mix.inputs['Factor'])
        ramp = mix
        return noise, ramp

    def bump(fac_output, staerke=0.3, abstand=0.02):
        b = nt.nodes.new('ShaderNodeBump')
        b.inputs['Strength'].default_value = staerke
        b.inputs['Distance'].default_value = abstand
        nt.links.new(fac_output, b.inputs['Height'])
        nt.links.new(b.outputs['Normal'], bsdf.inputs['Normal'])

    if art in ('ziegel', 'dach', 'pflaster'):
        brick = nt.nodes.new('ShaderNodeTexBrick')
        nt.links.new(_coord(nt), brick.inputs['Vector'])
        brick.inputs['Color1'].default_value = col
        brick.inputs['Color2'].default_value = tuple(c * 0.82 for c in farbe) + (1,)
        if art == 'ziegel':
            brick.inputs['Mortar'].default_value = (0.78, 0.76, 0.72, 1)
            brick.inputs['Scale'].default_value = 28
            brick.inputs['Mortar Size'].default_value = 0.012
            brick.inputs['Brick Width'].default_value = 0.5
            brick.inputs['Row Height'].default_value = 0.18
        elif art == 'dach':
            brick.inputs['Mortar'].default_value = tuple(c * 0.55 for c in farbe) + (1,)
            brick.inputs['Scale'].default_value = 20
            brick.inputs['Mortar Size'].default_value = 0.02
            brick.inputs['Brick Width'].default_value = 0.45
            brick.inputs['Row Height'].default_value = 0.3
        else:
            brick.inputs['Mortar'].default_value = tuple(c * 0.6 for c in farbe) + (1,)
            brick.inputs['Scale'].default_value = 22
            brick.inputs['Mortar Size'].default_value = 0.03
            brick.inputs['Brick Width'].default_value = 0.5
            brick.inputs['Row Height'].default_value = 0.5
        nt.links.new(brick.outputs['Color'], bsdf.inputs['Base Color'])
        bump(brick.outputs['Fac'], 0.4)
    elif art in ('putz', 'stein', 'erde', 'holz'):
        skala = {'putz': 18, 'stein': 9, 'erde': 14, 'holz': 30}[art]
        noise, mix = noise_mix(skala, 0.5)
        nt.links.new(mix.outputs['Result'], bsdf.inputs['Base Color'])
        bump(noise.outputs['Fac'], 0.15 if art == 'putz' else 0.35)
        if art == 'stein':
            vor = nt.nodes.new('ShaderNodeTexVoronoi')
            vor.inputs['Scale'].default_value = 14
            nt.links.new(_coord(nt), vor.inputs['Vector'])
            b = nt.nodes.new('ShaderNodeBump')
            b.inputs['Strength'].default_value = 0.35
            nt.links.new(vor.outputs['Distance'], b.inputs['Height'])
            nt.links.new(b.outputs['Normal'], bsdf.inputs['Normal'])
    elif art in ('gras', 'laub'):
        noise = nt.nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 40 if art == 'gras' else 25
        noise.inputs['Detail'].default_value = 8
        nt.links.new(_coord(nt), noise.inputs['Vector'])
        ramp = nt.nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].color = tuple(c * 0.62 for c in farbe) + (1,)
        ramp.color_ramp.elements[1].color = tuple(min(1, c * 1.2) for c in farbe) + (1,)
        nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
        nt.links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])
        bump(noise.outputs['Fac'], 0.6, 0.03)
        bsdf.inputs['Roughness'].default_value = 0.85
    elif art == 'glas':
        bsdf.inputs['Base Color'].default_value = (0.08, 0.12, 0.17, 1)
        bsdf.inputs['Roughness'].default_value = 0.08
        bsdf.inputs['Metallic'].default_value = 0.3
        if NACHT:
            bsdf.inputs['Emission Color'].default_value = (1.0, 0.72, 0.35, 1)
            bsdf.inputs['Emission Strength'].default_value = 5.0
    elif art == 'leucht':
        bsdf.inputs['Base Color'].default_value = col
        bsdf.inputs['Emission Color'].default_value = col
        bsdf.inputs['Emission Strength'].default_value = 6.0 if NACHT else 1.5
    elif art in ('metall', 'gold'):
        bsdf.inputs['Base Color'].default_value = col
        bsdf.inputs['Metallic'].default_value = 1.0
        bsdf.inputs['Roughness'].default_value = rau if art == 'metall' else 0.25
    elif art == 'wasser':
        bsdf.inputs['Base Color'].default_value = col
        bsdf.inputs['Roughness'].default_value = 0.05
        noise = nt.nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 20
        nt.links.new(_coord(nt), noise.inputs['Vector'])
        bump(noise.outputs['Fac'], 0.25)
    else:
        bsdf.inputs['Base Color'].default_value = col
    _mats[schluessel] = m
    return m


# --------------------------------------------------------------------------
# Bausteine (Maße in Welteinheiten, ein Feld = 1×1, z nach oben)


def _fertig(obj, material, bevel=0.0):
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new('bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    obj.data.materials.append(material)
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


def box(x, y, z, sx, sy, sz, material, bevel=0.006, rot=0.0):
    """Quader mit Mittelpunkt der Grundfläche bei (x, y, z)."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + sz / 2))
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    o.rotation_euler = (0, 0, rot)
    return _fertig(o, material, bevel)


def zylinder(x, y, z, r, h, material, n=32, r2=None, bevel=0.0):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=n, radius=r, depth=h,
                                            location=(x, y, z + h / 2))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r2,
                                        depth=h, location=(x, y, z + h / 2))
    o = bpy.context.active_object
    _fertig(o, material, bevel)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def kegel(x, y, z, r, h, material, n=32):
    return zylinder(x, y, z, r, h, material, n=n, r2=0.0)


def kugel(x, y, z, r, material, sz=1.0, n=24, glatt=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=n, ring_count=n // 2,
                                         radius=r, location=(x, y, z))
    o = bpy.context.active_object
    o.scale = (1, 1, sz)
    _fertig(o, material)
    for p in o.data.polygons:
        p.use_smooth = glatt
    return o


def mesh(name, verts, faces, material):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def satteldach(x, y, z, sx, sy, h, material, achse='x', ueberstand=0.04):
    """Satteldach über einer Grundfläche sx×sy, First entlang `achse`."""
    ax, ay = sx / 2 + ueberstand, sy / 2 + ueberstand
    if achse == 'x':
        v = [(x - ax, y - ay, z), (x + ax, y - ay, z), (x + ax, y + ay, z),
             (x - ax, y + ay, z), (x - ax, y, z + h), (x + ax, y, z + h)]
        f = [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5)]
    else:
        v = [(x - ax, y - ay, z), (x + ax, y - ay, z), (x + ax, y + ay, z),
             (x - ax, y + ay, z), (x, y - ay, z + h), (x, y + ay, z + h)]
        f = [(1, 2, 5, 4), (3, 0, 4, 5), (0, 1, 4), (2, 3, 5)]
    o = mesh('dach', v, f, material)
    sol = o.modifiers.new('dicke', 'SOLIDIFY')
    sol.thickness = 0.02
    return o


def giebel(x, y, z, sx, sy, h, material, achse='x'):
    """Giebelwände unter einem Satteldach (Dreiecke an den Stirnseiten)."""
    if achse == 'x':
        v = [(x - sx / 2, y - sy / 2, z), (x - sx / 2, y + sy / 2, z), (x - sx / 2, y, z + h),
             (x + sx / 2, y - sy / 2, z), (x + sx / 2, y + sy / 2, z), (x + sx / 2, y, z + h)]
    else:
        v = [(x - sx / 2, y - sy / 2, z), (x + sx / 2, y - sy / 2, z), (x, y - sy / 2, z + h),
             (x - sx / 2, y + sy / 2, z), (x + sx / 2, y + sy / 2, z), (x, y + sy / 2, z + h)]
    return mesh('giebel', v, [(0, 1, 2), (3, 5, 4)], material)


def walmdach(x, y, z, sx, sy, h, material, ueberstand=0.04, spitze=0.0):
    """Walm- bzw. Zeltdach; spitze > 0 = Firstlänge entlang x."""
    ax, ay = sx / 2 + ueberstand, sy / 2 + ueberstand
    v = [(x - ax, y - ay, z), (x + ax, y - ay, z), (x + ax, y + ay, z),
         (x - ax, y + ay, z), (x - spitze / 2, y, z + h), (x + spitze / 2, y, z + h)]
    f = [(0, 1, 5, 4), (2, 3, 4, 5), (1, 2, 5), (3, 0, 4)]
    o = mesh('walm', v, f, material)
    sol = o.modifiers.new('dicke', 'SOLIDIFY')
    sol.thickness = 0.02
    return o


def fenster(x0, y0, z0, sx, sy, etagen, spalten, hoehe, seiten=('+x', '+y'),
            fb=0.07, fh=0.1, rahmen=(0.93, 0.92, 0.88), start=0.08):
    """Fenster auf den sichtbaren Fassaden (+x und +y) eines Quaders mit
    Grundflächen-Mitte (x0, y0) und Unterkante z0."""
    glas = mat('glas')
    rahm = mat('putz', rahmen, 0.6)
    etage_h = (hoehe - start) / etagen
    for seite in seiten:
        laenge = sy if seite == '+x' else sx
        for e in range(etagen):
            z = z0 + start + e * etage_h + (etage_h - fh) / 2
            for s in range(spalten):
                t = -laenge / 2 + laenge * (s + 0.5) / spalten
                if seite == '+x':
                    px, py = x0 + sx / 2 + 0.004, y0 + t
                    box(px, py, z - 0.008, 0.012, fb + 0.02, fh + 0.016, rahm, 0.002)
                    box(px + 0.005, py, z, 0.01, fb, fh, glas, 0.0)
                else:
                    px, py = x0 + t, y0 + sy / 2 + 0.004
                    box(px, py, z - 0.008, fb + 0.02, 0.012, fh + 0.016, rahm, 0.002)
                    box(px, py + 0.005, z, fb, 0.01, fh, glas, 0.0)


def tuer(x0, y0, sx, sy, seite='+y', farbe=(0.36, 0.22, 0.13), b=0.09, h=0.16):
    holz = mat('holz', farbe, 0.6)
    if seite == '+y':
        box(x0, y0 + sy / 2 + 0.006, 0, b, 0.014, h, holz, 0.002)
    else:
        box(x0 + sx / 2 + 0.006, y0, 0, 0.014, b, h, holz, 0.002)


def zinnen(x, y, z, sx, sy, material, n=5, hoch=0.05):
    for i in range(n):
        t = -0.5 + (i + 0.5) / n
        for (px, py) in ((x + t * sx, y - sy / 2), (x + t * sx, y + sy / 2),
                         (x - sx / 2, y + t * sy), (x + sx / 2, y + t * sy)):
            box(px, py, z, 0.045, 0.045, hoch, material, 0.003)


def baumkrone(x, y, z, r, farbe=(0.24, 0.45, 0.2), n=5, seed=0):
    import random
    rnd = random.Random(seed)
    laub = mat('laub', farbe)
    for i in range(n):
        a = rnd.random() * math.tau
        d = r * 0.45 * rnd.random()
        rr = r * (0.55 + 0.35 * rnd.random())
        o = kugel(x + math.cos(a) * d, y + math.sin(a) * d,
                  z + r * 0.5 * rnd.random(), rr, laub, n=16)
        mod = o.modifiers.new('disp', 'DISPLACE')
        tex = bpy.data.textures.new(f'laub{seed}{i}', 'CLOUDS')
        tex.noise_scale = 0.06
        mod.texture = tex
        mod.strength = rr * 0.35
        sub = o.modifiers.new('sub', 'SUBSURF')
        sub.levels = 1
        sub.render_levels = 1
        o.modifiers.move(1, 0)


def baum(x, y, s=1.0, farbe=(0.24, 0.45, 0.2), seed=0):
    zylinder(x, y, 0, 0.022 * s, 0.22 * s, mat('holz', (0.33, 0.22, 0.14)), n=10)
    baumkrone(x, y, 0.28 * s, 0.14 * s, farbe, seed=seed)


def tanne(x, y, s=1.0, farbe=(0.16, 0.33, 0.2)):
    zylinder(x, y, 0, 0.02 * s, 0.1 * s, mat('holz', (0.3, 0.2, 0.12)), n=8)
    for i, (r, h) in enumerate(((0.13, 0.2), (0.1, 0.18), (0.07, 0.16))):
        kegel(x, y, 0.07 * s + i * 0.1 * s, r * s, h * s, mat('laub', farbe), n=14)


def geruest(x, y, sx, sy, h, ebenen=3):
    holz = mat('holz', (0.62, 0.45, 0.26), 0.7)
    for px in (x - sx / 2, x + sx / 2):
        for py in (y - sy / 2, y + sy / 2):
            zylinder(px, py, 0, 0.008, h, holz, n=6)
    for e in range(1, ebenen + 1):
        z = h * e / ebenen
        box(x, y - sy / 2, z - 0.01, sx, 0.02, 0.01, holz, 0)
        box(x, y + sy / 2, z - 0.01, sx, 0.02, 0.01, holz, 0)
        box(x - sx / 2, y, z - 0.01, 0.02, sy, 0.01, holz, 0)
        box(x + sx / 2, y, z - 0.01, 0.02, sy, 0.01, holz, 0)


def kran(x, y, h):
    gelb = mat('metall', (0.9, 0.62, 0.1), 0.5)
    box(x, y, 0, 0.05, 0.05, 0.03, mat('stein', (0.5, 0.5, 0.5)))
    box(x, y, 0, 0.025, 0.025, h, gelb, 0)
    box(x - 0.18, y, h, 0.5, 0.025, 0.025, gelb, 0)
    box(x + 0.12, y, h - 0.04, 0.08, 0.06, 0.05, mat('stein', (0.4, 0.4, 0.4)))
    zylinder(x - 0.3, y, h - 0.22, 0.003, 0.22, mat('metall', (0.2, 0.2, 0.2)), n=4)


def rasen(sx=0.96, sy=0.96, farbe=(0.3, 0.5, 0.18)):
    box(0, 0, 0, sx, sy, 0.012, mat('gras', farbe), 0.004)


def platz(sx=0.94, sy=0.94, farbe=(0.62, 0.6, 0.56)):
    box(0, 0, 0, sx, sy, 0.012, mat('pflaster', farbe, 0.8), 0.003)


# --------------------------------------------------------------------------
# Gebäude. Jede Funktion baut um den Ursprung; True = hat Fenster (Nachtbild).

CREME = (0.93, 0.87, 0.74)
TERRAKOTTA = (0.62, 0.25, 0.16)
SANDSTEIN = (0.82, 0.72, 0.55)
SCHIEFER = (0.22, 0.24, 0.28)
WEISS = (0.92, 0.91, 0.88)

GENREFARBEN = {
    'neutral': (0.78, 0.66, 0.48),
    'krimi': (0.55, 0.57, 0.6),
    'fantasy': (0.55, 0.4, 0.78),
    'scifi': (0.35, 0.52, 0.66),
    'sachbuch': (0.86, 0.8, 0.64),
    'romance': (0.86, 0.5, 0.62),
    'geschichte': (0.85, 0.82, 0.76),
    'horror': (0.3, 0.26, 0.34),
    'klassiker': (0.85, 0.66, 0.2),
}


def haus(wand=CREME, dach=TERRAKOTTA, s=1.0):
    sx, sy, h = 0.56 * s, 0.5 * s, 0.34 * s
    box(0, 0, 0, sx, sy, h, mat('putz', wand))
    giebel(0, 0, h, sx, sy, 0.24 * s, mat('putz', wand), 'x')
    satteldach(0, 0, h, sx, sy, 0.24 * s, mat('dach', dach), 'x')
    box(-0.12 * s, -0.1 * s, h, 0.06, 0.06, 0.26 * s, mat('ziegel', (0.55, 0.3, 0.22)))
    fenster(0, 0, 0, sx, sy, 2, 2, h)
    tuer(0.1 * s, 0, sx, sy, '+y')
    return True


def g_haus():
    haus()
    baum(-0.34, 0.3, 0.8, seed=3)
    return True


def g_baum():
    baum(0, 0, 1.4, seed=1)
    return False


def g_baum2():
    tanne(0.02, 0.0, 1.5)
    return False


def g_polizeiwache():
    platz(0.9, 0.9, (0.55, 0.55, 0.55))
    sx, sy, h = 0.7, 0.62, 0.5
    box(0, 0, 0, sx, sy, h, mat('ziegel', (0.4, 0.42, 0.48)))
    box(0, 0, h, sx + 0.03, sy + 0.03, 0.04, mat('stein', (0.7, 0.7, 0.72)))
    fenster(0, 0, 0, sx, sy, 2, 3, h, fb=0.08)
    box(0, sy / 2 + 0.01, 0.2, 0.3, 0.02, 0.07, mat('leucht', (0.12, 0.3, 0.75)))
    tuer(0, 0, sx, sy, '+y', (0.15, 0.2, 0.35), b=0.12)
    kugel(0.2, sy / 2 + 0.03, 0.2, 0.025, mat('leucht', (0.2, 0.45, 1.0)))
    return True


def g_detektivbuero():
    sx, sy, h = 0.5, 0.46, 0.66
    box(0, 0, 0, sx, sy, h, mat('ziegel', (0.36, 0.2, 0.15)))
    walmdach(0, 0, h, sx, sy, 0.2, mat('dach', SCHIEFER), spitze=0.18)
    fenster(0, 0, 0, sx, sy, 3, 2, h)
    box(0.06, sy / 2 + 0.03, 0.22, 0.22, 0.06, 0.18, mat('holz', (0.2, 0.14, 0.1)))
    fenster(0.06, 0.03, 0.22, 0.22, sy, 1, 2, 0.18, seiten=('+y',), start=0.02)
    tuer(-0.14, 0, sx, sy, '+y', (0.12, 0.1, 0.08))
    baum(0.32, -0.28, 0.8, seed=5)
    return True


def g_gefaengnis():
    stein = mat('stein', (0.5, 0.49, 0.47))
    box(0, 0, 0, 0.84, 0.84, 0.08, mat('pflaster', (0.45, 0.45, 0.44)))
    for (x, y, sx, sy) in ((0, -0.4, 0.84, 0.05), (0, 0.4, 0.84, 0.05),
                           (-0.4, 0, 0.05, 0.84), (0.4, 0, 0.05, 0.84)):
        box(x, y, 0.08, sx, sy, 0.22, stein)
    box(-0.05, -0.05, 0.08, 0.46, 0.4, 0.34, mat('stein', (0.62, 0.6, 0.57)))
    fenster(-0.05, -0.05, 0.08, 0.46, 0.4, 2, 4, 0.34, fb=0.04, fh=0.06)
    zylinder(0.32, 0.32, 0.08, 0.08, 0.62, stein, n=16)
    box(0.32, 0.32, 0.7, 0.2, 0.2, 0.08, mat('holz', (0.3, 0.22, 0.15)))
    walmdach(0.32, 0.32, 0.78, 0.2, 0.2, 0.1, mat('dach', SCHIEFER))
    return True


def g_magierturm():
    rasen(0.8, 0.8)
    stein = mat('stein', (0.66, 0.62, 0.72))
    zylinder(0, 0, 0, 0.23, 0.12, mat('stein', (0.5, 0.48, 0.52)))
    zylinder(0, 0, 0.12, 0.19, 1.05, stein)
    zylinder(0, 0, 0.8, 0.24, 0.04, mat('stein', (0.5, 0.48, 0.52)))
    kegel(0, 0, 1.17, 0.27, 0.62, mat('dach', (0.32, 0.2, 0.55)))
    zylinder(0, 0, 1.79, 0.006, 0.16, mat('metall', (0.3, 0.3, 0.3)), n=6)
    box(0.05, 0, 1.9, 0.1, 0.004, 0.05, mat('putz', (0.85, 0.2, 0.2)), 0)
    glas = mat('glas')
    for z in (0.35, 0.62, 0.95):
        for a in (math.radians(20), math.radians(70)):
            box(math.cos(a) * 0.19, math.sin(a) * 0.19, z, 0.05, 0.05, 0.1, glas, 0.004,
                rot=a)
    kugel(0.14, 0.2, 0.82, 0.03, mat('leucht', (0.6, 0.4, 1.0)))
    return True


def g_burg():
    rasen(0.95, 0.95, (0.34, 0.5, 0.24))
    stein = mat('stein', (0.6, 0.58, 0.54))
    box(0, 0, 0, 0.62, 0.62, 0.34, stein)
    zinnen(0, 0, 0.34, 0.62, 0.62, stein)
    box(-0.06, -0.06, 0.34, 0.3, 0.3, 0.4, stein)
    zinnen(-0.06, -0.06, 0.74, 0.3, 0.3, stein, n=3)
    for (x, y) in ((-0.31, -0.31), (0.31, -0.31), (-0.31, 0.31), (0.31, 0.31)):
        zylinder(x, y, 0, 0.09, 0.5, stein, n=20)
        kegel(x, y, 0.5, 0.11, 0.22, mat('dach', (0.25, 0.28, 0.5)), n=20)
    box(0, 0.31, 0, 0.14, 0.02, 0.18, mat('holz', (0.3, 0.2, 0.12)))
    fenster(-0.06, -0.06, 0.34, 0.3, 0.3, 1, 2, 0.4, fb=0.04)
    return True


def g_drachenhort():
    fels = mat('stein', (0.36, 0.33, 0.33), 0.9)
    o = kugel(0, 0, 0.05, 0.42, fels, sz=0.95, n=20, glatt=False)
    mod = o.modifiers.new('disp', 'DISPLACE')
    tex = bpy.data.textures.new('fels', 'VORONOI')
    tex.noise_scale = 0.25
    mod.texture = tex
    mod.strength = 0.12
    sub = o.modifiers.new('sub', 'SUBSURF')
    sub.levels = 2
    sub.render_levels = 2
    o.modifiers.move(1, 0)
    kugel(0.2, 0.28, 0.02, 0.14, mat('stein', (0.05, 0.04, 0.04)), sz=0.8)
    gold = mat('gold', (1.0, 0.75, 0.25))
    for (x, y, r) in ((0.28, 0.3, 0.05), (0.33, 0.2, 0.04), (0.2, 0.36, 0.035)):
        kugel(x, y, 0.0, r, gold, sz=0.6)
    for (x, y, h) in ((-0.2, 0.25, 0.22), (-0.28, 0.12, 0.16)):
        kegel(x, y, 0.05, 0.035, h, mat('leucht', (0.85, 0.15, 0.2)), n=6)
    return False


def g_observatorium():
    rasen(0.9, 0.9)
    zylinder(0, 0, 0, 0.3, 0.36, mat('putz', WEISS))
    o = kugel(0, 0, 0.36, 0.3, mat('metall', (0.75, 0.77, 0.8), 0.3), n=32)
    box(0.06, 0.06, 0.4, 0.07, 0.62, 0.3, mat('stein', (0.08, 0.08, 0.1)), rot=math.radians(45))
    fenster(0, 0, 0, 0.6, 0.6, 1, 3, 0.36, fb=0.05)
    tuer(0, 0, 0.6, 0.6, '+y')
    return True


def g_raumhafen():
    box(0, 0, 0, 0.94, 0.94, 0.02, mat('pflaster', (0.42, 0.44, 0.47), 0.6))
    zylinder(0.08, -0.05, 0.02, 0.28, 0.02, mat('putz', (0.85, 0.8, 0.2)))
    weiss = mat('metall', (0.9, 0.9, 0.92), 0.35)
    zylinder(0.08, -0.05, 0.08, 0.07, 0.7, weiss)
    kegel(0.08, -0.05, 0.78, 0.07, 0.22, mat('metall', (0.8, 0.15, 0.15), 0.35))
    for a in (0, 120, 240):
        r = math.radians(a)
        box(0.08 + math.cos(r) * 0.08, -0.05 + math.sin(r) * 0.08, 0.04, 0.04, 0.04, 0.2,
            mat('metall', (0.8, 0.15, 0.15), 0.35), rot=r)
    box(-0.28, 0.28, 0, 0.3, 0.3, 0.22, mat('metall', (0.55, 0.6, 0.65), 0.4))
    fenster(-0.28, 0.28, 0, 0.3, 0.3, 1, 2, 0.22, fb=0.08, fh=0.06)
    return True


def g_labor():
    platz(0.9, 0.9, (0.7, 0.7, 0.72))
    sx, sy, h = 0.66, 0.6, 0.62
    box(0, 0, 0, sx, sy, h, mat('metall', (0.6, 0.64, 0.68), 0.35))
    fenster(0, 0, 0, sx, sy, 4, 4, h, fb=0.1, fh=0.08, rahmen=(0.3, 0.32, 0.35))
    box(0.1, 0.05, h, 0.2, 0.2, 0.08, mat('metall', (0.5, 0.52, 0.55)))
    zylinder(-0.18, -0.15, h, 0.005, 0.25, mat('metall', (0.3, 0.3, 0.3)), n=6)
    kugel(-0.18, -0.15, h + 0.25, 0.015, mat('leucht', (1, 0.2, 0.2)))
    return True


def g_bibliothek():
    platz()
    sx, sy, h = 0.72, 0.6, 0.42
    stein = mat('stein', SANDSTEIN)
    box(0, 0, 0, sx + 0.04, sy + 0.04, 0.05, stein)
    box(0, -0.04, 0.05, sx, sy - 0.08, h, stein)
    for i in range(4):
        zylinder(-0.24 + i * 0.16, sy / 2 - 0.02, 0.05, 0.03, h - 0.02, mat('stein', (0.9, 0.86, 0.78)), n=16)
    box(0, 0.0, 0.05 + h, sx + 0.02, sy + 0.02, 0.05, stein)
    satteldach(0, 0, 0.1 + h, sx, sy, 0.12, mat('dach', (0.35, 0.4, 0.38)), 'x', 0.01)
    giebel(0, 0, 0.1 + h, sx, sy, 0.12, stein, 'x')
    fenster(0, -0.04, 0.05, sx, sy - 0.08, 2, 3, h, seiten=('+x',))
    tuer(0, -0.04, sx, sy - 0.08, '+y', b=0.12, h=0.2)
    return True


def g_schule():
    rasen()
    sx, sy, h = 0.78, 0.46, 0.4
    box(0, -0.1, 0, sx, sy, h, mat('ziegel', (0.62, 0.3, 0.22)))
    walmdach(0, -0.1, h, sx, sy, 0.18, mat('dach', (0.3, 0.3, 0.32)), spitze=0.4)
    box(0, -0.1, h + 0.1, 0.1, 0.1, 0.16, mat('holz', (0.9, 0.9, 0.88)))
    kegel(0, -0.1, h + 0.26, 0.08, 0.1, mat('dach', (0.3, 0.3, 0.32)), n=4)
    fenster(0, -0.1, 0, sx, sy, 2, 4, h)
    tuer(0, -0.1, sx, sy, '+y')
    baum(-0.3, 0.32, 0.8, seed=8)
    baum(0.32, 0.32, 0.7, seed=9)
    return True


def g_universitaet():
    platz()
    stein = mat('stein', SANDSTEIN)
    box(0, 0, 0, 0.8, 0.7, 0.44, stein)
    box(0, 0, 0.44, 0.82, 0.72, 0.04, mat('stein', (0.9, 0.85, 0.75)))
    zylinder(0, 0, 0.48, 0.16, 0.22, stein)
    kugel(0, 0, 0.7, 0.16, mat('metall', (0.35, 0.55, 0.45), 0.4), n=32)
    for i in range(5):
        zylinder(-0.24 + i * 0.12, 0.36, 0, 0.022, 0.44, mat('stein', (0.92, 0.88, 0.8)), n=12)
    fenster(0, 0, 0, 0.8, 0.7, 2, 4, 0.44, seiten=('+x',))
    return True


def g_park():
    rasen(0.96, 0.96, (0.36, 0.58, 0.26))
    weg = mat('pflaster', (0.78, 0.72, 0.6))
    box(0, 0, 0.012, 0.18, 0.96, 0.004, weg, 0)
    box(0.29, 0, 0.012, 0.38, 0.18, 0.004, weg, 0)
    box(-0.29, 0, 0.012, 0.38, 0.18, 0.004, weg, 0)
    baum(-0.28, -0.28, 1.0, seed=11)
    baum(0.28, -0.3, 0.8, seed=12)
    baum(-0.3, 0.28, 0.9, seed=13)
    for i, farbe in enumerate(((0.9, 0.3, 0.4), (0.95, 0.8, 0.3), (0.7, 0.4, 0.9))):
        for j in range(4):
            kugel(0.18 + j * 0.05, 0.2 + i * 0.07, 0.03, 0.022, mat('putz', farbe))
    box(0.2, -0.1, 0.02, 0.14, 0.04, 0.03, mat('holz', (0.45, 0.3, 0.18)))
    return False


def g_cafe():
    platz(0.94, 0.94, (0.72, 0.64, 0.56))
    haus(wand=(0.95, 0.8, 0.78), dach=(0.4, 0.3, 0.3), s=0.85)
    box(0.0, 0.25, 0.2, 0.46, 0.14, 0.015, mat('putz', (0.75, 0.22, 0.3)), rot=0)
    for (x, y) in ((-0.25, 0.36), (0.25, 0.36)):
        zylinder(x, y, 0, 0.005, 0.2, mat('metall', (0.3, 0.3, 0.3)), n=6)
        kegel(x, y, 0.2, 0.09, 0.05, mat('putz', (0.95, 0.95, 0.9)), n=12)
        zylinder(x, y, 0, 0.04, 0.09, mat('holz', (0.4, 0.28, 0.2)), n=12)
    return True


def g_brunnen():
    platz(0.94, 0.94, (0.66, 0.63, 0.58))
    stein = mat('stein', (0.8, 0.78, 0.74))
    zylinder(0, 0, 0.01, 0.3, 0.1, stein, n=40)
    zylinder(0, 0, 0.02, 0.27, 0.085, mat('wasser', (0.2, 0.45, 0.6)), n=40)
    zylinder(0, 0, 0.1, 0.05, 0.22, stein, n=16)
    zylinder(0, 0, 0.3, 0.12, 0.03, stein, n=24)
    zylinder(0, 0, 0.32, 0.1, 0.02, mat('wasser', (0.3, 0.55, 0.7)), n=24)
    kugel(0, 0, 0.4, 0.035, mat('wasser', (0.5, 0.7, 0.85)))
    for (x, y) in ((-0.36, -0.36), (0.36, 0.36)):
        baum(x, y, 0.6, seed=int(x * 10 + 20))
    return False


def g_denkmal():
    rasen()
    box(0, 0, 0.012, 0.5, 0.5, 0.004, mat('pflaster', (0.7, 0.68, 0.64), 0.8), 0)
    stein = mat('stein', (0.78, 0.76, 0.72))
    box(0, 0, 0.012, 0.3, 0.3, 0.1, stein)
    box(0, 0, 0.11, 0.2, 0.2, 0.18, stein)
    bronze = mat('metall', (0.42, 0.3, 0.18), 0.45)
    zylinder(0, 0, 0.29, 0.045, 0.2, bronze, n=16)
    kugel(0, 0, 0.53, 0.04, bronze)
    box(0.04, 0, 0.42, 0.14, 0.03, 0.03, bronze, rot=math.radians(30))
    return False


def g_rathaus():
    platz()
    sx, sy, h = 0.8, 0.56, 0.42
    box(0, -0.06, 0, sx, sy, h, mat('putz', (0.93, 0.9, 0.82)))
    satteldach(0, -0.06, h, sx, sy, 0.2, mat('dach', TERRAKOTTA), 'x')
    giebel(0, -0.06, h, sx, sy, 0.2, mat('putz', (0.93, 0.9, 0.82)), 'x')
    box(0, 0.2, 0, 0.18, 0.12, 0.86, mat('putz', (0.93, 0.9, 0.82)))
    kegel(0, 0.2, 0.86, 0.14, 0.26, mat('dach', (0.25, 0.4, 0.35)), n=4)
    zylinder(0, 0.265, 0.68, 0.05, 0.01, mat('putz', (0.98, 0.98, 0.95)), n=24).rotation_euler = (math.radians(90), 0, 0)
    fenster(0, -0.06, 0, sx, sy, 2, 4, h, seiten=('+x',))
    fenster(0, 0.2, 0, 0.18, 0.12, 3, 1, 0.66, seiten=('+y',))
    return True


def g_museum():
    platz()
    marmor = mat('stein', (0.9, 0.89, 0.86))
    box(0, 0, 0, 0.8, 0.7, 0.05, marmor)
    box(0, -0.04, 0.05, 0.7, 0.56, 0.38, marmor)
    for i in range(6):
        zylinder(-0.3 + i * 0.12, 0.3, 0.05, 0.022, 0.38, marmor, n=12)
    box(0, 0, 0.43, 0.74, 0.66, 0.04, marmor)
    zylinder(0, -0.04, 0.47, 0.15, 0.08, marmor)
    kugel(0, -0.04, 0.55, 0.15, mat('metall', (0.6, 0.62, 0.64), 0.35), n=32)
    fenster(0, -0.04, 0.05, 0.7, 0.56, 1, 3, 0.38, seiten=('+x',), fh=0.16)
    return True


def g_friedhof():
    rasen(0.96, 0.96, (0.3, 0.42, 0.24))
    stein = mat('stein', (0.62, 0.62, 0.6))
    for i in range(3):
        for j in range(3):
            x, y = -0.25 + i * 0.2, -0.05 + j * 0.16
            box(x, y, 0.012, 0.07, 0.025, 0.1, stein, 0.01)
    box(-0.28, -0.3, 0, 0.26, 0.2, 0.2, mat('stein', (0.55, 0.53, 0.5)))
    satteldach(-0.28, -0.3, 0.2, 0.26, 0.2, 0.12, mat('dach', SCHIEFER), 'y')
    giebel(-0.28, -0.3, 0.2, 0.26, 0.2, 0.12, mat('stein', (0.55, 0.53, 0.5)), 'y')
    eisen = mat('metall', (0.12, 0.12, 0.12), 0.5)
    for i in range(12):
        t = -0.46 + i * 0.084
        zylinder(t, 0.46, 0, 0.005, 0.1, eisen, n=5)
        zylinder(0.46, t, 0, 0.005, 0.1, eisen, n=5)
    tanne(0.28, -0.28, 1.1, (0.12, 0.25, 0.16))
    return True


def g_spukhaus():
    rasen(0.96, 0.96, (0.26, 0.3, 0.22))
    holz = mat('holz', (0.22, 0.2, 0.22), 0.8)
    box(0, 0, 0, 0.5, 0.46, 0.6, holz)
    satteldach(0, 0, 0.6, 0.5, 0.46, 0.3, mat('dach', (0.12, 0.12, 0.15)), 'y')
    giebel(0, 0, 0.6, 0.5, 0.46, 0.3, holz, 'y')
    box(0.22, 0.2, 0, 0.16, 0.16, 0.84, holz)
    walmdach(0.22, 0.2, 0.84, 0.16, 0.16, 0.2, mat('dach', (0.12, 0.12, 0.15)))
    fenster(0, 0, 0, 0.5, 0.46, 2, 2, 0.6, rahmen=(0.3, 0.28, 0.3))
    ast = mat('holz', (0.2, 0.16, 0.12))
    zylinder(-0.32, 0.3, 0, 0.02, 0.4, ast, n=6)
    box(-0.32, 0.3, 0.3, 0.2, 0.012, 0.012, ast, rot=math.radians(30))
    box(-0.32, 0.3, 0.36, 0.14, 0.012, 0.012, ast, rot=math.radians(-40))
    return True


def g_theater():
    platz()
    rot = mat('putz', (0.62, 0.18, 0.18))
    box(0, -0.05, 0, 0.74, 0.6, 0.5, rot)
    stein = mat('stein', (0.9, 0.86, 0.76))
    for i in range(4):
        zylinder(-0.24 + i * 0.16, 0.27, 0, 0.025, 0.42, stein, n=12)
    box(0, 0.27, 0.42, 0.62, 0.08, 0.06, stein)
    giebel(0, 0.27, 0.48, 0.62, 0.08, 0.16, stein, 'y')
    satteldach(0, -0.05, 0.5, 0.74, 0.6, 0.18, mat('metall', (0.35, 0.55, 0.45), 0.5), 'y')
    fenster(0, -0.05, 0, 0.74, 0.6, 2, 3, 0.5, seiten=('+x',))
    return True


def g_oper():
    platz()
    sand = mat('stein', SANDSTEIN)
    box(0, 0, 0, 0.84, 0.74, 0.46, sand)
    for i in range(6):
        zylinder(-0.3 + i * 0.12, 0.38, 0, 0.022, 0.46, mat('stein', (0.92, 0.88, 0.8)), n=12)
    box(0, 0, 0.46, 0.86, 0.76, 0.05, mat('stein', (0.92, 0.88, 0.8)))
    zylinder(0, -0.05, 0.51, 0.22, 0.12, sand)
    kugel(0, -0.05, 0.63, 0.22, mat('gold', (1.0, 0.78, 0.35)), n=32)
    fenster(0, 0, 0, 0.84, 0.74, 2, 4, 0.46, seiten=('+x',))
    return True


def g_marktplatz():
    platz(0.96, 0.96, (0.7, 0.66, 0.6))
    farben = [(0.8, 0.2, 0.2), (0.2, 0.45, 0.75), (0.95, 0.7, 0.2), (0.3, 0.6, 0.3)]
    for i, (x, y) in enumerate(((-0.24, -0.24), (0.24, -0.24), (-0.24, 0.24), (0.24, 0.24))):
        holz = mat('holz', (0.5, 0.35, 0.22))
        box(x, y, 0, 0.26, 0.18, 0.1, holz)
        for (dx, dy) in ((-0.12, -0.08), (0.12, -0.08), (-0.12, 0.08), (0.12, 0.08)):
            zylinder(x + dx, y + dy, 0.1, 0.006, 0.12, holz, n=6)
        satteldach(x, y, 0.22, 0.28, 0.2, 0.06, mat('putz', farben[i]), 'x', 0.01)
        for k in range(3):
            kugel(x - 0.07 + k * 0.07, y + 0.05, 0.12, 0.022,
                  mat('putz', ((0.9, 0.5, 0.1), (0.3, 0.6, 0.2), (0.8, 0.1, 0.2))[k]))
    zylinder(0, 0, 0, 0.08, 0.05, mat('stein', (0.8, 0.78, 0.74)))
    zylinder(0, 0, 0.01, 0.065, 0.045, mat('wasser', (0.2, 0.45, 0.6)))
    return False


def g_bahnhof():
    platz(0.96, 0.96, (0.55, 0.53, 0.5))
    ziegel = mat('ziegel', (0.58, 0.32, 0.24))
    box(-0.2, 0, 0, 0.36, 0.8, 0.4, ziegel)
    satteldach(-0.2, 0, 0.4, 0.36, 0.8, 0.14, mat('dach', SCHIEFER), 'y')
    giebel(-0.2, 0, 0.4, 0.36, 0.8, 0.14, ziegel, 'y')
    fenster(-0.2, 0, 0, 0.36, 0.8, 2, 4, 0.4)
    halle = mat('metall', (0.35, 0.4, 0.42), 0.4)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.2, depth=0.84,
                                        location=(0.18, 0, 0.12),
                                        rotation=(math.radians(90), 0, 0))
    o = bpy.context.active_object
    _fertig(o, halle)
    for p in o.data.polygons:
        p.use_smooth = True
    box(0.18, 0, 0, 0.4, 0.84, 0.12, mat('stein', (0.5, 0.5, 0.5)))
    box(-0.2, 0.25, 0.4, 0.1, 0.1, 0.34, ziegel)
    zylinder(-0.2, 0.305, 0.66, 0.04, 0.01, mat('putz', (0.98, 0.98, 0.95)), n=24).rotation_euler = (math.radians(90), 0, 0)
    return True


def g_hafen():
    box(0, 0, 0, 0.96, 0.96, 0.01, mat('wasser', (0.12, 0.32, 0.45)), 0)
    holz = mat('holz', (0.45, 0.32, 0.2))
    box(-0.3, 0, 0.01, 0.34, 0.96, 0.06, mat('stein', (0.55, 0.53, 0.5)))
    box(0.1, 0, 0.05, 0.5, 0.1, 0.02, holz)
    for x in (-0.1, 0.1, 0.3):
        zylinder(x, -0.05, 0, 0.012, 0.07, holz, n=8)
        zylinder(x, 0.05, 0, 0.012, 0.07, holz, n=8)
    box(-0.32, -0.25, 0.07, 0.24, 0.3, 0.24, mat('ziegel', (0.55, 0.3, 0.22)))
    satteldach(-0.32, -0.25, 0.31, 0.24, 0.3, 0.1, mat('dach', TERRAKOTTA), 'x')
    fenster(-0.32, -0.25, 0.07, 0.24, 0.3, 1, 2, 0.24)
    rumpf = mat('holz', (0.6, 0.15, 0.12))
    box(0.25, 0.28, 0.0, 0.34, 0.12, 0.07, rumpf)
    box(0.22, 0.28, 0.07, 0.12, 0.08, 0.06, mat('putz', WEISS))
    zylinder(0.3, 0.28, 0.07, 0.006, 0.2, holz, n=6)
    kran(-0.3, 0.3, 0.5)
    return True


def buchdenkmal(farbe):
    rasen(0.7, 0.7)
    stein = mat('stein', (0.8, 0.78, 0.74))
    box(0, 0, 0.01, 0.4, 0.4, 0.06, stein)
    box(0, 0, 0.07, 0.26, 0.26, 0.08, stein)
    box(0, 0, 0.15, 0.16, 0.16, 0.36, mat('stein', farbe))
    gold = mat('gold', (1.0, 0.8, 0.4))
    box(0, 0, 0.51, 0.2, 0.2, 0.02, gold)
    seite = mat('putz', (0.98, 0.96, 0.9), 0.5)
    for s in (-1, 1):
        box(0.045 * s, 0, 0.55, 0.1, 0.13, 0.008, seite, 0.001, rot=0).rotation_euler = (0, math.radians(18 * s), 0)
    box(0, 0, 0.53, 0.012, 0.13, 0.03, mat('putz', (0.5, 0.2, 0.15)))
    return False


def baustelle(stufe):
    box(0, 0, 0, 0.7, 0.7, 0.02, mat('erde', (0.5, 0.4, 0.28)))
    box(0, 0, 0.02, 0.6, 0.6, 0.04, mat('stein', (0.62, 0.62, 0.6)))
    h = [0.0, 0.12, 0.3, 0.5][stufe]
    if h:
        box(0, 0, 0.06, 0.52, 0.5, h, mat('ziegel', (0.62, 0.35, 0.25)))
    geruest(0, 0, 0.62, 0.6, max(0.25, h + 0.12), ebenen=3)
    kran(0.38, -0.3, 0.9)
    for i in range(3):
        box(-0.34, 0.2 + i * 0.04, 0.02, 0.12, 0.03, 0.03, mat('holz', (0.6, 0.45, 0.28)))
    return False


def reihenhaus(farbe):
    sx, sy, h = 0.46, 0.46, 0.4
    box(0, 0, 0, sx, sy, h, mat('putz', farbe))
    giebel(0, 0, h, sx, sy, 0.22, mat('putz', farbe), 'y')
    satteldach(0, 0, h, sx, sy, 0.22, mat('dach', (0.3, 0.22, 0.2)), 'y')
    fenster(0, 0, 0, sx, sy, 2, 2, h)
    tuer(-0.08, 0, sx, sy, '+y')
    return True


def g_geruest():
    box(0, 0, 0, 0.6, 0.6, 0.04, mat('stein', (0.62, 0.62, 0.6)))
    geruest(0, 0, 0.5, 0.5, 0.36, ebenen=3)
    return False


def g_wahrzeichen():
    rasen(0.8, 0.8)
    stein = mat('stein', (0.85, 0.82, 0.76))
    box(0, 0, 0.01, 0.46, 0.46, 0.08, stein)
    box(0, 0, 0.09, 0.3, 0.3, 0.12, stein)
    gold = mat('gold', (1.0, 0.78, 0.35))
    o = zylinder(0, 0, 0.21, 0.1, 1.2, gold, n=4, r2=0.035)
    o.rotation_euler = (0, 0, math.radians(45))
    kegel(0, 0, 1.41, 0.05, 0.12, gold, n=4)
    return False


def jahresbauwerk(teile, fertig):
    stein = mat('stein', SANDSTEIN)
    box(0, 0, 0, 0.6, 0.6, 0.06, mat('stein', (0.7, 0.68, 0.64)))
    z = 0.06
    for i in range(teile):
        s = 0.44 - i * 0.04
        box(0, 0, z, s, s, 0.2, stein)
        box(0, 0, z + 0.2, s + 0.03, s + 0.03, 0.03, mat('stein', (0.9, 0.85, 0.75)))
        fenster(0, 0, z, s, s, 1, 2, 0.2, fb=0.05, fh=0.08, start=0.04)
        z += 0.23
    if fertig:
        kegel(0, 0, z, 0.2, 0.34, mat('dach', (0.25, 0.4, 0.35)), n=4)
        zylinder(0, 0, z + 0.34, 0.006, 0.12, mat('gold', (1, 0.8, 0.4)), n=6)
    else:
        geruest(0, 0, 0.5, 0.5, z + 0.12, ebenen=max(2, teile + 1))
    return True


def boden_gras(seed):
    box(0, 0, -0.01, 1.01, 1.01, 0.01, mat('gras', (0.3, 0.5, 0.18), name=f'grasboden{seed}'), 0)
    import random
    rnd = random.Random(seed)
    for _ in range(6):
        x, y = rnd.uniform(-0.42, 0.42), rnd.uniform(-0.42, 0.42)
        kugel(x, y, 0.0, rnd.uniform(0.02, 0.04), mat('laub', (0.3, 0.5, 0.22)), sz=0.5, n=10)
    return False


def boden_strasse():
    box(0, 0, -0.01, 1.01, 1.01, 0.01, mat('pflaster', (0.55, 0.54, 0.52), 0.85), 0)
    return False


# --------------------------------------------------------------------------
# Liste aller Bilder

BILDER = {
    'haus': g_haus,
    'baum': g_baum,
    'baum2': g_baum2,
    'polizeiwache': g_polizeiwache,
    'detektivbuero': g_detektivbuero,
    'gefaengnis': g_gefaengnis,
    'magierturm': g_magierturm,
    'burg': g_burg,
    'drachenhort': g_drachenhort,
    'observatorium': g_observatorium,
    'raumhafen': g_raumhafen,
    'labor': g_labor,
    'bibliothek': g_bibliothek,
    'schule': g_schule,
    'universitaet': g_universitaet,
    'park': g_park,
    'cafe': g_cafe,
    'brunnen': g_brunnen,
    'denkmal': g_denkmal,
    'rathaus': g_rathaus,
    'museum': g_museum,
    'friedhof': g_friedhof,
    'spukhaus': g_spukhaus,
    'theater': g_theater,
    'oper': g_oper,
    'marktplatz': g_marktplatz,
    'bahnhof': g_bahnhof,
    'hafen': g_hafen,
    'geruest': g_geruest,
    'wahrzeichen': g_wahrzeichen,
    'boden_gras1': lambda: boden_gras(1),
    'boden_gras2': lambda: boden_gras(2),
    'boden_strasse': boden_strasse,
}
for _genre, _farbe in GENREFARBEN.items():
    BILDER[f'buch_{_genre}'] = (lambda f: lambda: buchdenkmal(f))(_farbe)
    BILDER[f'reihe_{_genre}'] = (lambda f: lambda: reihenhaus(f))(_farbe)
for _stufe in (1, 2, 3):
    BILDER[f'baustelle{_stufe}'] = (lambda s: lambda: baustelle(s))(_stufe)
for _teile in range(0, 5):
    BILDER[f'jahr{_teile}'] = (lambda t: lambda: jahresbauwerk(t, False))(_teile)
BILDER['jahr_fertig'] = lambda: jahresbauwerk(4, True)


def render(name, out, nacht):
    global NACHT
    NACHT = nacht
    _mats.clear()
    sc = reset()
    kamera(sc)
    licht(sc, nacht)
    if not name.startswith('boden'):
        schattenfaenger(sc)
    hat_fenster = BILDER[name]()
    if nacht and not hat_fenster:
        return False
    datei = os.path.join(out, f"{name}{'_nacht' if nacht else ''}.png")
    sc.render.filepath = datei
    bpy.ops.render.render(write_still=True)
    return hat_fenster


def main():
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    out = os.path.abspath(args[0])
    namen = args[1:] or list(BILDER)
    os.makedirs(out, exist_ok=True)
    for name in namen:
        hat_fenster = render(name, out, False)
        if hat_fenster:
            render(name, out, True)
        print('fertig:', name, flush=True)


if __name__ == '__main__':
    main()
