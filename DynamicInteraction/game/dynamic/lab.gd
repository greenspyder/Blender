extends "res://interaction.gd"

const Detector=preload("res://dynamic/contact.gd")
const Response=preload("res://dynamic/response.gd")
const Hand=preload("res://dynamic/hand.gd")
var response=Response.new()
var hands=[]
var mode:=0
var zoom_size:=2.65
var pivot_y:=1.02
var yaw:=0.0
var pitch:=.04
var depth:=.31
var roll:=0.0
var pointer:=Vector2.ZERO
var settings={"Rigidez":52.0,"Amortecimento":.9,"Sensibilidade":1.0,"Influência":1.0,"Recuperação":1.0,"Distância":.12,"Espelho":1.0}
var debug_box:=VBoxContainer.new()
var readout:=Label.new()
var bindings: Array=[]
var contacts: Array=[]

func _ready() -> void:
 super()
 rose.rotation.y=0
 _start_angle=0
 for sign_ in [1,-1]:
  var hand=Hand.new()
  rose.add_child(hand)
  hand.setup(sign_)
  hand.desired=Vector3(sign_*.25,1.52,.30)
  hand.last=hand.desired
  hands.append(hand)
 for mesh in $Rose/Portrait.get_children():
  if mesh is MeshInstance3D:
   for key in ["lean_left","lean_right","yield_back","balance","arm_l","arm_r","brow_up"]:
    var idx:int=mesh.find_blend_shape_by_name(key)
    if idx>=0:bindings.append([mesh,idx,key])
 var bar:=HBoxContainer.new()
 $HUD/Top.add_child(bar)
 var options:=OptionButton.new()
 for item in ["Pirulito","Mão direita","Mão esquerda","Ambas as mãos"]:options.add_item(item)
 options.item_selected.connect(change_mode)
 bar.add_child(options)
 var toggle:=Button.new()
 toggle.text="Ajustes"
 toggle.pressed.connect(func():debug_box.visible=not debug_box.visible)
 bar.add_child(toggle)
 $HUD/Top.add_child(debug_box)
 debug_box.visible=false
 for spec in [["Rigidez",12,100,.5],["Amortecimento",.5,1.8,.05],["Sensibilidade",.2,2,.05],["Influência",0,1,.05],["Recuperação",.25,2,.05],["Distância",0,.32,.01],["Espelho",0,1,.05]]:
  var row:=HBoxContainer.new()
  debug_box.add_child(row)
  var label:=Label.new()
  row.add_child(label)
  label.custom_minimum_size.x=165
  var slider:=HSlider.new()
  row.add_child(slider)
  slider.custom_minimum_size.x=125
  slider.min_value=spec[1];slider.max_value=spec[2];slider.step=spec[3]
  var key:String=spec[0]
  slider.value=settings[key]
  label.text="%s %.2f"%[key,slider.value]
  slider.value_changed.connect(func(v):settings[key]=v;label.text="%s %.2f"%[key,v])
 debug_box.add_child(readout)
 update_camera()
 pointer=camera.unproject_position(Vector3(.25,1.59,.14))
 change_mode(0)

func change_mode(m:int) -> void:
 mode=m
 _return_to_tray()
 candy.visible=m==0
 action.visible=m==0
 hands[0].enabled=m in [1,3]
 hands[1].enabled=m in [2,3]
 $HUD/Top/Instructions.text="Arraste o pirulito · botão direito gira · roda aproxima" if m==0 else "Mouse move · W/S profundidade · Q/E rotação · direito orbita · ↑/↓ altura"
 if m!=0:status_label.text="  Aproxime a mão do ombro com W"

func update_camera() -> void:
 camera.size=zoom_size
 var center:=Vector3(0,pivot_y,0)
 camera.position=center+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*4
 camera.look_at(center)

func _input(event:InputEvent) -> void:
 if event is InputEventMouseMotion:
  if _orbiting:
   yaw-=event.relative.x*.006
   pitch=clampf(pitch+event.relative.y*.005,-1.05,1.05)
   update_camera()
   return
  pointer=event.position
 if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
  zoom_size=clampf(zoom_size*(.88 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.14),.43,3.4)
  update_camera()
 if mode==0:super(event)
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:_orbiting=event.pressed

func _unhandled_input(event:InputEvent) -> void:
 if mode==0:super(event)
 elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_R:reset_demo()

func reset_demo() -> void:
 super()
 yaw=0;pitch=.04;zoom_size=2.65;pivot_y=1.02;depth=.31;roll=0
 update_camera()

func _physics_process(dt:float) -> void:
 pivot_y=clampf(pivot_y+(int(Input.is_key_pressed(KEY_UP))-int(Input.is_key_pressed(KEY_DOWN)))*dt,0,2.15)
 depth=clampf(depth+(int(Input.is_key_pressed(KEY_S))-int(Input.is_key_pressed(KEY_W)))*dt*.42,-.31,.60)
 roll=clampf(roll+(int(Input.is_key_pressed(KEY_E))-int(Input.is_key_pressed(KEY_Q)))*dt,-1.5,1.5)
 update_camera()
 var normal:=camera.global_basis.z
 var plane:=Plane(normal,Vector3(0,pivot_y,0)+normal*depth)
 var hit:Variant=plane.intersects_ray(camera.project_ray_origin(pointer),camera.project_ray_normal(pointer))
 if hit==null:return
 var p:Vector3=hit.clamp(Vector3(-.96,.03,-.6),Vector3(.96,2.25,.6))
 contacts=[]
 for i in range(2):
  var target:=p
  if mode==3:
   var half:float=settings["Distância"]*.5
   target.x=clampf(absf(p.x)+half,half,.96)
   if i==1:target.x=-lerpf(half,target.x,settings["Espelho"])
  contacts.append(hands[i].advance(target,dt,roll,debug_box.visible,Detector))
 response.step(contacts,dt,settings["Rigidez"],settings["Amortecimento"],settings["Sensibilidade"],settings["Recuperação"])
 var weights={"lean_left":maxf(0,-response.pose.x),"lean_right":maxf(0,response.pose.x),"yield_back":response.pose.y,"balance":response.pose.z,"arm_l":response.arms.x,"arm_r":response.arms.y,"brow_up":response.intensity*.60}
 for binding in bindings:binding[0].set_blend_shape_value(binding[1],clampf(weights[binding[2]]*settings["Influência"],0,1))
 if debug_box.visible:readout.text="D %s %.2f  •  E %s %.2f"%[contacts[0].region,contacts[0].force,contacts[1].region,contacts[1].force]

func _follow_mouth() -> void:
 super()
 var offset:=Vector3(response.pose.x*.12,-absf(response.pose.x)*.022-response.pose.z*.045,-response.pose.y*.105)*float(settings["Influência"])
 candy.position+=offset
 candy.scale=Vector3.ONE*.24

func _return_to_tray() -> void:
 super()
 candy.scale=Vector3.ONE*.24

func drag_to(screen:Vector2) -> void:
 super(screen)
 candy.scale=Vector3.ONE*.24
