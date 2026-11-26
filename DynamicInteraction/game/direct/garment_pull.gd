extends Node3D
## Mantém uma cópia da peça no espaço do mundo do primeiro puxão à recolocação.
## A malha vestida é trocada pela pose congelada no mesmo quadro.
signal detached
signal dressed

enum State { WORN, PULLING, RETURNING, FINISHING, HELD, FALLING, RESTING, DRESSING }
const FABRIC = preload("res://direct/garment_pull.gdshader")
const DRESS_NODES = ["Dress","Ribbon"]
const FLOOR_Y := .035
const GRAVITY := 5.2

var state:=State.WORN
var held_slot:=-1
var side:=1.
var progress:=0.
var demand:=0.
var equipped_point:=Vector3.ZERO
var carry_target:=Vector3.ZERO
var velocity:=Vector3.ZERO
var garment_materials:Array[ShaderMaterial]=[]
var floor_support:=PackedVector3Array()
var sources:Array[MeshInstance3D]=[]
var meshes:Array[MeshInstance3D]=[]
var motion_frame:=Basis.IDENTITY
var pull_picker
var dressing_origin:=Transform3D.IDENTITY
var dressing_time:=0.

func configure(model:Node, picker)->void:
 pull_picker=picker
 for part in DRESS_NODES:
  var mesh:MeshInstance3D=model.find_child(part,true,false)
  if mesh:sources.append(mesh)

func begin(slot:int,point:Vector3,body_basis:Basis,shoulder_side:float)->bool:
 if state!=State.WORN or sources.is_empty():return false
 motion_frame=body_basis.orthonormalized()
 equipped_point=point
 carry_target=point
 global_transform=Transform3D(Basis.IDENTITY,point)
 side=shoulder_side
 held_slot=slot
 state=State.PULLING
 for source in sources:
  var copy:=MeshInstance3D.new()
  copy.mesh=bake(source)
  copy.custom_aabb=copy.mesh.get_aabb().grow(.3)
  add_child(copy)
  meshes.append(copy)
  source.hide()
 return true

func bake(source:MeshInstance3D)->ArrayMesh:
 var copy:=ArrayMesh.new()
 for s in pull_picker.surfaces:
  if s.node!=source:continue
  pull_picker.update_surface(s)
  var index:int=s.surface_index
  var original:=source.mesh.surface_get_arrays(index)
  var posed:=PackedVector3Array()
  for i in s.vertices.size():
   var v:Vector3=pull_picker.vertex(s,i)-equipped_point
   posed.append(v)
   var hem:=clampf(-v.y/.46,0.,1.)
   var wave:=sin(26.*v.x+13.*v.y)*hem
   floor_support.append(Vector3(v.x*(1.-.32*hem)-side*.09*hem,v.y*.70,v.z*.77+wave*.024))
  var arrays:Array=[]
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=posed
  arrays[Mesh.ARRAY_NORMAL]=original[Mesh.ARRAY_NORMAL]
  arrays[Mesh.ARRAY_INDEX]=original[Mesh.ARRAY_INDEX]
  copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var render:=ShaderMaterial.new()
  render.shader=FABRIC
  var material:Material=source.get_active_material(index)
  if material is StandardMaterial3D:
   render.set_shader_parameter("fabric_color",material.albedo_color)
   render.set_shader_parameter("fabric_roughness",material.roughness)
  render.set_shader_parameter("side",side)
  copy.surface_set_material(copy.get_surface_count()-1,render)
  garment_materials.append(render)
 return copy

func owns(slot:int)->bool:
 return held_slot==slot and state in [State.PULLING,State.HELD]

func pull(value:float,screen_target:Vector3)->void:
 demand=clampf(value,0.,1.)
 var extra:=motion_frame.inverse()*(screen_target-path(1.))
 extra=extra.limit_length(.33)
 extra.x=side*maxf(extra.x*side,-.17)
 extra.z=maxf(extra.z,-.08)
 carry_target=path(1.)+motion_frame*extra

func release(canceled:bool)->void:
 held_slot=-1
 if state==State.PULLING:
  state=State.FINISHING if demand>=1. and not canceled else State.RETURNING
 elif state==State.HELD:state=State.FALLING

func redress()->bool:
 if state not in [State.HELD,State.FALLING,State.RESTING]:return false
 held_slot=-1
 dressing_origin=global_transform
 dressing_time=0.
 state=State.DRESSING
 return true

func path(value:float)->Vector3:
 var rise:=smoothstep(0.,1.,value)
 var clear_front:=smoothstep(.025,.47,value)
 var clear_side:=smoothstep(.42,1.,value)
 var travel:=Vector3(side*(.055*rise+.38*clear_side),.67*rise,.38*clear_front-.040*clear_side)
 return equipped_point+motion_frame*travel

func pose_path()->void:
 var turn:=smoothstep(.08,1.,progress)
 var turn_basis:=Basis.from_euler(Vector3(-.32,side*.24,-side*.38)*turn)
 global_transform=Transform3D(turn_basis,path(progress))

func advance(dt:float)->void:
 match state:
  State.WORN,State.RESTING:return
  State.PULLING,State.FINISHING:
   progress=move_toward(progress,1. if state==State.FINISHING else demand,dt*2.35)
   pose_path()
   if progress>=1.:
    state=State.HELD if held_slot>=0 else State.FALLING
    velocity=motion_frame*Vector3(side*.24,.12,.08)
    detached.emit()
  State.RETURNING:
   progress=move_toward(progress,0.,dt*2.0)
   pose_path()
   if progress<=0.:reset()
  State.DRESSING:
   dressing_time=minf(1.,dressing_time+dt*2.05)
   pose_path()
   global_transform=dressing_origin.interpolate_with(global_transform,smoothstep(0.,1.,dressing_time))
   if dressing_time>=1.:state=State.RETURNING
  State.HELD:
   var old:=global_position
   global_position=old.lerp(carry_target,1.-exp(-dt*10.))
   velocity=((global_position-old)/maxf(dt,.001)).limit_length(1.6)
  State.FALLING:
   velocity.y-=GRAVITY*dt
   velocity*=exp(-dt*1.25)
   global_position+=velocity*dt
   var tilt:=Basis.from_euler(Vector3(-1.30,side*.24,-side*.38))
   global_basis=global_basis.slerp(tilt,1.-exp(-dt*3.5))
   var bottom:=lowest_world_y() if global_position.y<.48 else global_position.y
   if bottom<FLOOR_Y:
    global_position.y+=FLOOR_Y-bottom
    velocity.y=0.
    velocity.x=move_toward(velocity.x,0.,dt*5.)
    velocity.z=move_toward(velocity.z,0.,dt*5.)
    if velocity.length_squared()<.004:state=State.RESTING
 var gathered:=smoothstep(.03,.92,progress)
 for material in garment_materials:
  material.set_shader_parameter("gather",gathered)
  material.set_shader_parameter("flutter",minf(1.,velocity.length()/2.) if state!=State.RESTING else 0.)

func lowest_world_y()->float:
 var lowest:=0.
 var frame:=global_basis
 var world_up:=Vector3(frame.x.y,frame.y.y,frame.z.y)
 for v in floor_support:lowest=minf(lowest,world_up.dot(v))
 return global_position.y+lowest

func arm_weight(right:bool)->float:
 var first:bool=(side>0.)==right
 if state in [State.PULLING,State.RETURNING,State.FINISHING,State.DRESSING]:
  var weight:=smoothstep(.015 if first else .22,.58 if first else .86,progress)
  return weight*smoothstep(.27,1.,dressing_time) if state==State.DRESSING else weight
 return 0.

func reset()->void:
 for mesh in meshes:
  remove_child(mesh)
  mesh.queue_free()
 meshes.clear()
 garment_materials.clear()
 floor_support.clear()
 for source in sources:source.show()
 state=State.WORN
 held_slot=-1
 demand=0.
 progress=0.
 velocity=Vector3.ZERO
 dressed.emit()
