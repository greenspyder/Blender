extends "res://precision/pose_solver.gd"

const IDLE_DROP:=.51
const IMPACT_REACH:=.27
const MAX_SWING_SPEED:=8.0

var clock:=0.
var wardrobe_lift:=Vector2.ZERO
var body_load:=Vector3.ZERO
var bend:=[0.,0.]
var elevation:=[0.,0.]
var limited:=[false,false]
var ik_goals:=[Vector3.ZERO,Vector3.ZERO]
var actual_wrist:=[Vector3.ZERO,Vector3.ZERO]
var stiffness:=45.
var damping:=1.
var recovery:=1.
var arm_speed:=[Vector3.ZERO,Vector3.ZERO]
var solved_axis:=[Vector3.ZERO,Vector3.ZERO]
var solved_pole:=[Vector3.ZERO,Vector3.ZERO]

var shoulder_limit:=158.
var elbow_min:=12.
var elbow_max:=128.
var wrist_limit:=65.
# Estas entradas começam neutras. A bancada usa o mesmo solver da Rosé.
var pose_pelvis:=Vector2.ZERO
var pose_spine:=Vector2.ZERO
var pose_head:=Vector2.ZERO
var pose_wrist:=Vector2.ZERO

func solve(sk:Skeleton3D,contacts:Array,dt:float,influence:float)->void:
 clock+=dt
 sk.reset_bone_poses()
 var base:=sk.find_bone("Base")
 var bp:=sk.get_bone_global_pose(base)
 bp.origin+=Vector3(.008+.004*sin(clock*1.1),.002*sin(clock*1.7),0)+body_load*.28
 bp.origin+=Vector3(clampf(pose_pelvis.x,-.09,.09),clampf(pose_pelvis.y,-.07,.07),0)
 sk.set_bone_global_pose(base,bp)
 var spine:=sk.find_bone("Spine")
 var sp:=sk.get_bone_global_pose(spine)
 var yaw:=clampf(pose_spine.x,-.44,.44)
 var lean:=clampf(pose_spine.y,-.31,.31)
 sp.basis=Basis.from_euler(Vector3(.018+.009*sin(clock*1.7)+body_load.z*.48,yaw,-body_load.x*.6-.014+lean))*sp.basis
 sk.set_bone_global_pose(spine,sp)
 var head:=sk.find_bone("Head")
 var hp:=sk.get_bone_global_pose(head)
 var aim:=Vector2(body_load.x*.8,-body_load.z*.4)+pose_head.clamp(Vector2(-.58,-.44),Vector2(.58,.44))
 if look_target!=null:
  var d:Vector3=look_target-hp.origin
  aim+=Vector2(clampf(atan2(d.x,d.z),-.45,.45),clampf(-atan2(d.y,Vector2(d.x,d.z).length()),-.25,.25))
 gaze=gaze.lerp(aim,1.-exp(-8.*dt))
 hp.basis=Basis.from_euler(Vector3(gaze.y,gaze.x,.009))*hp.basis
 sk.set_bone_global_pose(head,hp)
 for i in 2:solve_arm(sk,i,contacts,dt,influence)

static func reach_for_bend(upper:float,fore:float,angle:float)->float:
 return sqrt(upper*upper+fore*fore+2.*upper*fore*cos(deg_to_rad(angle)))

func constrain_axis(ray:Vector3,side:float)->Vector3:
 # Mantém o alvo no lado do respectivo braço e limita o alcance para trás.
 ray.x=side*maxf(.041,ray.x*side)
 ray.z=maxf(-.21,ray.z)
 var direction:=ray.normalized()
 var raise:=clampf(shoulder_limit,80.,162.)
 if direction.dot(Vector3.DOWN)<cos(deg_to_rad(raise)):
  var horizontal:=Vector3(direction.x,0.,direction.z).normalized()
  return Vector3.DOWN*cos(deg_to_rad(raise))+horizontal*sin(deg_to_rad(raise))
 return direction

func solve_arm(sk:Skeleton3D,i:int,contacts:Array,dt:float,influence:float,chain:=Vector3i(-1,-1,-1))->void:
 var suffix:="L" if i==0 else "R"
 var sign_:=-1. if i==0 else 1.
 var upper:=chain.x if chain.x>=0 else sk.find_bone("Upper"+suffix)
 var fore:=chain.y if chain.y>=0 else sk.find_bone("Fore"+suffix)
 var palm:=chain.z if chain.z>=0 else sk.find_bone("Palm"+suffix)
 var a:=sk.get_bone_global_pose(upper).origin
 var b:=sk.get_bone_global_pose(fore).origin
 var c:=sk.get_bone_global_pose(palm).origin
 var l1:=a.distance_to(b)
 var l2:=b.distance_to(c)
 var idle:=a+Vector3(sign_*.108,-IDLE_DROP,.08+.004*sin(clock*1.1+i))
 var raised:float=wardrobe_lift[i]
 if raised>.001:
  var radians:=lerpf(.20,2.72,raised)
  idle=a+Vector3(sign_*sin(radians)*.51,-cos(radians)*IDLE_DROP,.08+.08*raised)
 var impact:=Vector3.ZERO
 for sample_ in contacts:
  if sample_.region!="" and sample_.surface.x*sign_>0. and sample_.surface.y>.98:
   impact-=Vector3(sample_.normal)*float(sample_.force)*.051*influence
 var active:=reach_targets.has(suffix)
 var requested:=idle+impact.limit_length(IMPACT_REACH)
 if active:
  requested=idle.lerp(Vector3(reach_targets[suffix]),1.-raised)+impact*.23
 var min_bend:=clampf(elbow_min,5.,48.)
 var max_bend:=clampf(elbow_max,min_bend+25.,137.)
 var low:=reach_for_bend(l1,l2,max_bend)
 var high:=reach_for_bend(l1,l2,min_bend)
 var raw:=requested-a
 var direction:=constrain_axis(raw,sign_)
 var admissible:=direction*clampf(raw.length(),low,high)
 var goal:=a+admissible-idle
 var k:=stiffness*(1. if active else recovery)
 var remaining:=minf(dt,.1)
 while remaining>.00001:
  var h:=minf(remaining,1./120.)
  arm_speed[i]+=(k*(goal-Vector3(offsets[i]))-2.*sqrt(k)*damping*Vector3(arm_speed[i]))*h
  offsets[i]+=Vector3(arm_speed[i])*h
  remaining-=h
 var ray:=idle+Vector3(offsets[i])-a
 var axis:=constrain_axis(ray,sign_)
 var previous:Vector3=solved_axis[i]
 if not previous.is_zero_approx():
  var change:=previous.angle_to(axis)
  if change>MAX_SWING_SPEED*dt:
   axis=previous.slerp(axis,MAX_SWING_SPEED*dt/change).normalized()
 solved_axis[i]=axis
 var reach:=clampf(ray.length(),low,high)
 limited[i]=active and raw.distance_to(admissible)>.018
 bend[i]=rad_to_deg(acos(clampf((reach*reach-l1*l1-l2*l2)/(2.*l1*l2),-1.,1.)))
 var along:=(l1*l1-l2*l2+reach*reach)/(2.*reach)
 # O polo se mantém lateral. Perto da elevação máxima avança um pouco
 # para impedir que o cotovelo vire para trás ao cruzar a altura do ombro.
 var up:=smoothstep(-.3,.7,axis.y)
 var pole_candidate:=Vector3(sign_*.78,-.10,lerpf(-.66,-.27,up))
 var projected:=pole_candidate.slide(axis)
 var pole_before:=Vector3(solved_pole[i]).slide(axis).normalized()
 if projected.length_squared()<.06:
  projected=pole_before if not pole_before.is_zero_approx() else Vector3.FORWARD.slide(axis)
 var pole:=projected.normalized()
 if not pole_before.is_zero_approx():
  var angle:=atan2(axis.dot(pole_before.cross(pole)),pole_before.dot(pole))
  pole=pole_before.rotated(axis,clampf(angle,-MAX_SWING_SPEED*dt,MAX_SWING_SPEED*dt))
 solved_pole[i]=pole
 var elbow:=a+axis*along+pole*sqrt(maxf(0.,l1*l1-along*along))
 align(sk,upper,b-a,elbow-a)
 var mid:=sk.get_bone_global_pose(fore).origin
 var endpoint:=a+axis*reach
 align(sk,fore,sk.get_bone_global_pose(palm).origin-mid,endpoint-mid)
 var palm_pose:=sk.get_bone_global_pose(palm)
 var twist:=clampf(pose_wrist[i],-wrist_limit,wrist_limit)
 if absf(twist)>.001:
  palm_pose.basis=Basis(Quaternion((palm_pose.origin-mid).normalized(),deg_to_rad(twist)))*palm_pose.basis
  sk.set_bone_global_pose(palm,palm_pose)
 ik_goals[i]=a+admissible
 actual_wrist[i]=palm_pose.origin
 elevation[i]=rad_to_deg((mid-a).angle_to(Vector3.DOWN))
