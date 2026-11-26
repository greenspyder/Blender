extends "res://precision/pose_solver.gd"
const IDLE_DROP := 0.51
const MAX_PULL := 0.27
var clock:=0.0
var body_load:=Vector3.ZERO
var bend:=[0.,0.]
var limited:=[false,false]
var stiffness:=45.0
var damping:=1.0
var recovery:=1.0
var arm_speed:=[Vector3.ZERO,Vector3.ZERO]

func solve(sk:Skeleton3D,contacts:Array,dt:float,influence:float)->void:
 clock+=dt
 sk.reset_bone_poses()
 var base:=sk.find_bone("Base")
 var bp:=sk.get_bone_global_pose(base)
 bp.origin+=Vector3(.008+.004*sin(clock*1.1),.002*sin(clock*1.7),0)+body_load*.28
 sk.set_bone_global_pose(base,bp)
 var spine:=sk.find_bone("Spine")
 var sp:=sk.get_bone_global_pose(spine)
 sp.basis=Basis.from_euler(Vector3(.018+.009*sin(clock*1.7)+body_load.z*.48,0,-body_load.x*.6-.014))*sp.basis
 sk.set_bone_global_pose(spine,sp)
 var head:=sk.find_bone("Head")
 var hp:=sk.get_bone_global_pose(head)
 var aim:=Vector2(body_load.x*.8,-body_load.z*.4)
 if look_target!=null:
  var d:Vector3=look_target-hp.origin
  aim+=Vector2(clampf(atan2(d.x,d.z),-.45,.45),clampf(-atan2(d.y,Vector2(d.x,d.z).length()),-.25,.25))
 gaze=gaze.lerp(aim,1-exp(-8*dt))
 hp.basis=Basis.from_euler(Vector3(gaze.y,gaze.x,.009))*hp.basis
 sk.set_bone_global_pose(head,hp)
 for i in range(2):
  var side:="L" if i==0 else "R"
  var sign_:=-1.0 if i==0 else 1.0
  var upper:=sk.find_bone("Upper"+side)
  var fore:=sk.find_bone("Fore"+side)
  var palm:=sk.find_bone("Palm"+side)
  var a:=sk.get_bone_global_pose(upper).origin
  var b:=sk.get_bone_global_pose(fore).origin
  var c:=sk.get_bone_global_pose(palm).origin
  var idle:=a+Vector3(sign_*.108,-IDLE_DROP,.080+.004*sin(clock*1.1+i))
  var demand:=Vector3.ZERO
  for sample_ in contacts:
   if sample_.region!="" and sample_.surface.x*sign_>0 and sample_.surface.y>.98:
    demand-=Vector3(sample_.normal)*float(sample_.force)*.051*influence
  if reach_targets.has(side):demand+=Vector3(reach_targets[side])-idle
  var goal:=demand.limit_length(MAX_PULL)
  var k:=stiffness*(recovery if demand.length_squared()<.00001 else 1.)
  var remaining:=minf(dt,.1)
  while remaining>.00001:
   var h:=minf(remaining,1./120.)
   arm_speed[i]+=(k*(goal-Vector3(offsets[i]))-2*sqrt(k)*damping*Vector3(arm_speed[i]))*h
   offsets[i]+=Vector3(arm_speed[i])*h
   remaining-=h
  var ray:Vector3=idle+Vector3(offsets[i])-a
  ray.x=sign_*maxf(.04,ray.x*sign_)
  var axis:=ray.normalized()
  var l1:=a.distance_to(b)
  var l2:=b.distance_to(c)
  var low:=sqrt(l1*l1+l2*l2+2*l1*l2*cos(deg_to_rad(120)))
  var high:=sqrt(l1*l1+l2*l2+2*l1*l2*cos(deg_to_rad(15)))
  var reach:=clampf(ray.length(),low,high)
  limited[i]=absf(reach-ray.length())>.001 or demand.length()>MAX_PULL
  bend[i]=rad_to_deg(acos(clampf((reach*reach-l1*l1-l2*l2)/(2*l1*l2),-1,1)))
  var along:=(l1*l1-l2*l2+reach*reach)/(2*reach)
  var pole:=Vector3(sign_*.48,-.06,-.87).slide(axis).normalized()
  var elbow:=a+axis*along+pole*sqrt(maxf(0,l1*l1-along*along))
  align(sk,upper,b-a,elbow-a)
  var mid:=sk.get_bone_global_pose(fore).origin
  align(sk,fore,sk.get_bone_global_pose(palm).origin-mid,a+axis*reach-mid)
