extends Node3D
## Interface de diagnóstico. O nó Rose executa o mesmo IK e skin da cena principal.

const LIMITS={
 "shoulder_l":["Ombro E · alvo",12.,158.],
 "shoulder_r":["Ombro D · alvo",12.,158.],
 "elbow_l":["Cotovelo E",12.,128.],
 "elbow_r":["Cotovelo D",12.,128.],
 "wrist_l":["Rotação do punho E",-65.,65.],
 "wrist_r":["Rotação do punho D",-65.,65.],
 "pelvis_cm":["Pelve · deslocamento (cm)",-9.,9.],
 "spine_turn":["Coluna · rotação",-25.,25.],
 "spine_tilt":["Coluna · inclinação",-17.,17.],
 "neck_turn":["Pescoço · rotação",-32.,32.],
 "neck_tilt":["Pescoço · inclinação",-24.,24.],
 "knee_morph":["Joelho · blend shape (%)",0.,100.],
 "max_shoulder":["Limite do alvo do ombro",90.,162.],
 "max_elbow":["Limite de flexão do cotovelo",65.,137.],
 "camera_turn":["Câmera",-65.,65.],
}

@export_group("Braços em graus")
@export_range(12.,158.,1.) var shoulder_l:=25.
@export_range(12.,158.,1.) var shoulder_r:=25.
@export_range(12.,128.,1.) var elbow_l:=55.
@export_range(12.,128.,1.) var elbow_r:=55.
@export_range(-65.,65.,1.) var wrist_l:=0.
@export_range(-65.,65.,1.) var wrist_r:=0.
@export_group("Pelve, tronco e referência de joelho")
@export_range(-9.,9.,1.) var pelvis_cm:=0.
@export_range(-25.,25.,1.) var spine_turn:=0.
@export_range(-17.,17.,1.) var spine_tilt:=0.
@export_range(-32.,32.,1.) var neck_turn:=0.
@export_range(-24.,24.,1.) var neck_tilt:=0.
@export_range(0.,100.,1.) var knee_morph:=100.
@export_group("Limites e visualização")
@export_range(90.,162.,1.) var max_shoulder:=158.
@export_range(65.,137.,1.) var max_elbow:=128.
@export_range(-65.,65.,1.) var camera_turn:=0.
@export var draw_rig:=true

@onready var game=$Rose
var lines:=ImmediateMesh.new()
var readout:=Label.new()
var knee_meshes:Array[MeshInstance3D]=[]
var configured:=Dictionary()
var cached_knee:=-1.
var report_elapsed:=0.

func _ready()->void:
 game.set_physics_process(false)
 game.set_process_input(false)
 game.set_process_unhandled_input(false)
 game.set_control_mode(game.ControlMode.Mode.TOUCHSCREEN,false)
 game.select_tool(game.Tool.RIGHT)
 for hand in game.hands:hand.enabled=false
 game.get_node("HUD").hide()
 game.camera.h_offset=-.49
 game.update_camera()
 for part in game.get_node("Rose/Portrait").find_children("*","MeshInstance3D",true,false):
  if part.find_blend_shape_by_name("idle_knees")>=0:knee_meshes.append(part)
 for key in LIMITS:configured[key]=get(key)
 create_rig_overlay()
 create_panel()

func create_rig_overlay()->void:
 var instance:=MeshInstance3D.new()
 instance.mesh=lines
 var material:=StandardMaterial3D.new()
 material.vertex_color_use_as_albedo=true
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.no_depth_test=true
 material.render_priority=20
 instance.material_override=material
 instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 instance.custom_aabb=AABB(Vector3(-2,-1,-2),Vector3(4,5,4))
 add_child(instance)

func create_panel()->void:
 var canvas:=CanvasLayer.new()
 canvas.layer=2
 add_child(canvas)
 var panel:=PanelContainer.new()
 canvas.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
 panel.offset_left=10
 panel.offset_right=267
 panel.offset_top=10
 panel.offset_bottom=-12
 var scroll:=ScrollContainer.new()
 panel.add_child(scroll)
 var content:=VBoxContainer.new()
 content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.add_child(content)
 var title:=Label.new()
 title.text="Articulações da Rosé"
 content.add_child(title)
 var back:=Button.new()
 back.text="Voltar à bancada física"
 back.custom_minimum_size.y=44
 back.pressed.connect(func():get_tree().change_scene_to_file("res://direct/constraint_lab.tscn"))
 content.add_child(back)
 var toggle:=CheckButton.new()
 toggle.text="Ossos e alvos de IK"
 toggle.button_pressed=draw_rig
 toggle.toggled.connect(func(on):draw_rig=on;lines.clear_surfaces())
 content.add_child(toggle)
 content.add_child(readout)
 var missing:=Label.new()
 missing.text="Quadris, joelhos e tornozelos sem ossos no GLB. Pelve e morph são referências."
 missing.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 content.add_child(missing)
 var sliders:Dictionary={}
 var captions:Dictionary={}
 for key in LIMITS:
  var spec:Array=LIMITS[key]
  var caption:=Label.new()
  caption.text="%s · %.0f"%[spec[0],float(get(key))]
  content.add_child(caption)
  captions[key]=caption
  var slider:=HSlider.new()
  slider.custom_minimum_size.y=30
  slider.min_value=spec[1]
  slider.max_value=spec[2]
  slider.step=1.
  slider.value=float(get(key))
  slider.value_changed.connect(func(v):
   set(key,v)
   caption.text="%s · %.0f"%[spec[0],v])
  sliders[key]=slider
  content.add_child(slider)
 var reset:=Button.new()
 reset.text="Restaurar pose inicial"
 reset.custom_minimum_size.y=44
 content.add_child(reset)
 reset.pressed.connect(func():
  for key in sliders:sliders[key].value=configured[key])
 var hint:=Label.new()
 hint.text="Ciano: braço E · rosa: braço D
Amarelo: alvo de IK"
 content.add_child(hint)

func apply_arm(side:String,requested:float,flexion:float)->void:
 var sk:Skeleton3D=game.skeleton
 var humerus:=sk.find_bone("Upper"+side)
 var radius:=sk.find_bone("Fore"+side)
 var palm:=sk.find_bone("Palm"+side)
 var a:=sk.get_bone_global_pose(humerus).origin
 var rest_a:=sk.get_bone_global_rest(humerus).origin
 var rest_b:=sk.get_bone_global_rest(radius).origin
 var rest_c:=sk.get_bone_global_rest(palm).origin
 var length:float=game.solver.reach_for_bend(rest_a.distance_to(rest_b),rest_b.distance_to(rest_c),flexion)
 var angle:=deg_to_rad(requested)
 var sign_:=-1. if side=="L" else 1.
 var axis:=Vector3(sign_*sin(angle)*.87,-cos(angle),.09+sin(angle)*.24).normalized()
 game.set_reach_target(side,a+axis*length)

func _physics_process(dt:float)->void:
 game.yaw=deg_to_rad(camera_turn)
 game.solver.shoulder_limit=max_shoulder
 game.solver.elbow_max=max_elbow
 game.solver.pose_wrist=Vector2(wrist_l,wrist_r)
 game.solver.pose_pelvis=Vector2(pelvis_cm*.01,0.)
 game.solver.pose_spine=Vector2(deg_to_rad(spine_turn),deg_to_rad(spine_tilt))
 game.solver.pose_head=Vector2(deg_to_rad(neck_turn),deg_to_rad(neck_tilt))
 if knee_morph!=cached_knee:
  cached_knee=knee_morph
  for mesh in knee_meshes:mesh.set_blend_shape_value(mesh.find_blend_shape_by_name("idle_knees"),knee_morph*.01)
 apply_arm("L",shoulder_l,elbow_l)
 apply_arm("R",shoulder_r,elbow_r)
 game._physics_process(dt)
 if draw_rig:draw_pose()
 report_elapsed+=dt
 if report_elapsed>.12:
  report_elapsed=0.
  readout.text="Ombro real E %.0f° · D %.0f°\nCotovelo E %.0f° · D %.0f°\nLimite do alvo %.0f° · flexão %.0f°"%[
   game.solver.elevation[0],game.solver.elevation[1],game.solver.bend[0],game.solver.bend[1],max_shoulder,max_elbow]

func segment(a:Vector3,b:Vector3,color:Color)->void:
 lines.surface_set_color(color)
 lines.surface_add_vertex(to_local(a))
 lines.surface_add_vertex(to_local(b))

func draw_pose()->void:
 lines.clear_surfaces()
 lines.surface_begin(Mesh.PRIMITIVE_LINES)
 var sk:Skeleton3D=game.skeleton
 for i in sk.get_bone_count():
  var parent:=sk.get_bone_parent(i)
  if parent<0:continue
  var tag:=str(sk.get_bone_name(i))
  var color:=Color("#61e3ea") if tag.ends_with("L") else (Color("#f599b8") if tag.ends_with("R") else Color("#f5e6cc"))
  segment(sk.to_global(sk.get_bone_global_pose(parent).origin),sk.to_global(sk.get_bone_global_pose(i).origin),color)
 for target in game.solver.ik_goals:
  var p:=sk.to_global(target)
  for direction in [Vector3.UP,Vector3.RIGHT,Vector3.BACK]:
   segment(p-direction*.025,p+direction*.025,Color("#ffe477"))
 lines.surface_end()
