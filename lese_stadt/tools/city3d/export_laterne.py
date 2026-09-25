"""Skaliert die Laterne aus den glTF-Beispielmodellen der Khronos Group
("Lantern", CC0, https://github.com/KhronosGroup/glTF-Sample-Assets) auf
Stadtgröße (0,45 Feld hoch, Fuß im Ursprung) und exportiert laterne.glb.

    python export_laterne.py Lantern.glb <ausgabeordner>
"""

import os
import sys

import bpy
from mathutils import Vector

quelle, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=quelle)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
punkte = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
unten = min(p.z for p in punkte)
hoehe = max(p.z for p in punkte) - unten
mitte = sum(punkte, Vector()) / len(punkte)
wurzel = bpy.data.objects.new('laterne', None)
bpy.context.scene.collection.objects.link(wurzel)
for o in bpy.data.objects:
    if o.parent is None and o is not wurzel:
        o.parent = wurzel
k = 0.45 / hoehe
wurzel.scale = (k, k, k)
wurzel.location = (-mitte.x * k, -mitte.y * k, -unten * k)
for m in bpy.data.materials:
    if 'glass' in m.name.lower() or 'light' in m.name.lower():
        m.name = 'leucht'
os.makedirs(out, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(out, 'laterne.glb'), export_format='GLB',
                          export_yup=True, export_image_format='JPEG')
print('materialien', [m.name for m in bpy.data.materials])
