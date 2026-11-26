extends SceneTree
const Strap=preload("res://direct/strap.gd")
var lab
var failed:=0
const CAMISOLA:="Camisola"

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
 touch(1,p,true)
 check(lab.links.has(0) and lab.touches[0].strap,"modo Agarrar reconhece alça")
 drag(1,p+Vector2(0,15))
 touch(1,p+Vector2(0,15),false)
 check(dress.visible,"puxão curto conserva a roupa")
 touch(2,p,true)
 drag(2,p+Vector2(0,105))
 check(lab.notice.begins_with("Solte"),"feedback para confirmar")
 touch(2,p+Vector2(0,105),false,true)
 check(dress.visible and lab.links.is_empty(),"cancelamento não retira")
 touch(3,p,true)
 drag(3,p+Vector2(0,105))
 step()
 touch(3,p+Vector2(0,105),false)
 step()
 check(not dress.visible and not bow.visible and shorts.visible,"retira só a camisola e seu laço")
 check(lab.base_layer.visible and lab.base_layer.fabric.get_shader_parameter("top_visible"),"camada interna aparece")
 check(lab.links.is_empty() and lab.fingers.is_empty() and lab.removed.count(CAMISOLA)==1,"vínculo encerrado e remoção única")
 var button_center:Vector2=lab.garment_button.get_global_rect().get_center()
 touch(4,button_center,true)
 touch(4,button_center,false)
 step()
 check(dress.visible and bow.visible and shorts.visible and not lab.base_layer.visible,"recolocar pelo botão touchscreen")
 check(lab.removed.is_empty(),"estado da roupa restaurado")
 # O reinício deve restaurar a roupa e a seleção também.
 var exact:Variant=visible_strap()
 if exact!=null:
  touch(5,exact,true)
  drag(5,exact+Vector2(0,105))
  touch(5,exact+Vector2(0,105),false)
  check(not dress.visible,"segundo gesto funciona")
  lab.mobile_reset()
  step()
  check(dress.visible and lab.removed.is_empty() and not lab.base_layer.visible,"reinício restaura a roupa")
 else:
  check(false,"alça voltando a ser selecionável após recolocar")
 print("Gesto da alça · falhas: ",failed)
 quit(failed)
