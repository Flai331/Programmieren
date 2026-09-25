"""Bereitet die Figur für die 3D-Stadt vor und exportiert mensch.glb.

Grundlage ist "Cesium Man" aus den glTF-Beispielmodellen der Khronos Group
(CC BY 4.0, https://github.com/KhronosGroup/glTF-Sample-Assets). Übernommen
werden Körper, Skelett und die Laufanimation. Die Originaltextur (mit dem
Cesium-Logo, das nicht unter die Lizenz fällt) wird ersetzt: Die Flächen
bekommen je nach Körperteil einfarbige Materialien (hemd, hose, haut, haare,
schuhe); die 3D-Stadt färbt "hemd" pro Person unterschiedlich ein.
Dazu kommen selbst erstellte Animationen "stehen" und "haemmern".

    python export_mensch.py CesiumMan.glb <ausgabeordner> [pruefbild.png]
"""

import math
import os
import sys

import bpy
from mathutils import Euler, Quaternion

# Lineare Farbwerte (glTF), daher dunkler als die sichtbare Farbe.
FARBEN = {
    'hemd': (0.12, 0.25, 0.1),
    'hose': (0.08, 0.06, 0.04),
    'haut': (0.6, 0.36, 0.24),
    'haare': (0.06, 0.03, 0.015),
    'schuhe': (0.03, 0.02, 0.012),
}


def material(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*FARBEN[name], 1)
    bsdf.inputs['Roughness'].default_value = 0.8
    return m


def teil(knochen):
    if knochen.endswith('_5'):
        return 'schuhe'
    if knochen.startswith('leg'):
        return 'hose'
    if 'neck' in knochen:
        return 'haut'
    if knochen in ('Skeleton_arm_joint_L__2_', 'Skeleton_arm_joint_R__3_'):
        return 'haut'  # Hände
    return 'hemd'


def einfaerben(koerper):
    gruppen = {g.index: g.name for g in koerper.vertex_groups}
    mats = {n: material(n) for n in FARBEN}
    koerper.data.materials.clear()
    reihenfolge = list(FARBEN)
    for n in reihenfolge:
        koerper.data.materials.append(mats[n])
    me = koerper.data
    # Höhenachse und Richtung: vom Mittel der Beine zum Mittel des Halses.
    def mittel(teilname):
        pts = [v.co for v in me.vertices
               if any(gruppen.get(g.group, '').startswith(teilname) and g.weight > 0.5 for g in v.groups)]
        return sum(pts, pts[0] * 0) / len(pts)
    richtung = (mittel('Skeleton_neck') - mittel('leg_joint')).normalized()
    werte = [v.co.dot(richtung) for v in me.vertices]
    oben = max(werte)
    hoehe = oben - min(werte)
    for p in me.polygons:
        gewicht = {}
        for vi in p.vertices:
            for g in me.vertices[vi].groups:
                name = gruppen.get(g.group)
                if name:
                    gewicht[name] = gewicht.get(name, 0) + g.weight
        knochen = max(gewicht, key=gewicht.get) if gewicht else ''
        art = teil(knochen)
        mitte = sum(werte[vi] for vi in p.vertices) / len(p.vertices)
        if art == 'haut' and mitte > oben - hoehe * 0.05:
            art = 'haare'
        p.material_index = reihenfolge.index(art)
    if me.uv_layers:
        pass


def aktion(arm, name, frames, pose, basis):
    """pose(frame) -> {knochen: Euler}, relativ zur Grundhaltung `basis`."""
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    for f in frames:
        for pb in arm.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = basis[pb.name][0]
            pb.location = basis[pb.name][1]
        for knochen, rot in pose(f).items():
            pb = arm.pose.bones[knochen]
            pb.rotation_quaternion = basis[knochen][0] @ rot.to_quaternion()
        for pb in arm.pose.bones:
            pb.keyframe_insert('rotation_quaternion', frame=f)
            pb.keyframe_insert('location', frame=f)
    act.use_fake_user = True
    return act


def main():
    quelle, out = sys.argv[1], sys.argv[2]
    pruef = sys.argv[3] if len(sys.argv) > 3 else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=quelle)
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and o.name.startswith('Icosphere'):
            bpy.data.objects.remove(o)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    koerper = next(o for o in bpy.data.objects if o.type == 'MESH')
    einfaerben(koerper)
    for img in list(bpy.data.images):
        bpy.data.images.remove(img)

    gehen = arm.animation_data.action
    gehen.name = 'gehen'
    gehen.use_fake_user = True

    # Grundhaltung zum Stehen: Arme wie in der Laufanimation (hängend).
    bpy.context.scene.frame_set(13)
    basis = {pb.name: (pb.rotation_quaternion.copy(), pb.location.copy())
             for pb in arm.pose.bones}
    # Beine aus der Ruhestellung (gerade), sonst stünde die Figur im Schritt.
    for knochen in basis:
        if knochen.startswith('leg'):
            basis[knochen] = (Quaternion(), basis[knochen][1] * 0)

    def stehen(f):
        atmen = math.sin(f / 24 * math.tau) * 0.02
        return {'Skeleton_torso_joint_2': Euler((atmen, 0, 0))}

    def haemmern(f):
        # Rechter Arm holt langsam nach oben aus und schlägt schnell zu,
        # der Oberkörper beugt sich beim Schlag leicht mit.
        t = ((f - 1) % 24) / 24
        hub = math.sin(t / 0.75 * math.pi / 2) if t < 0.75 else math.cos((t - 0.75) / 0.25 * math.pi / 2)
        return {
            'Skeleton_arm_joint_R': Euler((0.3 + 1.9 * hub, 0, 0)),
            'Skeleton_arm_joint_R__2_': Euler((0.2 + 0.6 * hub, 0, 0)),
            'Skeleton_torso_joint_2': Euler((0.18 - 0.1 * hub, 0, 0)),
        }

    aktion(arm, 'stehen', range(1, 50, 4), stehen, basis)
    aktion(arm, 'haemmern', range(1, 26, 1), haemmern, basis)
    # Alle Aktionen als eigene Animationen exportieren (NLA-Spuren).
    arm.animation_data.action = None
    for act in (gehen, bpy.data.actions['stehen'], bpy.data.actions['haemmern']):
        spur = arm.animation_data.nla_tracks.new()
        spur.name = act.name
        spur.strips.new(act.name, int(act.frame_range[0]), act)

    hammer(arm, koerper)
    if pruef:
        pruefbild(arm, pruef)

    os.makedirs(out, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out, 'mensch.glb'), export_format='GLB',
        export_animations=True, export_animation_mode='NLA_TRACKS',
        export_yup=True,
    )


def hammer(arm, koerper):
    """Kleiner Hammer in der rechten Hand. Er hängt am Handknochen; die 3D-Stadt
    blendet ihn nur beim Hämmern ein (Objektname "hammer")."""
    import mathutils
    hand = 'Skeleton_arm_joint_R__3_'
    bpy.context.scene.frame_set(13)
    # Größe relativ zur Figur.
    bb = [koerper.matrix_world @ mathutils.Vector(c) for c in koerper.bound_box]
    groesse = max((max(v[i] for v in bb) - min(v[i] for v in bb)) for i in range(3))
    holz = bpy.data.materials.new('hammerstiel')
    holz.use_nodes = True
    holz.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.45, 0.28, 0.14, 1)
    eisen = bpy.data.materials.new('hammerkopf')
    eisen.use_nodes = True
    b = eisen.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (0.25, 0.25, 0.27, 1)
    b.inputs['Metallic'].default_value = 1.0
    b.inputs['Roughness'].default_value = 0.4
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=groesse * 0.012, depth=groesse * 0.2)
    stiel = bpy.context.active_object
    stiel.data.materials.append(holz)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, groesse * 0.1))
    kopf = bpy.context.active_object
    kopf.scale = (groesse * 0.08, groesse * 0.035, groesse * 0.035)
    kopf.data.materials.append(eisen)
    bpy.ops.object.select_all(action='DESELECT')
    stiel.select_set(True)
    kopf.select_set(True)
    bpy.context.view_layer.objects.active = stiel
    bpy.ops.object.join()
    stiel.name = 'hammer'
    # An den Handknochen hängen: Ursprung an der Knochenspitze, entlang des Knochens.
    pb = arm.pose.bones[hand]
    m = arm.matrix_world @ pb.matrix
    stiel.matrix_world = m @ mathutils.Matrix.Translation((0, pb.length, 0)) @ mathutils.Euler((math.radians(90), 0, 0)).to_matrix().to_4x4()
    stiel.parent = arm
    stiel.parent_type = 'BONE'
    stiel.parent_bone = hand
    stiel.matrix_world = m @ mathutils.Matrix.Translation((0, pb.length, 0)) @ mathutils.Euler((math.radians(90), 0, 0)).to_matrix().to_4x4()


def pruefbild(arm, pfad):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 8
    sc.render.resolution_x, sc.render.resolution_y = 900, 400
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    welt = bpy.data.worlds.new('w')
    welt.color = (0.8, 0.85, 0.9)
    sc.world = welt
    sonne = bpy.data.objects.new('s', bpy.data.lights.new('s', 'SUN'))
    sonne.rotation_euler = (0.8, 0.2, 0.5)
    sc.collection.objects.link(sonne)
    import mathutils
    koerper = next(o for o in bpy.data.objects if o.type == 'MESH')
    bb = [koerper.matrix_world @ mathutils.Vector(c) for c in koerper.bound_box]
    mitte = sum(bb, mathutils.Vector()) / 8
    groesse = max((max(v[i] for v in bb) - min(v[i] for v in bb)) for i in range(3))
    cam.location = mitte + mathutils.Vector((0, -groesse * 3, groesse * 0.3))
    cam.rotation_euler = (math.radians(85), 0, 0)
    bilder = []
    for name, frame in (('gehen', 10), ('stehen', 1), ('haemmern', 12), ('haemmern', 20)):
        arm.animation_data.action = bpy.data.actions[name]
        for spur in arm.animation_data.nla_tracks:
            spur.mute = True
        sc.frame_set(frame)
        datei = pfad.replace('.png', f'_{name}{frame}.png')
        sc.render.filepath = datei
        bpy.ops.render.render(write_still=True)
        bilder.append(datei)
    arm.animation_data.action = None
    for spur in arm.animation_data.nla_tracks:
        spur.mute = False
    print('pruefbilder', bilder)


if __name__ == '__main__':
    main()
