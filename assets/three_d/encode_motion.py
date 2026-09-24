"""Encode already rendered PNG frames with Blender's bundled FFmpeg."""
import argparse
import json
import re
import sys
from pathlib import Path

import bpy

parser = argparse.ArgumentParser()
parser.add_argument('--frames', required=True)
parser.add_argument('--out', required=True)
parser.add_argument('--fps', type=int, default=24)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
frames = sorted(Path(args.frames).glob('*.png'))
assert frames, 'No PNG frames found'
numbers = [int(re.search(r'(\d+)\.png$', p.name).group(1)) for p in frames]
assert numbers == list(range(1, 121)), f'Expected every frame 1..120: {numbers}'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
first = bpy.data.images.load(str(frames[0]))
width, height = first.size
assert width > 0 and height > 0
scene.render.resolution_x = width
scene.render.resolution_y = height
scene.render.resolution_percentage = 100
scene.render.pixel_aspect_x = 1
scene.render.pixel_aspect_y = 1
scene.render.fps = args.fps
scene.render.fps_base = 1
scene.frame_start = 1
scene.frame_end = len(frames)
editor = scene.sequence_editor_create()
strip = editor.strips.new_image('Proximeet attachment proof', str(frames[0]), 1, 1)
for path in frames[1:]:
    strip.elements.append(path.name)
scene.render.use_sequencer = True
scene.render.use_compositing = False
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.render.image_settings.file_format = 'FFMPEG'
scene.render.ffmpeg.format = 'MPEG4'
scene.render.ffmpeg.codec = 'H264'
scene.render.ffmpeg.constant_rate_factor = 'HIGH'
scene.render.ffmpeg.ffmpeg_preset = 'GOOD'
scene.render.ffmpeg.audio_codec = 'NONE'
scene.render.filepath = args.out
bpy.ops.render.render(animation=True)
print('PM_ENCODE=' + json.dumps({'frames':len(frames), 'fps':args.fps,
      'resolution':[width,height], 'output':args.out}))
