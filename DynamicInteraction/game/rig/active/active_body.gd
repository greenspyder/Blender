extends Node3D
const Muscle=preload("res://rig/active/muscle_profile.gd")
const Segment=preload("res://rig/active/segment.gd")
var settings:Muscle
var profile:Resource
var reference:Skeleton3D
var skin:Skeleton3D
var ids:Dictionary
var bodies:Dictionary={}
var offsets:Dictionary={}
var inverse_offsets:Dictionary={}
var groups:Dictionary={}
var joints:Dictionary={}
var gain:Dictionary={}
var applied_force:Dictionary={}
var applied_torque:Dictionary={}
var targets:Dictionary={}
var state:=1
var com:=Vector3.ZERO
var rms:=0.
var max_gap:=0.
var active_support:Array=[]
var leg:float
var gravity:float
var recovery_phase:=1.

func build(output:Skeleton3D,reference_:Skeleton3D,character:Resource,muscles:Muscle,length_:float)->void:
 skin=output
 reference=reference_
 profile=character
 settings=muscles
 ids=profile.resolve(skin)
 leg=length_
 gravity=ProjectSettings.get_setting("physics/3d/default_gravity")
 for segment in profile.MASS_SEGMENTS:
  make_segment(segment)
 for role in bodies:
  if profile.PARENTS.has(role):make_joint(role)

func rest(role:String)->Transform3D:
 return skin.global_transform*skin.get_bone_global_rest(ids[role])

func make_segment(segment:Array)->void:
 var role:String=segment[0]
 var kind:String=segment[2]
 var frame:=rest(role)
 var tip:=rest(segment[1]).origin
 var span:=frame.origin.distance_to(tip)
 var center:Vector3=(frame.origin+tip)*0.5
 var rotation:=Basis.IDENTITY
 var shape:Shape3D
 if kind=="foot":
  var box:=BoxShape3D.new()
  var sole:Vector3=frame*profile.sole_offset
  var height:=maxf(absf(sole.y-frame.origin.y),leg*0.035)
  box.size=Vector3(profile.sole_half_width*leg*2,height,profile.sole_half_length*leg*2)
  center=sole+Vector3.UP*height*0.5
  span=box.size.length()
  shape=box
 elif span<leg*0.001:
  var ball:=SphereShape3D.new()
  ball.radius=leg*settings.radius_factor[kind]
  if kind=="head":center+=Vector3.UP*ball.radius*0.5
  span=ball.radius*2
  shape=ball
 else:
  var capsule:=CapsuleShape3D.new()
  capsule.radius=minf(span*settings.radius_factor[kind],span*0.49)
  capsule.height=span
  rotation=Basis(Quaternion(Vector3.UP,(tip-frame.origin).normalized()))
  shape=capsule
 var body:=Segment.new()
 body.name=role
 body.mass=profile.segment_mass(kind)
 body.collision_layer=settings.segment_layer
 body.collision_mask=profile.ground_mask | settings.segment_layer
 body.ground_mask=profile.ground_mask
 body.max_contacts_reported=8
 body.can_sleep=false
 body.continuous_cd=kind in ["foot","head","hand"]
 body.linear_damp=settings.linear_drag
 body.angular_damp=settings.angular_drag
 var collider:=CollisionShape3D.new()
 collider.shape=shape
 collider.basis=rotation
 body.add_child(collider)
 add_child(body)
 body.global_position=center
 bodies[role]=body
 offsets[role]=frame.affine_inverse()*body.global_transform
 inverse_offsets[role]=Transform3D(offsets[role]).affine_inverse()
 groups[role]=settings.group(role)
 gain[role]=settings.state_strength[state]

func make_joint(role:String)->void:
 var parent:RigidBody3D=bodies[profile.PARENTS[role]]
 var child:RigidBody3D=bodies[role]
 var hinge:=role.begins_with("shin_")
 var joint:Joint3D=HingeJoint3D.new() if hinge else Generic6DOFJoint3D.new()
 joint.name="Joint_"+role
 add_child(joint)
 joint.global_transform=Transform3D(Basis.from_euler(Vector3(settings.joint_axes_degrees.get(role,Vector3.ZERO))*PI/180.),rest(role).origin)
 if hinge:joint.rotate_object_local(Vector3.UP,PI/2.)
 joint.node_a=joint.get_path_to(parent)
 joint.node_b=joint.get_path_to(child)
 joint.exclude_nodes_from_collision=true
 joints[role]=joint
 update_limits(role)

func update_limits(role:String)->void:
 var bounds:=settings.bounds(role,profile)
 if joints[role] is HingeJoint3D:
  var hinge:HingeJoint3D=joints[role]
  hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT,true)
  hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER,deg_to_rad(-bounds[1].x))
  hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER,deg_to_rad(-bounds[0].x))
  return
 for i in 3:
  var axis:String=["x","y","z"][i]
  var joint:Generic6DOFJoint3D=joints[role]
  joint.set("linear_limit_"+axis+"/enabled",true)
  joint.set("angular_limit_"+axis+"/enabled",true)
  if ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT")!="Jolt Physics":
   joint.set("angular_limit_"+axis+"/erp",0.12)
  joint.set("angular_limit_"+axis+"/restitution",0.)
  # A junta mede o corpo A em relação ao B; o perfil mede o filho em relação ao pai.
  joint.set("angular_limit_"+axis+"/lower_angle",deg_to_rad(-bounds[1][i]))
  joint.set("angular_limit_"+axis+"/upper_angle",deg_to_rad(-bounds[0][i]))

func select_state(next:int)->void:
 if next==4 and state!=4:recovery_phase=0.
 state=next

func measure()->void:
 com=Vector3.ZERO
 active_support.clear()
 for role in bodies:
  var b:Segment=bodies[role]
  com+=b.global_position*b.mass
  if b.grounded:active_support.append(role)
 com/=profile.mass_kg

func drive(dt:float,stance:Dictionary,support_fraction:float=1.,reference_strength:float=1.)->void:
 measure()
 recovery_phase=move_toward(recovery_phase,1.,dt*0.65)
 var error_sq:=0.
 for role in bodies:
  targets[role]=reference.global_transform*reference.get_bone_global_pose(ids[role])*Transform3D(offsets[role])
 # Assistência de reação do solo, limitada pela capacidade dos contatos reais.
 var reaction:=Vector3.ZERO
 var forces:Dictionary={}
 var support_capacity:=0.
 for role in bodies:
  var b:Segment=bodies[role]
  var g:int=groups[role]
  var strength:float=settings.state_strength[state]*reference_strength
  if state==4:strength*=smoothstep(0.,1.,recovery_phase)
  gain[role]=move_toward(gain[role],strength,dt*settings.recovery_speed[g])
  var authority:=clampf(gain[role],0.,1.)
  if role in active_support:support_capacity+=settings.max_force[g]*authority
  var target:Transform3D=targets[role]
  var delta:=target.origin-b.global_position
  error_sq+=delta.length_squared()
  var k:float=settings.stiffness[g]*gain[role]
  var d:float=2.*sqrt(k)*settings.damping[g]
  var f:=Vector3.ZERO
  if not active_support.is_empty():
   f=(delta*k-b.linear_velocity*d+Vector3.UP*gravity*settings.weight_assist*minf(gain[role],1.))*b.mass
   if role.begins_with("foot_") and not stance.has(role.right(1)):
    var side:String=role.right(1)
    var swing_mass:float=b.mass+bodies["shin_"+side].mass+0.5*bodies["thigh_"+side].mass
    f=(delta*k-b.linear_velocity*d+Vector3.UP*gravity*minf(gain[role],1.))*swing_mass
   f=f.limit_length(settings.max_force[g]*authority)
  forces[role]=f
  reaction+=f
  var target_basis:=target.basis.orthonormalized()
  if role=="pelvis":
   var bounds:=settings.bounds(role,profile)
   target_basis=Basis.from_euler(target_basis.get_euler().clamp(Vector3(bounds[0])*PI/180.,Vector3(bounds[1])*PI/180.))
  var rel:=target_basis*b.global_basis.inverse()
  var spin:=b.angular_velocity
  var parent:RigidBody3D=bodies.get(profile.PARENTS.get(role,""))
  if parent!=null:
   var parent_goal:Transform3D=targets[profile.PARENTS[role]]
   rel=parent.global_basis*parent_goal.basis.orthonormalized().inverse()*rel
   spin-=parent.angular_velocity
  var q:=rel.orthonormalized().get_rotation_quaternion()
  if q.w<0.:q=-q
  var axis:=Vector3(q.x,q.y,q.z)
  var rot:=axis.normalized()*2.*atan2(axis.length(),q.w)
  var inverse_inertia:=b.get_inverse_inertia_tensor()
  if parent!=null:
   var other:=parent.get_inverse_inertia_tensor()
   inverse_inertia=Basis(inverse_inertia.x+other.x,inverse_inertia.y+other.y,inverse_inertia.z+other.z)
  var torque:=Vector3.ZERO
  if absf(inverse_inertia.determinant())>0.000001:
   torque=inverse_inertia.inverse()*((rot*k-spin*d)/(1.+d*dt+k*dt*dt))
   torque=torque.limit_length(settings.max_torque[g]*authority)
  if parent!=null:parent.apply_torque(-torque)
  elif active_support.is_empty():torque=Vector3.ZERO
  b.apply_torque(torque)
  applied_torque[role]=torque
 var factor:=minf(1.,support_capacity/maxf(reaction.length(),0.0001))
 for role in bodies:
  var f:=Vector3(forces[role])*factor*support_fraction
  bodies[role].apply_central_force(f)
  applied_force[role]=f
 rms=sqrt(error_sq/bodies.size())

# Entrada comum ao toque e a futuros efetuadores. A posição é local ao segmento.
func apply_grip(role:String,local_point:Vector3,goal:Vector3,dt:float)->Dictionary:
 var body:RigidBody3D=bodies.get(role)
 if body==null or dt<=0.:return {}
 var group:int=groups[role]
 var arm:=body.global_basis*local_point
 var velocity:=body.linear_velocity+body.angular_velocity.cross(arm)
 var k:float=settings.stiffness[group]
 var d:float=2.*sqrt(k)*settings.damping[group]
 var acceleration:=((goal-body.global_position-arm)*k-velocity*d)/(1.+dt*d)
 var force:Vector3=(acceleration*profile.mass_kg).limit_length(settings.max_force[group])
 var torque:=arm.cross(force).limit_length(settings.max_torque[group])
 body.apply_central_force(force)
 body.apply_torque(torque)
 return {"force":force,"torque":torque}

func support_outline(seat:StaticBody3D,load_bearing_only:bool)->PackedVector2Array:
 var points:=PackedVector2Array()
 for role in active_support:
  var body:Segment=bodies[role]
  if role.begins_with("foot_"):
   var collider:CollisionShape3D=body.get_child(0)
   var box:BoxShape3D=collider.shape
   for x in [-.5,.5]:
    for z in [-.5,.5]:
     var corner:=collider.to_global(box.size*Vector3(x,-.5,z))
     points.append(Vector2(corner.x,corner.z))
  elif role=="pelvis" and seat!=null and seat.visible and body.support_body==seat:
   var support:=Vector2(body.support_point.x,body.support_point.z)
   for x in [-1.,1.]:
    for z in [-1.,1.]:points.append(support+Vector2(.13*x,.10*z)*leg)
  elif not load_bearing_only:points.append(Vector2(body.support_point.x,body.support_point.z))
 return points

func physical_pose(role:String)->Transform3D:
 return bodies[role].global_transform*Transform3D(inverse_offsets[role])

func present()->void:
 # Conserva os comprimentos de repouso. A única translação escrita é a da raiz.
 max_gap=0.
 var world_to_skin:=skin.global_transform.affine_inverse()
 for segment in profile.MASS_SEGMENTS:
  var role:String=segment[0]
  var id:int=ids[role]
  var physical:=physical_pose(role)
  var target:=world_to_skin*physical
  var parent:=skin.get_bone_parent(id)
  if parent>=0:target=skin.get_bone_global_pose(parent).affine_inverse()*target
  skin.set_bone_pose_rotation(id,target.basis.orthonormalized().get_rotation_quaternion())
  if role=="pelvis":skin.set_bone_pose_position(id,target.origin)
  max_gap=maxf(max_gap,physical.origin.distance_to(skin.to_global(skin.get_bone_global_pose(id).origin)))
