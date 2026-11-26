extends SceneTree
var lab
var faults:=0
func check(ok:bool,title:String):
 if not ok:faults+=1;push_error(title)
func step(n:int):
 for i in n:lab._physics_process(1./60)
func touch(id:int,p:Vector2,down:bool):
 var e:=InputEventScreenTouch.new();e.pressed=down;e.position=p;e.index=id;root.push_input(e,true)
func drag(id:int,p:Vector2):
 var e:=InputEventScreenDrag.new();e.index=id;e.position=p;root.push_input(e,true)
func cube_check() -> void:
 var cube_scene=load("res://direct/drag_cube.tscn").instantiate()
 root.add_child(cube_scene)
 await process_frame
 var camera:Camera3D=cube_scene.camera
 var screen:=camera.unproject_position(cube_scene.cube.global_position)
 var origin:Vector3=cube_scene.cube.global_position
 touch(14,screen,true)
 check(cube_scene.linked and cube_scene.active_finger==14,"cubo recebe toque e seleciona")
 var depth:float=camera.to_local(cube_scene.hand_point).z
 drag(19,screen+Vector2(60,40))
 check(cube_scene.cube.global_position==origin,"outro dedo não desloca o cubo")
 drag(14,screen+Vector2(95,30))
 check(cube_scene.input_drag.drag_count==2,"cubo recebe ambos os eventos de arraste")
 check(cube_scene.cube.global_position.distance_to(origin)>.15,"arraste move o cubo")
 check(absf(camera.to_local(cube_scene.hand_point).z-depth)<.0001,"cubo mantém profundidade")
 var toolbar_point:Vector2=cube_scene.tools.get_global_rect().get_center()
 drag(14,toolbar_point)
 check(camera.unproject_position(cube_scene.hand_point).distance_to(toolbar_point)<.1,"captura continua sobre a barra")
 var parked:Vector3=cube_scene.cube.global_position
 touch(14,toolbar_point,false)
 drag(14,screen+Vector2(180,45))
 check(not cube_scene.linked and cube_scene.cube.global_position==parked,"soltura encerra o vínculo")
 cube_scene.grab_mode=false
 touch(15,screen,true)
 drag(15,screen+Vector2(50,-30))
 check(camera.unproject_position(cube_scene.hand_point).distance_to(screen+Vector2(50,-30))<.1,"Tocar segue fora da superfície")
 check(cube_scene.cube.global_position==parked,"Tocar não move o objeto")
 touch(15,screen,false)
 cube_scene.queue_free()
 await process_frame

func _initialize():call_deferred("run")
func run():
 await cube_check()
 if faults>0:quit(faults);return
 print("Cubo · toque, índice, arraste, profundidade e soltura aprovados")
 lab=load("res://direct_touch.tscn").instantiate();root.add_child(lab);await process_frame
 lab.set_control_mode(lab.ControlMode.Mode.TOUCHSCREEN,false)
 lab.set_physics_process(false);step(60)
 for yaw in [0.,.48,-.72]:
  lab.yaw=yaw;lab.update_camera()
  for key in ["Mão D","Antebraço E","Ombro D","Tronco","Pirulito"]:
   var p:Vector2=lab.camera.unproject_position(lab.anchors[key])
   var h:Dictionary=lab.picker.cast(lab.camera,p,0)
   check(not h.is_empty(),"ray "+key+" a "+str(yaw))
   if h.is_empty():continue
   check(lab.camera.unproject_position(h.p).distance_to(p)<.08,"reprojeção")
   var tracked:Dictionary=lab.picker.track(h)
   check(tracked.p.distance_to(h.p)<.0007,"triângulo persistente")
 lab.yaw=0;lab.update_camera()
 var point:Vector2=lab.camera.unproject_position(lab.anchors["Mão D"])
 touch(3,point,true);step(2)
 check(lab.fingers.has(3),"toque real de viewport capturado")
 if lab.fingers.has(3):
  var slot:int=lab.fingers[3][0]
  var g:Dictionary=lab.touches[slot]
  check(lab.camera.unproject_position(lab.hands[slot].tips[1].global_position).distance_to(point)<2.,"dedo sobre a tela")
  check(not lab.links.has(slot),"toque curto")
  var drag_point:=point+Vector2(95,28)
  var original_depth:float=lab.camera.to_local(g.point).z
  drag(8,drag_point)
  check(Vector3(g.point).distance_to(g.base)<.001,"índice diferente ignorado")
  drag(3,drag_point);step(4)
  check(lab.camera.unproject_position(lab.hands[slot].tips[1].global_position).distance_to(drag_point)<2.,"Tocar acompanha fora da malha")
  check(absf(lab.camera.to_local(g.point).z-original_depth)<.0001,"Rosé conserva profundidade")
  check(lab.input_drag.drag_count==2 and not lab.links.has(slot),"drag recebido sem vínculo em Tocar")
  touch(3,drag_point,false)
  step(1)
  lab.set_grab_mode(true)
  touch(3,point,true)
  check(lab.links.has(slot),"Agarrar liga sem espera")
  var left:Vector2=lab.camera.unproject_position(lab.anchors["Antebraço E"])
  touch(5,left,true);step(2);check(lab.links.size()==2,"duas capturas")
  for i in 10:drag(3,point+Vector2(i*2,-i));step(1)
  drag(3,point+Vector2(250,70));step(25)
  check(lab.force_readout[slot]>.05 and lab.solver.body_load.length()>.001,"tração")
  check(Vector3(lab.touches[slot].point).distance_to(lab.touches[slot].physical)>.25,"dedo distante da mão restringida")
  var actual:Dictionary=lab.picker.track(lab.touches[slot].hit)
  check(lab.hands[slot].tips[1].global_position.distance_to(actual.p)<.004,"mão permanece no triângulo da Rosé")
  drag(5,left+Vector2(-200,70));step(70)
  check(lab.links.size()==2 and lab.solver.body_load.length()<=.241,"puxadas opostas nos braços ficam limitadas")
  touch(3,point,false);check(lab.links.size()==1,"soltura independente")
  touch(5,left,false);step(120);check(lab.links.is_empty() and lab.solver.body_load.length()<.004,"recuperação")
 lab.select_tool(lab.Tool.MIRROR);touch(6,point,true);step(1)
 check(lab.fingers.get(6,[]).size()==2 and lab.links.size()==2,"espelho de um dedo")
 touch(6,point,false);lab.select_tool(lab.Tool.RIGHT)
 var candy_origin:Vector3=lab.candy.global_position
 var candy_screen:Vector2=lab.camera.unproject_position(candy_origin)
 touch(7,candy_screen,true)
 check(lab.links.size()==1 and lab.links[0].name=="Pirulito","pirulito selecionado imediatamente")
 drag(7,candy_screen+Vector2(48,30));step(12)
 check(lab.candy.global_position.distance_to(candy_origin)>.05,"pirulito move")
 var candy_parked:Vector3=lab.candy.global_position
 touch(7,candy_screen,false);drag(7,candy_screen+Vector2(160,20));step(12)
 check(lab.links.is_empty() and lab.fingers.is_empty(),"pirulito libera")
 check(lab.candy.global_position.distance_to(candy_parked)<.32,"inércia após soltar é limitada")
 lab.camera_mode()
 var yaw_before:float=lab.yaw
 touch(9,Vector2(450,360),true);drag(9,Vector2(520,360));touch(9,Vector2(520,360),false)
 check(absf(lab.yaw-yaw_before)>.01 and lab.fingers.is_empty() and lab.links.is_empty(),"câmera não aciona mãos")
 lab.camera_mode()
 lab.yaw=0;lab.update_camera()
 var strap:=false
 var strap_screen:=Vector2.ZERO
 for surface in lab.picker.surfaces:
  if surface.node.name!="Dress":continue
  lab.picker.update_surface(surface)
  for f in range(0,surface.indices.size(),3):
   var a:Vector3=lab.picker.vertex(surface,surface.indices[f])
   if a.y<1.611:continue
   var b:Vector3=lab.picker.vertex(surface,surface.indices[f+1]);var c:Vector3=lab.picker.vertex(surface,surface.indices[f+2])
   var h:Dictionary=lab.picker.cast(lab.camera,lab.camera.unproject_position((a+b+c)/3),0)
   if not h.is_empty() and h.surface.node.name=="Dress" and h.p.y>1.611:
    strap=true;strap_screen=lab.camera.unproject_position(h.p);break
  if strap:break
 check(strap,"alça da camisola visível, sem tolerância")
 if strap:
  touch(11,strap_screen,true);drag(11,strap_screen+Vector2(45,-30));step(14)
  check(lab.links.has(0) and lab.links[0].name=="Camisola" and lab.force_readout[0]>.08,"alça seleciona e transmite tração")
  var canceled:=InputEventScreenTouch.new()
  canceled.index=11;canceled.position=strap_screen;canceled.canceled=true
  root.push_input(canceled,true)
  check(lab.links.is_empty() and lab.fingers.is_empty(),"cancelamento encerra captura")
 lab.set_control_mode(lab.ControlMode.Mode.DESKTOP,false)
 lab.select_tool(lab.Tool.RIGHT)
 var mouse:=InputEventMouseButton.new()
 mouse.button_index=MOUSE_BUTTON_LEFT
 mouse.position=lab.camera.unproject_position(lab.anchors["Mão D"])
 mouse.pressed=true
 root.push_input(mouse,true)
 check(lab.links.has(0) and lab.fingers.has(lab.desktop_id()),"clique do PC usa vínculo compartilhado")
 mouse.pressed=false
 root.push_input(mouse,true)
 mouse.pressed=true
 root.push_input(mouse,true)
 check(lab.links.is_empty(),"segundo clique do PC solta")
 print("Rosé · integração com cena principal concluída")
 var bench=load("res://direct/fabric.tscn").instantiate();lab.queue_free();await process_frame;root.add_child(bench);await process_frame
 bench.set_physics_process(false)
 for name_ in ["Amostra","Cordão","Tira","Alça de bolsa"]:
  bench.pos=bench.rest.duplicate();bench.last=bench.rest.duplicate()
  for i in 300:bench.simulate(1./120)
  var baseline:PackedVector3Array=bench.pos.duplicate()
  var sample_vertices:Dictionary={}
  for f in range(0,bench.indices.size(),3):
   if bench.groups[f/3]!=name_:continue
   for j in 3:sample_vertices[bench.indices[f+j]]=true
  var found:=false
  for f in range(0,bench.indices.size(),3):
   if bench.groups[f/3]!=name_ or bench.pinned.has(bench.indices[f]):continue
   var p:Vector3=(bench.pos[bench.indices[f]]+bench.pos[bench.indices[f+1]]+bench.pos[bench.indices[f+2]])/3
   if p.y>.18 or p.y<-.30:continue
   var screen:Vector2=bench.cam.unproject_position(p)
   var h:Dictionary=bench.pick(screen)
   if h.is_empty() or h.name!=name_:continue
   found=true;touch(8,screen,true)
   for i in 55:bench.simulate(1./120)
   drag(8,screen+Vector2(180,10))
   for i in 80:bench.simulate(1./120)
   check(not bench.holds.is_empty(),"vínculo tecido")
   touch(8,screen,false)
   var peak:=0.
   for i in sample_vertices:peak=maxf(peak,bench.pos[i].distance_to(baseline[i]))
   for i in 200:bench.simulate(1./120)
   var after:=0.
   for i in bench.pos.size():
    check(bench.pos[i].is_finite() and bench.pos[i].distance_to(bench.rest[i])<.75,"estabilidade")
    if bench.pinned.has(i):check(bench.pos[i]==bench.rest[i],"pino fixo")
    if sample_vertices.has(i):after=maxf(after,bench.pos[i].distance_to(baseline[i]))
   check(peak>.03 and after<peak,"retorno tecido "+name_)
   break
  check(found,"alvo "+name_)
 print("Toque e resistência 1.2.4 · falhas: ",faults);quit(faults)
