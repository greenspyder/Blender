"""Executar na cena do clipe, passando o diretório de saída após --."""
import bpy as b, math, sys, os
from mathutils import Vector, Matrix
from pathlib import Path
out=Path(sys.argv[-1]).resolve()
source=next(s for s in b.data.scenes if 'atuação facial' in s.name)
b.context.window.scene=source
source.frame_set(1)
graph=b.context.evaluated_depsgraph_get()
names={'Corpo •':'Body','Plane.':'Face','ZÓI.':'Eyes','luzolho.':'GlintR','luzolhoesq.':'GlintL','01 • Massa':'Hair','02 • Franja':'Locks','Camisola •':'Dress','Laço •':'Ribbon','Short •':'Shorts','Bolso aplicado • E':'PocketL','Bolso aplicado • D':'PocketR','Pantufa de malha':'Slipper'}
morph={'Boca entreaberta':'mouth_open','Sorriso leve':'smile','Sobrancelha levantada':'brow_up','Piscada • E':'blink_l','Piscada • D':'blink_r'}
scene=b.data.scenes.new('07 • Corpo inteiro | exportação')
factor=.14
transform=Matrix.Scale(factor,4)@Matrix.Translation(Vector((-31.594,-2.20,6.69)))
parts=[]
for o in source.objects:
 if o.type!='MESH':continue
 name=next((v for k,v in names.items() if o.name.startswith(k)),None)
 if not name:continue
 if not o.visible_get() and name not in ('Shorts','PocketL','PocketR'):continue
 mesh=o.data.copy() if o.data.shape_keys or not o.visible_get() else b.data.meshes.new_from_object(o.evaluated_get(graph))
 mesh.transform(transform@o.matrix_world,shape_keys=True)
 n=b.data.objects.new(name,mesh);scene.collection.objects.link(n);parts.append(n)
 if mesh.shape_keys:
  mesh.shape_keys.animation_data_clear()
  for k in list(mesh.shape_keys.key_blocks)[1:]:k.name=morph.get(k.name,k.name);k.value=0
 else:n.shape_key_add(name='Basis')
 for key in ['lean_left','lean_right','yield_back','arm_l','arm_r','balance','hip_press','chest_press']:
  sk=n.shape_key_add(name=key,from_mix=False)
  for i,v in enumerate(mesh.vertices):
   x,y,z=v.co;t=max(0,min(1,(z-.85)/1.0));t=t*t*(3-2*t)
   dx=dy=dz=0.
   if key.startswith('lean'):dx=(.12 if key=='lean_right' else -.12)*t;dz=-.022*t
   elif key=='yield_back':dy=.105*t
   elif key.startswith('arm'):
    side=-1 if key=='arm_l' else 1
    w=max(0,min(1,(x*side-.12)/.5))*max(0,1-abs(z-1.56)/.45)
    dy=.14*w;dz=-.075*w
   elif key=='balance':dz=-.045*max(0,min(1,z/.9));dy=.028*math.sin(min(1,z/1.1)*math.pi)
   else:
    hip=key=='hip_press';cx,cy,cz=(.105,.205,1.03) if hip else (.085,-.147,1.54)
    weight=math.exp(-((x-cx)/.092)**2-((z-cz)/.085)**2-((y-cy)/.104)**2)
    dy=(-.042 if hip else .039)*weight
   sk.data[i].co+=Vector((dx,dy,dz))
b.context.window.scene=scene
b.ops.export_scene.gltf(filepath=str(out/'assets/full.glb'),use_active_scene=True,export_animations=False,export_morph=True)
# Os estudos compartilham a pose e têm drivers independentes por cena.
for hip in (True,False):
 study=b.data.scenes.new('05 • Esfera e short' if hip else '06 • Almofada e camisola')
 b.context.window.scene=study
 ctl=b.data.objects.new('Mover em Y • '+study.name[:2],None);study.collection.objects.link(ctl)
 x,z=(.105,1.03) if hip else (.085,1.54)
 near,deep,far=(.303,.262,.44) if hip else (-.23,-.188,-.37)
 ctl.location=(x,far,z);ctl.lock_location=(True,False,True);ctl.empty_display_size=.09
 ctl['Retorno']=0.0
 b.ops.mesh.primitive_uv_sphere_add(radius=1)
 prop=b.context.object;prop.name='Espuma';prop.parent=ctl;prop.location=(0,0,0);prop.scale=(.085,.082,.083) if hip else (.115,.073,.084)
 mat=b.data.materials.new('Espuma de estudo');mat.diffuse_color=(.06,.43,.38,1);prop.data.materials.append(mat)
 for n in parts:
  obj=n.copy();obj.data=n.data.copy();study.collection.objects.link(obj)
  k=obj.data.shape_keys.key_blocks['hip_press' if hip else 'chest_press']
  dr=k.driver_add('value').driver
  var=dr.variables.new();var.name='y';var.type='TRANSFORMS';var.targets[0].id=ctl;var.targets[0].transform_type='LOC_Y'
  var=dr.variables.new();var.name='ret';var.type='SINGLE_PROP';var.targets[0].id=ctl;var.targets[0].data_path='["Retorno"]'
  dr.expression=f'min(1,max(0,(y-({near}))/({deep-near}))+ret)'
 for f,y,ret in [(1,far,0.),(16,near,0.),(46,deep,0.),(58,deep,0.),(84,near,.17),(108,far,0.)]:
  ctl.location.y=y;ctl['Retorno']=float(ret);ctl.keyframe_insert(data_path='location',index=1,frame=f);ctl.keyframe_insert(data_path='["Retorno"]',frame=f)
 study.frame_end=108
 for f,label in [(1,'Repouso'),(16,'Contato'),(46,'Pressão'),(84,'Retorno'),(108,'Repouso')]:study.timeline_markers.new(label,frame=f)
 b.ops.object.camera_add(location=(x+.83,(1.22 if hip else -1.22),z+.30))
 cam=b.context.object;cam.rotation_euler=(Vector((x,0,z))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=.91;study.camera=cam
 study.render.engine='CYCLES';study.cycles.samples=5;study.cycles.use_denoising=True
 study.world=b.data.worlds.new('Estúdio');study.world.use_nodes=True;study.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.28,.34,1)
 b.ops.object.light_add(type='AREA',location=(.8,.9 if hip else -.9,z+1.4));light=b.context.object;light.rotation_euler=(Vector((0,0,z))-light.location).to_track_quat('-Z','Y').to_euler();light.data.energy=45;light.data.shape='DISK';light.data.size=1.1
 study.render.resolution_x=560;study.render.resolution_y=480;study.render.resolution_percentage=100
 for f in (1,46,84):
  study.frame_set(f);study.render.filepath=str(out.parent/'src'/f'{study.name[:2]}_{f}.png');b.ops.render.render(write_still=True)
 study.frame_set(46)
 for o in study.objects:o.select_set(False)
 ctl.select_set(True);b.context.view_layer.objects.active=ctl
b.context.window.scene=b.data.scenes['05 • Esfera e short']
for area in b.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
b.data.texts.new('LEIA • Contato').write('Cenas 05 e 06. Arraste a timeline de 1 a 108. Selecione Mover em Y e use G Y. Nas malhas, abra Shape Keys e inspecione hip_press ou chest_press. O driver lê Y do controle e soma Retorno. No Graph Editor, edite o atraso da propriedade Retorno.')
b.ops.wm.save_as_mainfile(filepath=str(out.parent/'src/Rose_Contato_1_0.blend'),compress=True)
