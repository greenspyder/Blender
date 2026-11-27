extends SceneTree
const TARGET_SCENE=preload("res://direct_touch.tscn")
const LAB_SCENE=preload("res://direct/articulation_lab.tscn")
var failures:=0
var game

func _initialize()->void:call_deferred("run")

func check(ok:bool,label_:String)->void:
 if not ok:
  failures+=1
  push_error(label_)

func run_steps(count:int)->void:
 for i in count:game._physics_process(1./60.)

func lengths_stable(suffix:String)->bool:
 var sk:Skeleton3D=game.skeleton
 for names in [["Upper"+suffix,"Fore"+suffix],["Fore"+suffix,"Palm"+suffix]]:
  var a:=sk.find_bone(names[0])
  var b:=sk.find_bone(names[1])
  var posed:=sk.get_bone_global_pose(a).origin.distance_to(sk.get_bone_global_pose(b).origin)
  var length:=sk.get_bone_global_rest(a).origin.distance_to(sk.get_bone_global_rest(b).origin)
  if absf(posed-length)>.0015:return false
 return true

func audit()->void:
 var sk:Skeleton3D=game.skeleton
 check(sk.get_bone_count()==9,"inventário exato do GLB desta versão")
 for pair in [["Spine","Base"],["Head","Spine"],["UpperL","Spine"],["ForeL","UpperL"],["PalmL","ForeL"],["UpperR","Spine"],["ForeR","UpperR"],["PalmR","ForeR"]]:
  var child:=sk.find_bone(pair[0])
  var parent:=sk.find_bone(pair[1])
  check(child>=0 and sk.get_bone_parent(child)==parent,"hierarquia "+pair[0])
 for limb in ["ThighL","ThighR","ShinL","ShinR","FootL","FootR","ClavicleL","ClavicleR"]:
  check(sk.find_bone(limb)<0,"osso não exportado "+limb)
 check(game.get_node("Rose/Portrait").find_children("*","AnimationPlayer",true,false).is_empty(),"GLB sem animação importada")

func gameplay()->void:
 game.set_control_mode(game.ControlMode.Mode.TOUCHSCREEN,false)
 game.select_tool(game.Tool.RIGHT)
 game.set_grab_mode(true)
 run_steps(75)
 var rest:Vector3=game.wrist("PalmR")
 var screen:Vector2=game.camera.unproject_position(rest)
 var end:Vector2=game.camera.unproject_position(rest+Vector3(.16,.98,.04))
 check(game.begin_direct(8,screen),"pega a mão real")
 check(game.links.has(0) and game.links[0].arm=="R","armadura vinculada à cadeia certa")
 var previous:=rest
 var max_step:=0.
 var extension_ok:=true
 for j in 36:
  game.move_direct(8,screen.lerp(end,float(j+1)/36.))
  run_steps(1)
  var p:Vector3=game.wrist("PalmR")
  max_step=maxf(max_step,p.distance_to(previous))
  previous=p
  extension_ok=extension_ok and lengths_stable("R") and game.solver.bend[1]>=game.solver.elbow_min-.1 and game.solver.bend[1]<=game.solver.elbow_max+.1
 run_steps(125)
 var up:Vector3=game.wrist("PalmR")
 check(up.y-rest.y>.82 and up.y>game.wrist("UpperR").y+.29,"punho alcança acima do ombro durante o gesto")
 check(max_step<.09 and extension_ok,"travessia fluida, sem esticar nem inverter a cadeia")
 check(game.hands[0].tips[1].global_position.distance_to(game.picker.track(game.touches[0].hit).p)<.004,"mão fica no ponto agarrado")
 game.move_direct(8,end+Vector2(220,-160))
 run_steps(120)
 check(game.solver.limited[1] and lengths_stable("R"),"limite anatômico ao estender demais")
 game.end_direct(8,end,false)
 run_steps(145)
 check(game.wrist("PalmR").distance_to(rest)<.045,"recuperação suave")
 print("Puxada pela mão D · punho subiu %.1f cm · maior passo %.1f cm"%[(up.y-rest.y)*100.,max_step*100.])

func laboratory(lab:Node)->void:
 game=lab.game
 var sk:Skeleton3D=game.skeleton
 lab.shoulder_l=134.
 lab.elbow_l=79.
 lab.shoulder_r=45.
 lab.elbow_r=38.
 lab.wrist_l=0.
 lab.spine_turn=0.
 for i in 125:lab._physics_process(1./60.)
 check(absf(game.solver.bend[0]-79.)<2.5 and absf(game.solver.bend[1]-38.)<2.5,"cotovelos independentes")
 check(game.solver.elevation[0]>game.solver.elevation[1]+55.,"elevação independente")
 check(lengths_stable("L") and lengths_stable("R"),"comprimentos dos dois braços")
 check(lab.lines.get_surface_count()==1,"ossos e alvos são desenhados")
 var palm:=sk.find_bone("PalmL")
 var initial:=sk.get_bone_global_pose(palm)
 lab.wrist_l=43.
 for i in 24:lab._physics_process(1./60.)
 var turned:=sk.get_bone_global_pose(palm)
 check(initial.basis.get_rotation_quaternion().angle_to(turned.basis.get_rotation_quaternion())>.61,"punho gira independentemente")
 check(initial.origin.distance_to(turned.origin)<.020,"torção do punho sem translado")
 var base:=sk.find_bone("Base")
 var spine:=sk.find_bone("Spine")
 var head:=sk.find_bone("Head")
 var base_before:=sk.get_bone_global_pose(base)
 var spine_before:=sk.get_bone_pose_rotation(spine)
 var head_before:=sk.get_bone_pose_rotation(head)
 lab.pelvis_cm=7.
 lab.spine_turn=19.
 lab.spine_tilt=13.
 lab.neck_turn=22.
 lab.neck_tilt=15.
 lab.knee_morph=35.
 lab.max_elbow=85.
 lab.elbow_l=125.
 for i in 125:lab._physics_process(1./60.)
 check(sk.get_bone_global_pose(base).origin.x-base_before.origin.x>.061,"controle da pelve")
 check(spine_before.angle_to(sk.get_bone_pose_rotation(spine))>.25,"coluna roda e inclina")
 check(head_before.angle_to(sk.get_bone_pose_rotation(head))>.27,"pescoço orienta a cabeça")
 check(absf(game.solver.bend[0]-85.)<1.8,"limite de cotovelo editável")
 for mesh in lab.knee_meshes:
  check(is_equal_approx(mesh.get_blend_shape_value(mesh.find_blend_shape_by_name("idle_knees")),.35),"referência visual de joelho, sem IK ausente")

func run()->void:
 game=TARGET_SCENE.instantiate()
 root.add_child(game)
 await process_frame
 game.set_physics_process(false)
 audit()
 gameplay()
 game.queue_free()
 await process_frame
 var lab:=LAB_SCENE.instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_physics_process(false)
 laboratory(lab)
 print("Articulações e IK · falhas: ",failures)
 quit(failures)
