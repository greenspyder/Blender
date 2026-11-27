extends RefCounted
var intensity:=.3
var direction:=Vector3.BACK
var duration:=.25
var remaining:=0.
func trigger()->void:
    remaining=duration
func step(core,dt:float)->void:
    if remaining<=0.:return
    var fraction:=minf(dt,remaining)/dt
    var body:RigidBody3D=core.bodies.chest
    body.apply_central_force(direction.normalized()*minf(core.settings.max_force[1],core.profile.mass_kg*core.gravity*intensity)*fraction)
    remaining=maxf(0.,remaining-dt)
