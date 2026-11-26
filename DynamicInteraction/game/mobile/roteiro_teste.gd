extends Node
var root:Viewport
var errors:Array[String]=[]

var failures:=0
func check(ok:bool,name_:String)->void:
 if not ok:
  failures+=1;errors.append(name_);push_error(name_)

func _ready()->void:
 root=get_viewport();call_deferred("run")
func press(i:int,p:Vector2,down:bool)->void:
 var e:=InputEventScreenTouch.new()
 e.index=i;e.position=p;e.pressed=down;root.push_input(e,true)
func drag(i:int,p:Vector2)->void:
 var e:=InputEventScreenDrag.new()
 e.index=i;e.position=p;root.push_input(e,true)

func run()->void:

 var lab=load("res://mobile_lab.tscn").instantiate()
 add_child(lab);await get_tree().process_frame
 lab.set_mobile(true);lab.set_physics_process(false)
 lab.get_window().content_scale_size=Vector2i(960,720)
 await get_tree().process_frame
 lab.select_tool(lab.Tool.MIRROR)
 press(4,Vector2(565,285),true);drag(4,Vector2(600,285))
 for n in range(90):lab._physics_process(1./60)
 check(absf(lab.hands[0].desired.x+lab.hands[1].desired.x)<.002,"espelho")
 press(4,Vector2(600,285),false)
 lab.select_tool(lab.Tool.MULTI)
 press(8,Vector2(615,275),true);press(3,Vector2(310,330),true)
 drag(8,Vector2(580,270));drag(3,Vector2(350,400))
 lab._physics_process(1./60)
 check(lab.owners.get(8)==0 and lab.owners.get(3)==1,"IDs estáveis")
 check(lab.independent[0].y>lab.independent[1].y,"alturas independentes")
 var rail_pos:Vector2=lab.rail.get_global_rect().get_center()
 press(6,rail_pos,true);drag(6,rail_pos+Vector2(0,20));press(6,rail_pos,false)
 check(lab.depth_by_hand[0]!=lab.depth_by_hand[1],"profundidade por mão")
 press(8,Vector2(580,270),false);press(3,Vector2(350,400),false)
 lab.camera_mode()
 var original:float=lab.zoom_size
 press(1,Vector2(330,330),true);press(2,Vector2(530,330),true)
 drag(2,Vector2(630,330))
 check(lab.zoom_size<original,"pinça")
 press(2,Vector2(630,330),false)
 var yaw_:float=lab.yaw
 drag(1,Vector2(370,335))
 check(lab.yaw!=yaw_,"órbita")
 press(1,Vector2(370,335),false)
 lab.select_tool(lab.Tool.RIGHT)
 lab.hands[0].global_position=lab.wrist("PalmR")
 lab.toggle_grip();check(lab.held.get(0)=="PalmR","segurar punho")
 lab._physics_process(1./60)
 check(lab.solver.reach_targets.has("R"),"IK de mão")
 lab.toggle_grip();check(lab.held.is_empty() and lab.solver.reach_targets.is_empty(),"soltar punho")
 lab.hands[0].global_position=lab.candy.global_position
 lab.toggle_grip();check(lab.held.get(0)=="candy","agarrar pirulito")
 lab.toggle_grip();check(lab.held.is_empty(),"soltar pirulito")
 print("mobile touch checks, failures = ",failures)
 lab.queue_free()
 var label:=Label.new()
 add_child(label)
 label.position=Vector2(18,24)
 label.text="Teste sintético: OK" if failures==0 else "Falhas: "+" / ".join(errors)
