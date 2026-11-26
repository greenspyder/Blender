extends RefCounted
# Dynamic triangle picking. Broad-phase cells enclose the union of their skin
# influences. The narrow phase evaluates morphs before skinning each vertex.
var surfaces:Array = []
var skeleton:Skeleton3D
# Möller–Trumbore: tolerância relativa à área. O viés e o cabo do pirulito
# ficam pequenos demais para um epsilon absoluto depois de escalar o objeto.
static func intersection(o:Vector3,d:Vector3,a:Vector3,b:Vector3,c:Vector3)->Vector3:
 var e1:=b-a;var e2:=c-a;var v:=d.cross(e2);var det:=e1.dot(v)
 if absf(det)<=maxf(1e-15,1e-7*e1.length()*e2.length()):return Vector3(-1,0,0)
 var rel:=o-a;var u:=rel.dot(v)/det
 if u<-.00001 or u>1.00001:return Vector3(-1,0,0)
 var q:=rel.cross(e1);var w:=d.dot(q)/det
 if w<-.00001 or u+w>1.00001:return Vector3(-1,0,0)
 return Vector3(e2.dot(q)/det,u,w)

func configure(root:Node, sk:Skeleton3D, props:Array)->void:
 skeleton=sk
 for instance in root.find_children("*","MeshInstance3D",true,false)+props:
  for surface in instance.mesh.get_surface_count():
   register(instance,surface)

func register(instance:MeshInstance3D,index:int)->void:
 var arrays:=instance.mesh.surface_get_arrays(index)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 if indices.is_empty():
  for i in vertices.size():indices.append(i)
 var s:={"node":instance,"surface_index":index,"vertices":vertices,"indices":indices,"shapes":[],"extent":[],"weights":arrays[Mesh.ARRAY_WEIGHTS],"joints":arrays[Mesh.ARRAY_BONES],"slots":[],"cells":{},"active":[],"relative":false}
 if instance.mesh is ArrayMesh:
  s.relative=instance.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE
  for shape in instance.mesh.surface_get_blend_shape_arrays(index):
   var values:PackedVector3Array=shape[Mesh.ARRAY_VERTEX]
   var extent:=Vector3.ZERO
   for i in values.size():
    var delta:=values[i] if s.relative else values[i]-vertices[i]
    extent=extent.max(delta.abs())
   s.shapes.append(values);s.extent.append(extent)
 if instance.skin:
  for i in instance.skin.get_bind_count():
   var bone:=skeleton.find_bone(instance.skin.get_bind_name(i))
   if bone<0:bone=instance.skin.get_bind_bone(i)
   s.slots.append([bone,instance.skin.get_bind_pose(i)])
 for f in range(0,indices.size(),3):
  var a:=vertices[indices[f]]
  var b:=vertices[indices[f+1]]
  var c:=vertices[indices[f+2]]
  var key:=Vector3i(((a+b+c)/.30).floor())
  if not s.cells.has(key):s.cells[key]={"box":AABB(a,Vector3.ZERO),"slots":{},"faces":PackedInt32Array()}
  var cell:Dictionary=s.cells[key]
  cell.faces.append(f)
  cell.box=cell.box.expand(a).expand(b).expand(c)
  if not s.slots.is_empty():
   for offset in 3:
    var first:=indices[f+offset]*4
    for j in 4:
     if s.weights[first+j]>0:cell.slots[s.joints[first+j]]=true
 surfaces.append(s)

func update_surface(s:Dictionary)->void:
 s.active.clear()
 var margin:=Vector3.ZERO
 for i in s.shapes.size():
  var w:float=s.node.get_blend_shape_value(i)
  if absf(w)>.00001:
   s.active.append([i,w]);margin+=Vector3(s.extent[i])*absf(w)
 s.margin=margin
 s.matrix=[]
 for slot in s.slots:
  s.matrix.append(skeleton.global_transform*skeleton.get_bone_global_pose(slot[0])*slot[1])

func vertex(s:Dictionary,i:int)->Vector3:
 var base:Vector3=s.vertices[i]
 var p:=base
 for shape in s.active:
  var v:Vector3=s.shapes[shape[0]][i]
  p+=(v if s.relative else v-base)*float(shape[1])
 if s.slots.is_empty():return s.node.global_transform*p
 var result:=Vector3.ZERO
 var sum:=0.
 for j in range(i*4,i*4+4):
  var w:float=s.weights[j]
  if w>0:
   result+=Vector3(s.matrix[s.joints[j]]*p)*w;sum+=w
 return result/maxf(sum,.00001)

func track(hit:Dictionary)->Dictionary:
 var s:Dictionary=hit.surface
 update_surface(s)
 var f:int=hit.face
 var a:=vertex(s,s.indices[f]);var b:=vertex(s,s.indices[f+1]);var c:=vertex(s,s.indices[f+2])
 var bary:Vector3=hit.bary
 return {"p":a*bary.x+b*bary.y+c*bary.z,"n":(b-a).cross(c-a).normalized()*float(hit.sign)}

static func selection_offsets(tolerance:float)->Array[Vector2]:
 var offsets: Array[Vector2]=[Vector2.ZERO]
 if tolerance>0:
  for radius in [tolerance*.5,tolerance]:
   for i in 8:offsets.append(Vector2.RIGHT.rotated(i*TAU/8)*float(radius))
 return offsets

func cast(camera:Camera3D,screen:Vector2,tolerance:float)->Dictionary:
 var offsets:=selection_offsets(tolerance)
 for s in surfaces:
  if s.node.is_visible_in_tree():update_surface(s)
 for offset in offsets:
  var o:=camera.project_ray_origin(screen+Vector2(offset))
  var d:=camera.project_ray_normal(screen+Vector2(offset))
  var best:Dictionary={}
  var nearest:=INF
  for s in surfaces:
   if not s.node.is_visible_in_tree():continue
   var cache:Dictionary={}
   for cell in s.cells.values():
    var box:AABB=cell.box
    box=AABB(box.position-Vector3(s.margin),box.size+2*Vector3(s.margin)+Vector3.ONE*.00001)
    var bounds:AABB=s.node.global_transform*box
    if not cell.slots.is_empty():
     var first:=true
     for slot in cell.slots:
      var posed:AABB=s.matrix[slot]*box
      bounds=posed if first else bounds.merge(posed);first=false
    if bounds.intersects_ray(o,d)==null:continue
    for f in cell.faces:
     var ids:PackedInt32Array=s.indices
     for j in range(f,f+3):
      if not cache.has(ids[j]):cache[ids[j]]=vertex(s,ids[j])
     var a:Vector3=cache[ids[f]];var b:Vector3=cache[ids[f+1]];var c:Vector3=cache[ids[f+2]]
     var crossing:=intersection(o,d,a,b,c)
     if crossing.x<0:continue
     var point:=o+d*crossing.x
     var dist:=crossing.x
     if dist>=nearest:continue
     nearest=dist
     var n:=(b-a).cross(c-a).normalized()
     var sign_:=-1. if n.dot(d)>0 else 1.
     best={"p":point,"n":n*sign_,"surface":s,"face":f,"bary":Vector3(1-crossing.y-crossing.z,crossing.y,crossing.z),"sign":sign_,"offset":offset}
  if not best.is_empty():return best
 return {}
