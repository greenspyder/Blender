extends Node3D

const Profile=preload("res://rig/character_profile.gd")
const Legacy=preload("res://rig/legacy_rose_skin.gd")
const FullBody=preload("res://rig/full_body_pose.gd")
const POSES:=["Em pé", "Transferência E", "Transferência D", "Inclinar", "Sentar · referência", "Suspender", "Reclinar · referência"]
const JOINTS:={
 "pelvis":"Pelve","lumbar":"Lombar","chest":"Tórax","head":"Cabeça",
 "arm_l":"Braço E","arm_r":"Braço D","hip_l":"Quadril E","hip_r":"Quadril D",
 "knee_l":"Joelho E","knee_r":"Joelho D","ankle_l":"Tornozelo E","ankle_r":"Tornozelo D",
}
const PASSES:={"pelvis":"Pelve","spine":"Coluna","head":"Cabeça","arms":"IK dos braços","legs":"Cadeia das pernas","feet":"IK de apoio"}
const COLORS:={"bone":Color("#bce9f1"),"com":Color("#ffd681"),"mass":Color("#d6a1ed"),"ik":Color("#74e6b1"),"limit":Color("#f38985")}

@export var profile:Profile
@onready var camera:Camera3D=$Camera3D
var sk:Skeleton3D
var solver:=FullBody.new()
var ready_to_pose:=false
var preview:Dictionary={}
var plant:=Vector2.ONE
var selected:="pelvis"
var orbit:=26.
var draw:Dictionary={"bone":true,"com":true,"mass":false,"ik":true,"limit":true}
var lines:=ImmediateMesh.new()
var readout:Label
var support_menu:OptionButton
var sliders:Array[HSlider]=[]
var captions:Array[Label]=[]
var interval:=0.

func _ready()->void:
 var content:=create_panel()
 update_camera()
 if profile==null or profile.model==null:
  show_message(content,"Escolha um modelo no perfil de personagem.")
  return
 var model:=profile.model.instantiate() as Node3D
 if model==null:
  show_message(content,"O modelo precisa de uma raiz Node3D.")
  return
 $Model.add_child(model)
 var skeletons:=model.find_children("*","Skeleton3D",true,false)
 sk=skeletons[0] if not skeletons.is_empty() else null
 if sk==null:
  show_message(content,"O modelo precisa de um Skeleton3D.")
  return
 if profile.add_legacy_rose_bones and not profile.validate(sk).is_empty():
  if not Legacy.add_limbs(model,sk,profile):
   show_message(content,"O adaptador serve para o rig legado específico da Rosé.")
   return
 var errors:=solver.configure(sk,profile)
 if not errors.is_empty():
  show_message(content,"\n".join(errors))
  return
 for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  var index:=mesh.find_blend_shape_by_name("idle_knees")
  if index>=0:mesh.set_blend_shape_value(index,0.)
 create_overlay()
 add_controls(content)
 choose_pose(0)
 ready_to_pose=true

func create_panel()->VBoxContainer:
 var hud:=CanvasLayer.new()
 add_child(hud)
 var panel:=PanelContainer.new()
 hud.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
 panel.offset_left=10.
 panel.offset_top=10.
 panel.offset_right=289.
 panel.offset_bottom=-10.
 var scroll:=ScrollContainer.new()
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 panel.add_child(scroll)
 var content:=VBoxContainer.new()
 content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.add_child(content)
 show_message(content,"Rosé · Corpo inteiro")
 var back:=Button.new()
 back.text="Voltar às articulações"
 back.custom_minimum_size.y=42.
 content.add_child(back)
 back.pressed.connect(func():get_tree().change_scene_to_file("res://direct/articulation_lab.tscn"))
 return content

func show_message(parent:VBoxContainer,message:String)->Label:
 var label:=Label.new()
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.text=message
 parent.add_child(label)
 return label

func dropdown(content:VBoxContainer,items:Array,change:Callable)->OptionButton:
 var options:=OptionButton.new()
 options.fit_to_longest_item=false
 options.custom_minimum_size.y=43.
 for item in items:options.add_item(item)
 content.add_child(options)
 options.item_selected.connect(change)
 return options

func checkbox(content:VBoxContainer,label_:String,value:bool,change:Callable)->void:
 var box:=CheckButton.new()
 box.text=label_
 box.button_pressed=value
 box.custom_minimum_size.y=38.
 box.add_theme_font_size_override("font_size",15)
 content.add_child(box)
 box.toggled.connect(change)

func add_controls(content:VBoxContainer)->void:
 readout=show_message(content,"")
 var balance_button:=Button.new()
 balance_button.text="Equilíbrio e chão · 1.3.2"
 balance_button.custom_minimum_size.y=44
 content.add_child(balance_button)
 balance_button.pressed.connect(func():get_tree().change_scene_to_file("res://rig/balance_lab.tscn"))
 dropdown(content,POSES,choose_pose)
 show_message(content,"Apoio de referência")
 support_menu=dropdown(content,["Ambos os pés","Pé esquerdo","Pé direito","Livre"],func(index):
  plant=[Vector2.ONE,Vector2(1.,0.),Vector2(0.,1.),Vector2.ZERO][index])
 show_message(content,"Articulação e alvos em graus")
 dropdown(content,JOINTS.values(),func(i):
  selected=JOINTS.keys()[i]
  refresh_sliders())
 for axis in 3:
  captions.append(show_message(content,""))
  var slider:=HSlider.new()
  slider.custom_minimum_size.y=28.
  slider.step=1.
  slider.value_changed.connect(func(value):
   var angles:Vector3=preview[selected]
   angles[axis]=value
   preview[selected]=angles
   caption(axis,value))
  sliders.append(slider)
  content.add_child(slider)
 show_message(content,"Câmera")
 var turn:=HSlider.new()
 turn.min_value=-180.
 turn.max_value=180.
 turn.value=orbit
 turn.custom_minimum_size.y=32.
 turn.value_changed.connect(func(value):orbit=value;update_camera())
 content.add_child(turn)
 show_message(content,"Visualização")
 for item:Array in [["bone","Esqueleto"],["com","Centro de massa"],["mass","Distribuição de massa"],["ik","IK e apoios"],["limit","Limites da articulação"]]:
  var key:String=item[0]
  checkbox(content,item[1],draw[key],func(value):draw[key]=value)
 show_message(content,"Controladores")
 for key in PASSES:
  checkbox(content,PASSES[key],solver.enabled[key],func(value):solver.enabled[key]=value)

func choose_pose(index:int)->void:
 preview={"travel":Vector3(0.,-.015,0.)}
 for key in JOINTS:preview[key]=Vector3.ZERO
 for side in ["l","r"]:
  preview["arm_"+side]=Vector3(22.,45.,0.)
  preview["hip_"+side]=Vector3(-8.,0.,0.)
  preview["knee_"+side]=Vector3(15.,0.,0.)
  preview["ankle_"+side]=Vector3(-7.,0.,0.)
 plant=Vector2.ONE
 match index:
  1,2:
   var sign_:=-1. if index==1 else 1.
   preview.travel=Vector3(.107*sign_,-.068,.014)
   preview.pelvis=Vector3(2.,-7.*sign_,4.*sign_)
   preview.lumbar=Vector3(5.,3.*sign_,-6.*sign_)
   preview.chest=Vector3(-1.,-3.*sign_,-2.*sign_)
   var free_side:="r" if index==1 else "l"
   preview["hip_"+free_side]=Vector3(-24.,0.,-8.*sign_)
   preview["knee_"+free_side]=Vector3(43.,0.,0.)
   preview["ankle_"+free_side]=Vector3(-18.,0.,0.)
   plant=Vector2(1,0) if index==1 else Vector2(0,1)
  3:
   preview.travel=Vector3(0.,-.06,-.045)
   preview.pelvis=Vector3(12.,0.,0.)
   preview.lumbar=Vector3(17.,0.,0.)
   preview.chest=Vector3(18.,0.,0.)
   preview.head=Vector3(-13.,0.,0.)
  4:
   preview.travel=Vector3(0.,-.355,-.12)
   preview.lumbar=Vector3(12.,0.,0.)
   preview.chest=Vector3(6.,0.,0.)
   for side in ["l","r"]:
    preview["hip_"+side]=Vector3(-81.,0.,0.)
    preview["knee_"+side]=Vector3(83.,0.,0.)
    preview["ankle_"+side]=Vector3(-5.,0.,0.)
   plant=Vector2.ZERO
  5:
   preview.travel=Vector3(0.,.275,0.)
   preview.lumbar=Vector3(5.,0.,0.)
   plant=Vector2.ZERO
  6:
   preview.travel=Vector3(0.,-.46,.11)
   preview.pelvis=Vector3(-28.,0.,0.)
   preview.lumbar=Vector3(-17.,0.,0.)
   preview.chest=Vector3(-16.,0.,0.)
   preview.hip_l=Vector3(-69.,0.,0.)
   preview.hip_r=Vector3(-67.,0.,0.)
   preview.knee_l=Vector3(66.,0.,0.)
   preview.knee_r=Vector3(72.,0.,0.)
   plant=Vector2.ZERO
 if support_menu!=null:
  support_menu.select([Vector2.ONE,Vector2(1.,0.),Vector2(0.,1.),Vector2.ZERO].find(plant))
 refresh_sliders()

func selected_limits()->Vector3:
 match selected:
  "pelvis":return profile.pelvis_limit
  "lumbar":return profile.lumbar_limit
  "chest":return profile.chest_limit
  "head":return profile.head_limit
 if selected.begins_with("hip"):return profile.hip_limit
 if selected.begins_with("knee"):return Vector3(profile.knee_limit.y,0.,0.)
 if selected.begins_with("ankle"):return profile.ankle_limit
 return Vector3(profile.shoulder_limit,profile.elbow_limit.y,profile.wrist_limit)

func refresh_sliders()->void:
 var limits:=selected_limits()
 for i in sliders.size():
  var slider:=sliders[i]
  var arm:=selected.begins_with("arm")
  slider.min_value=profile.elbow_limit.x if arm and i==1 else (0. if (arm and i==0) or selected.begins_with("knee") else -limits[i])
  slider.max_value=limits[i]
  slider.editable=limits[i]>0.
  slider.set_value_no_signal(Vector3(preview[selected])[i])
  caption(i,slider.value)

func caption(axis:int,value:float)->void:
 var labels:=["Inclinação X","Rotação Y","Inclinação Z"]
 if selected.begins_with("arm"):labels=["Elevação","Flexão do cotovelo","Giro do punho"]
 if selected.begins_with("knee"):labels=["Flexão","—","—"]
 captions[axis].text="%s · %.0f°"%[labels[axis],value]

func update_camera()->void:
 var heading:=deg_to_rad(orbit)
 var target:=Vector3(0.,1.04,0.)
 camera.position=target+Vector3(sin(heading)*4.6,1.02,cos(heading)*4.6)
 camera.look_at(target)
 camera.h_offset=-.48

func create_overlay()->void:
 var instance:=MeshInstance3D.new()
 var material:=StandardMaterial3D.new()
 material.vertex_color_use_as_albedo=true
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.no_depth_test=true
 material.render_priority=20
 instance.mesh=lines
 instance.material_override=material
 instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 instance.custom_aabb=AABB(Vector3(-3,-1,-3),Vector3(6,5,6))
 add_child(instance)

func _physics_process(dt:float)->void:
 if not ready_to_pose:return
 solver.apply(preview,plant,dt)
 interval+=dt
 if interval<.045:return
 interval=0.
 draw_pose()
 var support:=PackedStringArray()
 for side in solver.contacts:
  var hit:Dictionary=solver.contacts[side]
  var state:="em transição" if float(hit.weight)<.99 else ("no limite" if hit.limited else "alvo atingido")
  support.append("%s %s"%["E" if side=="l" else "D",state])
 readout.text="%d ossos · %.1f kg\nApoio: %s\nCentro de massa: %.2f m"%[
  sk.get_bone_count(),profile.mass_kg,"livre" if support.is_empty() else " / ".join(support),solver.center_of_mass.y]

func line(a:Vector3,b:Vector3,color:Color)->void:
 for point in [a,b]:
  lines.surface_set_color(color)
  lines.surface_add_vertex(to_local(sk.to_global(point)))

func cross_mark(p:Vector3,radius:float,color:Color)->void:
 for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:line(p-axis*radius,p+axis*radius,color)

func draw_pose()->void:
 lines.clear_surfaces()
 lines.surface_begin(Mesh.PRIMITIVE_LINES)
 var has_lines:=false
 if draw.bone:
  for i in sk.get_bone_count():
   var parent:=sk.get_bone_parent(i)
   if parent<0:continue
   line(sk.get_bone_global_pose(parent).origin,sk.get_bone_global_pose(i).origin,COLORS.bone)
   has_lines=true
 if draw.com:
  var p:Vector3=solver.center_of_mass
  var floor_point:=Vector3(p.x,.012,p.z)
  cross_mark(p,.035,COLORS.com)
  cross_mark(floor_point,.04,COLORS.com)
  line(p,floor_point,COLORS.com)
  has_lines=true
 if draw.mass:
  for segment in solver.masses:cross_mark(segment.p,sqrt(segment.kg)*.011,COLORS.mass)
  has_lines=true
 if draw.ik:
  for hit in solver.contacts.values():
   var color:Color=COLORS.limit if hit.limited else COLORS.ik
   cross_mark(hit.target,.032,color)
   line(hit.target,hit.actual,color)
   line(hit.knee,hit.actual,color)
   has_lines=true
  if solver.enabled.arms:
   for i in 2:
    cross_mark(solver.arms.ik_goals[i],.031,COLORS.ik)
    line(solver.arms.ik_goals[i],solver.arms.actual_wrist[i],COLORS.ik)
   has_lines=true
 if draw.limit:
  var role:=selected.replace("arm_","upper_").replace("hip_","thigh_").replace("knee_","shin_").replace("ankle_","foot_")
  var p:=solver.pose(role).origin as Vector3
  var limit:=selected_limits().x
  var start:=0. if selected.begins_with("knee") or selected.begins_with("arm") else -limit
  for i in 15:
   var a:=deg_to_rad(lerpf(start,limit,float(i)/15.))
   var b:=deg_to_rad(lerpf(start,limit,float(i+1)/15.))
   line(p+Vector3.DOWN.rotated(Vector3.RIGHT,a)*.13,p+Vector3.DOWN.rotated(Vector3.RIGHT,b)*.13,COLORS.limit)
  has_lines=true
 if not has_lines:line(Vector3.ZERO,Vector3.ZERO,Color.TRANSPARENT)
 lines.surface_end()
