#!/usr/bin/env python3
"""Derive the mobile PBR asset from the preserved Proximeet design proof.
Blender 4.5, no external assets/dependencies. All output uses real metre units.
"""
import argparse, hashlib, json, math, sys, zipfile
from pathlib import Path
import bpy
import numpy as np
from mathutils import Matrix, Vector
from pxr import Usd, UsdGeom, UsdUtils, Sdf, Gf

p=argparse.ArgumentParser()
p.add_argument('--source',required=True)
p.add_argument('--out',required=True)
p.add_argument('--render',action='store_true')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
out=Path(a.out); out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=a.source)
scene=bpy.context.scene
scene.frame_set(100)
core=bpy.data.objects['Band | Hollow textile core']
plate_root=bpy.data.objects['SIGNAL_PLATE | Animated rigid assembly']
plate=bpy.data.objects['Plate | Silver body 28x26x3 mm']
clasp=bpy.data.objects['Clasp | Rear graphite buckle']
keep=[core,plate_root,plate,clasp]
keep += [o for o in bpy.data.objects if o.name.startswith(('Plate | Retaining lug','Plate | Graphite lug cushion','Clasp | Silver retention bar','Band | Reinforced bound edge'))]
stage=[o for o in bpy.data.objects if o.type in {'LIGHT','CAMERA'} or o.name=='Studio | Ground']
for o in list(bpy.data.objects):
    if o not in keep+stage:
        bpy.data.objects.remove(o,do_unlink=True)
for o in keep:
    o.animation_data_clear()
plate_root.location=(0,0,0);plate_root.rotation_euler=(0,0,0)
for m in list(plate.modifiers):
    if m.type=='BOOLEAN': plate.modifiers.remove(m)

# Keep the exact approved silhouette and hardware; replace only high-poly yarn.
# The physical tile repeats every 9.92 mm and contains sixteen yarn crossings.
size=2048; small=256
yy,xx=np.mgrid[0:small,0:small].astype(np.float32)
u=(xx+.5)/128;v=(yy+.5)/128
wu=(np.mod(u,1)-.5)/.46;wv=(np.mod(v,1)-.5)/.46
warp_cross=np.sqrt(np.maximum(0,1-wu*wu))
weft_cross=np.sqrt(np.maximum(0,1-wv*wv))
warp=warp_cross*(.19+.09*np.cos(np.pi*v)*np.cos(np.pi*np.floor(u)))
weft=weft_cross*(.19-.09*np.cos(np.pi*u)*np.cos(np.pi*np.floor(v)))
iswarp=warp>weft
height=np.maximum(warp,weft)
fibre=np.where(iswarp,np.sin(2*np.pi*u*17),np.sin(2*np.pi*v*17))*.0025
height=height+fibre
# Derivatives in millimetres; OpenGL tangent normal convention (+Y).
dx=(np.roll(height,-1,1)-np.roll(height,1,1))/(2*.62/128)
dy=(np.roll(height,-1,0)-np.roll(height,1,0))/(2*.62/128)
normal=np.stack((-dx*.72,-dy*.72,np.ones_like(dx)),axis=-1)
normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
normal=normal*.5+.5
shade=np.clip(.54+.36*(height/.29)+fibre*4,.48,.94)
rough=np.clip(.75-.10*(height/.29)+fibre*4,.62,.82)

def save_map(name,arr,noncolor=False):
    arr=np.tile(arr,(size//small,size//small,1)) if arr.ndim==3 else np.tile(arr,(size//small,size//small))
    if arr.ndim==2: arr=np.repeat(arr[...,None],3,axis=-1)
    rgba=np.concatenate((arr,np.ones((size,size,1),dtype=np.float32)),axis=-1)
    im=bpy.data.images.new(name,width=size,height=size,alpha=False)
    im.colorspace_settings.name='Non-Color' if noncolor else 'sRGB'
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw=str(out/(name+'.png'));im.file_format='PNG';im.save()
    return im

base=save_map('Woven_BaseColor_Neutral',shade)
norm=save_map('Woven_Normal',normal,True)
roughimg=save_map('Woven_Roughness',rough,True)
mat=bpy.data.materials.new('WovenFabric_Neutral_PBR');mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes['Principled BSDF']
bs.inputs['Base Color'].default_value=(1,1,1,1)
bs.inputs['Roughness'].default_value=.75
bs.inputs['Sheen Weight'].default_value=.15
for im,socket in [(base,'Base Color'),(roughimg,'Roughness')]:
    n=nodes.new('ShaderNodeTexImage');n.image=im;n.extension='REPEAT'
    links.new(n.outputs['Color'],bs.inputs[socket])
n=nodes.new('ShaderNodeTexImage');n.image=norm;n.extension='REPEAT'
nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=1
links.new(n.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bs.inputs['Normal'])
core.data.materials.clear();core.data.materials.append(mat)

# UVs follow arclength around the ellipse rather than a generated bounding box.
N=256;rx=35.7;ry=27.2
pts=[Vector((rx*math.cos(i*2*math.pi/N),ry*math.sin(i*2*math.pi/N),0)) for i in range(N+1)]
lengths=[0.]
for i in range(N): lengths.append(lengths[-1]+(pts[i+1]-pts[i]).length)
uv=core.data.uv_layers.new(name='st')
for face in core.data.polygons:
    ids=[core.data.loops[li].vertex_index%N for li in face.loop_indices]
    seam=(0 in ids and N-1 in ids)
    for li in face.loop_indices:
        vert=core.data.vertices[core.data.loops[li].vertex_index];i=vert.index%N
        un=lengths[N] if seam and i==0 else lengths[i]
        ring=vert.index//N
        # Cap yarns run over the folded strap edge instead of a flat strip.
        z=vert.co.z
        if abs(face.normal.z)>.5: z+=(0 if ring<2 else 2.2)
        uv.data[li].uv=(un/9.92,z/9.92)

# Portable silver uses explicit metal/roughness. Keep custom procedural nodes out
# of the interchange material so RealityKit sees a valid UsdPreviewSurface.
silver=bpy.data.materials.new('BrushedSilver_PBR');silver.use_nodes=True
pbs=silver.node_tree.nodes['Principled BSDF']
pbs.inputs['Base Color'].default_value=(.72,.76,.79,1)
pbs.inputs['Metallic'].default_value=1
pbs.inputs['Roughness'].default_value=.34
black=bpy.data.materials.new('GraphiteClasp_PBR');black.use_nodes=True
bbs=black.node_tree.nodes['Principled BSDF'];bbs.inputs['Base Color'].default_value=(.014,.023,.028,1)
bbs.inputs['Roughness'].default_value=.43;bbs.inputs['Metallic'].default_value=.12
for o in keep:
    if o.type in {'MESH','CURVE'} and o!=core:
        old=o.data.materials[0].name if o.data.materials else ''
        o.data.materials.clear()
        o.data.materials.append(silver if ('Silver' in old or 'silver' in old) else black if ('Graphite' in old or 'graphite' in old) else mat)

# Apply inexpensive edge rounding before exporting to eliminate modifier/runtime
# differences. All asset objects retain individual stable names and editability.
for o in keep:
    if o.type not in {'MESH','CURVE'}:continue
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.convert(target='MESH')
    o.data.calc_loop_triangles()

core.name='Band_Core';plate_root.name='Plate_Root';plate.name='PlateBody';clasp.name='Clasp'
counts={}
for o in keep:
    if o.name.startswith('Plate | Retaining lug'): o.name='Plate_Lug_'+('L' if o.location.x<0 else 'R')
    elif o.name.startswith('Plate | Graphite lug cushion'):o.name='Plate_Cushion_'+('L' if o.location.x<0 else 'R')
    elif o.name.startswith('Clasp | Silver retention bar'):o.name='Clasp_Retention_'+('L' if o.location.x<0 else 'R')
    elif o.name.startswith('Band | Reinforced bound edge'):o.name='Band_Edge_'+('Top' if o.data.vertices[0].co.z>12 else 'Bottom')
    if o.type=='MESH':o.data.name=o.name+'_Mesh'

# Set plate pivot to its physical centre while retaining every child's world pose.
children=list(plate_root.children);worlds={o:o.matrix_world.copy() for o in children}
plate_root.location=(0,-29.25,15)
bpy.context.view_layer.update()
for o,m in worlds.items():o.matrix_world=m

# Apply scale to world-space geometry; the final scene stores one unit = one metre.
for o in keep:
    if o.parent is None: o.location*=.001
    else:o.location*=.001
    if o.type=='MESH':
        for vtx in o.data.vertices:vtx.co*=.001
scene.unit_settings.scale_length=1
scene.unit_settings.length_unit='METERS'
for o in stage:
    o.location*=.001
    if o.type=='MESH':
        for vtx in o.data.vertices:vtx.co*=.001
    elif o.type=='CAMERA':
        o.data.clip_start=.0001;o.data.clip_end=10
    elif o.type=='LIGHT':
        o.data.energy*=.000001;o.data.size*=.001
        if o.data.type=='AREA' and o.data.shape=='RECTANGLE':o.data.size_y*=.001

for o in keep:
    if o.type=='MESH':
        o.data.calc_loop_triangles();counts[o.name]=len(o.data.loop_triangles)
assert sum(counts.values())<35000,counts
bpy.context.view_layer.update()
coords=[o.matrix_world@Vector(c) for o in keep if o.type=='MESH' for c in o.bound_box]
lo=[min(v[i] for v in coords) for i in range(3)];hi=[max(v[i] for v in coords) for i in range(3)]
asset=out/'ProximeetSignature.usdz'
for im in (base,norm,roughimg):im.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(out/'ProximeetSignature-Mobile.blend'),compress=True)
# Bake Z-up -> Y-up into both local vertices and local translations. This makes
# Plate_Root's *local* +Z point out of its front, without a rotated parent trap.
axis=Matrix.Rotation(-math.pi/2,4,'X')
for o in keep:
    o.location=axis.to_3x3()@o.location
    if o.type=='MESH':o.data.transform(axis)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for o in keep:o.select_set(True)
export_opts=dict(selected_objects_only=True,export_animation=False,export_hair=False,export_armatures=False,
    export_materials=True,export_textures=True,export_textures_mode='NEW',overwrite_textures=True,
    relative_paths=True,generate_preview_surface=True,generate_materialx_network=False,
    export_lights=False,export_cameras=False,export_world_material=False,
    convert_orientation=False,export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y',
    convert_scene_units='METERS',root_prim_path='/ProximeetSignature',triangulate_meshes=True,
    export_custom_properties=False,author_blender_name=False)
export_opts.pop('export_world_material')
export_opts['convert_world_material']=False
bpy.ops.wm.usd_export(filepath=str(out/'ProximeetSignature.usda'),**export_opts)
usd=Usd.Stage.Open(str(out/'ProximeetSignature.usda'))
UsdGeom.SetStageUpAxis(usd,UsdGeom.Tokens.y)
UsdGeom.SetStageMetersPerUnit(usd,1)
usd.GetRootLayer().Save()
usd.GetRootLayer().Export(str(out/'ProximeetSignature.usdc'))
if asset.exists():asset.unlink()
assert UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(out/'ProximeetSignature.usdc')),str(asset))
packed=Usd.Stage.Open(str(asset))
cache=UsdGeom.BBoxCache(Usd.TimeCode.Default(),[UsdGeom.Tokens.default_,UsdGeom.Tokens.render])
bb=cache.ComputeWorldBound(packed.GetDefaultPrim()).ComputeAlignedRange()
actual_min=list(bb.GetMin());actual_max=list(bb.GetMax())
pr=packed.GetPrimAtPath('/ProximeetSignature/Plate_Root')
plate_matrix=UsdGeom.Xformable(pr).ComputeLocalToWorldTransform(Usd.TimeCode.Default())
plate_world=list(plate_matrix.ExtractTranslation())
plate_local=list(UsdGeom.Xformable(pr).GetLocalTransformation().ExtractTranslation())
assert all(abs(x-y)<1e-6 for x,y in zip(plate_local,[0,.015,.02925])),plate_local
assert all(abs(x-y)<1e-6 for x,y in zip(plate_world,plate_local)),(plate_local,plate_world)
assert abs((actual_max[0]-actual_min[0])-.072)<1e-5,(actual_min,actual_max)
manifest={'source_sha256':hashlib.sha256(Path(a.source).read_bytes()).hexdigest(),'asset':asset.name,
    'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'asset_bytes':asset.stat().st_size,
    'triangles':sum(counts.values()),'triangles_by_object':counts,'units':'metres','up':'Y','front':'+Z',
    'bounds_min':actual_min,'bounds_max':actual_max,'plate_root_verified_local':plate_local,
    'plate_root_verified_world':plate_world,'usd_up_axis':str(UsdGeom.GetStageUpAxis(packed)),
    'plate_root_rest_position':[0,.015,.02925],'plate_glyph_local_position':[0,0,.00156],
    'glyph_size_m':[.018,.014],'hero_camera':[.038,.09,.207],'hero_target':[0,.015,.001],
    'hero_focal_mm':85,'hero_sensor_width_mm':36,
    'band_material':'WovenFabric_Neutral_PBR','band_tinting':'Preserve authored base-color texture, normal and roughness maps when changing tint.',
    'limitations':['Cycles review render is not an iPhone render.','Native glyph decal supplied at runtime; plate mesh is blank.','USDZ visual/material import still requires native verification.']}
with zipfile.ZipFile(asset) as z:manifest['archive_contents']=z.namelist()
(out/'mobile-manifest.json').write_text(json.dumps(manifest,indent=2))
print('MOBILE_EXPORT '+json.dumps(manifest),flush=True)
if a.render:
    # Round-trip the actual exported USDZ, preserving only the studio. This render
    # catches missing maps, scale mistakes and winding mismatches in the asset.
    for o in keep:bpy.data.objects.remove(o,do_unlink=True)
    # Blender's USD importer leaves these baked Y-up vertices as authored.
    # Rotate the Z-up authoring studio into the same Y-up coordinate space.
    for o in stage:o.matrix_world=axis@o.matrix_world
    bpy.ops.wm.usd_import(filepath=str(asset),import_lights=False,import_cameras=False,
        import_materials=True,import_usd_preview=True,import_textures_mode='IMPORT_PACK')
    imported=[o for o in scene.objects if o not in stage and o.type=='MESH']
    roundtrip={o.name:len(o.data.polygons) for o in imported}
    manifest['roundtrip_objects']=roundtrip
    # Review the neutral texture with the same cyan tint planned for native.
    tinted=set()
    for o in imported:
        if o.name.startswith(('Band_Core','Band_Edge')):
            for mt in o.data.materials:
                if not mt or not mt.use_nodes or mt.name in tinted:continue
                tinted.add(mt.name)
                ps=next((n for n in mt.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                if ps and ps.inputs['Base Color'].is_linked:
                    lk=ps.inputs['Base Color'].links[0];src=lk.from_socket;mt.node_tree.links.remove(lk)
                    mix=mt.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
                    mix.inputs[2].default_value=(.006,.4,.68,1)
                    mt.node_tree.links.new(src,mix.inputs[1]);mt.node_tree.links.new(mix.outputs[0],ps.inputs['Base Color'])
    pref=bpy.context.preferences.addons['cycles'].preferences;pref.compute_device_type='OPTIX';pref.refresh_devices()
    for d in pref.devices:d.use=(d.type=='OPTIX' and '5070' in d.name)
    assert any(d.use for d in pref.devices),'Expected RTX 5070 OptiX'
    scene.render.engine='CYCLES';scene.cycles.device='GPU';scene.cycles.samples=64
    scene.render.resolution_x=scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.render.filepath=str(out/'mobile-roundtrip.png')
    bpy.ops.render.render(write_still=True)
    manifest['roundtrip_render']='mobile-roundtrip.png'
    (out/'mobile-manifest.json').write_text(json.dumps(manifest,indent=2))
print('MOBILE_COMPLETE',flush=True)
