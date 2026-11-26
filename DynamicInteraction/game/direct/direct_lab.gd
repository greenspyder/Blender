extends "res://mechanics/body_lab.gd"

var picker=preload("res://direct/surface_picker.gd").new()
var prefs=preload("res://direct/preferences.gd").new()
const TouchDrag = preload("res://direct/touch_drag.gd")
const Grip = preload("res://direct/grip_physics.gd")
var input_drag := TouchDrag.new()
var prop_velocity := Vector3.ZERO
var prop_moving := false
var physics_readout := Label.new()
const Strap=preload("res://direct/strap.gd")
const GarmentPull=preload("res://direct/garment_pull.gd")
var garment:=GarmentPull.new()
var grab_mode := false
var fingers:Dictionary={} # índice do toque -> mãos controladas
var touches:Dictionary={} # mão -> triângulo, estado e intenção
var direct_active:=false
var options_panel:PopupPanel
var notice:=""
var touch_display:=false

func _ready()->void:
 super()
 picker.configure($Rose/Portrait,skeleton,[$Lollipop/Candy,$Lollipop/Stick])
 garment.name="Camisola_em_movimento"
 add_child(garment)
 garment.configure($Rose/Portrait,picker)
 garment.detached.connect(mark_dress_detached)
 garment.dressed.connect(mark_dress_worn)
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
 var interaction := OptionButton.new()
 interaction.add_item("Tocar")
 interaction.add_item("Agarrar")
 interaction.select(0)
 toolbar.add_child(interaction)
 toolbar.move_child(interaction,1)
 interaction.item_selected.connect(func(index):set_grab_mode(index==1))
 input_drag.add_debug(overlay,button(toolbar,"Debug toque",func():pass))
 button(toolbar,"Teste cubo",func():get_tree().change_scene_to_file("res://direct/drag_cube.tscn"))
 button(footer,"Física",func():physics_readout.visible=not physics_readout.visible)
 button(footer,"Bancada",func():get_tree().change_scene_to_file("res://direct/constraint_lab.tscn"))
 overlay.add_child(physics_readout)
 physics_readout.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 physics_readout.position+=Vector2(12,-345)
 physics_readout.mouse_filter=Control.MOUSE_FILTER_IGNORE
 physics_readout.hide()
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

func set_grab_mode(enabled:bool)->void:
 cancel_direct()
 grab_mode=enabled

func attach_touch(i:int, hit:Dictionary, pos:Vector2, mirrored:bool, initial:Vector3)->void:
 if links.has(i):release_grip(i)
 var normal:Vector3=hit.get("n",camera.global_basis.z)
 var binding={
  "hit":hit,"name":label_for(hit) if not hit.is_empty() else "",
  "start":pos,"base":initial,"plane":Plane(camera.global_basis.z,initial),
  "point":initial,"physical":initial,"anchor":initial,"normal":normal,"bind_normal":normal,"delta":Vector3.ZERO,"force":0.0,"down":true,"mirror":mirrored,
  "screen_origin":camera.unproject_position(initial),
 }
 binding.strap=Strap.contains_hit(hit)
 binding.pull=0.
 binding.detail="Alça da camisola" if binding.strap else binding.name
 touches[i]=binding
 hands[i].enabled=true
 hands[i].visible=true
 hands[i].fade=1.
 hands[i].scale=Vector3.ONE
 hands[i].pose_index=2
 place_hand(i,{"p":initial,"n":normal})
 update_contact(i,binding)
 notice="Contato · "+binding.detail if not binding.name.is_empty() else "Mão livre"
 if grab_mode:start_link(i,binding)

func update_contact(i:int,g:Dictionary)->void:
 var tracked:Dictionary={}
 if g.down and not g.hit.is_empty() and (garment.owns(i) or g.hit.surface.node.is_visible_in_tree()):
  if links.has(i):tracked={"p":g.anchor,"n":g.normal}
  elif not grab_mode and Vector3(g.point).distance_to(g.base)<.004:tracked=g.hit
 hands[i].surface_sample={
  "region":g.name if not tracked.is_empty() else "",
  "surface":tracked.get("p",g.point),"normal":tracked.get("n",g.normal),
  "force":maxf(.025,force_readout[i]) if not tracked.is_empty() else 0.,
 }

func place_hand(i:int,sample_:Dictionary)->void:
 var h:Node3D=hands[i]
 var n:Vector3=sample_.n
 var tangent:=camera.global_basis.y.slide(n).normalized()
 if tangent.length_squared()<.01:tangent=camera.global_basis.x.slide(n).normalized()
 h.global_basis=Basis.looking_at(tangent.rotated(n,roll*float(h.side)),n).orthonormalized()
 h.global_position+=Vector3(sample_.p)+n*.002-h.tips[1].global_position

func begin_direct(id:int,pos:Vector2)->bool:
 var i:=1 if tool==Tool.LEFT else 0
 if tool==Tool.MULTI:
  i=0 if pos.x>=overlay.size.x*.5 else 1
  for slot in [i,1-i]:
   if not touches.has(slot) or not touches[slot].down:i=slot;break
 if touches.has(i) and touches[i].down:
  input_drag.failure="A mão já está ocupada"
  return false
 var hit:Dictionary=picker.cast(camera,pos,prefs.values["Tolerância (px)"])
 if grab_mode and "Camisola" not in removed:hit=Strap.nearby(picker,camera,pos,hit)
 if hit.is_empty() and grab_mode:
  notice="Sem superfície para agarrar"
  input_drag.failure=notice
  return false
 var reference:Vector3=touches[i].physical if touches.has(i) else Vector3(0,pivot_y,0)
 var initial:Vector3=hit.get("p",TouchDrag.project(camera,Plane(camera.global_basis.z,reference),pos))
 direct_active=true
 active_hand=i
 fingers[id]=[i]
 attach_touch(i,hit,pos,false,initial)
 if tool==Tool.MIRROR:
  var local:Vector3=rose.to_local(initial)
  var center_x:float=(wrist("PalmL").x+wrist("PalmR").x)*.5 if str(touches[i].name).begins_with("Mão") else wrist("Spine").x
  local.x=2*center_x-local.x
  var mirrored:=rose.to_global(local)
  var other_pos:=camera.unproject_position(mirrored)
  var other:Dictionary=picker.cast(camera,other_pos,prefs.values["Tolerância (px)"])
  if other.is_empty():
   var source:String=touches[i].name
   if source.ends_with(" E") or source.ends_with(" D"):
    var opposite:=source.left(-1)+("E" if source.ends_with(" D") else "D")
    if anchors.has(opposite):
     other_pos=camera.unproject_position(anchors[opposite])
     other=picker.cast(camera,other_pos,prefs.values["Tolerância (px)"])
  if not other.is_empty() or not grab_mode:
   fingers[id].append(1-i)
   attach_touch(1-i,other,pos,true,other.get("p",mirrored))
 return true

func move_direct(id:int,pos:Vector2)->void:
 if fingers.has(id):active_hand=fingers[id][0]
 for i in fingers.get(id,[]):
  if not touches.has(i):continue
  var g:Dictionary=touches[i]
  var offset:Vector2=pos-g.start
  if g.mirror:offset.x=-offset.x
  var projected:Variant=TouchDrag.project(camera,g.plane,g.screen_origin+offset)
  if projected==null:
   input_drag.failure="Raio sem interseção com o plano"
   continue
  g.point=projected
  if g.strap and links.has(i) and not g.mirror:
   update_garment_pull(i,g,offset)
  if not links.has(i):
   g.physical=obstacle_motion(g.physical,g.point,.012)
   place_hand(i,{"p":g.physical,"n":g.normal})
   update_contact(i,g)

func update_garment_pull(i:int,g:Dictionary,offset:Vector2)->void:
 var travel:=clampf(overlay.size.y*.22,105.,180.)
 g.pull=clampf((-offset.y-10.)/travel,0.,1.)
 if g.pull>.06 and garment.state==GarmentPull.State.WORN:
  begin_garment(i,g.anchor)
 if not garment.owns(i):return
 garment.pull(g.pull,g.point)
 if garment.state==GarmentPull.State.HELD:
  notice="Camisola na mão · solte para largar"
 elif g.pull>=1.:
  notice="Camisola passando pelos ombros"
 else:
  notice="Puxe a alça para cima · %d%%"%roundi(g.pull*100.)

func begin_garment(slot:int,point:Vector3)->void:
 var direction:=signf(rose.to_local(point).x)
 if not garment.begin(slot,point,rose.global_basis,direction if direction!=0. else 1.):return
 for i in links.keys():
  if i!=slot and links[i].name=="Camisola":release_grip(i)

func mark_dress_detached()->void:
 if "Camisola" not in removed:removed.append("Camisola")
 sync_anchors()
 notice="Camisola na mão · solte para largar" if garment.held_slot>=0 else "Camisola solta · Recolocar para vestir"

func mark_dress_worn()->void:
 var was_removed:bool=removed.has("Camisola")
 removed.erase("Camisola")
 sync_anchors()
 notice="Camisola vestida" if was_removed else "Camisola voltou ao lugar"

func end_direct(id:int,_pos:Vector2,canceled:bool)->void:
 if fingers.has(id):active_hand=fingers[id][0]
 for i in fingers.get(id,[]):
  if not touches.has(i):continue
  var g:Dictionary=touches[i]
  if garment.owns(i):garment.release(canceled)
  if links.has(i):release_grip(i)
  g.down=false
  g.point=g.physical
  g.force=0.0
  update_contact(i,g)
  notice="Solta · Recolocar para vestir" if "Camisola" in removed else "Solto · "+str(g.detail)
 fingers.erase(id)

func clothing_action()->void:
 var link:Dictionary=links.get(active_hand,{})
 var garment_selected:bool=link.get("name","")=="Camisola"
 if "Camisola" in removed and (garment_selected or (not CLOTHES.has(link.get("name","")) and removed.back()=="Camisola")):
  var owner:=garment.held_slot
  if garment.redress():
   if owner>=0:release_grip(owner)
   notice="Recolocando a camisola"
   return
  if garment.state==GarmentPull.State.DRESSING or garment.state==GarmentPull.State.RETURNING:return
 if garment_selected:
  if garment.state==GarmentPull.State.WORN:begin_garment(active_hand,link.point)
  if garment.owns(active_hand):
   garment.pull(1.,garment.path(1.))
   garment.release(false)
   release_grip(active_hand)
  return
 super()

func cancel_direct()->void:
 for id in fingers.keys():end_direct(id,Vector2.ZERO,true)
 input_drag.captured.clear()
 touches.clear();direct_active=false
 prop_velocity=Vector3.ZERO
 prop_moving=false
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
  if event.pressed and not event.canceled and garment_button.is_visible_in_tree() and not garment_button.disabled and garment_button.get_global_rect().has_point(event.position):
   clothing_action();get_viewport().set_input_as_handled();return
 if event is InputEventMouse and event.device!=InputEvent.DEVICE_ID_EMULATION and fingers.is_empty():
  touch_display=false
  if direct_active:cancel_direct()
 if tool not in [Tool.CAMERA,Tool.CANDY] and (event is InputEventScreenTouch or event is InputEventScreenDrag):
  var can_start:=not blocked(event.position) if event is InputEventScreenTouch else false
  if input_drag.capture(event,can_start,begin_direct,move_direct,end_direct):
   get_viewport().set_input_as_handled()
   return
 super(event)

func reset_demo()->void:
 cancel_direct()
 garment.reset()
 super()

func blocked(pos:Vector2)->bool:
 for row in [toolbar,footer]:
  for child in row.get_children():
   if child.is_visible_in_tree() and child.get_global_rect().has_point(pos):return true
 return menu.get_popup().visible or (diag.visible and diag.get_global_rect().has_point(pos))

func start_link(i:int,g:Dictionary)->void:
 var side:="L" if str(g.name).ends_with(" E") else "R"
 var arm:=side if str(g.name).begins_with("Mão") or str(g.name).begins_with("Antebraço") else ""
 for other in links.values():
  if arm!="" and other.arm==arm:
   notice="Alvo já conduzido pela outra mão"
   input_drag.failure=notice
   return
 if g.name=="Pirulito":
  if state==State.ATTACHED:
   var world_pose:=candy.global_transform
   _return_to_tray()
   candy.global_transform=world_pose
 links[i]={"name":g.name,"point":g.base,"cursor":g.base,"arm":arm,"wrist":wrist("Palm"+side),"stretch":Vector3.ZERO}
 hands[i].pose_index=3
 notice="Alça agarrada · puxe para cima" if g.strap else "Vinculado · "+str(g.detail)

func follow_held(dt:float)->void:
 if not direct_active:
  super(dt)
  return
 var prop_goals: Array[Dictionary]=[]
 for i in touches:
  var g:Dictionary=touches[i]
  if not links.has(i):continue
  if garment.owns(i):
   var spring:=Grip.traction(g.point,garment.global_position,garment.velocity,prefs.values)
   g.force=spring.length()
   hands[i].desired=Vector3(g.base)+(spring/Grip.force_limit(prefs.values)*.045)
   continue
  if not g.hit.surface.node.is_visible_in_tree():
   release_grip(i)
   g.force=0.0
   input_drag.failure="A superfície ficou indisponível"
   continue
  if g.name=="Pirulito":
   prop_goals.append(g)
   continue
  var spring:=Grip.traction(g.point,g.anchor,Vector3.ZERO,prefs.values)
  g.force=spring.length()
  var goal:=spring/Grip.force_limit(prefs.values)*.31
  g.delta=Vector3(g.delta).lerp(goal,1-exp(-dt*float(prefs.values["Suavização"])))
  hands[i].desired=Vector3(g.base)+Vector3(g.delta)
 if not prop_goals.is_empty() or prop_moving:advance_prop(dt,prop_goals)
 for i in links:
  if links[i].name=="Pirulito":hands[i].global_position=candy.global_position
 super(dt)

func advance_prop(dt:float, goals:Array[Dictionary])->void:
 var offsets:Array[Vector3]=[]
 for g in goals:
  var sample:Dictionary=picker.track(g.hit)
  offsets.append(sample.p-candy.global_position)
 var remaining:=minf(dt,.05)
 while remaining>.00001:
  var h:=minf(remaining,Grip.STEP)
  var total:=Vector3.ZERO
  for i in goals.size():
   var spring:=Grip.traction(goals[i].point,candy.global_position+offsets[i],prop_velocity,prefs.values)
   goals[i].force=spring.length()
   total+=spring
  prop_velocity=Grip.drag_velocity(prop_velocity+total/float(prefs.values["Massa (kg)"])*h,h,prefs.values).limit_length(1.8)
  var start:=candy.global_position
  var dest:=(start+prop_velocity*h).clamp(Vector3(-1.15,.18,-.55),Vector3(1.15,2.24,.65))
  dest=obstacle_motion(start,dest,.036)
  prop_velocity=(dest-start)/h
  candy.global_position=dest
  remaining-=h
 prop_moving=prop_velocity.length()>.005

func obstacle_motion(start:Vector3,end:Vector3,radius:float)->Vector3:
 var hit:Dictionary=moving.sweep(start,end,radius)
 if hit.is_empty():return end
 var stop:=start.lerp(end,maxf(0.,float(hit.t)-.001))
 var slide:Vector3=(end-stop).slide(hit.normal)
 var next:Dictionary=moving.sweep(stop,stop+slide,radius)
 return stop+slide*(1. if next.is_empty() else maxf(0.,float(next.t)-.001))

func refresh_physical_hand(i:int,g:Dictionary)->void:
 if links.has(i):
  var tracked:Dictionary
  if garment.owns(i):
   tracked={"p":garment.global_position,"n":garment.global_basis*Vector3(g.bind_normal)}
  else:
   tracked=picker.track(g.hit)
  g.anchor=tracked.p
  g.physical=tracked.p
  g.normal=tracked.n
  force_readout[i]=float(g.force)/Grip.force_limit(prefs.values)
 place_hand(i,{"p":g.physical,"n":g.normal})
 update_contact(i,g)

func _physics_process(dt:float)->void:
 for key in ["Rigidez","Amortecimento","Recuperação","Suavização"]:settings[key]=prefs.values[key]
 garment.advance(minf(dt,.05))
 var lift:=Vector2(garment.arm_weight(false),garment.arm_weight(true))
 solver.wardrobe_lift=solver.wardrobe_lift.lerp(lift,1.-exp(-dt*16.))
 super(dt)
 if "Camisola" in removed and garment.state!=GarmentPull.State.WORN and links.get(active_hand,{}).get("name","") not in ["Short"]:
  garment_button.text="Recolocar"
  garment_button.disabled=garment.state in [GarmentPull.State.DRESSING,GarmentPull.State.RETURNING]
 if direct_active:
  reach_label.hide()
  for i in touches.keys():
   var g:Dictionary=touches[i]
   refresh_physical_hand(i,g)
   tags[i].position=camera.unproject_position(g.physical)+Vector2(10,-18)
   tags[i].text=("● " if links.has(i) else "○ ")+str(g.detail)
   if links.has(i):
    tags[i].text+=" · %d%%"%roundi(force_readout[i]*100)
    if float(g.force)>=.97*Grip.force_limit(prefs.values):tags[i].text+=" · limite"
   tags[i].visible=prefs.indicators and not g.detail.is_empty()
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
  feedback.text="Agarrar · toque em um alvo e arraste" if grab_mode else "Tocar · arraste a mão livremente"
 if physics_readout.visible:
  var g:Dictionary=touches.get(active_hand,{})
  if g.is_empty():
   physics_readout.text="Aguardando toque"
  else:
   var target:Vector3=g.point
   var actual:Vector3=g.physical
   physics_readout.text="Desejada %s\nEfetiva %s\nDiferença %.3f m · %.1f / %.1f N\n%s · Rigidez %.0f · Amort. %.2f" % [target,actual,target.distance_to(actual),g.force,Grip.force_limit(prefs.values),"Vinculado" if links.has(active_hand) else "Livre",prefs.values["Rigidez"],prefs.values["Amortecimento"]]
 input_drag.update_debug(hands[active_hand].tips[1].global_position,touches.get(active_hand,{}).get("detail",""),links.has(active_hand))
 feedback.visible=prefs.indicators
 if not prefs.indicators:
  reach_label.hide()
  for tag in tags:tag.hide()
