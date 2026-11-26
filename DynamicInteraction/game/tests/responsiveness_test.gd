extends SceneTree

const Prefs=preload("res://direct/preferences.gd")
const Grip=preload("res://direct/grip_physics.gd")
var failures:=0
var lab

func _initialize()->void:call_deferred("run")

func check(condition:bool,title:String)->void:
 if not condition:
  failures+=1
  push_error(title)

func ticks(n:int)->void:
 for i in n:lab._physics_process(1./60.)

func compare_rigid()->void:
 var starts:Dictionary={}
 for name_ in ["Leve","Natural","Resistente"]:
  lab.reset()
  lab.prefs.select_profile(name_)
  var origin:Vector3=lab.cart.global_position
  var screen:Vector2=lab.camera.unproject_position(origin)
  check(lab.begin(1,screen),"seleção do bloco "+name_)
  var shift:Vector2=lab.camera.unproject_position(origin+Vector3(.155,0,0))-screen
  lab.move(1,screen+shift)
  ticks(10)
  starts[name_]=lab.cart_x
  check(lab.cart_x>.015 and lab.cart_x<.20,"resposta curta sem salto "+name_)
  lab.clear_grips()
  lab.reset()
  var left:Vector2=lab.camera.unproject_position(origin-Vector3.RIGHT*.10)
  var right:Vector2=lab.camera.unproject_position(origin+Vector3.RIGHT*.10)
  lab.begin(4,left)
  lab.begin(5,right)
  lab.move(4,left-Vector2(240,0))
  lab.move(5,right+Vector2(240,0))
  ticks(45)
  check(absf(lab.cart_x)<.004 and lab.grips.size()==2,"equilíbrio oposto "+name_)
  lab.release(4,left,false)
  ticks(80)
  check(absf(lab.cart_x-lab.RAIL_MAX)<.0001 and is_zero_approx(lab.cart_speed),"batente preservado "+name_)
  lab.release(5,right,false)
 check(starts.Leve>starts.Natural+.008 and starts.Natural>starts.Resistente+.008,"ordem de resposta dos perfis")
 print("Trilho aos 167 ms (m): ",starts)

func compare_body()->void:
 var distances:Dictionary={}
 for name_ in ["Leve","Natural","Resistente"]:
  lab.mobile_reset()
  lab.prefs.select_profile(name_)
  lab.select_tool(lab.Tool.RIGHT)
  lab.set_grab_mode(true)
  ticks(110)
  var rest:Vector3=lab.wrist("PalmR")
  var original:Vector2=lab.camera.unproject_position(rest)
  check(lab.begin_direct(2,original),"toque no punho "+name_)
  if not lab.touches.has(0):continue
  var bound:Dictionary=lab.touches[0]
  check(bound.name=="Mão D","mão selecionada "+name_)
  lab.move_direct(2,original+Vector2(45,-10))
  ticks(10)
  distances[name_]=lab.wrist("PalmR").distance_to(rest)
  check(float(distances[name_])>.020,"reação imediata do punho "+name_)
  lab.move_direct(2,original+Vector2(385,0))
  ticks(40)
  check(lab.links.has(0),"vínculo resiste ao limite "+name_)
  check(Vector3(bound.point).distance_to(bound.physical)>.27,"mão física restringida "+name_)
  var anchor:Dictionary=lab.picker.track(bound.hit)
  check(lab.hands[0].tips[1].global_position.distance_to(anchor.p)<.004,"mão não acompanha dedo para longe "+name_)
  check(lab.solver.bend[1]>=14.9 and lab.solver.bend[1]<=120.1,"cotovelo limitado "+name_)
  lab.end_direct(2,original,false)
  ticks(180)
  check(lab.wrist("PalmR").distance_to(rest)<.036,"recuperação corporal "+name_)
 if distances.size()==3:
  check(distances.Leve>distances.Resistente+.009,"resposta diferenciada no corpo")
 print("Punho aos 167 ms (m): ",distances)

func compare_fabric()->void:
 var measurements:Dictionary={}
 for name_ in ["Leve","Natural","Resistente"]:
  lab.prefs.select_profile(name_)
  lab.reset_fabric()
  for i in 300:lab.simulate(1./120.)
  var hit:Dictionary={}
  for f in range(0,lab.indices.size(),3):
   if lab.groups[f/3]!="Amostra":continue
   var center:Vector3=(lab.pos[lab.indices[f]]+lab.pos[lab.indices[f+1]]+lab.pos[lab.indices[f+2]])/3.
   if center.y>.14 or center.y<.02:continue
   var sample:Dictionary=lab.pick(lab.cam.unproject_position(center))
   if sample.get("name","")=="Amostra":hit=sample;break
  check(not hit.is_empty(),"seleciona amostra "+name_)
  if hit.is_empty():continue
  lab.holds[6]=hit
  for i in 60:lab.simulate(1./120.)
  hit.screen=hit.start+Vector2(120,18)
  for i in 20:lab.simulate(1./120.)
  var contact:=Vector3.ZERO
  for j in 3:contact+=Vector3(lab.pos[lab.indices[int(hit.f)+j]])*float(hit.bary[j])
  measurements[name_]=contact.distance_to(hit.base)
  check(float(measurements[name_])>.045,"deforma durante a puxada "+name_)
  lab.holds.clear()
  for j in 275:lab.simulate(1./120.)
  var max_step:=0.
  for j in lab.pos.size():
   var point:Vector3=lab.pos[j]
   max_step=maxf(max_step,point.distance_to(lab.last[j]))
   if lab.pinned.has(j):check(point==lab.rest[j],"pino de tecido permanece fixo")
  check(max_step<.004,"tecido desacelera depois de soltar "+name_)
 if measurements.size()==3:
  check(absf(measurements.Leve-measurements.Resistente)>.001,"perfis alteram a deformação")
 print("Amostra aos 167 ms (m): ",measurements)

func preferences_test()->void:
 var temporary:="user://rose_preferences_test_%d.cfg"%Time.get_ticks_usec()
 var prefs:=Prefs.new(temporary,"")
 prefs.select_profile("Leve")
 prefs.set_value("Atrito",1.7)
 prefs.select_profile("Personalizada")
 prefs.set_value("Rigidez",67.)
 prefs.set_value("Massa (kg)",.65)
 check(prefs.save()==OK,"grava perfis")
 var loaded:=Prefs.new(temporary,"")
 check(loaded.active_profile=="Personalizada" and is_equal_approx(loaded.values["Massa (kg)"],.65),"perfil ativo restaurado")
 loaded.select_profile("Leve")
 check(is_equal_approx(loaded.values["Atrito"],1.7) and is_equal_approx(loaded.values.Rigidez,64.),"ajuste individual preservado")
 loaded.select_profile("Natural")
 check(is_equal_approx(loaded.values["Atrito"],2.1),"outros perfis preservados")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
 var v:=Prefs.preset("Natural")
 var slight:=Grip.traction(Vector3.RIGHT*.04,Vector3.ZERO,Vector3.ZERO,v).length()
 var stronger:=Grip.traction(Vector3.RIGHT*.24,Vector3.ZERO,Vector3.ZERO,v).length()
 check(stronger/.24>slight/.04+.1,"mola progressiva")
 check(Grip.traction(Vector3.RIGHT*10.,Vector3.ZERO,Vector3.ZERO,v).length()<=Grip.force_limit(v)+.001,"teto da força")

func run()->void:
 preferences_test()
 lab=load("res://direct/constraint_lab.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_physics_process(false)
 compare_rigid()
 lab.queue_free()
 await process_frame
 lab=load("res://direct_touch.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_physics_process(false)
 compare_body()
 lab.queue_free()
 await process_frame
 lab=load("res://direct/fabric.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_physics_process(false)
 compare_fabric()
 print("Responsividade e perfis · falhas: ",failures)
 quit(failures)
