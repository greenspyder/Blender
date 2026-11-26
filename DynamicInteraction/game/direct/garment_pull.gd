extends Node3D
signal detached
signal dressed

enum State { WORN, PULLING, RETURNING, FINISHING, HELD, FALLING, RESTING, DRESSING }
const FABRIC=preload("res://direct/garment_pull.gdshader")
const Cage=preload("res://direct/garment_cage.gd")
const DRESS_NODES=["Dress","Ribbon"]
const FLOOR_Y:=Cage.FLOOR

var state:=State.WORN
var held_slot:=-1
var side:=1.
var progress:=0.
var demand:=0.
var equipped_point:=Vector3.ZERO
var carry_target:=Vector3.ZERO
var velocity:=Vector3.ZERO
var sources:Array[MeshInstance3D]=[]
var meshes:Array[MeshInstance3D]=[]
var motion_frame:=Basis.IDENTITY
var pull_picker
var cage
var cloth_image:Image
var cloth_texture:ImageTexture
var texels:=PackedFloat32Array()
var anchors:=PackedVector3Array()
var obstacles:Array=[]
var remainder:=0.
var transition_time:=0.
var dressing_start:=Vector3.ZERO
var grip_target:=Vector3.ZERO

func configure(model:Node,picker)->void:
 pull_picker=picker
 for part in DRESS_NODES:
  var mesh:MeshInstance3D=model.find_child(part,true,false)
  if mesh:sources.append(mesh)

func begin(slot:int,point:Vector3,body_basis:Basis,shoulder_side:float)->bool:
 if state!=State.WORN or sources.is_empty():return false
 motion_frame=body_basis.orthonormalized()
 equipped_point=point
 carry_target=point
 grip_target=point
 global_transform=Transform3D(Basis.IDENTITY,point)
 side=shoulder_side
 held_slot=slot
 state=State.PULLING
 cage=Cage.new()
 cage.begin(point)
 var records:Array=[]
 for s in pull_picker.surfaces:
  if not s.node in sources:continue
  pull_picker.update_surface(s)
  var posed:=PackedVector3Array()
  var mapping:=PackedInt32Array()
  for i in s.vertices.size():
   var local:Vector3=pull_picker.vertex(s,i)-point
   posed.append(local)
   mapping.append(cage.particle(local,point))
  var indices:PackedInt32Array=s.indices
  for j in range(0,indices.size(),3):
   cage.triangle(mapping[indices[j]],mapping[indices[j+1]],mapping[indices[j+2]])
  records.append({"surface":s,"local":posed,"mapping":mapping})
 connect_ribbon(records)
 cage.pin_neighbors()
 anchors.resize(cage.rest.size())
 texels.resize(cage.rest.size()*4)
 texels.fill(0.)
 cloth_image=Image.create_from_data(cage.rest.size(),1,false,Image.FORMAT_RGBAF,texels.to_byte_array())
 cloth_texture=ImageTexture.create_from_image(cloth_image)
 for source in sources:
  var copy:=MeshInstance3D.new()
  copy.mesh=bake_render_mesh(source,records)
  add_child(copy)
  meshes.append(copy)
  source.hide()
 update_render()
 return true

func connect_ribbon(records:Array)->void:
 var dress:Dictionary={}
 var bow:Dictionary={}
 for record in records:
  for id in record.mapping:
   if record.surface.node.name=="Dress":dress[id]=true
   else:bow[id]=true
 # O laço tem topologia independente. Costure-o à frente da mesma peça.
 for id in bow:
  if dress.has(id):continue
  var rest_point:Vector3=cage.rest[id]
  var closest:=INF
  var nearest:=-1
  for other in dress:
   var distance:=rest_point.distance_squared_to(cage.rest[other])
   if distance<closest:
    closest=distance
    nearest=other
  if nearest>=0:cage.join(id,nearest,.53)

func bake_render_mesh(source:MeshInstance3D,records:Array)->ArrayMesh:
 var render_mesh:=ArrayMesh.new()
 for record in records:
  var s:Dictionary=record.surface
  if s.node!=source:continue
  var index:int=s.surface_index
  var original:=source.mesh.surface_get_arrays(index)
  var blend:=PackedVector2Array()
  var weights:=PackedVector2Array()
  for j in record.local.size():
   var binding:Vector3=cage.render_binding(record.local[j],record.mapping[j])
   blend.append(Vector2(binding.x,binding.y))
   weights.append(Vector2(binding.z,0.))
  var arrays:Array=[]
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=record.local
  arrays[Mesh.ARRAY_NORMAL]=original[Mesh.ARRAY_NORMAL]
  arrays[Mesh.ARRAY_INDEX]=original[Mesh.ARRAY_INDEX]
  arrays[Mesh.ARRAY_TEX_UV]=weights
  arrays[Mesh.ARRAY_TEX_UV2]=blend
  render_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var render:=ShaderMaterial.new()
  render.shader=FABRIC
  render.set_shader_parameter("cloth_offsets",cloth_texture)
  var material:Material=source.get_active_material(index)
  if material is StandardMaterial3D:
   render.set_shader_parameter("fabric_color",material.albedo_color)
   render.set_shader_parameter("fabric_roughness",material.roughness)
  render_mesh.surface_set_material(render_mesh.get_surface_count()-1,render)
 return render_mesh

func owns(slot:int)->bool:
 return held_slot==slot and state in [State.PULLING,State.HELD]

func pull(value:float,screen_target:Vector3)->void:
 demand=clampf(value,0.,1.)
 var extra:=motion_frame.inverse()*(screen_target-path(1.))
 extra=extra.limit_length(.33)
 extra.x=side*maxf(extra.x*side,-.14)
 extra.z=maxf(extra.z,-.045)
 carry_target=path(1.)+motion_frame*extra

func release(_canceled:bool)->void:
 held_slot=-1
 if state==State.PULLING:
  state=State.RETURNING
 elif state==State.HELD:
  state=State.FALLING
  transition_time=0.

func finish_with_button()->void:
 if state!=State.PULLING:return
 held_slot=-1
 demand=1.
 state=State.FINISHING

func redress()->bool:
 if state not in [State.HELD,State.FALLING,State.RESTING]:return false
 held_slot=-1
 dressing_start=global_position
 transition_time=0.
 state=State.DRESSING
 return true

func path(value:float)->Vector3:
 var rise:=smoothstep(0.,1.,value)
 var clear_front:=smoothstep(.025,.49,value)
 var clear_side:=smoothstep(.46,1.,value)
 var travel:=Vector3(side*(.055*rise+.40*clear_side),.69*rise,.39*clear_front-.025*clear_side)
 return equipped_point+motion_frame*travel

func write_guide(progress_:float,offset:Vector3=Vector3.ZERO)->void:
 var turn:=smoothstep(.1,1.,progress_)
 var twist:=Basis.from_euler(Vector3(-.22,side*.14,-side*.29)*turn)
 var pivot:=path(progress_)
 for i in cage.rest.size():
  var local:Vector3=cage.rest[i]
  var hem:=clampf(-local.y/.46,0.,1.)
  var lag:=hem*sin(progress_*PI)*.18
  var point:=pivot.lerp(path(progress_-lag),hem) if lag>.001 else pivot
  anchors[i]=point+offset+twist*local

func advance(dt:float)->void:
 if state in [State.WORN,State.RESTING]:return
 var previous_pin:=global_position
 var pin:Variant=null
 var guide:=0.
 match state:
  State.PULLING,State.FINISHING:
   var target:=1. if state==State.FINISHING else demand
   progress=move_toward(progress,target,dt*1.42)
   grip_target=path(progress)
   write_guide(progress)
   guide=.085+.07*smoothstep(.63,1.,progress)
   pin=grip_target
  State.RETURNING:
   progress=move_toward(progress,0.,dt*1.65)
   grip_target=path(progress)
   write_guide(progress)
   guide=.18+.13*(1.-progress)
   pin=grip_target
  State.DRESSING:
   transition_time=move_toward(transition_time,1.,dt*1.60)
   var p:=smoothstep(0.,1.,transition_time)
   grip_target=dressing_start.lerp(path(1.),p)
   write_guide(1.,grip_target-path(1.))
   guide=.085+.13*p
   pin=grip_target
  State.HELD:
   transition_time+=dt
   grip_target=grip_target.move_toward(carry_target,dt*.85)
   if transition_time<.20:
    write_guide(1.,grip_target-path(1.))
    guide=.10*(1.-transition_time/.20)
   pin=grip_target
  State.FALLING:
   transition_time+=dt
 remainder+=minf(dt,.05)
 while remainder>=Cage.STEP:
  var substep_pin:Variant=null
  if pin!=null:
   substep_pin=Vector3(cage.position[0]).move_toward(pin,Cage.STEP*1.25)
  var collision:=smoothstep(.075,.38,progress)*.92
  if state in [State.HELD,State.FALLING,State.DRESSING]:collision=.92
  cage.simulate(substep_pin,anchors,guide,obstacles,collision)
  remainder-=Cage.STEP
 update_render()
 velocity=((global_position-previous_pin)/maxf(dt,.001)).limit_length(2.2)
 match state:
  State.PULLING,State.FINISHING:
   if progress>=1. and has_clearance():
    state=State.HELD if held_slot>=0 else State.FALLING
    transition_time=0.
    detached.emit()
  State.RETURNING:
   if progress<=0. and mean_error()<.025:reset()
  State.DRESSING:
   if transition_time>=1. and mean_error()<.105:state=State.RETURNING
  State.FALLING:
   if cage.quiet_steps>=19:state=State.RESTING

func has_clearance()->bool:
 # A alça pode atingir o fim do gesto antes de a barra passar pelo ombro.
 if Vector3(cage.position[0]).distance_to(grip_target)>.06:return false
 var minimum:=equipped_point.y+.16
 for i in cage.position.size():
  if cage.position[i].y<minimum:return false
 return true

func mean_error()->float:
 var total:=0.
 for i in cage.position.size():total+=cage.position[i].distance_to(anchors[i])
 return total/float(cage.position.size())

func update_render()->void:
 global_position=cage.position[0]
 var bounds:AABB=cage.physical_extent()
 bounds.position-=global_position
 for mesh in meshes:mesh.custom_aabb=bounds.grow(.11)
 for i in cage.position.size():
  var offset:Vector3=cage.position[i]-global_position-cage.rest[i]
  texels[i*4]=offset.x
  texels[i*4+1]=offset.y
  texels[i*4+2]=offset.z
 cloth_image.set_data(cage.rest.size(),1,false,Image.FORMAT_RGBAF,texels.to_byte_array())
 cloth_texture.update(cloth_image)

func lowest_world_y()->float:
 return cage.lowest_y() if cage!=null else global_position.y

func arm_weight(right:bool)->float:
 var first:bool=(side>0.)==right
 if state in [State.PULLING,State.RETURNING,State.FINISHING,State.DRESSING]:
  var weight:=smoothstep(.025 if first else .25,.60 if first else .90,progress)
  return weight*smoothstep(.27,1.,transition_time) if state==State.DRESSING else weight
 return 0.

func reset()->void:
 for mesh in meshes:
  remove_child(mesh)
  mesh.queue_free()
 meshes.clear()
 for source in sources:source.show()
 cage=null
 cloth_image=null
 cloth_texture=null
 texels.clear()
 anchors.clear()
 state=State.WORN
 held_slot=-1
 demand=0.
 progress=0.
 velocity=Vector3.ZERO
 transition_time=0.
 remainder=0.
 dressed.emit()
