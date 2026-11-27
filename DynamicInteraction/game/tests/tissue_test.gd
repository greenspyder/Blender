extends SceneTree
var lab
var failed:=0
var body:Dictionary
func _initialize()->void:call_deferred("run")

func check(ok:bool,label_:String)->void:
 if not ok:
  failed+=1
  push_error(label_)

func ticks(n:int)->void:
 for i in n:lab._physics_process(1./60.)

func pointer(id:int,screen:Vector2,down:bool)->void:
 var event:=InputEventScreenTouch.new()
 event.index=id
 event.position=screen
 event.pressed=down
 root.push_input(event,true)

func drag(id:int,screen:Vector2)->void:
 var event:=InputEventScreenDrag.new()
 event.index=id
 event.position=screen
 root.push_input(event,true)

func mouse_click(screen:Vector2)->void:
 for down in [true,false]:
  var event:=InputEventMouseButton.new()
  event.position=screen
  event.button_index=MOUSE_BUTTON_LEFT
  event.pressed=down
  root.push_input(event,true)

func surface_point(region:int,node_names:Array)->Variant:
 var center:Vector3=lab.SoftTissue.AREAS[region/2].center
 if region%2==1:center.x=-center.x
 var screen:Vector2=lab.camera.unproject_position(center)
 for offset in [Vector2.ZERO,Vector2(0,8),Vector2(0,-8),Vector2(9,0),Vector2(-9,0),Vector2(0,17),Vector2(0,-17),Vector2(17,0),Vector2(-17,0)]:
  var p:=screen+Vector2(offset)
  if lab.blocked(p):continue
  var hit:Dictionary=lab.picker.cast(lab.camera,p,0)
  if lab.tissue.region_for_hit(hit)==region and str(hit.surface.node.name) in node_names:return p
 return null

func body_displacement(probe:Vector3)->Vector3:
 var pick:=-1
 var best:=INF
 for i in body.vertices.size():
  var distance:=Vector3(body.vertices[i]).distance_squared_to(probe)
  if distance<best:
   best=distance
   pick=i
 lab.picker.update_surface(body)
 var after:Vector3=lab.picker.vertex(body,pick)
 # Refaça a pose com os mesmos ossos e os mesmos morphs gerais.
 var old:Array=body.active.duplicate()
 body.active=old.filter(func(m):return str(body.node.mesh.get_blend_shape_name(m[0])) not in ["chest_press","hip_press"] and not str(body.node.mesh.get_blend_shape_name(m[0])).begins_with("hip_press_") and not str(body.node.mesh.get_blend_shape_name(m[0])).begins_with("chest_press_"))
 var reference:Vector3=lab.picker.vertex(body,pick)
 body.active=old
 return after-reference

func run()->void:
 lab=load("res://direct_touch.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_physics_process(false)
 for surface in lab.picker.surfaces:
  if surface.node.name=="Body":body=surface;break
 lab.set_control_mode(lab.ControlMode.Mode.TOUCHSCREEN,false)
 lab.select_tool(lab.Tool.MULTI)
 lab.set_grab_mode(true)
 ticks(60)
 var p:Variant=surface_point(0,["Dress","Body"])
 var q:Variant=surface_point(1,["Dress","Body"])
 check(p!=null and q!=null,"dois lados acessíveis de frente")
 if p!=null and q!=null:
  pointer(10,p,true)
  pointer(12,q,true)
  check(lab.links.size()==2,"pegas independentes por eventos touchscreen")
  ticks(18)
  check(lab.tissue.weights[0].z>.1 and lab.tissue.weights[1].z>.1,"pressão inicial nos dois lados")
  drag(10,p+Vector2(45,-48))
  drag(12,q+Vector2(-32,34))
  ticks(32)
  var right:Vector3=lab.tissue.weights[0]
  var left:Vector3=lab.tissue.weights[1]
  check(right.y>.30 and left.y<-.20,"movimentos opostos por lado")
  check(right.z>.07 and left.z>.07,"pressão local continua durante o arraste")
  check(absf(lab.tissue.weights[2].length())<.001,"pressão frontal não ativa glúteo")
  var displacement:=body_displacement(Vector3(.085,1.54,.147))
  check(displacement.length()>.009,"vértice da malha deformado, além do peso do morph")
  check(lab.get_node("Rose/Portrait").find_child("Dress",true,false).get_blend_shape_value(body.node.find_blend_shape_by_name("chest_press"))>.05,"camisola acompanha")
  pointer(10,p,false)
  ticks(100)
  check(lab.tissue.weights[0].length()<.005 and lab.tissue.weights[1].length()>.15,"um lado recupera mesmo com o outro preso")
  pointer(12,q,false)
  ticks(110)
  check(lab.tissue.weights[1].length()<.005,"retorno amortecido")
  print("Deslocamento local dianteiro: %.1f mm"%[displacement.length()*1000.])
 lab.set_control_mode(lab.ControlMode.Mode.DESKTOP,false)
 lab.select_tool(lab.Tool.RIGHT)
 lab.yaw=PI
 lab.update_camera()
 ticks(10)
 var rear:Variant=surface_point(2,["Shorts","PocketR","Body"])
 check(rear!=null,"alvo traseiro acessível de costas")
 if rear!=null:
  mouse_click(rear)
  check(lab.links.size()==1,"pega pelo clique")
  var motion:=InputEventMouseMotion.new()
  motion.position=rear+Vector2(-28,-40)
  motion.relative=Vector2(-28,-40)
  root.push_input(motion,true)
  ticks(40)
  var displacement:=body_displacement(Vector3(.105,1.03,-.205))
  check(displacement.length()>.007 and lab.tissue.weights[2].z>.24,"glúteo e short respondem ao arraste")
  check(lab.get_node("Rose/Portrait").find_child("Shorts",true,false).get_blend_shape_value(body.node.find_blend_shape_by_name("hip_press"))>.05,"peso aplicado ao short")
  check(lab.tissue.weights[0].length()<.004,"contato traseiro não ativa peito")
  mouse_click(rear)
  ticks(100)
  check(lab.links.is_empty() and lab.tissue.weights[2].length()<.005,"soltar com mouse retorna")
  print("Deslocamento local traseiro: %.1f mm"%[displacement.length()*1000.])
 lab.set_control_mode(lab.ControlMode.Mode.TOUCHSCREEN,false)
 lab.set_grab_mode(false)
 var other_rear:Variant=surface_point(3,["Shorts","PocketL","Body"])
 check(other_rear!=null,"segundo lado traseiro acessível")
 if other_rear!=null:
  pointer(31,other_rear,true)
  ticks(28)
  check(lab.links.is_empty() and lab.tissue.weights[3].z>.13 and lab.tissue.weights[2].length()<.005,"toque simples pressiona só o lado escolhido")
  pointer(31,other_rear,false)
  ticks(100)
  check(lab.tissue.weights[3].length()<.005,"retorno após contato sem agarrar")
 lab.mobile_reset()
 for amount in lab.tissue.weights:check(amount.is_zero_approx(),"reinício zera os canais")
 print("Deformação de contato · falhas: ",failed)
 quit(failed)
