"""Exporte um retrato da Rosé com shape keys. Execute em Blender 5.1."""
import argparse
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector


MORPHS = {
    "Boca entreaberta": "mouth_open",
    "Sorriso leve": "smile",
    "Sobrancelha levantada": "brow_up",
    "Piscada • E": "blink_l",
    "Piscada • D": "blink_r",
}
PARTS = {
    "Plane.": "Face",
    "ZÓI.": "Eyes",
    "luzolho.": "EyeGlintR",
    "luzolhoesq.": "EyeGlintL",
    "01 • Massa sob as ondas": "HairBase",
    "02 • Franja repartida": "HairLocks",
    "Corpo • dinâmica localizada": "Shoulders",
    "Camisola • rosa de alcinha": "Top",
}
ORIGIN = Vector((31.594, 1.9, 7.02))
SCALE = 0.6
CROP_Z = 4.77


def crop_portrait(mesh):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.bisect_plane(
        bm,
        geom=[*bm.verts, *bm.edges, *bm.faces],
        dist=0.00001,
        plane_co=(0, 0, (CROP_Z - ORIGIN.z) * SCALE),
        plane_no=(0, 0, 1),
        clear_inner=True,
    )
    bm.to_mesh(mesh)
    bm.free()


def export(output):
    source = next(scene for scene in bpy.data.scenes if "atuação facial" in scene.name)
    bpy.context.window.scene = source
    source.frame_set(1)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    transform = Matrix.Scale(SCALE, 4) @ Matrix.Translation(-ORIGIN)
    portrait = bpy.data.scenes.new("RosePortraitExport")
    for prefix, name in PARTS.items():
        source_object = next(
            obj for obj in source.objects
            if obj.type == "MESH" and obj.name.startswith(prefix) and obj.visible_get()
        )
        if name in {"Shoulders", "Top"}:
            mesh = bpy.data.meshes.new_from_object(source_object.evaluated_get(depsgraph))
        else:
            mesh = source_object.data.copy()
        mesh.transform(transform @ source_object.matrix_world, shape_keys=True)
        if name in {"Shoulders", "Top"}:
            crop_portrait(mesh)
        if name.startswith("EyeGlint"):
            highlight = bpy.data.materials.get("Portrait Glint")
            if not highlight:
                highlight = bpy.data.materials.new("Portrait Glint")
                highlight.diffuse_color = (1, 1, 0.95, 1)
            mesh.materials.append(highlight)
        obj = bpy.data.objects.new(name, mesh)
        portrait.collection.objects.link(obj)
        if mesh.shape_keys:
            mesh.shape_keys.animation_data_clear()
            for key in list(mesh.shape_keys.key_blocks)[1:]:
                key.name = MORPHS[key.name]
                key.value = 0
    bpy.context.window.scene = portrait
    bpy.ops.export_scene.gltf(
        filepath=output,
        export_format="GLB",
        use_active_scene=True,
        export_animations=False,
        export_morph=True,
        export_morph_normal=True,
        export_cameras=False,
        export_lights=False,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output")
    export(parser.parse_args(sys.argv[sys.argv.index("--") + 1:]).output)
