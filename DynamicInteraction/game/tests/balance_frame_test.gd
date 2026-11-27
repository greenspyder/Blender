extends SceneTree

func _initialize()->void:call_deferred("run")

func run()->void:
 var lab:=preload("res://rig/balance_lab.tscn").instantiate()
 root.add_child(lab)
 for frame in 90:await physics_frame
 var ok:bool=lab.ready_to_pose and lab.balance.support_state=="Bilateral"
 var samples:=0
 lab.movement=1
 lab.elapsed=0.
 for frame in 180:
  await physics_frame
  if lab.balance.support_state=="Unilateral":samples+=1
  ok=ok and lab.solver.center_of_mass.is_finite()
 ok=ok and samples>60 and absf(lab.balance.velocity)<.75
 print("Ciclo da engine · 180 ticks de marcha · ",samples," unilaterais · ",ok)
 quit(0 if ok else 1)
