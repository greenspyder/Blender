extends SceneTree
const Strap=preload("res://direct/strap.gd")
var lab
var failed:=0
const CAMISOLA:="Camisola"
const Garment=preload("res://direct/garment_pull.gd")

func _initialize()->void:call_deferred("run")

func check(condition:bool, title:String)->void:
 if not condition:
  failed+=1
  push_error(title)

func touch(id:int,p:Vector2,down:bool,canceled:=false)->void:
 var e:=InputEventScreenTouch.new()
 e.index=id
 e.position=p
 e.pressed=down
 e.canceled=canceled
 root.push_input(e,true)

func drag(id:int,p:Vector2)->void:
 var e:=InputEventScreenDrag.new()
 e.index=id
 e.position=p
 root.push_input(e,true)

func step(n:=2)->void:
 for i in n:lab._physics_process(1./60)

func visible_strap()->Variant:
 for s in lab.picker.surfaces:
  if s.node.name!="Dress" or s.surface_index!=1:continue
  lab.picker.update_surface(s)
  for f in range(0,s.indices.size(),3):
   var bind:Vector3=(s.vertices[s.indices[f]]+s.vertices[s.indices[f+1]]+s.vertices[s.indices[f+2]])/3.
   if not Strap.in_strap(bind) or bind.y<1.61:continue
   var p:Vector3=(lab.picker.vertex(s,s.indices[f])+lab.picker.vertex(s,s.indices[f+1])+lab.picker.vertex(s,s.indices[f+2]))/3.
   var screen:Vector2=lab.camera.unproject_position(p)
   if lab.blocked(screen):continue
   if Strap.contains_hit(lab.picker.cast(lab.camera,screen,0)):return screen
 return null

func run()->void:
 lab=load("res://direct_touch.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_control_mode(lab.ControlMode.Mode.TOUCHSCREEN,false)
 lab.set_physics_process(false)
 lab.select_tool(lab.Tool.RIGHT)
 lab.set_grab_mode(true)
 step(40)
 var dress:MeshInstance3D=lab.get_node("Rose/Portrait").find_child("Dress",true,false)
 var bow:MeshInstance3D=lab.get_node("Rose/Portrait").find_child("Ribbon",true,false)
 var shorts:MeshInstance3D=lab.get_node("Rose/Portrait").find_child("Shorts",true,false)
 for yaw in [0.0,.42,-.42]:
  lab.yaw=yaw
  lab.update_camera()
  check(visible_strap()!=null,"alça visível em ângulo "+str(yaw))
 lab.yaw=0.
 lab.update_camera()
 var p:Variant=visible_strap()
 if p==null:quit(1);return
 var near:Variant=null
 for y in [-5,-9,5,9,0]:
  for x in [-8,8,-12,12]:
   var shifted:Vector2=p+Vector2(x,y)
   var raw:Dictionary=lab.picker.cast(lab.camera,shifted,0)
   if Strap.contains_hit(raw):continue
   if Strap.contains_hit(Strap.nearby(lab.picker,lab.camera,shifted,raw)):
    near=shifted
    break
  if near!=null:break
 check(near!=null,"tolerância encontra a alça com raio central fora")
 if near!=null:p=near
 var wardrobe=lab.garment
 var right_before:Vector3=lab.wrist("PalmR")
 var left_before:Vector3=lab.wrist("PalmL")
 touch(1,p,true)
 check(lab.links.has(0) and lab.touches[0].strap,"modo Agarrar reconhece alça")
 drag(1,p+Vector2(0,210))
 touch(1,p+Vector2(0,210),false)
 step()
 check(dress.visible and wardrobe.state==Garment.State.WORN,"puxão para baixo não retira")
 p=visible_strap()
 touch(2,p,true)
 drag(2,p+Vector2(0,-70))
 step(16)
 check(wardrobe.state==Garment.State.PULLING and wardrobe.progress>.2,"puxão curto deforma a peça")
 check(not dress.visible and wardrobe.meshes.size()==2,"camisola e laço continuam renderizáveis")
 touch(2,p+Vector2(0,-70),false)
 step(42)
 check(dress.visible and wardrobe.state==Garment.State.WORN,"puxão incompleto volta a vestir")
 p=visible_strap()
 touch(3,p,true)
 drag(3,p+Vector2(0,-210))
 step(9)
 touch(3,p+Vector2(0,-210),false,true)
 step(42)
 check(dress.visible and lab.links.is_empty(),"cancelamento durante a subida retorna")
 p=visible_strap()
 touch(4,p,true)
 var origin:Vector3=lab.touches[0].anchor
 drag(4,p+Vector2(0,-210))
 step(22)
 check(wardrobe.state==Garment.State.PULLING and wardrobe.progress<1.,"gesto passa por estados intermediários")
 var lift_r:float=lab.wrist("PalmR").y-right_before.y
 var lift_l:float=lab.wrist("PalmL").y-left_before.y
 check(maxf(lift_r,lift_l)>.35,"braço acompanha a subida")
 check((lift_r>lift_l)==(wardrobe.side>0.),"braço do lado da alça começa primeiro")
 check(lab.hands[0].tips[1].global_position.distance_to(wardrobe.global_position)<.004,"mão fica na alça em movimento")
 check(wardrobe.global_position.distance_to(origin)>.20,"peça se desloca visivelmente")
 step(22)
 check(wardrobe.state==Garment.State.HELD and lab.links.has(0),"continua agarrada depois de desvestir")
 check(not dress.visible and not bow.visible and shorts.visible,"apenas camisola e laço foram movidos")
 var airtime:Vector3=wardrobe.global_position
 drag(4,p+Vector2(110,-260))
 step(12)
 check(wardrobe.global_position.distance_to(airtime)>.015,"peça livre acompanha a mão")
 touch(4,p+Vector2(110,-260),false)
 step(130)
 check(wardrobe.state==Garment.State.RESTING and wardrobe.meshes.size()==2,"peça repousa no chão, ainda presente")
 check(absf(wardrobe.lowest_world_y()-wardrobe.FLOOR_Y)<.004,"repouso encosta no chão")
 check(lab.links.is_empty() and lab.fingers.is_empty() and lab.removed.count(CAMISOLA)==1,"retirada registrada uma vez")
 check(lab.wrist("PalmR").distance_to(right_before)<.07 and lab.wrist("PalmL").distance_to(left_before)<.07,"braços se recuperam")
 var button_center:Vector2=lab.garment_button.get_global_rect().get_center()
 touch(5,button_center,true)
 touch(5,button_center,false)
 step(13)
 check(wardrobe.state==Garment.State.DRESSING and wardrobe.meshes.size()==2,"recolocar começa com a mesma peça")
 step(80)
 check(dress.visible and bow.visible and shorts.visible and wardrobe.meshes.is_empty(),"gesto de recolocar restaura a peça vestida")
 check(lab.removed.is_empty(),"estado da roupa restaurado")
 p=visible_strap()
 if p!=null:
  touch(6,p,true)
  drag(6,p+Vector2(0,-210))
  touch(6,p+Vector2(0,-210),false)
  step(40)
  check(not dress.visible and wardrobe.state in [Garment.State.FALLING,Garment.State.RESTING],"soltura rápida conclui a animação")
  lab.mobile_reset()
  step()
  check(dress.visible and lab.removed.is_empty() and wardrobe.meshes.is_empty(),"reinício restaura a roupa")
 else:
  check(false,"alça voltando a ser selecionável após recolocar")
 print("Gesto da alça · falhas: ",failed)
 quit(failed)
