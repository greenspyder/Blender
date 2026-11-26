extends SceneTree
var failures:=0
func check(ok:bool,msg:String)->void:
 if not ok:
  failures+=1
  push_error(msg)
func _initialize()->void:call_deferred("run")
func run()->void:
 var lab=load("res://dynamic.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_physics_process(false)
 lab.change_mode(3)
 lab.depth=.09
 lab.pointer=lab.camera.unproject_position(Vector3(.185,1.59,.09))
 for i in range(240):lab._physics_process(1./60)
 check(lab.contacts[0].force>.1 and lab.contacts[1].force>.1,"dois contatos")
 check(abs(lab.hands[0].desired.x+lab.hands[1].desired.x)<.001,"espelho")
 check(lab.response.arms.x>.1 and lab.response.arms.y>.1,"dois ombros")
 check(lab.response.pose.length()<2 and lab.response.pose.is_finite(),"estabilidade")
 check(lab.face.get_blend_shape_value(lab.face.find_blend_shape_by_name("brow_up"))>.01,"expressão")
 lab.change_mode(1)
 for i in range(30):lab._physics_process(1./60)
 check(not lab.hands[1].visible,"modo direito")
 lab.change_mode(2)
 for i in range(30):lab._physics_process(1./60)
 check(not lab.hands[0].visible and lab.hands[1].visible,"modo esquerdo")
 lab.change_mode(0)
 for i in range(240):lab._physics_process(1./60)
 check(lab.response.pose.length()<.002,"repouso")
 lab.toggle_lollipop()
 check(lab.candy.global_position.distance_to(lab.anchor.global_position)<.005,"pirulito")
 lab.yaw=1.2;lab.pitch=.3;lab.zoom_size=.8;lab.pivot_y=1.7;lab.update_camera()
 check(lab.camera.size==.8 or abs(lab.camera.size-.8)<.001,"zoom")
 if failures==0:print("PASS: simultâneo, espelho, braços, expressão, modos, estabilidade, retorno, encaixe, zoom")
 quit(failures)
