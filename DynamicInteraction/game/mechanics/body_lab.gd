extends "res://mobile/touch_lab.gd"

const MovingContact=preload("res://mechanics/moving_contact.gd")
const Posture=preload("res://mechanics/posture.gd")
const CLOTHES={"Camisola":["Dress","Ribbon"],"Short":["Shorts","PocketL","PocketR"]}
var moving=MovingContact.new()
var links:Dictionary={}
var anchors:Dictionary={}
var pull_velocity:=Vector3.ZERO
var force_readout:=[0.,0.]
var reach_label:=Label.new()
var diag:=VBoxContainer.new()
var details:=Label.new()
var garment_button:Button
var removed:Array=[]
var fabric_weights:Dictionary={}

func _ready()->void:
 super()
 solver=Posture.new()
 # O solver assume os braços; evite somar uma segunda resposta nas mesmas articulações.
 bindings=bindings.filter(func(binding):return binding[2] not in ["arm_l","arm_r"])
 for hand in hands:hand.posed_detector=moving
 for part in $Rose/Portrait.find_children("*","MeshInstance3D",true,false):
  var index:int=part.find_blend_shape_by_name("idle_knees")
  if index>=0:part.set_blend_shape_value(index,1)
  index=part.find_blend_shape_by_name("fabric_pull")
  if index>=0:fabric_weights[part]=index
 # Um painel comum dá ao mouse o mesmo botão de pegar usado no celular.
 set_mobile(true)
 button(toolbar,"Diagnóstico",func():diag.visible=not diag.visible)
 garment_button=button(footer,"Roupa",clothing_action)
 overlay.add_child(diag);diag.visible=false;diag.position=Vector2(12,116)
 diag.add_child(details)
 for name_ in ["Rigidez","Amortecimento","Recuperação"]:
  var slider:=HSlider.new()
  var title:=Label.new()
  diag.add_child(title);diag.add_child(slider);slider.custom_minimum_size=Vector2(180,30)
  slider.min_value=12 if name_=="Rigidez" else .5
  slider.max_value=100 if name_=="Rigidez" else 1.8
  slider.step=1 if name_=="Rigidez" else .05
  slider.value=settings[name_]
  title.text="%s %.2f"%[name_,slider.value]
  slider.value_changed.connect(func(v):settings[name_]=v;title.text="%s %.2f"%[name_,v])
 overlay.add_child(reach_label);reach_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 sync_anchors()

func _notification(what:int)->void:
 super(what)
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
  for i in links.keys():release_grip(i)

func blocked(pos:Vector2)->bool:
 return (diag.visible and diag.get_global_rect().has_point(pos)) or super(pos)

func _input(event:InputEvent)->void:
 if not is_node_ready():return
 if event is InputEventMouse and event.device!=InputEvent.DEVICE_ID_EMULATION:
  if event is InputEventMouseMotion and blocked(event.position) and not _orbiting:return
  if event is InputEventMouseMotion and not _orbiting and not blocked(event.position):
   hand_screen[active_hand]=event.position
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and not blocked(event.position) and not rail.get_global_rect().has_point(event.position) and mode!=0:
   pointer=event.position;hand_screen[active_hand]=event.position
   toggle_grip();get_viewport().set_input_as_handled();return
 super(event)

func change_mode(m:int)->void:
 for i in links.keys():release_grip(i)
 super(m)

func release_grip(i:int)->void:
 if links.has(i):
  var bone:String=links[i].get("arm","")
  if bone!="":set_reach_target(bone,null)
  links.erase(i);hands[i].pose_index=1;force_readout[i]=0
 super(i)

func sync_anchors()->void:
 anchors.clear()
 for zone in ["tronco","quadril","perna_E","perna_D","short","cabeca","manga_E","manga_D"]:
  if (zone=="short" and "Short" in removed) or (zone.begins_with("manga") and "Camisola" in removed):
   moving.zones.erase(zone)
   continue
  if not moving.zones.has(zone):moving.zones[zone]=Detector.ZONES[zone].duplicate()
  var neutral:Vector3=Detector.ZONES[zone][0]
  var bone_name:="Spine" if neutral.y>1.22 else "Base"
  if zone=="cabeca":bone_name="Head"
  var bone:=skeleton.find_bone(bone_name)
  moving.zones[zone][0]=(skeleton.get_bone_global_pose(bone)*skeleton.get_bone_global_rest(bone).affine_inverse())*neutral
 for side in ["L","R"]:
  var shoulder:=wrist("Upper"+side)
  var elbow:=wrist("Fore"+side)
  var palm:=wrist("Palm"+side)
  var suffix:="E" if side=="L" else "D"
  anchors["Mão "+suffix]=palm
  anchors["Antebraço "+suffix]=elbow.lerp(palm,.44)
  anchors["Ombro "+suffix]=shoulder
  moving.zones["ombro_"+suffix][0]=shoulder
  moving.zones["braco_"+suffix][0]=shoulder.lerp(elbow,.5)
  moving.zones["braco_"+suffix][1]=Vector3(.085,.16,.09)
  moving.zones["antebraco_"+suffix]=[elbow.lerp(palm,.5),Vector3(.067,.14,.07)]
  moving.zones["mao_"+suffix]=[palm,Vector3(.055,.075,.05)]
 anchors["Cabeça"]=wrist("Head")+Vector3(0,.20,.10)
 for pair in [["Tronco","tronco"],["Quadril","quadril"],["Perna E","perna_E"],["Perna D","perna_D"]]:
  anchors[pair[0]]=moving.zones[pair[1]][0]+Vector3(0,0,.09)
 if not "Camisola" in removed:anchors["Camisola"]=Vector3(.10,1.32,.13)+solver.body_load*.28
 if not "Short" in removed:anchors["Short"]=Vector3(-.12,1.02,.15)+solver.body_load*.28
 anchors["Pirulito"]=candy.global_position

func candidate(i:int)->String:
 var nearest:=""
 var best:=1.0
 var screen:Vector2=hand_screen.get(i,pointer) if touch_ui else pointer
 for name_ in anchors:
  var busy:=false
  for other in links.values():
   if other.name==name_:busy=true
  if busy:continue
  var p:Vector3=anchors[name_]
  var pixels:=camera.unproject_position(p).distance_to(screen)
  var distance:float=hands[i].global_position.distance_to(p)
  var score:=minf(distance/.145, pixels/39.0+minf(distance,.7)*.28)
  if score<best:
   best=score;nearest=name_
 return nearest

func toggle_grip()->void:
 if tool==Tool.CAMERA:return
 if mode==0:super();return
 var i:=active_hand
 if links.has(i):release_grip(i);return
 var name_:=candidate(i)
 if name_=="":hint_time=1.4;grip_message="Aproxime a mão ou aponte para uma região.";return
 var side:="L" if name_.ends_with(" E") else "R"
 var arm:=side if name_.begins_with("Mão") or name_.begins_with("Antebraço") else ""
 var start:Vector3=anchors[name_]
 links[i]={"name":name_,"point":start,"cursor":hands[i].desired,"arm":arm,"wrist":wrist("Palm"+side),"stretch":Vector3.ZERO}
 hands[i].pose_index=3
 if name_=="Pirulito" and state==State.ATTACHED:_return_to_tray()
 # Alinhar a profundidade ao ponto visado após seleção em 2D.
 var near_depth:=clampf(camera.global_basis.z.dot(start-Vector3(0,pivot_y,0)),-.31,.60)
 depth=near_depth;depth_by_hand[i]=near_depth;rail.set_value_no_signal(-near_depth)
 hand_screen[i]=camera.unproject_position(start);pointer=hand_screen[i]
 hands[i].desired=start;links[i].cursor=start

func clothing_action()->void:
 if links.has(active_hand):
  var garment:String=links[active_hand].name
  if CLOTHES.has(garment):
   take_off(garment)
   return
 if not removed.is_empty():show_garment(removed.pop_back(),true)

func take_off(garment:String)->void:
 if not CLOTHES.has(garment) or garment in removed:return
 for i in links.keys():
  if links[i].name==garment:release_grip(i)
 removed.append(garment)
 show_garment(garment,false)

func show_garment(name_:String,on:bool)->void:
 for mesh_name in CLOTHES[name_]:
  var obj=$Rose/Portrait.find_child(mesh_name,true,false)
  if obj:obj.visible=on
 sync_anchors()

func follow_held(dt:float)->void:
 var total:=Vector3.ZERO
 var cloth:={}
 for i in links:
  var link:Dictionary=links[i]
  var delta:Vector3=hands[i].desired-link.cursor
  var yield_:float=1./(1.+delta.length()*2.2)
  var stretch:Vector3=(delta*yield_).limit_length(.26)
  link.stretch=stretch;force_readout[i]=minf(1.,delta.length()*3.4)
  if link.name=="Pirulito":
   candy.global_position=hands[i].global_position;continue
  total+=stretch*(.48 if link.arm!="" else .85)
  if link.arm!="":set_reach_target(link.arm,link.wrist+stretch)
  if CLOTHES.has(link.name):cloth[link.name]=force_readout[i]
  # Prenda a mão visível ao ponto animado; a intenção livre continua em desired.
  hands[i].global_position=anchors.get(link.name,link.point)
 for part in fabric_weights:
  var garment:="Camisola" if str(part.name) in CLOTHES.Camisola else "Short"
  var idx:int=fabric_weights[part]
  part.set_blend_shape_value(idx,lerpf(part.get_blend_shape_value(idx),cloth.get(garment,0.),1-exp(-dt*9)))
 var k:float=settings["Rigidez"]*(settings["Recuperação"] if links.is_empty() else 1.)
 var t:=minf(dt,.1)
 while t>.00001:
  var h:=minf(t,1./120)
  pull_velocity+=((total.limit_length(.24)-solver.body_load)*k-pull_velocity*(2*sqrt(k)*settings["Amortecimento"]))*h
  solver.body_load+=pull_velocity*h;t-=h

func _physics_process(dt:float)->void:
 sync_anchors()
 solver.stiffness=settings["Rigidez"];solver.damping=settings["Amortecimento"];solver.recovery=settings["Recuperação"]
 super(dt)
 sync_anchors()
 if not garment_button:return
 var i:=active_hand
 var name_:String=links[i].name if links.has(i) else candidate(i)
 reach_label.visible=name_!="" and mode!=0 and tool!=Tool.CAMERA
 if reach_label.visible:
  reach_label.position=camera.unproject_position(anchors.get(name_,hands[i].global_position))+Vector2(12,8)
  reach_label.text=("Ligado · " if links.has(i) else "Agarrar · ")+name_
 grip_button.text="Soltar" if links.has(i) else ("Agarrar" if mode!=0 else grip_button.text)
 garment_button.text="Remover" if links.has(i) and CLOTHES.has(name_) else "Recolocar"
 garment_button.disabled=not (links.has(i) and CLOTHES.has(name_)) and removed.is_empty()
 if mode!=0 and tool!=Tool.CAMERA and not links.is_empty():
  var states:Array[String]=[]
  for index in links:states.append(("D" if index==0 else "E")+" · "+str(links[index].name))
  feedback.text="Vínculo ativo   "+"   |   ".join(states)
 if diag.visible:
  details.text="%s · %s\nD %.2f / E %.2f · IK ligado\nCotovelo E %.0f° %s / D %.0f° %s"%["Vinculado" if links.has(i) else "Livre",name_,force_readout[0],force_readout[1],solver.bend[0],"limite" if solver.limited[0] else "",solver.bend[1],"limite" if solver.limited[1] else ""]


func reset_demo()->void:
 for i in links.keys():release_grip(i)
 var worn_again:=removed.duplicate()
 removed.clear()
 for garment in worn_again:show_garment(garment,true)
 super()
