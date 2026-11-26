"""Blender 5.1. Argumento após --: diretório raiz do projeto extraído."""
from pathlib import Path
import bpy as b, sys, math
from mathutils import Vector
root=Path(sys.argv[-1]).resolve()
scene=next(s for s in b.data.scenes if s.name.startswith('07 •'))
b.context.window.scene=scene
parts=[o for o in scene.objects if o.type=='MESH']
arm=b.data.armatures.new('Rosé • cadeias de reação')
rig=b.data.objects.new('ResponseRig',arm);scene.collection.objects.link(rig)
b.context.view_layer.objects.active=rig;rig.select_set(True)
b.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
 e=arm.edit_bones.new(name);e.head=head;e.tail=tail
 if parent:e.parent=arm.edit_bones[parent]
bone('Base',(0,0,.90),(0,0,1.24))
bone('Spine',(0,0,1.24),(0,0,1.67),'Base')
bone('Head',(0,0,1.67),(0,0,1.98),'Spine')
for sign,side in [(-1,'L'),(1,'R')]:
 shoulder=(sign*.205,-.006,1.62);elbow=(sign*.48,.025,1.48);wrist=(sign*.695,-.018,1.31)
 bone('Upper'+side,shoulder,elbow,'Spine');bone('Fore'+side,elbow,wrist,'Upper'+side)
 bone('Palm'+side,wrist,(sign*.79,-.015,1.25),'Fore'+side)
b.ops.object.mode_set(mode='OBJECT')
def ramp(x):return max(0,min(1,x))**2*(3-2*max(0,min(1,x)))
for o in parts:
 o.parent=rig
 groups={n.name:o.vertex_groups.new(name=n.name) for n in arm.bones}
 face=o.name.startswith(('Face','Hair','Locks','Eye','Glint'))
 for v in o.data.vertices:
  x,y,z=v.co;side='L' if x<0 else 'R'
  h=1 if face else ramp((z-1.66)/.12)
  a=0 if face or not o.name.startswith('Body') else ramp((abs(x)-.16)/.16)*ramp((z-1.06)/.19)
  fore=ramp((abs(x)-.42)/.13);palm=ramp((abs(x)-.64)/.11)
  spine=ramp((z-1.08)/.34)
  w={'Head':h,'Base':(1-h)*(1-a)*(1-spine),'Spine':(1-h)*(1-a)*spine,'Upper'+side:(1-h)*a*(1-fore),'Fore'+side:(1-h)*a*fore*(1-palm),'Palm'+side:(1-h)*a*fore*palm}
  for n,value in w.items():
   if value>0:groups[n].add([v.index],value,'REPLACE')
 mod=o.modifiers.new('Rig de resposta','ARMATURE');mod.object=rig
b.ops.export_scene.gltf(filepath=str(root/'game/assets/rig11.glb'),use_active_scene=True,export_animations=False,export_morph=True)
for side in 'LR':
 e=b.data.objects.new('Alvo • mão '+side,None);scene.collection.objects.link(e)
 e.location=rig.data.bones['Palm'+side].head_local;e.empty_display_size=.045
 c=rig.pose.bones['Fore'+side].constraints.new('IK');c.target=e;c.chain_count=2;c.use_stretch=False
e=b.data.objects.new('Alvo • olhar',None);scene.collection.objects.link(e);e.location=(0,-1.2,1.95);e.empty_display_size=.05
c=rig.pose.bones['Head'].constraints.new('DAMPED_TRACK');c.target=e;c.track_axis='TRACK_NEGATIVE_Z';c.influence=0
rig.show_in_front=True
b.ops.wm.save_as_mainfile(filepath=str(root/'src/Rose_Rig_1_1.blend'),compress=True)
