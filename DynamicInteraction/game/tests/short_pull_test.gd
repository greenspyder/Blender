extends SceneTree
const Short=preload("res://direct/short_pull.gd")
const Garment=preload("res://direct/garment_pull.gd")
var lab
var failed:=0

func _initialize()->void:call_deferred("run")

func check(ok:bool,label_:String)->void:
 if not ok:
  failed+=1
  push_error(label_)

func step(n:=1)->void:
 for i in n:lab._physics_process(1./60.)

func wait_for(state:int,limit:int)->bool:
 for i in limit:
  if lab.shorts.state==state:return true
  step()
 return lab.shorts.state==state

func touch(id:int,point:Vector2,down:bool,canceled:=false)->void:
 var event:=InputEventScreenTouch.new()
 event.index=id
 event.position=point
 event.pressed=down
 event.canceled=canceled
 root.push_input(event,true)

func drag(id:int,point:Vector2)->void:
 var event:=InputEventScreenDrag.new()
 event.index=id
 event.position=point
 root.push_input(event,true)

func click(point:Vector2)->void:
 for down in [true,false]:
  var event:=InputEventMouseButton.new()
  event.position=point
  event.button_index=MOUSE_BUTTON_LEFT
  event.pressed=down
  root.push_input(event,true)

func waist()->Variant:
 # O mesmo seletor de triângulos usado no jogo, no painel visível do cós.
 for part in lab.picker.surfaces:
  if part.node.name!="Shorts":continue
  lab.picker.update_surface(part)
  for f in range(0,part.indices.size(),3):
   var original:Vector3=(part.vertices[part.indices[f]]+part.vertices[part.indices[f+1]]+part.vertices[part.indices[f+2]])/3.
   if original.y<1.11:continue
   var world:Vector3=(lab.picker.vertex(part,part.indices[f])+lab.picker.vertex(part,part.indices[f+1])+lab.picker.vertex(part,part.indices[f+2]))/3.
   var p:Vector2=lab.camera.unproject_position(world)
   if not lab.blocked(p) and Short.contains_hit(lab.picker.cast(lab.camera,p,0.)):return p
 return null

func run()->void:
 lab=load("res://direct_touch.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_physics_process(false)
 lab.set_control_mode(lab.ControlMode.Mode.TOUCHSCREEN,false)
 lab.select_tool(lab.Tool.RIGHT)
 lab.set_grab_mode(true)
 step(60)
 var part:MeshInstance3D=lab.get_node("Rose/Portrait").find_child("Shorts",true,false)
 var dress:MeshInstance3D=lab.get_node("Rose/Portrait").find_child("Dress",true,false)
 var sole:MeshInstance3D=lab.get_node("Rose/Portrait").find_child("Slipper",true,false)
 var p:Variant=waist()
 check(p!=null,"cós acessível pela frente")
 if p==null:quit(1);return
 touch(5,p,true)
 check(lab.touches.get(0,{}).get("waist",false),"pressão reconhece o cós")
 drag(5,p+Vector2(0,-240));step(20)
 check(lab.shorts.state==Garment.State.WORN,"puxada para cima não retira o short")
 touch(5,p,false)
 p=waist()
 touch(6,p,true)
 drag(6,p+Vector2(0,62));step(18)
 check(lab.shorts.state==Garment.State.PULLING and lab.shorts.global_position.y<1.12,"puxada curta inicia a descida")
 touch(6,p+Vector2(0,62),false)
 check(wait_for(Garment.State.WORN,110),"soltura cedo devolve o short")
 p=waist()
 touch(7,p,true)
 drag(7,p+Vector2(0,260))
 step(25)
 check(lab.shorts.state==Garment.State.PULLING and lab.shorts.lowest_world_y()>.034,"a malha permanece acima do piso")
 check(lab.hands[0].tips[1].global_position.distance_to(lab.shorts.global_position)<.004,"mão segue o cós")
 check(wait_for(Garment.State.HELD,145),"tecido passa pelos pés e fica na mão")
 check("Short" in lab.removed and "Camisola" not in lab.removed and dress.visible and sole.visible,"retirada preserva a camisola e as pantufas")
 touch(7,p+Vector2(0,260),false)
 check(wait_for(Garment.State.RESTING,300) and lab.shorts.meshes.size()==3,"short e bolsos ficam no chão")
 var restore:Vector2=lab.garment_button.get_global_rect().get_center()
 touch(8,restore,true)
 touch(8,restore,false)
 check(wait_for(Garment.State.WORN,245) and part.visible and lab.removed.is_empty(),"recolocar restaura por toque")
 lab.set_control_mode(lab.ControlMode.Mode.DESKTOP,false)
 lab.yaw=PI
 lab.update_camera()
 step(8)
 var back:Variant=waist()
 check(back!=null,"cós acessível também por trás")
 if back!=null:
  click(back)
  var motion:=InputEventMouseMotion.new()
  motion.position=back+Vector2(0,260)
  motion.relative=Vector2(0,260)
  root.push_input(motion,true)
  check(wait_for(Garment.State.HELD,210),"trajeto completo com mouse e vista traseira")
  click(back)
  check(lab.shorts.state in [Garment.State.FALLING,Garment.State.RESTING],"clique solta o short")
  lab.mobile_reset()
  check(lab.shorts.state==Garment.State.WORN and part.visible,"reinício devolve o short")
 print("Retirada do short · falhas: ",failed)
 quit(failed)
