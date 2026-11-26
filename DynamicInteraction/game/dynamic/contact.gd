extends RefCounted

# Centro e semieixos em coordenadas locais da personagem (Y para cima).
const ZONES = {
 "ombro_E":[Vector3(-.245,1.59,0),Vector3(.13,.13,.13)],
 "ombro_D":[Vector3(.245,1.59,0),Vector3(.13,.13,.13)],
 "cabeca":[Vector3(0,1.92,0),Vector3(.18,.23,.17)],
 "tronco":[Vector3(0,1.38,-.025),Vector3(.235,.25,.18)],
 "quadril":[Vector3(0,1.02,-.045),Vector3(.27,.20,.2)],
 "perna_E":[Vector3(-.14,.58,-.035),Vector3(.12,.4,.12)],
 "perna_D":[Vector3(.14,.58,-.035),Vector3(.12,.4,.12)],
 "braco_E":[Vector3(-.48,1.5,-.02),Vector3(.31,.10,.11)],
 "braco_D":[Vector3(.48,1.5,-.02),Vector3(.31,.10,.11)]
}

static func sample(point: Vector3, speed: Vector3, duration: float) -> Dictionary:
 var best := {"region":"","force":0.0,"surface":point,"normal":Vector3.ZERO}
 for region in ZONES:
  var center: Vector3 = ZONES[region][0]
  var radii: Vector3 = ZONES[region][1] + Vector3.ONE*.033
  var local := (point-center)/radii
  var depth := 1.0-local.length()
  if depth <= 0: continue
  var axis := local.normalized() if local.length_squared()>.00001 else Vector3.FORWARD
  var normal := (axis/radii).normalized()
  var force := clampf(depth*3.2 + maxf(0,-speed.dot(normal))*.10 + minf(duration,.8)*depth*.25,0,1)
  if force > best.force:
   best={"region":region,"force":force,"surface":center+axis*radii,"normal":normal}
 return best
