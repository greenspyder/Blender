extends SceneTree
var bad:=0
var lab
func verify(ok:bool,label_:String)->void:
 if not ok:bad+=1;push_error(label_)
func tick(n:int)->void:
 for i in range(n):lab._physics_process(1./60)
func tap(p:Vector2,down:bool,id:int)->void:
 var e:=InputEventScreenTouch.new();e.index=id;e.position=p;e.pressed=down;root.push_input(e,true)
func aim(name_:String,i:int)->void:
 var p:Vector2=lab.camera.unproject_position(lab.anchors[name_])
 lab.active_hand=i
 lab.hand_screen[i]=p;lab.pointer=p
 lab.hands[i].global_position=lab.anchors[name_]
func _initialize()->void:call_deferred("run")
func run()->void:
 lab=load("res://mechanics_lab.tscn").instantiate();root.add_child(lab);await process_frame
 lab.set_physics_process(false);tick(90)
 var rest:Vector3=lab.wrist("PalmR")
 verify(rest.y<lab.wrist("UpperR").y-.45,"queda dos braços")
 lab.select_tool(lab.Tool.MULTI)
 var p:Vector2=lab.camera.unproject_position(lab.wrist("PalmR"))
 tap(p,true,4);tap(p,false,4);tick(30)
 var btn:Vector2=lab.grip_button.get_global_rect().get_center()
 tap(btn,true,9);tap(btn,false,9)
 verify(lab.links.has(0) and lab.links[0].name=="Mão D","punho por tela e botão")
 if lab.links.has(0):
  lab.hand_screen[0]+=Vector2(110,-40)
  tick(30)
  verify(lab.force_readout[0]>.05 and lab.solver.body_load.length()>.004,"vínculo conduz e transfere carga")
 aim("Ombro E",1);lab.toggle_grip()
 verify(lab.links.size()==2,"vínculos simultâneos")
 for i in range(90):
  lab.hand_screen[0]+=Vector2(1 if i<45 else -5,0);tick(1)
  verify(lab.solver.bend[0]>=14.99 and lab.solver.bend[1]<=120.01 and lab.solver.body_load.is_finite(),"limites")
 lab.release_grip(1);lab.release_grip(0);lab.select_tool(lab.Tool.CANDY);tick(180)
 verify(lab.solver.body_load.length()<.002 and lab.wrist("PalmR").distance_to(rest)<.025,"retorno ao repouso vivo")
 lab.select_tool(lab.Tool.RIGHT);tick(1)
 for garment in ["Camisola","Short"]:
  aim(garment,0);lab.toggle_grip();lab.clothing_action()
  verify(garment in lab.removed,"retirar "+garment)
  lab.clothing_action();verify(not garment in lab.removed,"recolocar "+garment)
 aim("Perna D",0);lab.toggle_grip()
 verify(lab.links.has(0),"perna")
 lab.release_grip(0)
 aim("Mão D",0)
 var click:=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT;click.position=lab.pointer;click.pressed=true
 root.push_input(click,true)
 verify(lab.links.has(0) and lab.links[0].name=="Mão D","clique agarra")
 click.pressed=false;root.push_input(click,true)
 click.pressed=true;root.push_input(click,true)
 verify(not lab.links.has(0),"segundo clique solta")
 aim("Pirulito",0);lab.toggle_grip();tick(2)
 verify(lab.links.has(0) and lab.links[0].name=="Pirulito" and lab.candy.global_position.distance_to(lab.hands[0].global_position)<.001,"objeto segue a mão")
 lab.release_grip(0)
 var st:Variant=lab.Detector.sample(Vector3(.245,1.59,.15),Vector3.ZERO,.05)
 verify(st.force>0 and st.force<1,"contato leve")
 print("Mecânica 1.2.1 · falhas: ",bad)
 quit(bad)
