#!/usr/bin/env python3
"""Nướng sáng tối vào ảnh màu của mô hình Tripo màu phẳng (D-232): ảnh màu chỉ có mảng màu phẳng thì trông như nhựa.
Blender (Cycles, CPU) nướng hai lớp lên UV: che khuất (AO — khe giáp, nách, dưới cằm) và hướng sáng (pháp tuyến so với
đèn từ trên-trước-trái); rồi trộn vào ảnh màu, dịu màu chói về tông bộ asset (đá ấm, vàng đồng). Sửa vật liệu về đặc
(Tripo FBX hay đặt BLEND, kim loại 1, độ bóng ×2 làm mô hình tối). Xương / hoạt ảnh giữ nguyên.

  <venv có bpy>/bin/python tools/models/bake_shading.py vào.(fbx|glb) ra.glb [ra.fbx] [--size 1024]
ra.fbx: bản cho Mixamo (giữ bộ xương mixamorig, nhúng ảnh).
"""
import argparse, os, sys
import bpy
import numpy as np

LIGHT = (-0.45, -0.55, 0.7)  # hướng tới đèn (Blender: −Y là trước), chuẩn hóa trong shader


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    return next(o for o in bpy.context.scene.objects if o.type == "MESH")


def base_image(mesh):
    for n in mesh.data.materials[0].node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image is not None:
            return n.image
    raise SystemExit("không thấy ảnh màu")


def bake(mesh, kind, size, light_shader=False):
    img = bpy.data.images.new(kind, size, size, float_buffer=True)
    mat = mesh.data.materials[0]
    nt = mat.node_tree
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    nt.nodes.active = node
    old = None
    if light_shader:  # phát sáng = clamp(n·L) để nướng EMIT
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        old = out.inputs[0].links[0].from_socket if out.inputs[0].links else None
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        dot.inputs[1].default_value = LIGHT
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(geo.outputs["Normal"], dot.inputs[0])
        nt.links.new(dot.outputs["Value"], em.inputs["Color"])
        nt.links.new(em.outputs[0], out.inputs[0])
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.bake(type="EMIT" if light_shader else "AO", margin=8)
    if old is not None:
        nt.links.new(old, out.inputs[0])
    px = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)
    nt.nodes.remove(node)
    return px[..., 0]


def compose(base, ao, light):
    rgb = base[..., :3]
    ao = np.clip(ao, 0, 1) ** 1.2
    light = np.clip(light / max(1e-3, float(np.linalg.norm(LIGHT))), -1, 1)
    shade = (0.5 + 0.5 * ao) * (0.8 + 0.32 * light)
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    rgb = lum[..., None] + (rgb - lum[..., None]) * 0.88  # dịu màu chói
    rgb = rgb * np.array([1.0, 0.97, 0.93], np.float32)   # ngả ấm nhẹ
    return np.clip(rgb * shade[..., None], 0, 1)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst"); ap.add_argument("fbx", nargs="?")
    ap.add_argument("--size", type=int, default=1024)
    a = ap.parse_args(argv)
    mesh = load(a.src)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.render.fps = 30
    src = base_image(mesh)
    src.scale(a.size, a.size)
    base = np.array(src.pixels[:], dtype=np.float32).reshape(a.size, a.size, 4)
    ao = bake(mesh, "ao", a.size)
    light = bake(mesh, "light", a.size, light_shader=True)
    out = base.copy()
    out[..., :3] = compose(base, ao, light)
    src.pixels = out.ravel()
    src.pack()
    for mat in mesh.data.materials:  # vật liệu đặc, không bóng
        mat.blend_method = "OPAQUE"
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None:
            bsdf.inputs["Roughness"].default_value = 1.0
            bsdf.inputs["Metallic"].default_value = 0.0  # Tripo FBX để kim loại mặc định 1 → đen
            bsdf.inputs["Specular IOR Level"].default_value = 0.2
            if bsdf.inputs["Alpha"].links:
                mat.node_tree.links.remove(bsdf.inputs["Alpha"].links[0])
            bsdf.inputs["Alpha"].default_value = 1.0
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=a.dst, export_yup=True, export_animations=True)
    print("→", a.dst)
    if a.fbx:
        bpy.ops.export_scene.fbx(filepath=a.fbx, path_mode="COPY", embed_textures=True, add_leaf_bones=False,
                                 bake_anim=False)
        print("→", a.fbx)


if __name__ == "__main__":
    main()
