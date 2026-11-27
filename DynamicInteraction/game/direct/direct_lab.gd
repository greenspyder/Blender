extends "res://mechanics/body_lab.gd"

var picker=preload("res://direct/surface_picker.gd").new()
var prefs=preload("res://direct/preferences.gd").new()
const TouchDrag = preload("res://direct/touch_drag.gd")
const Grip = preload("res://direct/grip_physics.gd")
var input_drag := TouchDrag.new()
var prop_velocity := Vector3.ZERO
var prop_moving := false
var physics_readout := Label.new()
var meter=preload("res://direct/physics_meter.gd").new()
const COTTON=preload("res://direct/fabrics/light_cotton.tres")
const SoftTissue=preload("res://mechanics/soft_tissue.gd")
var tissue:=SoftTissue.new()
const HipSkin=preload("res://mechanics/hip_skin.gd")
const Strap=preload("res://direct/strap.gd")
const GarmentPull=preload("res://direct/garment_pull.gd")
var garment:=GarmentPull.new()
const ShortPull=preload("res://direct/short_pull.gd")
var shorts:=ShortPull.new()
var cloth_by_name:Dictionary={}
var grab_mode := false
var fingers:Dictionary={} # índice do toque -> mãos controladas
var touches:Dictionary={} # mão -> triângulo, estado e intenção
var direct_active:=false
var options_panel:PopupPanel
var notice:=""
var touch_display:=false
const ControlMode=preload("res://direct/control_mode.gd")
var control_mode:=ControlMode.new()
var control_menu:=OptionButton.new()
var interaction:=OptionButton.new()
var desktop_cursor:=Vector2.ZERO
var mouse_touch_down:=false
var desktop_slider_active:=false


func _ready()->void:
 get_window().title="Rosé 1.3.3.1"
 super()
 HipSkin.correct($Rose/Portrait.find_child("Body",true,false))
 tissue.setup($Rose/Portrait)
 tone_clothing_materials()
 picker.configure($Rose/Portrait,skeleton,[$Lollipop/Candy,$Lollipop/Stick])
 garment.name="Camisola_em_movimento"
 shorts.name="Short_em_movimento"
 cloth_by_name={"Camisola":garment,"Short":shorts}
 for piece in cloth_by_name:
  var cloth=cloth_by_name[piece]
  add_child(cloth)
  cloth.configure($Rose/Portrait,picker)
  cloth.detached.connect(mark_cloth_detached.bind(piece))
  cloth.dressed.connect(mark_cloth_worn.bind(piece))
 # O diagnóstico herdado e o perfil compartilham os mesmos valores.
 var controls:=diag.get_children().filter(func(node):return node is HSlider)
 var names:=["Rigidez","Amortecimento","Recuperação"]
 for j in controls.size():
  var key:String=names[j]
  controls[j].value=prefs.values[key]
  controls[j].value_changed.connect(func(v):prefs.set_value(key,v))
  var slider:HSlider=controls[j]
  var caption:Label=diag.get_child(slider.get_index()-1)
  prefs.profile_changed.connect(func():
   slider.set_value_no_signal(prefs.values[key])
   caption.text="%s %.2f"%[key,prefs.values[key]])
 options_panel=prefs.panel(overlay)
 button(toolbar,"Ajustes",func():cancel_direct();options_panel.popup_centered_ratio(.8))
 button(toolbar,"Tecidos",func():get_tree().change_scene_to_file("res://direct/fabric.tscn"))
 interaction.add_item("Tocar")
 interaction.add_item("Agarrar")
 interaction.select(0)
 toolbar.add_child(interaction)
 toolbar.move_child(interaction,1)
 interaction.item_selected.connect(func(index):set_grab_mode(index==1))
 input_drag.add_debug(overlay,button(toolbar,"Debug toque",func():pass))
 button(toolbar,"Teste cubo",func():get_tree().change_scene_to_file("res://direct/drag_cube.tscn"))
 meter.attach(overlay,Vector2.ZERO)
 meter.caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 meter.caption.position+=Vector2(12,-385)
 meter.caption.hide()
 button(footer,"Física",func():
  physics_readout.visible=not physics_readout.visible
  meter.caption.visible=physics_readout.visible)
 button(footer,"Bancada",func():get_tree().change_scene_to_file("res://direct/constraint_lab.tscn"))
 var ragdoll_button:=button(footer,"Active Ragdoll",func():
  get_tree().change_scene_to_file("res://rig/active/lab.tscn"))
 footer.move_child(ragdoll_button,0)
 overlay.add_child(physics_readout)
 physics_readout.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 physics_readout.position+=Vector2(12,-345)
 physics_readout.mouse_filter=Control.MOUSE_FILTER_IGNORE
 physics_readout.hide()
 for label in ["Automático","Desktop","Touchscreen"]:control_menu.add_item(label)
 control_menu.custom_minimum_size=Vector2(140,48)
 toolbar.add_child(control_menu)
 toolbar.move_child(control_menu,1)
 control_menu.item_selected.connect(set_control_mode)
 for control in footer.get_children():
  if control.has_meta("rotation"):
   var amount:float=control.get_meta("rotation")
   control.pressed.connect(func():roll=clampf(roll+amount*.10,-1.5,1.5))
 rail.drag_started.connect(func():desktop_slider_active=not touch_display)
 rail.drag_ended.connect(func(_changed):desktop_slider_active=false)
 footer.resized.connect(position_footer)
 select_tool(Tool.MULTI)
 desktop_cursor=pointer
 set_control_mode(control_mode.choice,false)

func tone_clothing_materials()->void:
 for group in CLOTHES.values():
  for part in group:
   var mesh:MeshInstance3D=$Rose/Portrait.find_child(part,true,false)
   if not mesh:continue
   for surface in mesh.mesh.get_surface_count():
    var original:Material=mesh.get_active_material(surface)
    if original is StandardMaterial3D:
     var cotton:StandardMaterial3D=original.duplicate()
     COTTON.apply_material(cotton)
     mesh.set_surface_override_material(surface,cotton)

func set_control_mode(choice:int,persist:=true)->void:
 if choice not in [ControlMode.Mode.AUTO,ControlMode.Mode.DESKTOP,ControlMode.Mode.TOUCHSCREEN]:return
 clear_input()
 _orbiting=false
 control_mode.choice=choice
 var mobile_host:=OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
 touch_display=ControlMode.touchscreen(choice,mobile_host)
 control_menu.set_item_text(ControlMode.Mode.AUTO,"Auto · "+("Touchscreen" if mobile_host else "Desktop"))
 control_menu.select(choice)
 control_menu.tooltip_text="Modo ativo: "+("Touchscreen" if touch_display else "Desktop")
 interaction.visible=touch_display
 resize_canvas()
 if persist and control_mode.save()!=OK:notice="Modo aplicado nesta sessão"
 refresh()

func resize_canvas()->void:
 if not touch_ui:return
 if touch_display:
  super()
 else:
  get_window().content_scale_size=Vector2i(960,720)

func layout()->void:
 super()
 position_footer()

func position_footer()->void:
 footer.position.y=overlay.size.y-maxf(68.,footer.get_combined_minimum_size().y+16.)
 feedback.position.y=footer.position.y-57.

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

func attach_touch(i:int,hit:Dictionary,pos:Vector2,mirrored:bool,initial:Vector3,should_grip:bool,from_mouse:bool)->void:
 if links.has(i):release_grip(i)
 var normal:Vector3=hit.get("n",camera.global_basis.z)
 var binding={
  "hit":hit,"name":label_for(hit) if not hit.is_empty() else "",
  "start":pos,"base":initial,"plane":Plane(camera.global_basis.z,initial),
  "point":initial,"physical":initial,"anchor":initial,"normal":normal,"bind_normal":normal,"force":0.0,"down":true,"mirror":mirrored,
  "screen_origin":camera.unproject_position(initial),
  "desktop":from_mouse,"depth_origin":depth_by_hand[i],"pull_pixels":0.,"pull_bias":0.,
 }
 binding.strap=Strap.contains_hit(hit)
 binding.waist=ShortPull.contains_hit(hit)
 binding.tissue=-1 if binding.strap or binding.waist else tissue.region_for_hit(hit)
 binding.pull=0.
 if binding.strap:binding.detail="Alça da camisola"
 elif binding.waist:binding.detail="Cós do short"
 elif binding.tissue>=0:binding.detail=SoftTissue.NAMES[binding.tissue]
 else:binding.detail=binding.name
 touches[i]=binding
 hands[i].enabled=true
 hands[i].visible=true
 hands[i].fade=1.
 hands[i].scale=Vector3.ONE
 hands[i].pose_index=2
 place_hand(i,{"p":initial,"n":normal})
 update_contact(i,binding)
 notice="Contato · "+binding.detail if not binding.name.is_empty() else "Mão livre"
 if should_grip:start_link(i,binding)

func update_contact(i:int,g:Dictionary)->void:
 var tracked:Dictionary={}
 if g.down and not g.hit.is_empty() and (cloth_owned(i)!=null or g.hit.surface.node.is_visible_in_tree()):
  if links.has(i):tracked={"p":g.anchor,"n":g.normal}
  elif not g.desktop and not grab_mode and Vector3(g.point).distance_to(g.base)<.004:tracked=g.hit
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
 return begin_gesture(id,pos,grab_mode,false)

func begin_gesture(id:int,pos:Vector2,should_grip:bool,from_mouse:bool)->bool:
 meter.register_input()
 var i:=1 if tool==Tool.LEFT else 0
 if tool==Tool.MULTI:
  i=active_hand if from_mouse else (0 if pos.x>=overlay.size.x*.5 else 1)
  if not from_mouse:
   for slot in [i,1-i]:
    if not touches.has(slot) or not touches[slot].down:i=slot;break
 if touches.has(i) and touches[i].down:
  input_drag.failure="A mão já está ocupada"
  return false
 var query:Array=picker.prepare_query()
 var hit:Dictionary=picker.cast(camera,pos,prefs.values["Tolerância (px)"],query)
 if should_grip and "Camisola" not in removed:hit=Strap.nearby(picker,camera,pos,hit,query)
 if hit.is_empty() and should_grip:
  notice="Sem superfície para agarrar"
  input_drag.failure=notice
  return false
 var reference:Vector3=touches[i].physical if touches.has(i) else Vector3(0,pivot_y,0)
 var initial:Vector3=hit.get("p",TouchDrag.project(camera,Plane(camera.global_basis.z,reference),pos))
 direct_active=true
 active_hand=i
 fingers[id]=[i]
 attach_touch(i,hit,pos,false,initial,should_grip,from_mouse)
 if tool==Tool.MIRROR:
  var local:Vector3=rose.to_local(initial)
  var center_x:float=(wrist("PalmL").x+wrist("PalmR").x)*.5 if str(touches[i].name).begins_with("Mão") else wrist("Spine").x
  local.x=2*center_x-local.x
  var mirrored:=rose.to_global(local)
  var other_pos:=camera.unproject_position(mirrored)
  var other:Dictionary=picker.cast(camera,other_pos,prefs.values["Tolerância (px)"],picker.prepare_query())
  if other.is_empty():
   var source:String=touches[i].name
   if source.ends_with(" E") or source.ends_with(" D"):
    var opposite:=source.left(-1)+("E" if source.ends_with(" D") else "D")
    if anchors.has(opposite):
     other_pos=camera.unproject_position(anchors[opposite])
     other=picker.cast(camera,other_pos,prefs.values["Tolerância (px)"],picker.prepare_query())
  if not other.is_empty() or not should_grip:
   fingers[id].append(1-i)
   attach_touch(1-i,other,pos,true,other.get("p",mirrored),should_grip,from_mouse)
 return true

func move_direct(id:int,pos:Vector2)->void:
 meter.register_input()
 if fingers.has(id):active_hand=fingers[id][0]
 for i in fingers.get(id,[]):
  if not touches.has(i):continue
  var g:Dictionary=touches[i]
  var offset:Vector2=pos-g.start
  if g.mirror:offset.x=-offset.x
  var plane:Plane=g.plane
  if g.desktop:plane.d+=float(depth_by_hand[i])-float(g.depth_origin)
  var projected:Variant=TouchDrag.project(camera,plane,g.screen_origin+offset)
  if projected==null:
   input_drag.failure="Raio sem interseção com o plano"
   continue
  g.point=projected
  if links.has(i) and not g.mirror and (g.strap or g.waist):
   g.pull_pixels=(offset.y if g.waist else -offset.y)+float(g.pull_bias)
   update_garment_pull(i,g)
  if not links.has(i):
   g.physical=obstacle_motion(g.physical,g.point,.012)
   place_hand(i,{"p":g.physical,"n":g.normal})
   update_contact(i,g)

func cloth_owned(slot:int):
 for piece in cloth_by_name.values():
  if piece.owns(slot):return piece
 return null

func update_garment_pull(i:int,g:Dictionary)->void:
 var piece:String=g.name
 var cloth=cloth_by_name[piece]
 var travel:=clampf(overlay.size.y*(.28 if g.waist else .22),105.,220. if g.waist else 180.)
 g.pull=clampf((float(g.pull_pixels)-10.)/travel,0.,1.)
 if g.pull>.06 and cloth.state==GarmentPull.State.WORN:begin_garment(piece,i,g.anchor)
 if not cloth.owns(i):return
 cloth.pull(g.pull,g.point)
 if cloth.state==GarmentPull.State.HELD:
  notice="Short na mão · solte para largar" if g.waist else "Camisola na mão · solte para largar"
 elif g.pull>=1.:
  notice="Aguarde o tecido passar pelos pés" if g.waist else "Aguarde o tecido passar pelos ombros"
 else:
  var instruction:="Puxe o cós para baixo" if g.waist else "Puxe a alça para cima"
  notice="%s · %d%%"%[instruction,roundi(g.pull*100.)]

func begin_garment(piece:String,slot:int,point:Vector3)->void:
 var cloth=cloth_by_name[piece]
 if cloth==shorts:shorts.rig_origin=rose.global_position
 var direction:=signf(rose.to_local(point).x)
 if not cloth.begin(slot,point,rose.global_basis,direction if direction!=0. else 1.):return
 for i in links.keys():
  if i!=slot and links[i].name==piece:release_grip(i)

func mark_cloth_detached(piece:String)->void:
 if piece not in removed:removed.append(piece)
 sync_anchors()
 notice=piece+" na mão · solte para largar" if cloth_by_name[piece].held_slot>=0 else piece+" solto · Recolocar para vestir"

func mark_cloth_worn(piece:String)->void:
 var was_removed:=removed.has(piece)
 removed.erase(piece)
 sync_anchors()
 notice=piece+" no lugar" if was_removed else "A peça voltou ao lugar"

func end_direct(id:int,_pos:Vector2,canceled:bool)->void:
 if fingers.has(id):active_hand=fingers[id][0]
 for i in fingers.get(id,[]):
  if not touches.has(i):continue
  var g:Dictionary=touches[i]
  var cloth=cloth_owned(i)
  if cloth!=null:cloth.release(canceled)
  if links.has(i):release_grip(i)
  g.down=false
  g.point=g.physical
  g.force=0.0
  update_contact(i,g)
  notice="Solto · "+str(g.detail) if removed.is_empty() else "Solto · Recolocar para vestir"
 fingers.erase(id)

func clothing_action()->void:
 var link:Dictionary=links.get(active_hand,{})
 var selected:String=link.get("name","")
 if not cloth_by_name.has(selected):
  if removed.is_empty():return
  selected=removed.back()
 var cloth=cloth_by_name[selected]
 if selected in removed:
  var slot:int=cloth.held_slot
  if cloth.redress():
   if slot>=0:release_grip(slot)
   notice="Recolocando · "+selected
  return
 if cloth.state==GarmentPull.State.WORN:begin_garment(selected,active_hand,link.point)
 if cloth.owns(active_hand):
  cloth.finish_with_button()
  release_grip(active_hand)

func cancel_direct()->void:
 for id in fingers.keys():end_direct(id,Vector2.ZERO,true)
 input_drag.captured.clear()
 mouse_touch_down=false
 desktop_slider_active=false
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
 if event is InputEventScreenTouch or event is InputEventScreenDrag:
  if touch_display:route_touch(event)
  return
 if event is InputEventMouse:
  if event.device==InputEvent.DEVICE_ID_EMULATION:return
  if touch_display:
   route_mouse_as_touch(event)
   return
  if tool!=Tool.CANDY:
   if route_desktop(event):get_viewport().set_input_as_handled()
   return
 super(event)

func route_touch(event:InputEvent)->void:
 if event is InputEventScreenTouch and event.pressed and not event.canceled:
  if garment_button.is_visible_in_tree() and not garment_button.disabled and garment_button.get_global_rect().has_point(event.position):
   clothing_action()
   get_viewport().set_input_as_handled()
   return
 if tool not in [Tool.CAMERA,Tool.CANDY]:
  var can_start:=not blocked(event.position) if event is InputEventScreenTouch else false
  if input_drag.capture(event,can_start,begin_direct,move_direct,end_direct):
   get_viewport().set_input_as_handled()
   return
 super._input(event)

func route_mouse_as_touch(event:InputEventMouse)->void:
 # Um mouse pode testar o layout touchscreen no PC. A interface ainda recebe
 # os eventos normais, e um toque emulado pelo sistema é filtrado em _input.
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   if blocked(event.position):return
   mouse_touch_down=true
  elif not mouse_touch_down:return
  else:mouse_touch_down=false
  var touch:=InputEventScreenTouch.new()
  touch.index=ControlMode.MOUSE_TOUCH_ID
  touch.position=event.position
  touch.pressed=event.pressed
  route_touch(touch)
 elif event is InputEventMouseMotion and mouse_touch_down:
  var drag:=InputEventScreenDrag.new()
  drag.index=ControlMode.MOUSE_TOUCH_ID
  drag.position=event.position
  drag.relative=event.relative
  route_touch(drag)

func desktop_id()->int:
 return ControlMode.MOUSE_GRIP_ID-active_hand if tool==Tool.MULTI else ControlMode.MOUSE_GRIP_ID

func toggle_grip()->void:
 if touch_display or tool in [Tool.CANDY,Tool.CAMERA]:
  super()
  return
 var id:=desktop_id()
 if fingers.has(id):
  var slots:Array=fingers[id].duplicate()
  end_direct(id,desktop_cursor,false)
  for i in slots:
   touches.erase(i)
   hands[i].surface_sample={}
  direct_active=not fingers.is_empty()
 else:
  begin_gesture(id,desktop_cursor,true,true)

func route_desktop(event:InputEventMouse)->bool:
 var on_ui:=blocked(event.position) or (rail.visible and rail.get_global_rect().has_point(event.position))
 if event is InputEventMouseButton:
  if not on_ui:desktop_cursor=event.position
  if event.button_index==MOUSE_BUTTON_RIGHT:
   if not event.pressed or not on_ui:_orbiting=event.pressed
   return true
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   if on_ui:return false
   zoom_size=clampf(zoom_size*(.88 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.14),.43,3.4)
   update_camera()
   rebase_desktop_grips()
   return true
  if event.pressed and event.button_index==MOUSE_BUTTON_LEFT and tool!=Tool.CAMERA and not on_ui:
   toggle_grip()
   return true
  return false
 if event is InputEventMouseMotion:
  if _orbiting:
   desktop_cursor=event.position
   yaw-=event.relative.x*.006
   pitch=clampf(pitch+event.relative.y*.005,-1.05,1.05)
   update_camera()
   rebase_desktop_grips()
   return true
  if desktop_slider_active:return false
  if fingers.has(desktop_id()):
   desktop_cursor=event.position
   move_direct(desktop_id(),desktop_cursor)
  elif not on_ui and tool!=Tool.CAMERA:
   desktop_cursor=event.position
   move_hand(active_hand,desktop_cursor)
  return not on_ui
 return false

func rebase_desktop_grips()->void:
 for i in touches:
  var g:Dictionary=touches[i]
  if not g.desktop or not g.down:continue
  var point:Vector3=g.point
  g.plane=Plane(camera.global_basis.z,point)
  g.screen_origin=camera.unproject_position(point)
  g.start=desktop_cursor
  g.pull_bias=g.pull_pixels
  g.depth_origin=depth_by_hand[i]
  # A segunda mão espelhada aplica seu deslocamento a partir da nova projeção.

func apply_keyboard(dt:float)->void:
 if touch_display:return
 var depth_before:=depth
 var pivot_before:=pivot_y
 super(dt)
 if not is_equal_approx(depth,depth_before):apply_desktop_depth(depth)
 if not is_equal_approx(pivot_y,pivot_before):
  update_camera()
  rebase_desktop_grips()

func adjust_depth(value:float)->void:
 if touch_display:super(value)
 else:apply_desktop_depth(-value)

func apply_desktop_depth(value:float)->void:
 depth=value
 depth_by_hand[active_hand]=value
 if tool==Tool.MIRROR:depth_by_hand[1-active_hand]=value
 rail.set_value_no_signal(-value)
 if fingers.has(desktop_id()):move_direct(desktop_id(),desktop_cursor)
 if tool==Tool.MULTI:set_hand_target(active_hand,hand_world(active_hand))

func _unhandled_input(event:InputEvent)->void:
 if event is InputEventMouse:
  if event.device==InputEvent.DEVICE_ID_EMULATION or touch_display or tool!=Tool.CANDY:return
 super(event)

func reset_demo()->void:
 cancel_direct()
 garment.reset()
 shorts.reset()
 tissue.reset()
 super()
 depth_by_hand=[.31,.31]
 rail.set_value_no_signal(-depth)

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
 if g.strap:notice="Alça agarrada · puxe para cima"
 elif g.waist:notice="Cós agarrado · puxe para baixo"
 else:notice="Vinculado · "+str(g.detail)

func follow_held(dt:float)->void:
 if not direct_active:
  super(dt)
  return
 var prop_goals: Array[Dictionary]=[]
 for i in touches:
  var g:Dictionary=touches[i]
  if not links.has(i):continue
  var cloth=cloth_owned(i)
  if cloth!=null:
   var spring:=Grip.traction(g.point,cloth.global_position,cloth.velocity,prefs.values)
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
  hands[i].desired=g.point
 if not prop_goals.is_empty() or prop_moving:advance_prop(dt,prop_goals)
 for i in links:
  if links[i].name=="Pirulito":hands[i].global_position=candy.global_position
 super(dt)

func arm_reach_target(slot:int,link:Dictionary,stretch:Vector3)->Vector3:
 if not direct_active or not touches.has(slot):
  return super(slot,link,stretch)
 var touch:Dictionary=touches[slot]
 # O ponto agarrado fica sobre a superfície da palma. Use o deslocamento
 # em relação ao começo do gesto para manter esse mesmo ponto de pega.
 var displacement:Vector3=(touch.point-touch.base)*float(prefs.values["Sensibilidade"])
 return skeleton.to_local(Vector3(link.wrist)+displacement)

func grip_stretch(slot:int,delta:Vector3)->Vector3:
 if not direct_active or not touches.has(slot) or cloth_owned(slot)!=null:
  return super(slot,delta)
 return Grip.body_stretch(delta,prefs.values)

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
  prop_velocity=((prop_velocity+total/float(prefs.values["Massa (kg)"])*h)*Grip.friction_factor(h,prefs.values,not goals.is_empty())).limit_length(1.8)
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
  var cloth=cloth_owned(i)
  if cloth!=null:
   tracked={"p":cloth.global_position,"n":cloth.global_basis*Vector3(g.bind_normal)}
  else:
   tracked=picker.track(g.hit)
  g.anchor=tracked.p
  g.physical=tracked.p
  g.normal=tracked.n
  force_readout[i]=float(g.force)/Grip.force_limit(prefs.values)
 place_hand(i,{"p":g.physical,"n":g.normal})
 update_contact(i,g)

func update_garment_collisions()->void:
 if garment.state in [GarmentPull.State.WORN,GarmentPull.State.RESTING]:return
 garment.obstacles=[
  [wrist("Spine")+Vector3(0,.15,-.012),Vector3(.195,.24,.13)],
  [wrist("Head")+Vector3(0,.235,-.005),Vector3(.193,.23,.161)],
  [wrist("UpperL"),Vector3(.073,.087,.067)],
  [wrist("UpperR"),Vector3(.073,.087,.067)],
 ]

func update_short_collisions()->void:
 if shorts.state in [GarmentPull.State.WORN,GarmentPull.State.RESTING]:return
 shorts.obstacles=[]
 var base_xy:=wrist("Base")
 for x in [-.137,.137]:
  for height in [.32,.63]:
   var p:=rose.to_global(Vector3(x,height,-.035))
   p.x+=base_xy.x-rose.global_position.x
   p.z+=base_xy.z-rose.global_position.z
   shorts.obstacles.append([p,Vector3(.096,.23,.109)])
  shorts.obstacles.append([rose.to_global(Vector3(x,.09,.026)),Vector3(.105,.091,.147)])

func _physics_process(dt:float)->void:
 var t:=meter.begin_tick()
 for key in ["Amortecimento","Recuperação","Suavização"]:settings[key]=prefs.values[key]
 settings["Rigidez"]=Grip.pose_stiffness(prefs.values)
 update_garment_collisions()
 update_short_collisions()
 garment.advance(minf(dt,.05))
 shorts.advance(minf(dt,.05))
 var lift:=Vector2(garment.arm_weight(false),garment.arm_weight(true))
 solver.wardrobe_lift=solver.wardrobe_lift.lerp(lift,1.-exp(-dt*16.))
 super(dt)
 tissue.advance(dt,skeleton,touches,links)
 var active_piece:String=links.get(active_hand,{}).get("name","")
 if not cloth_by_name.has(active_piece) and not removed.is_empty():active_piece=removed.back()
 if active_piece in removed:
  garment_button.text="Recolocar"
  garment_button.disabled=cloth_by_name[active_piece].state in [GarmentPull.State.DRESSING,GarmentPull.State.RETURNING]
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
   if not touches.has(i) and touch_display: hands[i].enabled=false;hands[i].visible=false;tags[i].hide()
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
 if not touch_display and not direct_active and tool not in [Tool.CANDY,Tool.CAMERA]:
  feedback.text="Clique para pegar/soltar · W/S profundidade · Q/E rotação · direito orbita · roda aproxima"
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
 meter.end_tick(t)
