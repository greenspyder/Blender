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
func _initialize():call_deferred("run")
func run():
 lab=load("res://direct_touch.tscn").instantiate();root.add_child(lab);await process_frame
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
  step(30);check(lab.links.has(slot),"pressionar liga")
  var left:Vector2=lab.camera.unproject_position(lab.anchors["Antebraço E"])
  touch(5,left,true);step(30);check(lab.links.size()==2,"duas capturas")
  for i in 10:drag(3,point+Vector2(i*2,-i));step(1)
  drag(3,point+Vector2(250,70));step(25)
  check(lab.force_readout[slot]>.05 and lab.solver.body_load.length()>.001,"tração")
  touch(3,point,false);check(lab.links.size()==1,"soltura independente")
  touch(5,left,false);step(120);check(lab.links.is_empty() and lab.solver.body_load.length()<.004,"recuperação")
 lab.select_tool(lab.Tool.MIRROR);touch(6,point,true);step(30)
 check(lab.fingers.get(6,[]).size()==2 and lab.links.size()==2,"espelho de um dedo")
 touch(6,point,false);lab.select_tool(lab.Tool.RIGHT)
 touch(7,point,true);drag(7,point+Vector2(60,0));step(35)
 check(lab.links.is_empty(),"arrasto anterior ao prazo");touch(7,point,false)
 var strap:=false
 for surface in lab.picker.surfaces:
  if surface.node.name!="Dress":continue
  lab.picker.update_surface(surface)
  for f in range(0,surface.indices.size(),3):
   var a:Vector3=lab.picker.vertex(surface,surface.indices[f])
   if a.y<1.611:continue
   var b:Vector3=lab.picker.vertex(surface,surface.indices[f+1]);var c:Vector3=lab.picker.vertex(surface,surface.indices[f+2])
   var h:Dictionary=lab.picker.cast(lab.camera,lab.camera.unproject_position((a+b+c)/3),0)
   if not h.is_empty() and h.surface.node.name=="Dress" and h.p.y>1.611:strap=true;break
  if strap:break
 check(strap,"alça da camisola visível, sem tolerância")
 var bench=load("res://direct/fabric.tscn").instantiate();lab.queue_free();await process_frame;root.add_child(bench);await process_frame
 bench.set_physics_process(false)
 for name_ in ["Amostra","Tira","Alça de bolsa"]:
  var found:=false
  for f in range(0,bench.indices.size(),3):
   if bench.groups[f/3]!=name_ or bench.pinned.has(bench.indices[f]):continue
   var p:Vector3=(bench.pos[bench.indices[f]]+bench.pos[bench.indices[f+1]]+bench.pos[bench.indices[f+2]])/3
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
   for i in bench.pos.size():peak=maxf(peak,bench.pos[i].distance_to(bench.rest[i]))
   for i in 200:bench.simulate(1./120)
   var after:=0.
   for i in bench.pos.size():
    check(bench.pos[i].is_finite() and bench.pos[i].distance_to(bench.rest[i])<.75,"estabilidade")
    if bench.pinned.has(i):check(bench.pos[i]==bench.rest[i],"pino fixo")
    after=maxf(after,bench.pos[i].distance_to(bench.rest[i]))
   check(peak>.03 and after<peak,"retorno tecido "+name_)
   break
  check(found,"alvo "+name_)
 print("Direct Touch 1.2.2 · falhas: ",faults);quit(faults)
