extends "res://mechanics/body_lab.gd"

var picker=preload("res://direct/surface_picker.gd").new()
var prefs=preload("res://direct/preferences.gd").new()
var fingers:Dictionary={} # índice do toque -> mãos controladas
var touches:Dictionary={} # mão -> triângulo, estado e intenção
var direct_active:=false
var options_panel:PopupPanel
var notice:=""
var touch_display:=false

func _ready()->void:
 super()
 picker.configure($Rose/Portrait,skeleton,[$Lollipop/Candy,$Lollipop/Stick])
 # O diagnóstico herdado e o perfil compartilham os mesmos valores.
 var controls:=diag.get_children().filter(func(node):return node is HSlider)
 var names:=["Rigidez","Amortecimento","Recuperação"]
 for j in controls.size():
  var key:String=names[j]
  controls[j].value=prefs.values[key]
  controls[j].value_changed.connect(func(v):prefs.values[key]=v)
 options_panel=prefs.panel(overlay)
 button(toolbar,"Ajustes",func():cancel_direct();options_panel.popup_centered_ratio(.8))
 button(toolbar,"Tecidos",func():get_tree().change_scene_to_file("res://direct/fabric.tscn"))
 select_tool(Tool.MULTI)
 touch_display=OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func label_for(hit:Dictionary)->String:
 var part:String=str(hit.surface.node.name)
 for garment in CLOTHES:
  if part in CLOTHES[garment]:return garment
 if part in ["Stick","Candy"]:return "Pirulito"
 if part!="Body":return "Perna E" if part=="Slipper" else ("Perna D" if part.begins_with("Slipper") else "Cabeça")
 var nearest:=""
 var distance:=INF
 for key in anchors:
  if CLOTHES.has(key) or key=="Pirulito":continue
  var d:float=hit.p.distance_squared_to(anchors[key])
  if d<distance:distance=d;nearest=key
 return nearest

func attach_touch(i:int,hit:Dictionary,pos:Vector2,mirrored:bool)->void:
 if links.has(i):release_grip(i)
 var binding={"hit":hit,"name":label_for(hit),"start":pos,"pos":pos,"base":hit.p,"normal":camera.global_basis.z,"delta":Vector3.ZERO,"age":0.,"eligible":true,"down":true,"mirror":mirrored,"offset":camera.unproject_position(hit.p)-pos}
 binding.detail=binding.name
 if hit.surface.node.name=="Dress" and hit.surface.surface_index==1:
  var idx:int=hit.surface.indices[hit.face]
  if hit.surface.vertices[idx].y>1.59:binding.detail="Alça da camisola"
 touches[i]=binding
 hands[i].enabled=true;hands[i].visible=true;hands[i].fade=1.;hands[i].scale=Vector3.ONE
 hands[i].pose_index=2
 place_hand(i,hit)
 hands[i].surface_sample={"region":binding.name,"surface":hit.p,"normal":hit.n,"force":.025}
 notice="Contato · "+binding.detail

func place_hand(i:int,sample_:Dictionary)->void:
 var h:Node3D=hands[i]
 var n:Vector3=sample_.n
 var tangent:=camera.global_basis.y.slide(n).normalized()
 if tangent.length_squared()<.01:tangent=camera.global_basis.x.slide(n).normalized()
 h.global_basis=Basis.looking_at(tangent.rotated(n,roll*float(h.side)),n).orthonormalized()
 h.global_position+=Vector3(sample_.p)+n*.002-h.tips[1].global_position
 h.desired=h.global_position

func begin_direct(id:int,pos:Vector2)->void:
 if fingers.has(id):return
 var i:=1 if tool==Tool.LEFT else 0
 if tool==Tool.MULTI:
  i=0 if pos.x>=overlay.size.x*.5 else 1
  for slot in [i,1-i]:
   if not touches.has(slot) or not touches[slot].down:i=slot;break
 if touches.has(i) and touches[i].down:return
 var hit:Dictionary=picker.cast(camera,pos,prefs.values["Tolerância (px)"])
 if hit.is_empty():notice="Sem superfície";return
 direct_active=true;active_hand=i;fingers[id]=[i]
 attach_touch(i,hit,pos,false)
 if tool==Tool.MIRROR:
  var local:Vector3=rose.to_local(hit.p)
  var center_x:float=(wrist("PalmL").x+wrist("PalmR").x)*.5 if str(touches[i].name).begins_with("Mão") else wrist("Spine").x
  local.x=2*center_x-local.x
  var other_pos:=camera.unproject_position(rose.to_global(local))
  var other:Dictionary=picker.cast(camera,other_pos,prefs.values["Tolerância (px)"])
  if other.is_empty():
   var source:String=touches[i].name
   if source.ends_with(" E") or source.ends_with(" D"):
    var opposite:=source.left(-1)+("E" if source.ends_with(" D") else "D")
    if anchors.has(opposite):
     other_pos=camera.unproject_position(anchors[opposite])
     other=picker.cast(camera,other_pos,prefs.values["Tolerância (px)"])
  if not other.is_empty():
   fingers[id].append(1-i);attach_touch(1-i,other,pos,true)

func move_direct(id:int,pos:Vector2)->void:
 for i in fingers.get(id,[]):
  if not touches.has(i):continue
  var g:Dictionary=touches[i]
  g.pos=pos
  if not links.has(i) and pos.distance_to(g.start)>prefs.values["Precisão do gesto (px)"]:g.eligible=false

func end_direct(id:int)->void:
 for i in fingers.get(id,[]):
  if not touches.has(i):continue
  if links.has(i):release_grip(i)
  touches[i].down=false
  notice="Solto · "+str(touches[i].detail)
 fingers.erase(id)

func cancel_direct()->void:
 for id in fingers.keys():end_direct(id)
 touches.clear();direct_active=false
 for hand in hands:
  hand.surface_sample={}
  hand.rotation=Vector3.ZERO
  hand.last_offsets.clear()
  hand.enabled=(mode==3 or (mode==1 and hand==hands[0]) or (mode==2 and hand==hands[1]))

func clear_input()->void:
 cancel_direct()
 super()

func _input(event:InputEvent)->void:
 if not is_node_ready():return
 if event is InputEventScreenTouch:
  touch_display=true
  if event.pressed and not event.canceled and garment_button.is_visible_in_tree() and garment_button.get_global_rect().has_point(event.position):
   clothing_action();get_viewport().set_input_as_handled();return
 if event is InputEventMouse and event.device!=InputEvent.DEVICE_ID_EMULATION:touch_display=false
 if event is InputEventMouse and event.device!=InputEvent.DEVICE_ID_EMULATION and direct_active:
  cancel_direct()
 if tool not in [Tool.CAMERA,Tool.CANDY]:
  if event is InputEventScreenTouch:
   if fingers.has(event.index) and (not event.pressed or event.canceled):
    end_direct(event.index);get_viewport().set_input_as_handled();return
   if event.pressed and not event.canceled and not blocked(event.position) and not (rail.visible and rail.get_global_rect().has_point(event.position)):
    begin_direct(event.index,event.position);get_viewport().set_input_as_handled();return
  if event is InputEventScreenDrag and fingers.has(event.index):
   move_direct(event.index,event.position);get_viewport().set_input_as_handled();return
 super(event)

func blocked(pos:Vector2)->bool:
 for row in [toolbar,footer]:
  for child in row.get_children():
   if child.is_visible_in_tree() and child.get_global_rect().has_point(pos):return true
 return menu.get_popup().visible or (diag.visible and diag.get_global_rect().has_point(pos))

func start_link(i:int,g:Dictionary)->void:
 var side:="L" if str(g.name).ends_with(" E") else "R"
 var arm:=side if str(g.name).begins_with("Mão") or str(g.name).begins_with("Antebraço") else ""
 for other in links.values():
  if (g.name=="Pirulito" and other.name=="Pirulito") or (arm!="" and other.arm==arm):
   g.eligible=false;notice="Alvo já conduzido pela outra mão";return
 if g.name=="Pirulito":
  if state==State.ATTACHED:_return_to_tray()
 links[i]={"name":g.name,"point":g.base,"cursor":g.base,"arm":arm,"wrist":wrist("Palm"+side),"stretch":Vector3.ZERO}
 g.object_origin=candy.global_position
 hands[i].pose_index=3
 notice="Vinculado · "+str(g.detail)

func follow_held(dt:float)->void:
 if not direct_active:super(dt);return
 for i in touches:
  var g:Dictionary=touches[i]
  if not g.down or not g.hit.surface.node.is_visible_in_tree():continue
  g.age+=dt
  if g.eligible and not links.has(i) and g.age>=prefs.values["Pressão longa (s)"]:start_link(i,g)
  if not links.has(i):continue
  var screen:Vector2=g.pos+g.offset
  if g.mirror:screen=camera.unproject_position(g.base)+(g.pos-g.start)
  var p:Variant=Plane(g.normal,g.base).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
  if p==null:continue
  var raw:Vector3=(p-Vector3(g.base))*float(prefs.values["Sensibilidade"])
  if g.mirror:raw.x=-raw.x
  var goal:=raw.limit_length(.40*float(prefs.values["Força máxima"]))*float(prefs.values["Elasticidade"])
  g.delta=Vector3(g.delta).lerp(goal,1-exp(-dt*float(prefs.values["Suavização"])))
  hands[i].desired=Vector3(g.base)+Vector3(g.delta)
  if g.name=="Pirulito":hands[i].global_position=Vector3(g.object_origin)+Vector3(g.delta)
 super(dt)

func _physics_process(dt:float)->void:
 for key in ["Rigidez","Amortecimento","Recuperação","Suavização"]:settings[key]=prefs.values[key]
 super(dt)
 if direct_active:
  reach_label.hide()
  for i in touches.keys():
   var g:Dictionary=touches[i]
   if not g.hit.surface.node.is_visible_in_tree():touches.erase(i);continue
   var tracked:Dictionary=picker.track(g.hit)
   place_hand(i,tracked)
   hands[i].surface_sample={"region":g.name if g.down else "","surface":tracked.p,"normal":tracked.n,"force":maxf(.025,force_readout[i]) if g.down else 0.}
   tags[i].position=camera.unproject_position(tracked.p)+Vector2(10,-18)
   tags[i].text=("● " if links.has(i) else "○ ")+str(g.detail)
   if links.has(i):
    tags[i].text+=" · %d%%"%roundi(force_readout[i]*100)
    if Vector3(g.delta).length()>=.38*float(prefs.values["Força máxima"])*float(prefs.values["Elasticidade"]):tags[i].text+=" · limite"
   tags[i].visible=prefs.indicators
  feedback.text=notice
  for i in range(2):
   if not touches.has(i):hands[i].enabled=false;hands[i].visible=false;tags[i].hide()
 else:
  tags[0].text="D";tags[1].text="E"
 var gesture_mode:=touch_display and tool not in [Tool.CANDY,Tool.CAMERA]
 grip_button.visible=not gesture_mode
 rail.visible=not gesture_mode and tool not in [Tool.CANDY,Tool.CAMERA]
 depth_label.visible=rail.visible
 if gesture_mode and not direct_active:
  for h in hands:h.visible=false
  for tag in tags:tag.hide()
  reach_label.hide()
  feedback.text="Toque na superfície. Mantenha para agarrar."
 feedback.visible=prefs.indicators
 if not prefs.indicators:
  reach_label.hide()
  for tag in tags:tag.hide()
