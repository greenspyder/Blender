extends SceneTree
var failed:=0
var lab
func _initialize()->void:call_deferred("run")

func check(condition:bool, title:String)->void:
 if not condition:
  failed+=1
  push_error(title)

func touch(id:int, screen:Vector2, pressed:bool)->void:
 var event:=InputEventScreenTouch.new()
 event.index=id
 event.position=screen
 event.pressed=pressed
 root.push_input(event,true)

func drag(id:int, screen:Vector2)->void:
 var event:=InputEventScreenDrag.new()
 event.index=id
 event.position=screen
 root.push_input(event,true)

func step(n:int)->void:
 for i in n:lab._physics_process(1./60)

func run()->void:
 lab=load("res://direct/constraint_lab.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_physics_process(false)
 var origin:Vector3=lab.cart.global_position
 var first:Vector2=lab.camera.unproject_position(origin-Vector3.RIGHT*.11)
 var second:Vector2=lab.camera.unproject_position(origin+Vector3.RIGHT*.11)
 touch(2,first,true)
 touch(7,second,true)
 check(lab.grips.size()==2,"dois dedos no mesmo objeto")
 if lab.grips.size()==2:
  drag(2,first+Vector2.LEFT*210)
  drag(7,second+Vector2.RIGHT*210)
  step(90)
  check(lab.cart.global_position.distance_to(origin)<.005,"forças opostas equilibram o bloco")
  for g in lab.grips.values():
   check(Vector3(g.force).length()>10.,"tração existe nos dois lados")
   check(Vector3(g.anchor).distance_to(g.part.to_global(g.local))<.0001,"vínculo material persiste")
   check(Vector3(g.target).distance_to(g.anchor)>.3,"mão não persegue o dedo distante")
  touch(2,first,false)
  step(75)
  check(absf(lab.cart_x-lab.RAIL_MAX)<.0001 and absf(lab.cart_speed)<.0001,"batente impede atravessamento")
  check(lab.grips.size()==1 and lab.grips.has(7),"soltura independente")
  touch(7,second,false)
  check(lab.grips.is_empty(),"liberação final")
 lab.reset()
 var point:Vector2=lab.camera.unproject_position(lab.lever.global_position)
 touch(11,point,true)
 drag(11,point+Vector2.RIGHT*500)
 step(90)
 check(absf(lab.angle)>.45 and absf(lab.angle)<=lab.ANGLE_LIMIT,"dobradiça gira dentro dos limites")
 if lab.grips.has(11):
  var link:Dictionary=lab.grips[11]
  check(Vector3(link.anchor).distance_to(lab.lever.to_global(link.local))<.0001,"mão acompanha a rotação da alavanca")
 else:
  check(false,"vínculo articulado disponível")
 touch(11,point,false)
 step(160)
 check(is_finite(lab.angle) and absf(lab.spin)<.02,"atrito estabiliza após soltar")
 print("Bancada rígida e articulada · falhas: ",failed)
 quit(failed)
