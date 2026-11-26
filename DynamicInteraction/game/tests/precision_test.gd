extends SceneTree
var failures:=0
func check(ok:bool,msg:String)->void:
 if not ok:
  failures+=1
  push_error(msg)
func _initialize()->void:call_deferred("run")
func run()->void:
 var lab=load("res://precision_lab.tscn").instantiate()
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
 var sweep=lab.Detector.sweep(Vector3(.245,1.59,.8),Vector3(.245,1.59,-.8),.01)
 check(not sweep.is_empty() and sweep.t<.5,"varredura rápida")
 check(lab.Detector.sweep(Vector3(3,2,1),Vector3(3,2,-1),.01).is_empty(),"fora da malha")
 var hand=lab.hands[0]
 check(hand.joints.size()==5 and hand.joints[1].size()==3,"15 juntas por mão")
 for pose in range(4):
  hand.pose_index=pose
  for i in range(50):lab._physics_process(1./60)
  check(abs(hand.joints[1][1].rotation.x+hand.CURL[pose][1]*1.05)<.01,"pose de dedo %s"%pose)
 var sk=lab.skeleton
 var wrist=sk.find_bone("PalmR")
 var start:Vector3=sk.get_bone_global_rest(wrist).origin
 var target:=start+Vector3(-.08,.05,.04)
 lab.set_reach_target("R",target)
 lab.set_look_target(Vector3(.4,1.9,1))
 for i in range(100):lab._physics_process(1./60)
 check(sk.get_bone_global_pose(wrist).origin.distance_to(target)<.025,"IK alcança o alvo")
 check(sk.get_bone_global_pose(sk.find_bone("Head")).basis!=sk.get_bone_global_rest(sk.find_bone("Head")).basis,"olhar")
 lab.set_reach_target("R",null)
 lab.set_look_target(null)
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
