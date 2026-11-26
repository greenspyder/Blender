extends SceneTree

const Modes=preload("res://direct/control_mode.gd")
const Strap=preload("res://direct/strap.gd")
const Garment=preload("res://direct/garment_pull.gd")
var lab
var failures:=0

func _initialize()->void:call_deferred("run")

func check(ok:bool,title:String)->void:
 if not ok:
  failures+=1
  push_error(title)

func step(n:=1)->void:
 for i in n:lab._physics_process(1./60.)

func mouse(screen:Vector2,button:int,down:bool,device:=0)->void:
 var event:=InputEventMouseButton.new()
 event.position=screen
 event.button_index=button
 event.pressed=down
 event.device=device
 root.push_input(event,true)

func click(screen:Vector2)->void:
 mouse(screen,MOUSE_BUTTON_LEFT,true)
 mouse(screen,MOUSE_BUTTON_LEFT,false)

func motion(screen:Vector2,relative:Vector2)->void:
 var event:=InputEventMouseMotion.new()
 event.position=screen
 event.relative=relative
 root.push_input(event,true)

func touch(id:int,screen:Vector2,down:bool)->void:
 var event:=InputEventScreenTouch.new()
 event.position=screen
 event.index=id
 event.pressed=down
 root.push_input(event,true)

func key(code:Key,down:bool)->void:
 var event:=InputEventKey.new()
 event.keycode=code
 event.physical_keycode=code
 event.pressed=down
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func settings_test()->void:
 check(not Modes.touchscreen(Modes.Mode.AUTO,false) and Modes.touchscreen(Modes.Mode.AUTO,true),"Auto distingue PC e Android")
 check(Modes.touchscreen(Modes.Mode.TOUCHSCREEN,false) and not Modes.touchscreen(Modes.Mode.DESKTOP,true),"seleção manual prevalece")
 var local:="user://rose_controls_test_%d.cfg"%Time.get_ticks_usec()
 var prefs:=Modes.new(local)
 prefs.choice=Modes.Mode.TOUCHSCREEN
 check(prefs.save()==OK and Modes.new(local).choice==Modes.Mode.TOUCHSCREEN,"preferência manual persistida")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(local))

func desktop_prop()->void:
 lab.select_tool(lab.Tool.RIGHT)
 step(12)
 var origin:Vector3=lab.candy.global_position
 var screen:Vector2=lab.camera.unproject_position(origin)
 touch(3,screen,true)
 touch(3,screen,false)
 check(lab.fingers.is_empty(),"Desktop ignora toque para a cena")
 click(screen)
 check(lab.links.has(0) and lab.touches[0].name=="Pirulito","mouse seleciona usando o mesmo raycast do toque")
 if not lab.links.has(0):return
 var point:=screen+Vector2(58,36)
 motion(point,Vector2(58,36))
 step(15)
 check(lab.candy.global_position.distance_to(origin)>.035,"mouse move o objeto pela física compartilhada")
 var before_depth:Vector3=lab.touches[0].point
 key(KEY_W,true)
 step(12)
 key(KEY_W,false)
 check(absf(lab.camera.global_basis.z.dot(Vector3(lab.touches[0].point)-before_depth))>.045,"W altera a profundidade do objeto agarrado")
 key(KEY_S,true)
 step(12)
 key(KEY_S,false)
 check(Vector3(lab.touches[0].point).distance_to(before_depth)<.004,"S devolve a profundidade")
 var before_roll:float=lab.roll
 key(KEY_E,true)
 step(12)
 key(KEY_E,false)
 check(lab.roll>before_roll+.1,"E gira a mão")
 key(KEY_Q,true)
 step(12)
 key(KEY_Q,false)
 check(absf(lab.roll-before_roll)<.002,"Q gira no sentido oposto")
 var desired:Vector3=lab.touches[0].point
 var before_yaw:float=lab.yaw
 mouse(point,MOUSE_BUTTON_RIGHT,true)
 motion(point+Vector2(22,10),Vector2(22,10))
 mouse(point+Vector2(22,10),MOUSE_BUTTON_RIGHT,false)
 check(absf(lab.yaw-before_yaw)>.08 and lab.links.has(0),"botão direito orbita preservando a pega")
 check(Vector3(lab.touches[0].point).distance_to(desired)<.004,"órbita não teleporta o alvo")
 var zoom:float=lab.zoom_size
 mouse(point,MOUSE_BUTTON_WHEEL_UP,true)
 check(lab.zoom_size<zoom and lab.links.has(0),"roda aproxima preservando pega")
 var height:float=lab.pivot_y
 key(KEY_UP,true)
 step(10)
 key(KEY_UP,false)
 check(lab.pivot_y>height+.1,"seta sobe a câmera")
 key(KEY_DOWN,true)
 step(10)
 key(KEY_DOWN,false)
 check(absf(lab.pivot_y-height)<.005,"seta desce a câmera")
 var slider:Rect2=lab.rail.get_global_rect()
 var slider_before:float=lab.depth
 mouse(slider.position+slider.size*Vector2(.5,.25),MOUSE_BUTTON_LEFT,true)
 mouse(slider.position+slider.size*Vector2(.5,.25),MOUSE_BUTTON_LEFT,false)
 check(absf(lab.depth-slider_before)>.04 and lab.links.has(0),"controle visível altera profundidade sem soltar")
 click(point)
 check(lab.links.is_empty() and lab.fingers.is_empty(),"segundo clique libera")
 key(KEY_R,true)
 key(KEY_R,false)
 step()
 check(absf(lab.yaw)<.0001 and absf(lab.zoom_size-2.65)<.001,"R reinicia câmera")
 lab.select_tool(lab.Tool.CANDY)
 key(KEY_SPACE,true)
 key(KEY_SPACE,false)
 check(lab.state==lab.State.ATTACHED,"Espaço oferece o pirulito")
 key(KEY_SPACE,true)
 key(KEY_SPACE,false)
 check(lab.state==lab.State.TRAY,"Espaço recolhe o pirulito")
 var candy_at:Vector2=lab.camera.unproject_position(lab.candy.global_position)
 mouse(candy_at,MOUSE_BUTTON_LEFT,true)
 check(lab.state==lab.State.DRAGGING,"clique e arraste legado do pirulito")
 mouse(candy_at,MOUSE_BUTTON_LEFT,false)
 check(lab.state!=lab.State.DRAGGING,"soltura do pirulito legado")

func desktop_mirror()->void:
 lab.select_tool(lab.Tool.MIRROR)
 step(90)
 var wrist:Vector2=lab.camera.unproject_position(lab.wrist("PalmR"))
 click(wrist)
 check(lab.links.size()==2 and lab.fingers.get(lab.desktop_id(),[]).size()==2,"clique no PC mantém o par espelhado")
 if lab.links.size()==2:
  var first:Vector3=lab.touches[0].point
  var second:Vector3=lab.touches[1].point
  motion(wrist+Vector2(45,0),Vector2(45,0))
  check((Vector3(lab.touches[0].point).x-first.x)*(Vector3(lab.touches[1].point).x-second.x)<0.,"mãos espelhadas seguem em direções opostas")
 click(wrist)
 check(lab.links.is_empty(),"clique solta o par")

func strap_point()->Variant:
 for s in lab.picker.surfaces:
  if s.node.name!="Dress" or s.surface_index!=1:continue
  lab.picker.update_surface(s)
  for f in range(0,s.indices.size(),3):
   var base:Vector3=s.vertices[s.indices[f]]
   if not Strap.in_strap(base) or base.y<1.61:continue
   var p:Vector3=(lab.picker.vertex(s,s.indices[f])+lab.picker.vertex(s,s.indices[f+1])+lab.picker.vertex(s,s.indices[f+2]))/3.
   var projected:Vector2=lab.camera.unproject_position(p)
   if not lab.blocked(projected) and Strap.contains_hit(lab.picker.cast(lab.camera,projected,0)):return projected
 return null

func desktop_garment()->void:
 lab.select_tool(lab.Tool.RIGHT)
 step(4)
 var target:Variant=strap_point()
 check(target!=null,"alça disponível pelo mouse")
 if target==null:return
 click(target)
 motion(target+Vector2(0,-220),Vector2(0,-220))
 step(42)
 check(lab.garment.state==Garment.State.HELD and lab.links.has(0),"mouse puxa a camisola pela alça")
 # Soltar com o segundo clique, em uma área de cena livre do HUD.
 var release_at:Vector2=target+Vector2(40,10)
 click(release_at)
 step(120)
 check(lab.garment.state==Garment.State.RESTING and lab.links.is_empty(),"camisola continua na cena depois de soltar")
 click(lab.garment_button.get_global_rect().get_center())
 step(92)
 check(lab.garment.state==Garment.State.WORN and lab.removed.is_empty(),"botão Recolocar funciona com mouse")

func switch_and_touch()->void:
 lab.select_tool(lab.Tool.RIGHT)
 step(20)
 var wrist:Vector2=lab.camera.unproject_position(lab.wrist("PalmR"))
 click(wrist)
 check(lab.links.has(0),"pega desktop antes de trocar")
 lab.control_menu.item_selected.emit(Modes.Mode.TOUCHSCREEN)
 # Exercita o seletor sem deixar preferências deste teste alteradas.
 check(lab.touch_display and lab.links.is_empty() and lab.fingers.is_empty(),"seletor touchscreen limpa vínculo anterior")
 lab.set_grab_mode(true)
 step(3)
 wrist=lab.camera.unproject_position(lab.wrist("PalmR"))
 touch(12,wrist,true)
 mouse(wrist,MOUSE_BUTTON_LEFT,true,InputEvent.DEVICE_ID_EMULATION)
 check(lab.links.size()==1 and lab.fingers.has(12),"mouse emulado não duplica toque nativo")
 touch(12,wrist,false)
 step()
 check(lab.links.is_empty(),"soltura do toque nativo")
 mouse(wrist,MOUSE_BUTTON_LEFT,true)
 check(lab.links.has(0) and lab.fingers.has(Modes.MOUSE_TOUCH_ID),"mouse simula um dedo no layout touchscreen")
 motion(wrist+Vector2(48,10),Vector2(48,10))
 step(12)
 mouse(wrist+Vector2(48,10),MOUSE_BUTTON_LEFT,false)
 check(lab.links.is_empty() and lab.fingers.is_empty(),"mouse em Touchscreen solta no botão levantado")
 lab.set_control_mode(Modes.Mode.AUTO,false)
 check(lab.touch_display==OS.has_feature("mobile"),"voltar a Auto detecta o host")

func run()->void:
 settings_test()
 lab=load("res://direct_touch.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_physics_process(false)
 lab.control_mode.storage="user://rose_manual_selector_test_%d.cfg"%Time.get_ticks_usec()
 lab.set_control_mode(Modes.Mode.DESKTOP,false)
 desktop_prop()
 desktop_mirror()
 desktop_garment()
 switch_and_touch()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(lab.control_mode.storage))
 print("PC e Android · controles unificados · falhas: ",failures)
 quit(failures)
