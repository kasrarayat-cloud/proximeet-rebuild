"""Procedural neutral studio image-based lighting for the native band scene."""
import bpy,numpy as np,sys,json,hashlib
from pathlib import Path
out=Path(sys.argv[sys.argv.index('--')+1]);out.mkdir(parents=True,exist_ok=True)
w,h=1024,512
y,x=np.mgrid[0:h,0:w].astype(np.float32)
u=(x+.5)/w;v=(y+.5)/h
theta=(u-.5)*2*np.pi;phi=(v-.5)*np.pi
rgb=np.zeros((h,w,3),dtype=np.float32)+np.array([.10,.12,.145],dtype=np.float32)
def softbox(cx,cy,sx,sy,strength,color):
    du=np.mod(u-cx+.5,1)-.5;dv=v-cy
    shape=np.exp(-((np.abs(du)/sx)**10+(np.abs(dv)/sy)**10))
    return shape[...,None]*np.array(color,dtype=np.float32)*strength
rgb+=softbox(.28,.65,.045,.14,10,(.96,.985,1))
rgb+=softbox(.64,.61,.10,.07,7,(1,.96,.90))
rgb+=softbox(.86,.70,.025,.17,6,(.70,.84,1))
rgb+=softbox(.50,.94,.28,.035,4,(1,1,1))
rgba=np.concatenate((rgb,np.ones((h,w,1),dtype=np.float32)),axis=-1)
im=bpy.data.images.new('SignatureStudio',width=w,height=h,alpha=False,float_buffer=True)
im.colorspace_settings.name='Linear Rec.709';im.pixels.foreach_set(rgba.ravel())
im.file_format='OPEN_EXR';im.filepath_raw=str(out/'SignatureStudio.exr')
settings=bpy.context.scene.render.image_settings
settings.file_format='OPEN_EXR';settings.color_depth='16';settings.exr_codec='ZIP';settings.color_mode='RGB'
im.save_render(im.filepath_raw,scene=bpy.context.scene)
info={'name':'SignatureStudio','dimensions':[w,h],'projection':'equirectangular','source':'procedural neutral softboxes, no downloaded assets','sha256':hashlib.sha256(Path(im.filepath_raw).read_bytes()).hexdigest(),'bytes':Path(im.filepath_raw).stat().st_size}
(out/'ibl-manifest.json').write_text(json.dumps(info,indent=2));print(json.dumps(info))
