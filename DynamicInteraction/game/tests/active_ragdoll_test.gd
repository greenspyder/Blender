extends SceneTree
const Lab=preload("res://rig/active/lab.tscn")
var lab
var failures:=PackedStringArray()
var ticks:Array[float]=[]
var max_gap:=0.
var max_penetration:=0.
var max_energy:=0.
var bilateral:=0
var left_only:=0
var right_only:=0
var low:=INF
var high:=-INF
var peak_z:=-INF
var peak_lean:=-INF
var seat_samples:=0
var last_energy:=0.
var outside_seen:=false

func _initialize()->void:call_deferred("run")

func check(ok:bool,message:String)->void:
 if not ok and message not in failures:failures.append(message)

func sample(count_:int)->void:
 bilateral=0
 left_only=0
 right_only=0
 low=INF
 high=-INF
 peak_z=-INF
 peak_lean=-INF
 seat_samples=0
 outside_seen=false
 for i in roundi(count_*Engine.physics_ticks_per_second/60.):
  await physics_frame
  var core=lab.core
  var left:bool="foot_l" in core.active_support
  var right:bool="foot_r" in core.active_support
  if left and right:bilateral+=1
  elif left:left_only+=1
  elif right:right_only+=1
  if "pelvis" in core.active_support:seat_samples+=1
  low=minf(low,core.com.y)
  high=maxf(high,core.com.y)
  peak_z=maxf(peak_z,core.com.z)
  peak_lean=maxf(peak_lean,core.bodies.head.global_position.z-core.bodies.pelvis.global_position.z)
  max_gap=maxf(max_gap,core.max_gap)
  var energy:=0.
  for role in core.bodies:
   var b:RigidBody3D=core.bodies[role]
   var setting:int=lab.muscles.group(role)
   check(b.global_position.is_finite() and b.angular_velocity.is_finite(),"coordenadas finitas")
   check(Vector3(core.applied_force.get(role,Vector3.ZERO)).length()<=lab.muscles.max_force[setting]+.01,"teto de força")
   check(Vector3(core.applied_torque.get(role,Vector3.ZERO)).length()<=lab.muscles.max_torque[setting]+.01,"teto de torque motor")
   energy+=b.mass*b.linear_velocity.length_squared()*.5
   var inverse:=b.get_inverse_inertia_tensor()
   if absf(inverse.determinant())>.000001:
    energy+=.5*b.angular_velocity.dot(inverse.inverse()*b.angular_velocity)
   if role.begins_with("foot"):
    var box:BoxShape3D=b.get_child(0).shape
    for x in [-.5,.5]:
     for z in [-.5,.5]:
      var corner:=b.to_global(box.size*Vector3(x,-.5,z))
      max_penetration=maxf(max_penetration,-corner.y)
  last_energy=energy
  outside_seen=outside_seen or lab.physical_support=="COM fora da base"
  max_energy=maxf(max_energy,energy)
  ticks.append(lab.tick_us/1000.)

func run()->void:
 lab=Lab.instantiate()
 root.add_child(lab)
 if not lab.ready_to_pose:quit(1);return
 var core=lab.core
 var total:=0.
 for b in core.bodies.values():total+=b.mass
 check(core.bodies.size()==16 and core.joints.size()==15 and absf(total-lab.profile.mass_kg)<.01,"montagem e massa")
 await sample(160)
 var standing:float=core.com.y
 check(last_energy<1.,"repouso sem acúmulo de energia")
 check(standing>.85 and bilateral>140 and core.rms<.08,"repouso sustentado")
 print("Repouso COM %.3f m; RMS %.1f mm; %d ticks bilaterais"%[standing,core.rms*1000,bilateral])
 lab.select_move(1)
 await sample(240)
 print("Marcha E %d D %d; avanço máximo %.3f m"%[left_only,right_only,peak_z])
 check(mini(left_only,right_only)>20 and peak_z>.25,"marcha com apoios alternados e avanço físico")
 lab.select_move(2)
 await sample(180)
 check(low<standing-.12 and high-low>.13,"agachar e estender")
 lab.select_move(3)
 await sample(180)
 check(peak_lean>.12,"inclinação física do tronco")
 lab.select_move(6)
 await sample(180)
 check(core.com.y<standing-.15 and seat_samples>20,"sentar com apoio físico da pelve")
 lab.select_move(7)
 await sample(240)
 var fallen:float=core.com.y
 check(outside_seen,"perda de equilíbrio no polígono físico")
 check(last_energy<max_energy*.10,"dissipação após a queda")
 check(core.state==3 and fallen<standing*.45,"queda sob gravidade")
 for role in core.bodies:
  check(Vector3(core.applied_force[role]).is_zero_approx() and Vector3(core.applied_torque[role]).is_zero_approx(),"passivo sem motor")
 lab.select_move(0)
 lab.select_state(4)
 await sample(240)
 check(core.com.y>standing*.85 and core.rms<.14,"recuperação desde o piso")
 print("Após queda %.3f m; após Recovery %.3f m; RMS %.1f mm"%[fallen,core.com.y,core.rms*1000])
 var prior:Vector3=core.bodies.pelvis.position
 for state in [0,2,1]:
  lab.select_state(state)
  check(prior.is_equal_approx(core.bodies.pelvis.position),"troca não teleporta")
  await sample(60)
  prior=core.bodies.pelvis.position
 lab.apply_preset(0)
 check(core.settings.stiffness[0]>lab.original.stiffness[0],"preset rígido")
 lab.apply_preset(2)
 check(core.settings.stiffness[0]<lab.original.stiffness[0],"preset relaxado")
 lab.edit_value(97,0)
 lab.apply_preset(1)
 lab.apply_preset(3)
 check(core.settings.stiffness[0]==97,"personalizado mantém edição")
 var path:="user://ragdoll-test-%d.cfg"%OS.get_process_id()
 lab.save_custom(path)
 lab.custom=lab.original.duplicate(true)
 lab.read_custom(path)
 lab.apply_preset(3)
 check(lab.muscles.stiffness[0]==97,"persistência de parâmetros")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 check(max_penetration<.055 and max_gap<.13,"estabilidade geométrica sob impacto")
 ticks.sort()
 print("Pico de penetração da caixa do pé %.1f mm; desvio pele/junta %.1f mm; energia máxima %.1f J; controle mediana %.3f ms p95 %.3f ms"%[max_penetration*1000,max_gap*1000,max_energy,ticks[ticks.size()/2],ticks[int(ticks.size()*.95)]])
 print("Active Ragdoll · falhas ",failures.size()," ",failures)
 quit(0 if failures.is_empty() else 1)
