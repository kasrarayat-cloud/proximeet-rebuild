"""Render selected frames of the reviewed Blender scene on Kasra's OptiX GPU."""
import argparse
import json
import sys
from pathlib import Path
import bpy

p = argparse.ArgumentParser()
p.add_argument('--out', required=True)
p.add_argument('--frames', default='1:120')
p.add_argument('--resolution', type=int, default=900)
p.add_argument('--samples', type=int, default=64)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
out = Path(a.out)
out.mkdir(parents=True, exist_ok=True)
prefs = bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type = 'OPTIX'
prefs.refresh_devices()
for device in prefs.devices:
    device.use = device.type == 'OPTIX' and '5070' in device.name
assert any(d.use for d in prefs.devices), 'RTX 5070 OptiX unavailable'
scene = bpy.context.scene
scene.frame_set(100)
# Resolve static engraving once in this render process. The saved source keeps
# its editable modifiers; only rigid transforms change during the animation.
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj.name.startswith('Plate | Silver body'):
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
scene.render.engine = 'CYCLES'
scene.render.use_persistent_data = True
scene.cycles.device = 'GPU'
scene.cycles.samples = a.samples
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = a.resolution
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.use_file_extension = True
if ':' in a.frames:
    first, last = map(int, a.frames.split(':'))
    frames = range(first, last + 1)
else:
    frames = [int(x) for x in a.frames.split(',')]
print('PM_RENDER_GPU=' + json.dumps([d.name for d in prefs.devices if d.use]), flush=True)
for frame in frames:
    scene.frame_set(frame)
    target = out / f'frame_{frame:04d}.png'
    scene.render.filepath = str(target)
    bpy.ops.render.render(write_still=True)
    print(f'PM_FRAME_DONE={frame}', flush=True)
