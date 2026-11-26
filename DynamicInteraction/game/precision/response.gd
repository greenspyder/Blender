extends RefCounted

var pose := Vector3.ZERO # inclinação lateral, recuo, equilíbrio
var velocity := Vector3.ZERO
var arms := Vector2.ZERO
var intensity := 0.0

func step(contacts: Array, dt: float, stiffness: float, damping: float, gain: float, recovery: float) -> void:
 var goal := Vector3.ZERO
 var arm_goal := Vector2.ZERO
 var peak := 0.0
 for c in contacts:
  if c.region=="":continue
  var f: float=c.force*gain
  var side := signf(c.surface.x)
  var upper := 1.0 if c.surface.y>1.25 else .50
  goal += Vector3((-side*.65-c.normal.x*.35)*upper*f, maxf(0,c.normal.z)*f, f*.55)
  if c.surface.y>1.43 and absf(c.surface.x)>.13:
   if side<0:arm_goal.x+=f
   else:arm_goal.y+=f
  peak=maxf(peak,f)
 goal=goal.clamp(Vector3(-1,0,0),Vector3.ONE)
 var remaining:=minf(dt,.1)
 var k:=stiffness*(recovery if peak==0 else 1.0)
 while remaining>.00001:
  var h:=minf(remaining,1.0/120)
  velocity+=((goal-pose)*k-velocity*(2*sqrt(k)*damping))*h
  pose+=velocity*h
  remaining-=h
 arms=arms.lerp(arm_goal.clamp(Vector2.ZERO,Vector2.ONE),1-exp(-dt*8))
 intensity=lerpf(intensity,minf(1,peak),1-exp(-dt*8))
