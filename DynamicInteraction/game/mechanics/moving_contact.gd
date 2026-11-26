extends RefCounted

# Centro e semieixos em coordenadas locais da personagem (Y para cima).
var zones = {
 "ombro_E":[Vector3(-.245,1.59,0),Vector3(.13,.13,.13)],
 "ombro_D":[Vector3(.245,1.59,0),Vector3(.13,.13,.13)],
 "manga_E":[Vector3(-.204,1.52,.06),Vector3(.066,.10,.06)],
 "manga_D":[Vector3(.204,1.52,.06),Vector3(.066,.10,.06)],
 "short":[Vector3(0,.99,-.045),Vector3(.278,.16,.21)],
 "cabeca":[Vector3(0,1.92,0),Vector3(.18,.23,.17)],
 "tronco":[Vector3(0,1.38,-.025),Vector3(.235,.25,.18)],
 "quadril":[Vector3(0,1.02,-.045),Vector3(.27,.20,.2)],
 "perna_E":[Vector3(-.14,.58,-.035),Vector3(.12,.4,.12)],
 "perna_D":[Vector3(.14,.58,-.035),Vector3(.12,.4,.12)],
 "braco_E":[Vector3(-.48,1.5,-.02),Vector3(.31,.10,.11)],
 "braco_D":[Vector3(.48,1.5,-.02),Vector3(.31,.10,.11)]
}

func sample(point: Vector3, speed: Vector3, duration: float) -> Dictionary:
 var best := {"region":"","force":0.0,"surface":point,"normal":Vector3.ZERO}
 for region in zones:
  var center: Vector3 = zones[region][0]
  var radii: Vector3 = zones[region][1] + Vector3.ONE*.033
  var local := (point-center)/radii
  var depth := 1.0-local.length()
  if depth <= 0: continue
  var axis := local.normalized() if local.length_squared()>.00001 else Vector3.FORWARD
  var normal := (axis/radii).normalized()
  var force := clampf(depth*3.2 + maxf(0,-speed.dot(normal))*.10 + minf(duration,.8)*depth*.25,0,1)
  if force > best.force:
   best={"region":region,"force":force,"surface":center+axis*radii,"normal":normal}
 return best

# Interseção analítica de um segmento com um elipsoide expandido.
func sweep(a:Vector3,b:Vector3,radius:float)->Dictionary:
 var first:=1.01
 var hit:={}
 for name in zones:
  var center:Vector3=zones[name][0]
  var r:Vector3=zones[name][1]+Vector3.ONE*radius
  var p:=(a-center)/r
  var q:=(b-a)/r
  var aa:=q.dot(q)
  var bb:=p.dot(q)
  var cc:=p.dot(p)-1.0
  if aa<1e-10:continue
  var disc:=bb*bb-aa*cc
  if disc<0:continue
  var t:=(-bb-sqrt(disc))/aa
  if cc<0:
   if bb>=0:continue
   t=0.0
  if t<0 or t>1 or t>=first:continue
  first=t
  var unit:=(p+q*t).normalized()
  var surface:=center+r*unit
  hit={"region":name,"surface":surface,"normal":(unit/r).normalized(),"t":t}
 return hit
