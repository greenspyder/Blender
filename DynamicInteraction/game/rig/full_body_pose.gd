extends RefCounted
## Uma passagem de pose com ordem explícita. Alvos e diagnósticos ficam no espaço do esqueleto.

const Posture=preload("res://mechanics/posture.gd")
const SIDES:=["l","r"]
var profile:Resource
var sk:Skeleton3D
var bones:Dictionary
var arms:=Posture.new()
var enabled:Dictionary={"pelvis":true,"spine":true,"head":true,"arms":true,"legs":true,"feet":true}
var smoothed:Dictionary={}
var contacts:Dictionary={}
# Alvos em espaço do esqueleto fornecidos pela bancada física.
var foot_goals:Dictionary={}
var support_weights:=Vector2.ZERO
var masses:Array[Dictionary]=[]
var center_of_mass:=Vector3.ZERO

func configure(skeleton:Skeleton3D,character:Resource)->PackedStringArray:
 profile=character
 var issues:PackedStringArray=profile.validate(skeleton)
 if not issues.is_empty():return issues
 sk=skeleton
 bones=profile.resolve(sk)
 return issues

func apply(request:Dictionary,plant:Vector2,dt:float)->void:
 var response:=1.-exp(-profile.pose_response*maxf(dt,0.))
 for key in request:
  smoothed[key]=Vector3(smoothed.get(key,Vector3.ZERO)).lerp(request[key],response)
 sk.reset_bone_poses()
 if enabled.pelvis:
  var pelvis:=pose("pelvis")
  pelvis.origin+=Vector3(smoothed.get("travel",Vector3.ZERO))
  sk.set_bone_global_pose(bones.pelvis,pelvis)
  rotate("pelvis",angles("pelvis",profile.pelvis_limit))
 if enabled.spine:
  rotate("lumbar",angles("lumbar",profile.lumbar_limit))
  rotate("chest",angles("chest",profile.chest_limit))
 if enabled.head:rotate("head",angles("head",profile.head_limit))
 contacts.clear()
 for i in 2:
  var side:String=SIDES[i]
  if enabled.arms:apply_arm(i,side,dt)
  if not enabled.legs:continue
  var target_weight:=plant[i] if enabled.feet else 0.
  support_weights[i]=move_toward(support_weights[i],target_weight,dt*4.5)
  var roles:=["thigh_"+side,"shin_"+side,"foot_"+side]
  rotate(roles[0],angles("hip_"+side,profile.hip_limit))
  var knee:float=Vector3(smoothed.get("knee_"+side,Vector3.ZERO)).x
  bend_knee(roles,clampf(knee,profile.knee_limit.x,profile.knee_limit.y))
  rotate(roles[2],angles("ankle_"+side,profile.ankle_limit))
  if support_weights[i]>0.:
   var free_poses:Array[Quaternion]=[]
   for role in roles:free_poses.append(sk.get_bone_pose_rotation(bones[role]))
   for role in roles:sk.set_bone_pose_rotation(bones[role],sk.get_bone_rest(bones[role]).basis.get_rotation_quaternion())
   solve_leg(side)
   for j in roles.size():
    var idx:int=bones[roles[j]]
    sk.set_bone_pose_rotation(idx,free_poses[j].slerp(sk.get_bone_pose_rotation(idx),support_weights[i]))
   contacts[side].actual=pose(roles[2])*profile.sole_offset
   contacts[side].limited=contacts[side].actual.distance_to(contacts[side].target)>.025
   contacts[side].weight=support_weights[i]
 calculate_mass()

func apply_arm(i:int,side:String,dt:float)->void:
 var key:=Vector3i(bones["upper_"+side],bones["fore_"+side],bones["palm_"+side])
 var options:Vector3=smoothed.get("arm_"+side,profile.arm_rest_angles)
 var elevation:=deg_to_rad(clampf(options.x,0.,profile.shoulder_limit))
 var flexion:=clampf(options.y,profile.elbow_limit.x,profile.elbow_limit.y)
 var direction:=Vector3((-1. if i==0 else 1.)*sin(elevation)*.85,-cos(elevation),.12+.25*sin(elevation)).normalized()
 var chest_frame:Basis=(pose("chest").basis*sk.get_bone_global_rest(bones.chest).basis.inverse()).orthonormalized()
 var swing:Vector3=smoothed.get("swing_"+side,Vector3.ZERO)
 direction=chest_frame*direction.rotated(Vector3.RIGHT,-deg_to_rad(swing.x))
 var shoulder:=sk.get_bone_global_pose(key.x).origin
 var elbow:=sk.get_bone_global_pose(key.y).origin
 var wrist:=sk.get_bone_global_pose(key.z).origin
 var length:=Posture.reach_for_bend(shoulder.distance_to(elbow),elbow.distance_to(wrist),flexion)
 var suffix:=side.to_upper()
 arms.reach_targets[suffix]=shoulder+direction*length
 arms.shoulder_limit=profile.shoulder_limit
 arms.elbow_min=profile.elbow_limit.x
 arms.elbow_max=profile.elbow_limit.y
 arms.wrist_limit=profile.wrist_limit
 arms.pose_wrist[i]=options.z
 arms.solve_arm(sk,i,[],dt,1.,key,chest_frame,profile.elbow_pole)

func bend_knee(roles:Array,degrees:float)->void:
 var thigh:=pose(roles[0])
 var knee:=pose(roles[1]).origin
 var axis:=(knee-thigh.origin).normalized()
 var bend_reference:=thigh.basis*sk.get_bone_global_rest(bones[roles[0]]).basis.inverse()
 var pole:=(bend_reference*Vector3.BACK).slide(axis).normalized()
 if pole.is_zero_approx():pole=(bend_reference*Vector3.RIGHT).slide(axis).normalized()
 var angle:=deg_to_rad(degrees)
 arms.align(sk,bones[roles[1]],pose(roles[2]).origin-knee,axis*cos(angle)-pole*sin(angle))

func solve_leg(side:String,relative_goal:Variant=null)->void:
 var hip_role:="thigh_"+side
 var shin_role:="shin_"+side
 var foot_role:="foot_"+side
 var hip:=pose(hip_role).origin
 var knee:=pose(shin_role).origin
 var foot:=pose(foot_role).origin
 var rest_foot:=sk.get_bone_global_rest(bones[foot_role])
 var l1:=hip.distance_to(knee)
 var l2:=knee.distance_to(foot)
 var pelvis_reference:=pose("pelvis").basis*sk.get_bone_global_rest(bones.pelvis).basis.inverse()
 var floor_offset:Vector3=smoothed.get("target_"+side,Vector3.ZERO)
 var target:=rest_foot.origin+floor_offset
 var sole_basis:=rest_foot.basis
 var desired_sole:Vector3=rest_foot*profile.sole_offset+floor_offset
 if relative_goal!=null or foot_goals.has(side):
  var goal_pose:Transform3D=relative_goal if relative_goal!=null else foot_goals[side]
  sole_basis=goal_pose.basis
  desired_sole=goal_pose.origin
  target=desired_sole-sole_basis*profile.sole_offset
 var requested:=target-hip
 var low:=Posture.reach_for_bend(l1,l2,profile.knee_limit.y)
 var high:=Posture.reach_for_bend(l1,l2,profile.knee_limit.x)
 var ray:=pelvis_reference.inverse()*requested
 var limit:Vector3=profile.hip_limit
 var pitch:=clampf(atan2(ray.z,-ray.y),-deg_to_rad(limit.x),deg_to_rad(limit.x))
 var abduction:=clampf(atan2(ray.x,Vector2(ray.y,ray.z).length()),-deg_to_rad(limit.z),deg_to_rad(limit.z))
 var dir:=(pelvis_reference*Vector3(sin(abduction),-cos(abduction)*cos(pitch),cos(abduction)*sin(pitch))).normalized()
 var distance:=clampf(requested.length(),low,high)
 var along:=(l1*l1-l2*l2+distance*distance)/(2.*distance)
 var pole:=(pelvis_reference*Vector3.BACK).slide(dir)
 if pole.length_squared()<.0001:pole=(pelvis_reference*Vector3.RIGHT).slide(dir)
 var desired_knee:=hip+dir*along+pole.normalized()*sqrt(maxf(0.,l1*l1-along*along))
 arms.align(sk,bones[hip_role],knee-hip,desired_knee-hip)
 knee=pose(shin_role).origin
 arms.align(sk,bones[shin_role],pose(foot_role).origin-knee,hip+dir*distance-knee)
 var ankle:=pose(foot_role)
 var goal:=sole_basis.orthonormalized().get_rotation_quaternion()
 var current:=ankle.basis.orthonormalized().get_rotation_quaternion()
 var angle:=current.angle_to(goal)
 var blend:=1. if angle<.001 else minf(1.,deg_to_rad(profile.ankle_limit.x)/angle)
 ankle.basis=Basis(current.slerp(goal,blend))
 sk.set_bone_global_pose(bones[foot_role],ankle)
 var sole:Vector3=ankle*profile.sole_offset
 contacts[side]={
  "target":desired_sole, "actual":sole, "knee":knee,
  "limited":sole.distance_to(desired_sole)>.025,
 }

func angles(role:String,limit:Vector3)->Vector3:
 return Vector3(smoothed.get(role,Vector3.ZERO)).clamp(-limit,limit)

func pose(role:String)->Transform3D:
 return sk.get_bone_global_pose(bones[role])

func rotate(role:String,degrees:Vector3)->void:
 if degrees.is_zero_approx():return
 var index:int=bones[role]
 var current:=sk.get_bone_global_pose(index)
 var reference:=current.basis*sk.get_bone_global_rest(index).basis.inverse()
 current.basis=reference*Basis.from_euler(degrees*PI/180.)*reference.inverse()*current.basis
 sk.set_bone_global_pose(index,current)

func calculate_mass()->void:
 masses.clear()
 center_of_mass=Vector3.ZERO
 var total:=0.
 var mass_sum:float=profile.mass_total()
 for segment in profile.MASS_SEGMENTS:
  var point:=pose(segment[0]).origin.lerp(pose(segment[1]).origin,.5)
  var kg:float=profile.segment_mass(segment[2],mass_sum)
  masses.append({"p":point,"kg":kg})
  center_of_mass+=point*kg
  total+=kg
 if total>0.:center_of_mass/=total
