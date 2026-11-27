extends RefCounted
## Dinâmica vertical da raiz e apoio de duas solas. Coordenadas de cálculo no mundo.
var profile:Resource
var length_scale:=1.
var height:=0.
var velocity:=0.
var contacts:Dictionary={}
var targets:Dictionary={}
var hull:=PackedVector2Array()
var gravity:=9.8
var projection:=Vector3.ZERO
var correction:=Vector2.ZERO
var balance_state:="Sem apoio"
var support_state:="Sem apoio"
var recovery_time:=0.
var loads:=Vector2.ZERO
var filtered_normals:Dictionary={}

func configure(character:Resource,length_:float)->void:
 profile=character
 length_scale=length_
 gravity=float(ProjectSettings.get_setting("physics/3d/default_gravity"))

func sense(space:PhysicsDirectSpaceState3D,side:String,sole:Vector3,advance:bool)->void:
 var band:float=profile.contact_band*length_scale
 var anchor:Dictionary=contacts.get(side,{})
 var query_point:=sole
 if not anchor.is_empty():
  if is_instance_valid(anchor.body):
   var fixed:Vector3=anchor.body.to_global(anchor.local)
   if Vector2(fixed.x-sole.x,fixed.z-sole.z).length()<length_scale*.32:
    query_point.x=fixed.x
    query_point.z=fixed.z
   else:anchor={}
  else:anchor={}
 var top:=query_point+Vector3.UP*length_scale*.32
 var query:=PhysicsRayQueryParameters3D.create(top,query_point-Vector3.UP*length_scale*.5,profile.ground_mask)
 var hit:=space.intersect_ray(query)
 contacts.erase(side)
 targets[side]={"point":sole,"normal":Vector3.UP}
 if hit.is_empty() or hit.normal.y<.65:return
 var gap:float=sole.y-hit.position.y
 var same:bool=not anchor.is_empty() and anchor.body==hit.collider
 var active:bool=not advance and gap<band*(1.65 if same else 1.)
 if active:
  var point:Vector3=hit.position
  contacts[side]={"point":point,"normal":hit.normal,"body":hit.collider,"local":hit.collider.to_local(point),"gap":gap}
  targets[side]={"point":point,"normal":hit.normal}
 elif gap<0.:
  targets[side]={"point":hit.position,"normal":hit.normal}

func foot_normal(side:String,dt:float)->Vector3:
 var desired:Vector3=targets[side].normal
 var previous:Vector3=filtered_normals.get(side,Vector3.UP)
 var normal:=previous.slerp(desired,1.-exp(-dt*18.)).normalized()
 filtered_normals[side]=normal
 return normal

func verify_support(side:String,actual:Vector3)->void:
 if not contacts.has(side):return
 var error:Vector3=actual-Vector3(contacts[side].point)
 if error.length()>profile.contact_band*length_scale*1.8:contacts.erase(side)

func integrate(com:Vector3,dt:float)->void:
 var points:=PackedVector2Array()
 var avg_height:=0.
 var center:=Vector2.ZERO
 for foot in contacts.values():
  var p:Vector3=foot.point
  avg_height+=p.y
  center+=Vector2(p.x,p.z)
  for x in [-1.,1.]:
   for z in [-1.,1.]:
    points.append(Vector2(p.x+x*length_scale*profile.sole_half_width,p.z+z*length_scale*profile.sole_half_length))
 hull=Geometry2D.convex_hull(points) if not points.is_empty() else PackedVector2Array()
 var flat:=Vector2(com.x,com.z)
 projection=com
 var count_:=contacts.size()
 var share:=0.
 if count_>0:
  center/=count_
  projection.y=avg_height/count_
  if count_==2:
   var l:Vector3=contacts.l.point
   var r:Vector3=contacts.r.point
   var span:=Vector2(r.x-l.x,r.z-l.z)
   share=clampf((flat-Vector2(l.x,l.z)).dot(span)/maxf(.000001,span.length_squared()),0.,1.)
   projection.y=lerpf(plane_height(contacts.l,flat),plane_height(contacts.r,flat),share)
  else:
   share=1. if contacts.has("r") else 0.
   projection.y=plane_height(contacts.values()[0],flat)
 support_state=["Sem apoio","Unilateral","Bilateral"][count_]
 var outside:=count_>0 and not Geometry2D.is_point_in_polygon(flat,hull)
 if count_==0:
  balance_state="Sem apoio"
  recovery_time=0.
 elif outside:
  balance_state="Perda de equilíbrio"
  recovery_time=.30
 elif recovery_time>0.:
  recovery_time=maxf(0.,recovery_time-dt)
  balance_state="Recuperação"
 else:balance_state="Estável"
 var shift:=Vector2.ZERO
 if count_>0:shift=((center-flat)*profile.balance_gain).limit_length(length_scale*.18)
 correction=correction.lerp(shift,1.-exp(-dt*5.))
 loads=Vector2.ZERO
 var acceleration:=-gravity
 for i in 2:
  var side: String=["l","r"][i]
  if not contacts.has(side):continue
  var fraction:=share if i==1 else 1.-share
  var w:float=profile.support_frequency
  var reaction:=clampf(-float(contacts[side].gap)*w*w-2.*profile.support_damping*w*velocity,0.,gravity*4.)
  acceleration+=reaction*fraction
  loads[i]=reaction*fraction*profile.mass_kg
 velocity+=acceleration*dt
 height+=velocity*dt

func plane_height(foot:Dictionary,at:Vector2)->float:
 var n:Vector3=foot.normal
 var p:Vector3=foot.point
 return p.y-(n.x*(at.x-p.x)+n.z*(at.y-p.z))/n.y
