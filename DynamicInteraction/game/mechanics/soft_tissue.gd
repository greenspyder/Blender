extends RefCounted
## A pressão reutiliza as formas do GLB no lado original. Formas complementares
## permanecem locais, com resposta independente e retorno amortecido.

const NAMES=["Peito D","Peito E","Glúteo D","Glúteo E"]
const AREAS=[
 {"key":"chest_press","center":Vector3(.085,1.54,.147),"depth":-.039,"pieces":["Body","Dress","Ribbon"]},
 {"key":"hip_press","center":Vector3(.105,1.03,-.205),"depth":.042,"pieces":["Body","Shorts","PocketL","PocketR"]},
]
const RADII=Vector3(.092,.085,.104)
const SHEAR=.012

var weights:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
var speed:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
var bindings:Array[Dictionary]=[]
var shown:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]

func setup(root:Node)->void:
 for node:MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
  var source:=node.mesh as ArrayMesh
  if source==null:continue
  var regions:Array[int]=[]
  for i in AREAS.size():
   if str(node.name) in AREAS[i].pieces and node.find_blend_shape_by_name(AREAS[i].key)>=0:
    regions.append(i)
  if regions.is_empty():continue
  var mesh:=ArrayMesh.new()
  mesh.blend_shape_mode=source.blend_shape_mode
  var initial_weights:=PackedFloat32Array()
  for i in source.get_blend_shape_count():
   mesh.add_blend_shape(source.get_blend_shape_name(i))
   initial_weights.append(node.get_blend_shape_value(i))
  var channels:Dictionary={}
  for area in regions:
   var key:String=AREAS[area].key
   var original:=node.find_blend_shape_by_name(key)
   for side in 2:
    var lateral:=mesh.get_blend_shape_count()
    var suffix:="r" if side==0 else "l"
    mesh.add_blend_shape(&"%s_%s_x"%[key,suffix])
    mesh.add_blend_shape(&"%s_%s_y"%[key,suffix])
    var pressure:=original
    if side==1:
     pressure=mesh.get_blend_shape_count()
     mesh.add_blend_shape(&"%s_l"%key)
    channels[area*2+side]=Vector3i(lateral,lateral+1,pressure)
  for surface in source.get_surface_count():
   var arrays:=source.surface_get_arrays(surface)
   var morphs:=source.surface_get_blend_shape_arrays(surface)
   var relative:=source.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE
   for area in regions:
    for side in 2:
     morphs.append(make_shape(arrays,area,side,Vector3.RIGHT*SHEAR,relative))
     morphs.append(make_shape(arrays,area,side,Vector3.UP*SHEAR,relative))
     if side==1:
      morphs.append(make_shape(arrays,area,side,Vector3(0,0,AREAS[area].depth),relative))
   mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays,morphs)
   mesh.surface_set_material(surface,source.surface_get_material(surface))
   mesh.surface_set_name(surface,source.surface_get_name(surface))
  node.mesh=mesh
  for i in initial_weights.size():node.set_blend_shape_value(i,initial_weights[i])
  bindings.append({"node":node,"channels":channels})

static func envelope(p:Vector3,area:int,side:int)->float:
 var center:Vector3=AREAS[area].center
 if side==1:center.x=-center.x
 var distance:Vector3=(p-center)/RADII
 return exp(-distance.length_squared())

static func make_shape(arrays:Array,area:int,side:int,delta:Vector3,relative:bool)->Array:
 var shape:Array=[]
 shape.resize(Mesh.ARRAY_MAX)
 var original:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var points:=PackedVector3Array()
 points.resize(original.size())
 for i in original.size():
  var offset:=delta*envelope(original[i],area,side)
  points[i]=offset if relative else original[i]+offset
 shape[Mesh.ARRAY_VERTEX]=points
 if arrays[Mesh.ARRAY_NORMAL]!=null:
  var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate()
  if relative:normals.fill(Vector3.ZERO)
  shape[Mesh.ARRAY_NORMAL]=normals
 if arrays[Mesh.ARRAY_TANGENT]!=null:
  var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT].duplicate()
  if relative:tangents.fill(0.)
  shape[Mesh.ARRAY_TANGENT]=tangents
 return shape

func region_for_hit(hit:Dictionary)->int:
 if hit.is_empty():return -1
 var surface:Dictionary=hit.surface
 var name_:String=str(surface.node.name)
 var moment:Vector3=hit.bary
 var face:int=hit.face
 var p:Vector3=surface.vertices[surface.indices[face]]*moment.x
 p+=Vector3(surface.vertices[surface.indices[face+1]])*moment.y
 p+=Vector3(surface.vertices[surface.indices[face+2]])*moment.z
 var side:=0 if p.x>=0. else 1
 for area in AREAS.size():
  if name_ not in AREAS[area].pieces:continue
  var origin:Vector3=AREAS[area].center
  if p.z*origin.z<=0.:continue
  if envelope(p,area,side)>.19:return area*2+side
 return -1

func advance(dt:float,sk:Skeleton3D,touches:Dictionary,links:Dictionary)->void:
 var targets:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
 for slot in touches:
  var g:Dictionary=touches[slot]
  var id:int=g.get("tissue",-1)
  if id<0 or not g.down or not g.hit.surface.node.is_visible_in_tree():continue
  var movement:=sk.to_local(g.point)-sk.to_local(g.base)
  if links.has(slot):
   var normal:Vector3=(sk.global_basis.inverse()*Vector3(g.bind_normal)).normalized()
   var tangent:=movement.slide(normal)
   var press:=clampf(.13-movement.dot(normal)/.054+tangent.length()*2.1,.08,1.)
   targets[id]+=Vector3(tangent.x/.10,tangent.y/.10,press)
  elif Vector3(g.physical).distance_to(g.base)<.028:
   targets[id].z+=.18
 step(dt,targets)

func step(dt:float,targets:Array[Vector3])->void:
 var remaining:=minf(dt,.05)
 while remaining>.00001:
  var h:=minf(remaining,1./120.)
  for i in weights.size():
   var target:=targets[i].clamp(Vector3(-1.,-1.,0.),Vector3.ONE)
   var k:=78. if target.length_squared()>.001 else 47.
   speed[i]+=(k*(target-weights[i])-2.*sqrt(k)*.80*speed[i])*h
   weights[i]+=speed[i]*h
   if target.is_zero_approx() and weights[i].length_squared()+speed[i].length_squared() < .0000005:
    weights[i]=Vector3.ZERO
    speed[i]=Vector3.ZERO
  remaining-=h
 for i in weights.size():
  var amount:=weights[i].clamp(Vector3(-1.,-1.,0.),Vector3.ONE)
  if amount==shown[i]:continue
  shown[i]=amount
  for binding in bindings:
   if not binding.channels.has(i):continue
   var channels:Vector3i=binding.channels[i]
   binding.node.set_blend_shape_value(channels.x,amount.x)
   binding.node.set_blend_shape_value(channels.y,amount.y)
   binding.node.set_blend_shape_value(channels.z,amount.z)

func reset()->void:
 weights.fill(Vector3.ZERO)
 speed.fill(Vector3.ZERO)
 step(0.,weights)
