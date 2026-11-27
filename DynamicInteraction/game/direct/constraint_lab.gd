extends Node3D
## Bancada determinística de um grau de liberdade por objeto.
## O trilho resolve translação e a dobradiça resolve rotação em Z.

const Grip = preload("res://direct/grip_physics.gd")
const TouchDrag = preload("res://direct/touch_drag.gd")
const RAIL_ORIGIN := Vector3(-.58,.20,0)
const PIVOT_ORIGIN := Vector3(.44,-.34,0)
const RAIL_MIN := -.39
const RAIL_MAX := .37
const ANGLE_LIMIT := 1.05
var prefs=preload("res://direct/preferences.gd").new()
var router:=TouchDrag.new()
var grips:Dictionary={}
var cart_x:=0.
var cart_speed:=0.
var angle:=0.
var spin:=0.
var camera:=Camera3D.new()
var hinge:=Node3D.new()
var cart:MeshInstance3D
var lever:MeshInstance3D
var stops:Array[MeshInstance3D]=[]
var bar:=HBoxContainer.new()
var report:=Label.new()
var meter=preload("res://direct/physics_meter.gd").new()
var popup:PopupPanel

func box(parent:Node3D, center:Vector3, size_:Vector3, color:Color) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new()
 var shape:=BoxMesh.new()
 shape.size=size_
 var material:=StandardMaterial3D.new()
 material.albedo_color=color
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 shape.material=material
 mesh.mesh=shape
 parent.add_child(mesh)
 mesh.position=center
 return mesh

func _ready()->void:
 cart=box(self,RAIL_ORIGIN,Vector3(.42,.29,.18),Color("#639fbd"))
 box(self,RAIL_ORIGIN+Vector3(0,-.18,-.04),Vector3(1.34,.045,.14),Color("#667282"))
 for edge in [RAIL_MIN-.21-.035,RAIL_MAX+.21+.035]:
  stops.append(box(self,RAIL_ORIGIN+Vector3(edge,0,0),Vector3(.07,.38,.22),Color("#df9c68")))
 add_child(hinge)
 hinge.position=PIVOT_ORIGIN
 lever=box(hinge,Vector3(0,.30,0),Vector3(.16,.65,.14),Color("#91b883"))
 stops.append(box(self,PIVOT_ORIGIN+Vector3(0,0,.04),Vector3(.20,.16,.16),Color("#657682")))
 add_child(camera)
 camera.position=Vector3(0,0,3.4)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.keep_aspect=Camera3D.KEEP_WIDTH
 camera.size=2.8
 camera.current=true
 var hud:=CanvasLayer.new()
 add_child(hud)
 var overlay:=Control.new()
 hud.add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
 overlay.add_child(bar)
 bar.position=Vector2(12,10)
 popup=prefs.panel(overlay)
 for title in ["Rosé","Ajustes","Reiniciar","Articulações"]:
  var btn:=Button.new()
  btn.text=title
  btn.custom_minimum_size=Vector2(92,48)
  bar.add_child(btn)
  match title:
   "Rosé":btn.pressed.connect(func():get_tree().change_scene_to_file("res://direct_touch.tscn"))
   "Ajustes":btn.pressed.connect(func():clear_grips();popup.popup_centered_ratio(.8))
   "Reiniciar":btn.pressed.connect(reset)
   "Articulações":btn.pressed.connect(func():get_tree().change_scene_to_file("res://direct/articulation_lab.tscn"))
 meter.attach(overlay,Vector2(12,66))
 overlay.add_child(report)
 report.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 report.position+=Vector2(12,-174)
 report.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _input(event:InputEvent)->void:
 if not is_node_ready() or popup.visible:return
 if event is InputEventScreenTouch or event is InputEventScreenDrag:
  if router.capture(event,not bar.get_global_rect().has_point(event.position),begin,move,release):
   get_viewport().set_input_as_handled()
 elif event is InputEventMouse and event.device!=InputEvent.DEVICE_ID_EMULATION:
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed and not bar.get_global_rect().has_point(event.position):begin(-1,event.position)
   elif not event.pressed:release(-1,event.position,false)
  elif event is InputEventMouseMotion:move(-1,event.position)

func pick(screen:Vector2)->Dictionary:
 var origin:=camera.project_ray_origin(screen)
 var ray_end:=origin+camera.project_ray_normal(screen)*12.
 var nearest:=INF
 var result:Dictionary={}
 for part in [cart,lever]+stops:
  var intersection:Variant=part.get_aabb().intersects_segment(part.to_local(origin),part.to_local(ray_end))
  if intersection==null:continue
  var point:Vector3=part.to_global(intersection)
  var distance:=origin.distance_squared_to(point)
  if distance>=nearest:continue
  nearest=distance
  result={"part":part,"local":intersection,"point":point}
 return result

func begin(id:int,screen:Vector2)->bool:
 meter.register_input()
 if grips.has(id) or grips.size()>=2:
  router.failure="Use até dois dedos"
  return false
 var hit:=pick(screen)
 if hit.is_empty() or hit.part in stops:
  router.failure="Toque no bloco azul ou na alavanca"
  return false
 var marker:=MeshInstance3D.new()
 var dot:=SphereMesh.new()
 dot.radius=.024
 dot.height=.048
 marker.mesh=dot
 var material:=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color=Color("#ffd194")
 marker.material_override=material
 add_child(marker)
 marker.global_position=hit.point+Vector3.BACK*.027
 grips[id]={
  "part":hit.part,"local":hit.local,"target":hit.point,"anchor":hit.point,
  "plane":Plane(camera.global_basis.z,hit.point),"force":Vector3.ZERO,"marker":marker,
 }
 return true

func move(id:int,screen:Vector2)->void:
 if not grips.has(id):return
 meter.register_input()
 var g:Dictionary=grips[id]
 var target:Variant=TouchDrag.project(camera,g.plane,screen)
 if target!=null:g.target=target

func release(id:int,_screen:Vector2,_canceled:bool)->void:
 if not grips.has(id):return
 grips[id].marker.queue_free()
 grips.erase(id)

func clear_grips()->void:
 for id in grips.keys():release(id,Vector2.ZERO,true)
 router.captured.clear()

func reset()->void:
 clear_grips()
 cart_x=0.
 cart_speed=0.
 angle=0.
 spin=0.
 apply_pose()

func apply_pose()->void:
 cart.position=RAIL_ORIGIN+Vector3.RIGHT*cart_x
 hinge.rotation.z=angle

func simulate(h:float)->void:
 var net:=0.
 var torque:=0.
 var mass:float=prefs.values["Massa (kg)"]
 var held_cart:=false
 var held_lever:=false
 for g in grips.values():
  var point:Vector3=g.part.to_global(g.local)
  var arm:=point-PIVOT_ORIGIN
  var velocity:=Vector3.RIGHT*cart_speed if g.part==cart else Vector3.BACK.cross(arm)*spin
  g.force=Grip.traction(g.target,point,velocity,prefs.values)
  if g.part==cart:
   held_cart=true
   net+=Vector3(g.force).x
  else:
   held_lever=true
   torque+=arm.cross(g.force).z
 cart_speed=clampf((cart_speed+net/mass*h)*Grip.friction_factor(h,prefs.values,held_cart),-2.,2.)
 spin=clampf((spin+torque/(mass*.22)*h)*Grip.friction_factor(h,prefs.values,held_lever),-4.,4.)
 var next_x:=cart_x+cart_speed*h
 cart_x=clampf(next_x,RAIL_MIN,RAIL_MAX)
 if cart_x!=next_x:cart_speed=0.
 var next_angle:=angle+spin*h
 angle=clampf(next_angle,-ANGLE_LIMIT,ANGLE_LIMIT)
 if angle!=next_angle:spin=0.
 apply_pose()
 for g in grips.values():
  g.anchor=g.part.to_global(g.local)
  g.marker.global_position=Vector3(g.anchor)+Vector3.BACK*.027

func _physics_process(dt:float)->void:
 var t:=meter.begin_tick()
 var remaining:=minf(dt,.05)
 while remaining>.00001:
  var h:=minf(remaining,Grip.STEP)
  simulate(h)
  remaining-=h
 var lines:=PackedStringArray(["Bloco no trilho · Alavanca articulada"])
 for id in grips:
  var g:Dictionary=grips[id]
  lines.append("Dedo %d · Vinculado · %.1f N · erro %.3f m" % [id,Vector3(g.force).length(),Vector3(g.target).distance_to(g.anchor)])
  lines.append("Desejada %.2f, %.2f · Efetiva %.2f, %.2f m" % [g.target.x,g.target.y,g.anchor.x,g.anchor.y])
 if not router.failure.is_empty():lines.append(router.failure)
 report.text="\n".join(lines)
 meter.end_tick(t)

func _notification(what:int)->void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:clear_grips()
