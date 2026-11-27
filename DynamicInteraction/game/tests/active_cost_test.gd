extends SceneTree
## Compara as bancadas no mesmo processo. Rodar com --fixed-fps 60.
func _initialize()->void:call_deferred("run")
func run()->void:
 for path in ["res://rig/balance_lab.tscn","res://rig/active/lab.tscn"]:
  var lab=load(path).instantiate()
  root.add_child(lab)
  if not lab.ready_to_pose:quit(1);return
  lab.movement=1
  for i in 120:await physics_frame
  var rate:=Engine.physics_ticks_per_second
  var count_:=rate*6
  var start:=Time.get_ticks_usec()
  for i in count_:await physics_frame
  var ms:=(Time.get_ticks_usec()-start)*.001
  print("%s · %d Hz · %.3f ms/tick · %.1f ms host/s simulado"%[path,rate,ms/count_,ms/6.])
  lab.free()
  await process_frame
 quit(0)
