#!/usr/bin/env python3
"""Proximeet editable signature proof — Codex-authored bounded fallback.
Blender 4.5; millimetre coordinates. No downloaded dependencies or textures.
The .blend retains all editable objects and real interlaced textile geometry.
This is a rendered design study, not a verified RealityKit/iPhone asset.
"""
import argparse
import json
import math
import os
import random
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument('--out', required=True)
parser.add_argument('--samples', type=int, default=64)
parser.add_argument('--resolution', type=int, default=1000)
parser.add_argument('--render-frame', type=int, default=None)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
random.seed(841)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.materials, bpy.data.meshes, bpy.data.curves):
    for block in list(datablocks):
        if block.users == 0:
            datablocks.remove(block)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = .001
scene.unit_settings.length_unit = 'MILLIMETERS'
scene.render.engine = 'CYCLES'
scene.cycles.samples = args.samples
scene.cycles.use_denoising = True
scene.cycles.adaptive_threshold = .025
scene.cycles.max_bounces = 8
scene.render.resolution_x = scene.render.resolution_y = args.resolution
scene.render.resolution_percentage = 100
scene.render.fps = 24
scene.frame_start, scene.frame_end = 1, 120
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = False
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.028, .038, .045, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .22


def collection(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c


band_col = collection('01_CYAN_WOVEN_BAND')
plate_col = collection('02_ATTACHABLE_SIGNAL_PLATE')
stage_col = collection('03_STUDIO')


def place(obj, target):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    target.objects.link(obj)
    return obj


def material(name, color, roughness=.5, metallic=0, sheen=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Sheen Weight'].default_value = sheen
    return m


cyan = material('Textile | Cyan dyed yarn', (.004, .31, .53), .70, 0, .22)
cyan_light = material('Textile | Cyan highlight yarn', (.006, .38, .61), .70, 0, .22)
cyan_dark = material('Textile | Deep cyan warp', (.003, .20, .34), .75, 0, .20)
substrate = material('Textile | Dense woven interior', (.003, .18, .29), .82, 0, .20)
# Restrained yarn microfibres supplement (rather than replace) the physical weave.
for yarn_material in (cyan, cyan_light, cyan_dark):
    yn=yarn_material.node_tree.nodes
    yl=yarn_material.node_tree.links
    yp=yn['Principled BSDF']
    specular=yp.inputs.get('Specular IOR Level') or yp.inputs.get('Specular')
    if specular is not None:
        specular.default_value=.25
    coordinate=yn.new('ShaderNodeTexCoord')
    micro=yn.new('ShaderNodeTexNoise')
    micro.inputs['Scale'].default_value=15
    micro.inputs['Detail'].default_value=2
    fibre=yn.new('ShaderNodeBump')
    fibre.inputs['Strength'].default_value=.12
    fibre.inputs['Distance'].default_value=.008
    yl.new(coordinate.outputs['Object'],micro.inputs['Vector'])
    yl.new(micro.outputs['Fac'],fibre.inputs['Height'])
    yl.new(fibre.outputs['Normal'],yp.inputs['Normal'])

black = material('Clasp | Satin graphite', (.014, .023, .028), .4, .25)
engraving = material('Plate | Recessed charcoal enamel', (.012, .022, .026), .43, .1)
silver = material('Plate | Brushed silver', (.72, .76, .79), .37, 1)
silver.node_tree.nodes['Principled BSDF'].inputs['Anisotropic'].default_value = .6
# Fine directional brushing is intentionally procedural in this source proof.
n = silver.node_tree.nodes
l = silver.node_tree.links
tex = n.new('ShaderNodeTexCoord')
mapping = n.new('ShaderNodeVectorMath')
mapping.operation = 'MULTIPLY'
mapping.inputs[1].default_value = (.8, 1, 48)
noise = n.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value = 4
noise.inputs['Detail'].default_value = 2
bump = n.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .10
bump.inputs['Distance'].default_value = .02
l.new(tex.outputs['Generated'], mapping.inputs[0])
l.new(mapping.outputs['Vector'], noise.inputs['Vector'])
l.new(noise.outputs['Fac'], bump.inputs['Height'])
l.new(bump.outputs['Normal'], n['Principled BSDF'].inputs['Normal'])
roughness = n.new('ShaderNodeMapRange')
roughness.inputs['From Min'].default_value = 0
roughness.inputs['From Max'].default_value = 1
roughness.inputs['To Min'].default_value = .31
roughness.inputs['To Max'].default_value = .43
l.new(noise.outputs['Fac'], roughness.inputs['Value'])
l.new(roughness.outputs['Result'], n['Principled BSDF'].inputs['Roughness'])


def mesh_obj(name, verts, faces, mat, target, smooth=True):
    mesh = bpy.data.meshes.new(name + ' Mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    obj.data.materials.append(mat)
    if smooth:
        for poly in mesh.polygons:
            poly.use_smooth = True
    return obj


# A closed, genuinely hollow strap with top and bottom thickness surfaces.
rx, ry, bottom, top = 35.7, 27.2, 2.0, 24.0
N = 256
verts = []
for xrad, yrad, z in [(rx, ry, bottom), (rx, ry, top), (rx-2.2, ry-2.2, bottom), (rx-2.2, ry-2.2, top)]:
    verts.extend([(xrad*math.cos(i*2*math.pi/N), yrad*math.sin(i*2*math.pi/N), z) for i in range(N)])
faces = []
for i in range(N):
    j = (i+1) % N
    faces += [(i, j, N+j, N+i), (2*N+j, 2*N+i, 3*N+i, 3*N+j),
              (N+i, N+j, 3*N+j, 3*N+i), (j, i, 2*N+i, 2*N+j)]
body = mesh_obj('Band | Hollow textile core', verts, faces, substrate, band_col)
bev = body.modifiers.new('Soft bound textile edges', 'BEVEL')
bev.width, bev.segments = .26, 3
body['Outer dimensions mm'] = '72 x 55 x 22, including yarn relief'


def surface(theta, z, relief=0):
    normal = Vector((math.cos(theta)/rx, math.sin(theta)/ry, 0)).normalized()
    p = Vector((rx*math.cos(theta), ry*math.sin(theta), z))
    return p + normal*relief, normal


# True alternating over-under yarn paths. Two consolidated meshes stay editable.
# The radial excursion swaps sign at each warp/weft crossing.
warps, rows, steps, sides = 332, 36, 3, 8
pitch_z = (top-bottom-.45)/(rows-1)


def add_tube(v, f, center, normal, across, rnormal, racross):
    start = len(v)
    for k in range(sides):
        a = k*2*math.pi/sides + math.pi/4
        p = center + normal*(math.cos(a)*rnormal) + across*(math.sin(a)*racross)
        v.append(tuple(p))
    if start >= sides:
        for k in range(sides):
            q = (k+1) % sides
            f.append((start-sides+k, start-sides+q, start+q, start+k))


v, f = [], []
for row in range(rows):
    first = len(v)
    z = bottom+.225+row*pitch_z
    for i in range(warps*steps+1):
        theta = i*2*math.pi/(warps*steps)
        relief = .17 + .13*math.cos(math.pi*(i/steps+row))
        p, normal = surface(theta, z, relief)
        # Do not connect distinct yarns to one another.
        local_v, local_f = [], []
        for k in range(sides):
            a = k*2*math.pi/sides+math.pi/4
            point = p+normal*(math.cos(a)*.135)+Vector((0,0,math.sin(a)*.265))
            v.append(tuple(point))
        base = len(v)-sides
        if base > first:
            for k in range(sides):
                q = (k+1)%sides
                f.append((base-sides+k, base-sides+q, base+q, base+k))
weft = mesh_obj('Band | Interlaced circumferential weft', v, f, cyan_light, band_col)
weft.data.materials.append(cyan)
for p in weft.data.polygons:
    p.material_index = (p.index//(warps*steps*sides)) % 2

v, f = [], []
for i in range(warps):
    theta = i*2*math.pi/warps
    first = len(v)
    tangent = Vector((-rx*math.sin(theta), ry*math.cos(theta), 0)).normalized()
    for j in range((rows-1)*steps+1):
        z = bottom+.225+j*pitch_z/steps
        relief = .17-.13*math.cos(math.pi*(j/steps+i))
        p, normal = surface(theta, z, relief)
        for k in range(sides):
            a = k*2*math.pi/sides+math.pi/4
            v.append(tuple(p+normal*(math.cos(a)*.135)+tangent*(math.sin(a)*.27)))
        base = len(v)-sides
        if base > first:
            for k in range(sides):
                q = (k+1)%sides
                f.append((base-sides+k, base-sides+q, base+q, base+k))
warp = mesh_obj('Band | Interlaced vertical warp', v, f, cyan, band_col)
warp.data.materials.append(cyan_dark)
for p in warp.data.polygons:
    p.material_index = 1 if (p.index//((rows-1)*steps*sides)) % 5 == 0 else 0


# The inside has the same genuinely interlaced textile as the outside.
# Reflect radial relief across the strap wall rather than duplicating a smooth lining.
for original in (weft, warp):
    inner_verts=[]
    for vertex in original.data.vertices:
        point=vertex.co.copy()
        theta=math.atan2(point.y/ry, point.x/rx)
        base, normal=surface(theta, point.z, 0)
        relief=(point-base).dot(normal)
        inner_verts.append(tuple(point-normal*(2.2+2*relief)))
    inner_obj=mesh_obj(original.name+' | Inner face',inner_verts,
                       [tuple(poly.vertices) for poly in original.data.polygons],
                       original.data.materials[0],band_col)
    for mat in list(original.data.materials)[1:]:
        inner_obj.data.materials.append(mat)
    for target_poly, source_poly in zip(inner_obj.data.polygons,original.data.polygons):
        target_poly.material_index=source_poly.material_index

# Individual fold-over yarns cover the otherwise rubber-like top/bottom cut faces.
v,f=[],[]
for edge_z,sign in ((top,1),(bottom,-1)):
    for i in range(warps):
        theta=i*2*math.pi/warps
        tangent=Vector((-rx*math.sin(theta),ry*math.cos(theta),0)).normalized()
        first=len(v)
        for j in range(11):
            t=j/10
            p,normal=surface(theta,edge_z+sign*(.055+.13*math.sin(math.pi*t)),.18-2.56*t)
            for k in range(sides):
                angle=k*2*math.pi/sides+math.pi/4
                v.append(tuple(p+Vector((0,0,math.cos(angle)*.12))+tangent*(math.sin(angle)*.27)))
            base=len(v)-sides
            if base>first:
                for k in range(sides):
                    q=(k+1)%sides
                    f.append((base-sides+k,base-sides+q,base+q,base+k))
edge_weave=mesh_obj('Band | Fold-over woven edge yarns',v,f,cyan,band_col)


# Rounded rectangle extruded along Y. Works for plate, hardware, and icon inlays.
def rounded_rect(name, width, height, depth, radius, center, mat, col, bevel=0):
    pts = []
    for cx, cz, a0 in [(width/2-radius,height/2-radius,0),(-width/2+radius,height/2-radius,90),
                       (-width/2+radius,-height/2+radius,180),(width/2-radius,-height/2+radius,270)]:
        for k in range(9):
            angle = math.radians(a0+k*90/8)
            pts.append((cx+radius*math.cos(angle), cz+radius*math.sin(angle)))
    count = len(pts)
    vertices = [(x, y, z) for y in (-depth/2, depth/2) for x,z in pts]
    polygons = [tuple(range(count)), tuple(range(2*count-1,count-1,-1))]
    polygons.extend((i,i+count,(i+1)%count+count,(i+1)%count) for i in range(count))
    obj = mesh_obj(name, vertices, polygons, mat, col, False)
    obj.location = center
    if bevel:
        b = obj.modifiers.new('Machined edge radius', 'BEVEL')
        b.width, b.segments = bevel, 4
        b = obj.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
        b.keep_sharp = True
    return obj


root = bpy.data.objects.new('SIGNAL_PLATE | Animated rigid assembly', None)
plate_col.objects.link(root)
root.empty_display_type = 'PLAIN_AXES'
root.empty_display_size = 5
plate_center = (0, -29.25, 15.0)
plate = rounded_rect('Plate | Silver body 28x26x3 mm', 28, 26, 3, 3, plate_center, silver, plate_col, .55)
plate.parent = root
# Solid side shoulders sit behind the face and visibly embrace the textile.
for side in (-1,1):
    lug = rounded_rect('Plate | Retaining lug '+str(side), 4.0, 14, 4.1, 1.4,
                       (side*13.7,-27.1,15), silver, plate_col, .4)
    lug.parent = root
    seat = rounded_rect('Plate | Graphite lug cushion '+str(side), 2.6, 11, .55, .9,
                        (side*14.9,-24.65,15), black, plate_col, .18)
    seat.parent = root


def tail(name, xyz, mat):
    x,y,z = xyz
    o = mesh_obj(name, [(x,y,z),(x+3.1,y,z),(x+.15,y,z-3.0)], [(0,1,2)], mat, plate_col, False)
    o.parent = root
    return o


# Genuine shallow engraving using ONE closed, manifold cutter and ONE inlay.
# The planar union is sampled at 0.06 mm, below one pixel in the hero render.
# Shared vertices and boundary-only walls avoid intersecting/coplanar cutters.
cutters_col=collection('04_EDITABLE_ENGRAVING_TOOLS')

def in_ellipse(x,z,cx,cz,rx,rz):
    return ((x-cx)/rx)**2+((z-cz)/rz)**2 <= 1

def in_triangle(x,z,pts):
    signs=[]
    for index in range(3):
        a,b=pts[index],pts[(index+1)%3]
        signs.append((x-a[0])*(b[1]-a[1])-(z-a[1])*(b[0]-a[0]))
    return all(value>=0 for value in signs) or all(value<=0 for value in signs)

def in_symbol(x,z):
    outer=in_ellipse(x,z,-2.2,14.9,7.9,5.85)
    inner=in_ellipse(x,z,-2.2,14.95,6.4,4.35)
    front_tail=in_triangle(x,z,[(-7.6,11.7),(-4.5,11.7),(-7.45,8.1)])
    rear=in_ellipse(x,z,3.3,18.7,5.15,4.0)
    rear_tail=in_triangle(x,z,[(5.3,16.4),(8.4,16.4),(5.45,12.8)])
    return ((outer or front_tail) and not inner) or ((rear or rear_tail) and not outer)

step=.06
xmin,zmin=-10.6,7.7
nx,nz=332,256
occupied=set()
for i in range(nx):
    for j in range(nz):
        if in_symbol(xmin+(i+.5)*step,zmin+(j+.5)*step):
            occupied.add((i,j))
vertices,faces,indexes=[],[],{}

def grid_vertex(i,j,layer):
    key=(i,j,layer)
    if key not in indexes:
        indexes[key]=len(vertices)
        vertices.append((xmin+i*step,-31.05 if layer==0 else -30.55,zmin+j*step))
    return indexes[key]

for i,j in sorted(occupied):
    a,b,c,d=[grid_vertex(*key,0) for key in ((i,j),(i+1,j),(i+1,j+1),(i,j+1))]
    aa,bb,cc,dd=[grid_vertex(*key,1) for key in ((i,j),(i+1,j),(i+1,j+1),(i,j+1))]
    faces.extend([(a,b,c,d),(dd,cc,bb,aa)])
    if (i-1,j) not in occupied:
        faces.append((a,d,dd,aa))
    if (i+1,j) not in occupied:
        faces.append((b,bb,cc,c))
    if (i,j-1) not in occupied:
        faces.append((a,aa,bb,b))
    if (i,j+1) not in occupied:
        faces.append((d,c,cc,dd))
cutter=mesh_obj('Cutter | Unified conversation engraving',vertices,faces,engraving,cutters_col,False)
cutter.parent=root
mod=plate.modifiers.new('Conversation engraving - single manifold difference','BOOLEAN')
mod.operation='DIFFERENCE'
mod.solver='EXACT'
mod.object=cutter
inlay_mesh=cutter.data.copy()
for vertex in inlay_mesh.vertices:
    t=(vertex.co.y+31.05)/.50
    vertex.co.y=-30.585+t*.035
inlay=bpy.data.objects.new('Signal | Recessed conversation enamel',inlay_mesh)
plate_col.objects.link(inlay)
inlay.parent=root
cutter.display_type='WIRE'
cutter.hide_render=True
cutter.hide_set(True)
# Geometry remains editable; normal correction follows the single cavity operation.
normals=plate.modifiers.new('Engraved plate weighted normals','WEIGHTED_NORMAL')
normals.keep_sharp=True

clasp = rounded_rect('Clasp | Rear graphite buckle',18,23,4.2,2.5,(0,27.4,13),black,band_col,.55)
for x in (-5.5,5.5):
    rounded_rect('Clasp | Silver retention bar',1.2,17,.45,.45,(x,29.6,13),silver,band_col,.12)

# Small raised woven-edge cords make the fabric's real depth read at a distance.
for z in (bottom+.25, top-.25):
    curve=bpy.data.curves.new('Bound edge cord','CURVE')
    curve.dimensions='3D'
    curve.bevel_depth=.12
    curve.bevel_resolution=2
    spline=curve.splines.new('POLY')
    spline.points.add(255)
    for i,p in enumerate(spline.points):
        pos,_=surface(i*2*math.pi/256,z,.18)
        p.co=(*pos,1)
    spline.use_cyclic_u=True
    obj=bpy.data.objects.new('Band | Reinforced bound edge',curve)
    band_col.objects.link(obj)
    obj.data.materials.append(cyan_light)

# 5-second rigid attachment: approach, alignment, settle, then a still inspection hold.
root.rotation_mode='XYZ'
for frame, location, rotation in [
    (1,(8,-62,34),(-.12,.06,-.08)), (18,(8,-62,34),(-.12,.06,-.08)),
    (48,(1,-11,9),(-.04,.015,-.018)), (67,(0,-1.0,1.1),(0,0,0)),
    (77,(0,.16,-.16),(0,0,0)), (90,(0,0,0),(0,0,0)), (120,(0,0,0),(0,0,0))]:
    root.location=location
    root.rotation_euler=rotation
    root.keyframe_insert(data_path='location',frame=frame)
    root.keyframe_insert(data_path='rotation_euler',frame=frame)
if root.animation_data and root.animation_data.action:
    # Blender 4.5 action compatibility: use standard inserted channel handles.
    try:
        for fcurve in root.animation_data.action.fcurves:
            for key in fcurve.keyframe_points:
                key.interpolation='BEZIER'
                key.handle_left_type=key.handle_right_type='AUTO_CLAMPED'
    except AttributeError:
        pass
for frame,label in [(1,'Plate inspection / approach'),(48,'Alignment'),(77,'Magnetic settle'),(90,'Attached / inspect')]:
    scene.timeline_markers.new(label,frame=frame)

floor=material('Studio | Soft charcoal',(.005,.007,.009),.72)
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,0))
ground=place(bpy.context.object,stage_col)
ground.name='Studio | Ground'
ground.data.materials.append(floor)


def aim(obj, point):
    obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()


def light(name, location, energy, size, color, target=(0,0,12), size_y=None):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=energy
    data.color=color
    if size_y:
        data.shape='RECTANGLE'
        data.size=size
        data.size_y=size_y
    else:
        data.shape='DISK'
        data.size=size
    obj=bpy.data.objects.new(name,data)
    stage_col.objects.link(obj)
    obj.location=location
    aim(obj,target)


# Millimetre modelling needs proportionately larger Blender light powers.
light('Light | Broad white key',(-70,-75,125),190000,100,(.92,.97,1.0),size_y=65)
light('Light | Silver reflection strip',(45,-105,60),100000,28,(1.0,.97,.92),size_y=95)
light('Light | Cool rear rim',(40,65,80),145000,65,(.35,.8,1.0),size_y=30)
light('Light | Soft cyan floor bounce',(-55,8,22),6000,45,(.02,.65,.9),size_y=12)
light('Light | Gentle front fill',(-15,-110,5),130000,120,(1.0,.98,.95),size_y=90)
camdata=bpy.data.cameras.new('Camera | 85 mm product lens')
cam=bpy.data.objects.new('Camera | Signature product',camdata)
stage_col.objects.link(cam)
cam.location=(38,-207,90)
aim(cam,(0,-1,15))
camdata.lens=85
camdata.clip_start=.1
camdata.clip_end=4000
scene.camera=cam
camdata.dof.use_dof=False
scene.frame_set(100)
scene['Proof author']='Codex fallback; not attributed to Claude Opus'
scene['Scope']='Editable design proof. Native mobile materials and performance unverified.'
scene['Yarn topology']='Two real over-under consolidated meshes; keep high poly source for baking.'
blend_path=out/'proximeet-signature-proof.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path),compress=True)
manifest={'author':'Codex bounded fallback','source':'build_signature.py','blend':blend_path.name,
          'frame_count':120,'fps':24,'hero_frame':100,'units':'millimetres',
          'render_engine':'Cycles / OptiX RTX 5070','mobile_ready':False,
          'limitations':['Procedural brushing needs baking for native export.',
                         'High-poly textile requires a separate mobile mesh and normal bake.',
                         'Rendered concept study; no iPhone performance or RealityKit validation.']}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
if args.render_frame is not None:
    prefs=bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type='OPTIX'
    prefs.refresh_devices()
    for dev in prefs.devices:
        dev.use=(dev.type=='OPTIX' and '5070' in dev.name)
    if not any(dev.use for dev in prefs.devices):
        raise RuntimeError('RTX 5070 OptiX device required; no silent CPU fallback.')
    scene.cycles.device='GPU'
    scene.frame_set(args.render_frame)
    scene.render.filepath=str(out/('hero-%03d.png'%args.render_frame))
    bpy.ops.render.render(write_still=True)
print('PROXIMEET_SCENE_COMPLETE '+str(blend_path),flush=True)
