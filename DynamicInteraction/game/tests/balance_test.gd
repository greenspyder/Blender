extends SceneTree
const Lab=preload("res://rig/balance_lab.tscn")
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label_:String)->void:
 if not ok:
  failures+=1
  push_error(label_)
func run()->void:
 for hz in [30,60,120]:
  var lab:=Lab.instantiate()
  root.add_child(lab)
  lab.set_physics_process(false)
  await physics_frame
  await physics_frame
  if not lab.ready_to_pose:quit(1);return
  var dt:=1./float(hz)
  var clock:=Time.get_ticks_usec()
  for i in 2*hz:lab._physics_process(dt)
  var balance=lab.balance
  var force:float=balance.loads.x+balance.loads.y
  check(balance.support_state=="Bilateral","duas solas no piso")
  check(absf(force-lab.profile.mass_kg*balance.gravity)<1.,"reação de repouso igual ao peso")
  check(balance.balance_state=="Estável","COM dentro da base")
  var still:Vector3=balance.contacts.l.point
  lab.movement=2
  for i in 2*hz:lab._physics_process(dt)
  check(still.distance_to(balance.contacts.l.point)<.002,"apoio permanece durante agachamento")
  lab.movement=1
  lab.elapsed=0.
  var singles:=0
  var drift:=0.
  var prev:Dictionary={}
  var penetration:=0.
  var sole_error:=0.
  var worst_tick_us:=0
  for i in 3*hz:
   var before:=Time.get_ticks_usec()
   lab._physics_process(dt)
   worst_tick_us=maxi(worst_tick_us,Time.get_ticks_usec()-before)
   if balance.contacts.size()==1:singles+=1
   var next:Dictionary={}
   for side in balance.contacts:
    var p:Vector3=balance.contacts[side].point
    next[side]=p
    if prev.has(side):drift=maxf(drift,p.distance_to(prev[side]))
    var actual:Vector3=lab.sk.to_global(lab.solver.pose("foot_"+side)*lab.profile.sole_offset)
    penetration=maxf(penetration,p.y-actual.y)
    sole_error=maxf(sole_error,Vector2(p.x-actual.x,p.z-actual.z).length())
   prev=next
  check(singles>hz,"caminhada libera pés alternados")
  check(drift<.004,"deriva da âncora durante apoio")
  check(sole_error<.025,"erro horizontal real da sola")
  check(penetration<.024,"limite de penetração na sola")
  lab.movement=4
  for i in hz:lab._physics_process(dt)
  check(balance.contacts.has("l") and not balance.contacts.has("r") and balance.loads.y==0.,"apoio esquerdo")
  lab.movement=5
  lab.elapsed=0.
  var lost:=false
  var recovering:=false
  for i in 4*hz:
   lab._physics_process(dt)
   lost=lost or balance.balance_state=="Perda de equilíbrio"
   recovering=recovering or balance.balance_state=="Recuperação"
  check(lost and recovering and balance.balance_state=="Estável","perda e recuperação")
  lab.movement=0
  balance.height+=.22
  lab._physics_process(dt)
  check(balance.contacts.is_empty() and balance.velocity<0.,"sem apoio cai sob gravidade")
  for i in 2*hz:lab._physics_process(dt)
  check(balance.contacts.size()==2 and absf(balance.velocity)<.02,"aterrissagem amortecida")
  lab.get_node("Ground").rotation.x=deg_to_rad(9.)
  await physics_frame
  await physics_frame
  for i in hz:lab._physics_process(dt)
  check(balance.contacts.size()==2 and balance.contacts.l.normal.z>.10,"normal da rampa vem do colisor")
  var basis:Basis=lab.solver.foot_goals.l.basis
  check(basis.y.normalized().dot(balance.contacts.l.normal)>.99,"orientação solicitada acompanha rampa")
  lab.movement=3
  for i in hz:lab._physics_process(dt)
  check(lab.solver.pose("head").origin.z>lab.solver.pose("pelvis").origin.z+.1,"tronco e pelve coordenam inclinação")
  print("Erro horizontal máximo da sola %.2f mm · maior tick medido %.2f ms"%[sole_error*1000.,worst_tick_us/1000.])
  print("%d Hz · %.1f N · deriva %.3f mm · penetração %.2f mm · %.2f ms/tick (ensaio)"%[hz,force,drift*1000.,penetration*1000.,float(Time.get_ticks_usec()-clock)/1000./(16*hz)])
  lab.free()
 print("Equilíbrio · falhas ",failures)
 quit(failures)
