extends "res://precision/lab.gd"

enum Tool { CANDY, RIGHT, LEFT, MIRROR, MULTI, CAMERA }
const GRAB_DISTANCE := 0.165
var tool := Tool.RIGHT
var owners := {}
var points := {}
var hand_screen := {}
var held := {} # índice da mão -> "PalmL", "PalmR" ou "candy"
var active_hand := 0
var grip_message := ""
var hint_time := 0.0
var touch_ui := false
var overlay := Control.new()
var toolbar := HFlowContainer.new()
var footer := HFlowContainer.new()
var feedback := Label.new()
var rail := VSlider.new()
var side_button: Button
var depth_label := Label.new()
var grip_button: Button
var menu := OptionButton.new()
var depth_by_hand := [.31,.31]
var rotation_owner := {}
var last_tool := Tool.RIGHT
var tags := []

func _ready() -> void:
 super()
 touch_ui = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
 $HUD.add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for node in [toolbar,footer,feedback,rail,depth_label]:
  overlay.add_child(node)
 for row in [toolbar,footer]:
  row.mouse_filter=Control.MOUSE_FILTER_IGNORE
  row.add_theme_constant_override("h_separation",8)
 menu.custom_minimum_size=Vector2(175,48)
 for name_ in ["Pirulito","Mão direita","Mão esquerda","Par espelhado","Duas independentes"]:
  menu.add_item(name_)
 toolbar.add_child(menu)
 menu.item_selected.connect(select_tool)
 side_button=button(toolbar,"D / E",switch_hand)
 button(toolbar,"Câmera",camera_mode)
 button(toolbar,"Reiniciar",mobile_reset)
 grip_button=button(footer,"Agarrar",toggle_grip)
 for title in ["Girar −","Girar +"]:
  var btn:=button(footer,title,func():pass)
  btn.set_meta("rotation", -1 if title=="Girar −" else 1)
 rail.min_value=-.60;rail.max_value=.31;rail.step=.005
 rail.value_changed.connect(adjust_depth)
 depth_label.text="Perto";depth_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 feedback.mouse_filter=Control.MOUSE_FILTER_IGNORE
 feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 for tag in ["D","E"]:
  var label:=Label.new()
  label.text=tag
  label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  overlay.add_child(label);tags.append(label)
 overlay.resized.connect(layout)
 get_window().size_changed.connect(resize_canvas)
 set_mobile(touch_ui)
 layout()

func button(row:Control,title:String,callback:Callable)->Button:
 var btn:=Button.new()
 btn.text=title;btn.custom_minimum_size=Vector2(96,50)
 row.add_child(btn);btn.pressed.connect(callback)
 return btn

func resize_canvas()->void:
 if not touch_ui:return
 var window:=get_window()
 var target:=Vector2i(580,850) if window.size.y>window.size.x else Vector2i(900,510)
 if window.content_scale_size!=target:window.content_scale_size=target

func layout()->void:
 var size_:=overlay.size
 toolbar.position=Vector2(12,10);toolbar.size.x=maxf(180,size_.x-24)
 footer.position=Vector2(12,size_.y-68);footer.size.x=maxf(180,size_.x-24)
 rail.position=Vector2(size_.x-66,maxf(105,size_.y*.26))
 rail.size=Vector2(52,maxf(86,size_.y*.38))
 depth_label.position=rail.position-Vector2(0,32)
 feedback.position=Vector2(14,footer.position.y-57);feedback.size=Vector2(size_.x-28,55)

func set_mobile(on:bool)->void:
 touch_ui=on;overlay.visible=on
 resize_canvas()
 $HUD/Top.visible=not on;$HUD/Bottom.visible=not on
 if on:select_tool(Tool.RIGHT)

func clear_input()->void:
 owners.clear();points.clear();rotation_owner.clear()
 if state==State.DRAGGING:_return_to_tray()

func release_grip(i:int)->void:
 if not held.has(i):return
 var item:String=held[i]
 held.erase(i)
 if item=="candy":_return_to_tray()
 else:set_reach_target(item.right(1),null)
 hands[i].pose_index=1

func select_tool(t:int)->void:
 clear_input()
 for i in held.keys():release_grip(i)
 hand_screen.clear();independent.clear()
 tool=t;last_tool=t
 menu.select(t)
 active_hand=1 if t==Tool.LEFT else 0
 change_mode([0,1,2,3,3][t])
 candy.visible=true
 for i in range(2):
  hand_screen[i]=camera.unproject_position(Vector3(.36 if i==0 else -.36,1.55,.3))
 pointer=hand_screen[active_hand]
 rail.set_value_no_signal(-float(depth_by_hand[active_hand]))
 rail.visible=t!=Tool.CANDY;depth_label.visible=rail.visible
 grip_message="";refresh()

func switch_hand()->void:
 if tool==Tool.MULTI:
  active_hand=1-active_hand
  depth=depth_by_hand[active_hand]
  rail.set_value_no_signal(-depth)
  refresh()

func camera_mode()->void:
 clear_input()
 if tool==Tool.CAMERA:
  for i in range(2):
   var parked:Vector3=hands[i].desired
   hand_screen[i]=camera.unproject_position(parked)
   depth_by_hand[i]=clampf(camera.global_basis.z.dot(parked-Vector3(0,pivot_y,0)),-.31,.60)
  depth=depth_by_hand[active_hand]
  rail.set_value_no_signal(-depth)
  pointer=hand_screen[active_hand]
  tool=last_tool
 else:
  last_tool=tool;tool=Tool.CAMERA
 rail.visible=tool not in [Tool.CAMERA,Tool.CANDY]
 depth_label.visible=rail.visible
 refresh()

func mobile_reset()->void:
 reset_demo();depth_by_hand=[.31,.31];select_tool(Tool.RIGHT)

func adjust_depth(value:float)->void:
 depth_by_hand[active_hand]=-value
 if tool!=Tool.MULTI:depth_by_hand[1-active_hand]=-value
 depth=-value

func hand_world(i:int)->Vector3:
 var normal:=camera.global_basis.z
 var plane:=Plane(normal,Vector3(0,pivot_y,0)+normal*float(depth_by_hand[i]))
 var screen:Vector2=hand_screen[i]
 return plane.intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))

func wrist(name_:String)->Vector3:
 return skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(name_)).origin)

func toggle_grip()->void:
 if tool==Tool.CAMERA:return
 if tool==Tool.CANDY:toggle_lollipop();refresh();return
 var i:=active_hand
 if held.has(i):release_grip(i);refresh();return
 var best:=""
 var distance:=GRAB_DISTANCE
 for name_ in ["PalmL","PalmR","candy"]:
  if name_ in held.values():continue
  var pos:Vector3=candy.global_position if name_=="candy" else wrist(name_)
  var d:float=hands[i].global_position.distance_to(pos)
  if d<distance:distance=d;best=name_
 if best=="candy" and state==State.ATTACHED:_return_to_tray()
 if best.is_empty():
  grip_message="Aproxime a palma do punho da Rosé ou do pirulito.";hint_time=2.0
 else:
  held[i]=best;hands[i].pose_index=3
 refresh()

func refresh()->void:
 if not touch_ui:return
 side_button.visible=tool==Tool.MULTI
 grip_button.disabled=tool==Tool.CAMERA
 grip_button.text=("Retirar" if state==State.ATTACHED else "Oferecer") if tool==Tool.CANDY else ("Soltar" if held.has(active_hand) else "Agarrar")
 if tool==Tool.CAMERA:
  feedback.text="Câmera · um dedo orbita · dois dedos aproximam e deslocam a altura"
 elif tool==Tool.CANDY:
  feedback.text="Pirulito · "+status_label.text.strip_edges()
 elif hint_time>0:feedback.text=grip_message
 else:
  var regions: Array[String]=[]
  for i in range(2):
   if not hands[i].enabled:continue
   var name_:String="D" if i==0 else "E"
   var region:String=contacts[i].region if contacts.size()>i else ""
   regions.append(name_+" · "+("segurando "+str(held[i]) if held.has(i) else ("livre" if region=="" else region)))
  feedback.text="   ".join(regions)+"   |   Profundidade: "+("D" if active_hand==0 else "E")

func blocked(pos:Vector2)->bool:
 for row in [toolbar,footer]:
  for child in row.get_children():
   if child.get_global_rect().has_point(pos):return true
 return menu.get_popup().visible

func start_finger(id:int,pos:Vector2)->bool:
 if owners.has(id):return false
 if rail.visible and rail.get_global_rect().grow(6).has_point(pos):
  owners[id]="depth"+str(active_hand);slide_depth(pos,active_hand);return true
 for btn in footer.get_children():
  if btn.has_meta("rotation") and btn.get_global_rect().has_point(pos):
   if tool not in [Tool.CAMERA,Tool.CANDY]:
    owners[id]="rotation";rotation_owner[id]=btn.get_meta("rotation")
    roll=clampf(roll+float(rotation_owner[id])*.10,-1.5,1.5)
   return true
 if grip_button.visible and grip_button.get_global_rect().has_point(pos):
  if not grip_button.disabled:toggle_grip()
  return true
 if side_button.visible and side_button.get_global_rect().has_point(pos):
  switch_hand()
  return true
 if blocked(pos):return false
 if tool==Tool.CAMERA:
  if points.size()>=2:return true
  owners[id]="camera";points[id]=pos
 elif tool==Tool.CANDY:
  if "candy" in owners.values() or not _hits_lollipop(pos):return true
  owners[id]="candy";start_drag(pos)
 else:
  var i:=1 if tool==Tool.LEFT else 0
  if tool==Tool.MULTI:
   i=0 if pos.x>=overlay.size.x*.5 else 1
   if i in owners.values():i=1-i
  if i in owners.values():return true
  owners[id]=i;move_hand(i,pos)
 return true

func move_hand(i:int,pos:Vector2)->void:
 active_hand=i;hand_screen[i]=pos;pointer=pos
 rail.set_value_no_signal(-float(depth_by_hand[i]))
 depth=depth_by_hand[i]

func slide_depth(pos:Vector2,index:int)->void:
 var fraction:=clampf((pos.y-rail.global_position.y)/maxf(1,rail.size.y),0,1)
 var value:=lerpf(rail.max_value,rail.min_value,fraction)
 depth_by_hand[index]=-value
 if tool!=Tool.MULTI:depth_by_hand[1-index]=-value
 if index==active_hand:
  rail.set_value_no_signal(value);depth=-value

func drag_finger(id:int,pos:Vector2)->void:
 var slot:Variant=owners[id]
 if typeof(slot)==TYPE_INT:move_hand(slot,pos)
 elif str(slot).begins_with("depth"):slide_depth(pos,int(str(slot).right(1)))
 elif slot=="candy":drag_to(pos)
 elif slot=="camera":
  var prev:Vector2=points[id];points[id]=pos
  if points.size()==1:
   yaw-=(pos.x-prev.x)*.007;pitch=clampf(pitch+(pos.y-prev.y)*.006,-1.05,1.05)
  else:
   for other in points:
    if other==id:continue
    var span:=maxf(8,pos.distance_to(points[other]))
    zoom_size=clampf(zoom_size*maxf(8,prev.distance_to(points[other]))/span,.43,3.4)
    pivot_y=clampf(pivot_y+(pos.y-prev.y)*zoom_size/maxf(1,overlay.size.y)*.5,0,2.15)
  update_camera()

func end_finger(id:int,pos:Vector2,cancelled:bool)->void:
 if typeof(owners[id])==TYPE_STRING and owners[id]=="candy":
  if cancelled:_return_to_tray()
  else:finish_drag(pos)
 owners.erase(id);points.erase(id);rotation_owner.erase(id)

func _input(event:InputEvent)->void:
 if not is_node_ready():return
 if event is InputEventScreenTouch:
  if not touch_ui:set_mobile(true)
  if event.pressed and not event.canceled:
   if not start_finger(event.index,event.position):return
  elif owners.has(event.index):end_finger(event.index,event.position,event.canceled)
  else:return
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and owners.has(event.index):
  drag_finger(event.index,event.position);get_viewport().set_input_as_handled()
 elif touch_ui and event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:
  return
 else:super(event)

func _unhandled_input(event:InputEvent)->void:
 if touch_ui and event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:return
 super(event)

func _physics_process(dt:float)->void:
 if touch_ui:
  hint_time=maxf(0,hint_time-dt)
  for id in rotation_owner:roll=clampf(roll+dt*float(rotation_owner[id])*1.4,-1.5,1.5)
  if tool==Tool.MULTI:
   for i in range(2):set_hand_target(i,hand_world(i))
  elif tool==Tool.CAMERA:
   for i in range(2):
    if not independent.has(i):set_hand_target(i,hands[i].desired)
  elif last_tool!=Tool.MULTI:independent.clear()
 super(dt)
 if not touch_ui:return
 follow_held(dt)
 for i in range(2):
  var label:Label=tags[i]
  label.visible=hands[i].enabled and tool!=Tool.CAMERA
  if label.visible:
   label.position=camera.unproject_position(hands[i].global_position)+Vector2(12,-20)
   label.modulate=Color.AQUAMARINE if contacts[i].region!="" or held.has(i) else Color.WHITE
 refresh()

func _notification(what:int)->void:
 super(what)
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
  clear_input()
  for i in held.keys():release_grip(i)

func follow_held(_dt:float)->void:
 for i in held:
  if held[i]=="candy":
   candy.global_position=hands[i].global_position;candy.scale=Vector3.ONE*.24
  else:set_reach_target(str(held[i]).right(1),skeleton.to_local(hands[i].global_position))
