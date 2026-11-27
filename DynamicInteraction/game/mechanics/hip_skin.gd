extends RefCounted
## A malha importada é duplicada em memória. Somente os pesos são editados.

const ARM_BONES=["UpperL","UpperR","ForeL","ForeR","PalmL","PalmR"]

static func correct(body:MeshInstance3D)->void:
 if body==null or not body.mesh is ArrayMesh or body.skin==null:return
 var pelvis:=-1
 var torso:=-1
 var arms:Dictionary={}
 for slot in body.skin.get_bind_count():
  var bone:=str(body.skin.get_bind_name(slot))
  if bone=="Base":pelvis=slot
  if bone=="Spine":torso=slot
  if bone in ARM_BONES:arms[slot]=true
 if pelvis<0 or torso<0 or arms.is_empty():return
 var original:ArrayMesh=body.mesh
 var mesh:=ArrayMesh.new()
 mesh.blend_shape_mode=original.blend_shape_mode
 for i in original.get_blend_shape_count():mesh.add_blend_shape(original.get_blend_shape_name(i))
 for surface in original.get_surface_count():
  var arrays:=original.surface_get_arrays(surface)
  correct_surface(arrays,pelvis,torso,arms)
  mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface),arrays,original.surface_get_blend_shape_arrays(surface))
  mesh.surface_set_material(surface,original.surface_get_material(surface))
  mesh.surface_set_name(surface,original.surface_get_name(surface))
 body.mesh=mesh

static func correct_surface(arrays:Array,pelvis:int,torso:int,arms:Dictionary)->void:
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 # O GLB de Rosé usa quatro influências. Preserve outros formatos.
 if bones.size()!=vertices.size()*4 or weights.size()!=bones.size():return
 for vertex in vertices.size():
  var p:=vertices[vertex]
  # O quadril perde a influência do braço progressivamente na transição para
  # a axila. A posição lateral preserva mãos e antebraços baixos no bind.
  var arm_factor:=maxf(smoothstep(.275,.355,absf(p.x)),smoothstep(1.25,1.49,p.y))
  if arm_factor>=.9999:continue
  var influences:Dictionary={}
  var removed:=0.
  for i in range(vertex*4,vertex*4+4):
   var w:=weights[i]
   if w<=.00001:continue
   var joint:=bones[i]
   var kept:=w*arm_factor if arms.has(joint) else w
   if kept>.00001:influences[joint]=float(influences.get(joint,0.))+kept
   removed+=w-kept
  if removed<=.00001:continue
  var spine_share:=smoothstep(1.08,1.42,p.y)
  influences[pelvis]=float(influences.get(pelvis,0.))+removed*(1.-spine_share)
  influences[torso]=float(influences.get(torso,0.))+removed*spine_share
  var slots:=influences.keys()
  slots.sort_custom(func(a,b):return influences[a]>influences[b])
  var total:=0.
  for i in mini(4,slots.size()):total+=float(influences[slots[i]])
  for i in 4:
   var at:=vertex*4+i
   bones[at]=int(slots[i]) if i<slots.size() else pelvis
   weights[at]=float(influences[slots[i]])/total if i<slots.size() else 0.
 arrays[Mesh.ARRAY_BONES]=bones
 arrays[Mesh.ARRAY_WEIGHTS]=weights
