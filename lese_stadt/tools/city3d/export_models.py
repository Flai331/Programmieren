"""Exportiert die Gebäude aus render_sprites.py als glTF-Modelle (.glb) für
die 3D-Stadt.

Die prozeduralen Blender-Materialien (Ziegel, Putz, Dach, Stein, Gras …)
gibt es in glTF nicht; sie werden deshalb pro Gebäude in eine Farbtextur und
eine Normal-Map eingebrannt. Glas, Leuchtflächen und Metall bleiben einfache
Materialien, damit die 3D-Stadt nachts die Fenster (Material "glas") zum
Leuchten bringen kann.

    python export_models.py <ausgabeordner> [name ...]

Ein Feld ist 1×1 Einheit, die Gebäude stehen um den Ursprung, oben ist +Y.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'sprites'))

import bpy  # noqa: E402

import render_sprites as rs  # noqa: E402

UNGEBACKEN = ('glas', 'leucht', 'metall', 'gold')
TEXTUR = 1024


def _art(material):
    return material.name.split('-')[0] if material else ''


def _alle_meshes():
    return [o for o in bpy.context.scene.objects if o.type == 'MESH']


def _auswahl(objs, aktiv=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = aktiv or objs[0]


def _backen(obj, name):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 4
    sc.cycles.use_denoising = False

    _auswahl([obj])
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')

    farbe = bpy.data.images.new(f'{name}_farbe', TEXTUR, TEXTUR)
    normal = bpy.data.images.new(f'{name}_normal', TEXTUR // 2, TEXTUR // 2)
    normal.colorspace_settings.name = 'Non-Color'

    def ziel(bild):
        for slot in obj.material_slots:
            nt = slot.material.node_tree
            node = nt.nodes.get('_backziel') or nt.nodes.new('ShaderNodeTexImage')
            node.name = '_backziel'
            node.image = bild
            nt.nodes.active = node

    ziel(farbe)
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.use_pass_color = True
    sc.render.bake.margin = 4
    bpy.ops.object.bake(type='DIFFUSE')
    ziel(normal)
    bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT')

    m = bpy.data.materials.new(f'{name}_gebacken')
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value = 0.85
    tf = nt.nodes.new('ShaderNodeTexImage')
    tf.image = farbe
    nt.links.new(tf.outputs['Color'], bsdf.inputs['Base Color'])
    tn = nt.nodes.new('ShaderNodeTexImage')
    tn.image = normal
    nm = nt.nodes.new('ShaderNodeNormalMap')
    nt.links.new(tn.outputs['Color'], nm.inputs['Color'])
    nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    obj.data.materials.clear()
    obj.data.materials.append(m)
    # Gepackt, damit der Exporter die Bilder findet.
    farbe.pack()
    normal.pack()


def _einfache_materialien(objs):
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            art = _art(m)
            if art == 'glas':
                m.name = 'glas'
            elif art == 'leucht':
                m.name = 'leucht'


def export(name, out):
    rs.NACHT = False
    rs._mats.clear()
    rs.reset()
    rs.BILDER[name]()
    objs = _alle_meshes()
    _auswahl(objs)
    bpy.ops.object.convert(target='MESH')
    objs = _alle_meshes()

    backen, einfach = [], []
    for o in objs:
        m = o.material_slots[0].material if o.material_slots else None
        (einfach if _art(m) in UNGEBACKEN else backen).append(o)

    if backen:
        _auswahl(backen)
        bpy.ops.object.join()
        koerper = bpy.context.view_layer.objects.active
        koerper.name = name
        _backen(koerper, name)
    _einfache_materialien(einfach)
    if einfach:
        _auswahl(einfach)
        bpy.ops.object.join()
        bpy.context.view_layer.objects.active.name = f'{name}_details'

    for o in _alle_meshes():
        for p in o.data.polygons:
            p.use_smooth = False
    ziel = os.path.join(out, f'{name}.glb')
    kwargs = dict(filepath=ziel, export_format='GLB', export_yup=True,
                  export_apply=True, export_image_format='JPEG')
    # Komprimiert wird danach mit gltf-transform (Meshopt), siehe README.
    try:
        bpy.ops.export_scene.gltf(**kwargs, export_image_quality=82)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)
    return ziel


def main():
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    out = os.path.abspath(args[0])
    os.makedirs(out, exist_ok=True)
    namen = args[1:] or [n for n in rs.BILDER if not n.startswith('boden')]
    for name in namen:
        pfad = export(name, out)
        print('fertig:', name, os.path.getsize(pfad) // 1024, 'KB', flush=True)


if __name__ == '__main__':
    main()
