extends RefCounted
## Converte só uma instância conhecida de rig121.glb, preservando o GLB e os demais usos.

const HipSkin=preload("res://mechanics/hip_skin.gd")

static func add_limbs(model:Node3D,sk:Skeleton3D,profile:Resource)->bool:
 var body:=model.find_child(profile.mesh_roles.skin,true,false) as MeshInstance3D
 if sk.get_bone_count()!=9 or body==null or body.skin==null:return false
 var ids:Dictionary=profile.resolve(sk)
 var pelvis:int=ids.pelvis
 var chest:int=ids.chest
 if pelvis<0 or chest<0 or sk.get_bone_parent(chest)!=pelvis:return false
 for role in ["lumbar","thigh_l","shin_l","foot_l","thigh_r","shin_r","foot_r"]:
  if int(ids[role])>=0:return false
 HipSkin.correct(body)
 var chest_rest:=sk.get_bone_global_rest(chest)
 var lumbar:=add_joint(sk,profile.bones.lumbar,pelvis,Vector3(0.,1.095,-.012))
 sk.set_bone_parent(chest,lumbar)
 sk.set_bone_rest(chest,sk.get_bone_global_rest(lumbar).affine_inverse()*chest_rest)
 for side in ["l","r"]:
  var sign_ := -1. if side=="l" else 1.
  var thigh:=add_joint(sk,profile.bones["thigh_"+side],pelvis,Vector3(sign_*.137,.91,-.037))
  var shin:=add_joint(sk,profile.bones["shin_"+side],thigh,Vector3(sign_*.144,.495,.023))
  add_joint(sk,profile.bones["foot_"+side],shin,Vector3(sign_*.145,.083,-.038))
 sk.reset_bone_poses()
 ids=profile.resolve(sk)
 var names:Array=[profile.mesh_roles.skin]+profile.mesh_roles.lower_clothes+profile.mesh_roles.shoes+profile.mesh_roles.upper_clothes
 for name_ in names:
  var part:=model.find_child(name_,true,false) as MeshInstance3D
  if part!=null:replace_skin(part,sk,ids,profile.mesh_roles.shoes.has(name_))
 return true

static func add_joint(sk:Skeleton3D,name_:String,parent:int,origin:Vector3)->int:
 var index:=sk.get_bone_count()
 sk.add_bone(name_)
 sk.set_bone_parent(index,parent)
 sk.set_bone_rest(index,sk.get_bone_global_rest(parent).affine_inverse()*Transform3D(Basis.IDENTITY,origin))
 return index

static func replace_skin(part:MeshInstance3D,sk:Skeleton3D,ids:Dictionary,shoe:bool)->void:
 if not part.mesh is ArrayMesh or part.skin==null:return
 var original:=part.mesh as ArrayMesh
 var mesh:=ArrayMesh.new()
 mesh.blend_shape_mode=original.blend_shape_mode
 for i in original.get_blend_shape_count():mesh.add_blend_shape(original.get_blend_shape_name(i))
 var skin:=part.skin.duplicate() as Skin
 var slots:Dictionary={}
 for role in ids:
  var name_:=sk.get_bone_name(ids[role])
  for i in skin.get_bind_count():
   if skin.get_bind_name(i)==name_:slots[role]=i
  if not slots.has(role):
   slots[role]=skin.get_bind_count()
   skin.add_named_bind(name_,sk.get_bone_global_rest(ids[role]).affine_inverse())
 var bind_space:=sk.global_transform.affine_inverse()*part.global_transform
 for surface in original.get_surface_count():
  var arrays:=original.surface_get_arrays(surface)
  distribute(arrays,slots,bind_space,shoe)
  mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface),arrays,original.surface_get_blend_shape_arrays(surface))
  mesh.surface_set_material(surface,original.surface_get_material(surface))
  mesh.surface_set_name(surface,original.surface_get_name(surface))
 part.mesh=mesh
 part.skin=skin

static func distribute(arrays:Array,slots:Dictionary,bind_space:Transform3D,shoe:bool)->void:
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var joints:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 if joints.size()!=vertices.size()*4 or weights.size()!=joints.size():return
 for v in vertices.size():
  var p:=bind_space*vertices[v]
  var side:="l" if p.x<0. else "r"
  var leg:=1.-smoothstep(.78,1.08,p.y)
  if shoe:
   joints[v*4]=slots["foot_"+side]
   weights[v*4]=1.
   for i in range(1,4):weights[v*4+i]=0.
   continue
  var waist:=smoothstep(.99,1.14,p.y)*(1.-smoothstep(1.22,1.34,p.y))
  if leg<=0. and waist<=0.:continue
  var influences:Dictionary={}
  for i in range(v*4,v*4+4):
   var slot:=joints[i]
   var w:=weights[i]*(1.-leg)
   if slot in [slots.pelvis,slots.chest]:
    add_weight(influences,slots.lumbar,w*waist)
    w*=1.-waist
   add_weight(influences,slot,w)
  var below_knee:=1.-smoothstep(.43,.56,p.y)
  var below_ankle:=1.-smoothstep(.065,.145,p.y)
  add_weight(influences,slots["thigh_"+side],leg*(1.-below_knee))
  add_weight(influences,slots["shin_"+side],leg*below_knee*(1.-below_ankle))
  add_weight(influences,slots["foot_"+side],leg*below_ankle)
  var indices:=influences.keys()
  indices.sort_custom(func(a,b):return influences[a]>influences[b])
  var total:=0.
  for i in mini(4,indices.size()):total+=float(influences[indices[i]])
  for i in 4:
   joints[v*4+i]=indices[i] if i<indices.size() else slots.pelvis
   weights[v*4+i]=float(influences[indices[i]])/total if i<indices.size() else 0.
 arrays[Mesh.ARRAY_BONES]=joints
 arrays[Mesh.ARRAY_WEIGHTS]=weights

static func add_weight(weights:Dictionary,slot:int,amount:float)->void:
 if amount>.000001:weights[slot]=float(weights.get(slot,0.))+amount
