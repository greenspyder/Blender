extends RefCounted
## Pelve em comprimentos de perna e ângulos em referenciais anatômicos de repouso.
const ROLES := {
    "pelvis":"Pelve", "lumbar":"Lombar", "chest":"Tórax", "head":"Cabeça",
    "upper_l":"Ombro esquerdo", "fore_l":"Cotovelo esquerdo", "palm_l":"Punho esquerdo",
    "upper_r":"Ombro direito", "fore_r":"Cotovelo direito", "palm_r":"Punho direito",
    "thigh_l":"Quadril esquerdo", "shin_l":"Joelho esquerdo", "foot_l":"Tornozelo esquerdo",
    "thigh_r":"Quadril direito", "shin_r":"Joelho direito", "foot_r":"Tornozelo direito",
}
const TRAVEL_MIN := Vector3(-1.5,-0.94,-1.5)
const TRAVEL_MAX := Vector3(1.5,0.45,1.5)

var solver
var origin:Transform3D
var leg_length:float
var muscles:Resource
var rests:Dictionary={}

func configure(body_solver, muscle_profile:Resource, length_:float)->void:
    solver=body_solver
    origin=solver.sk.global_transform
    leg_length=length_
    muscles=muscle_profile
    for role in ROLES:
        rests[role]=solver.sk.get_bone_global_rest(solver.bones[role])

func joint_basis(role:String)->Basis:
    if role=="pelvis":return Basis.IDENTITY
    var world_basis:=Basis.from_euler(Vector3(muscles.joint_axes_degrees.get(role,Vector3.ZERO))*PI/180.)
    return origin.basis.orthonormalized().inverse()*world_basis

func limits(role:String)->Array:
    var bounds:Array=muscles.bounds(role,solver.profile)
    if role.begins_with("shin_"):
        bounds[0]=Vector3(bounds[0].x,0.,0.)
        bounds[1]=Vector3(bounds[1].x,0.,0.)
    return bounds

func clamp_angles(role:String,value:Vector3)->Vector3:
    var bounds:=limits(role)
    return value.clamp(bounds[0],bounds[1])

func capture(get_world_bone:Callable,seat:bool)->Dictionary:
    var frames:Dictionary={}
    var angles:Dictionary={}
    var from_world:=origin.affine_inverse()
    for role in ROLES:frames[role]=from_world*get_world_bone.call(role)
    for role in ROLES:
        var current:Transform3D=frames[role]
        var rest:Transform3D=rests[role]
        var delta:=current.basis.orthonormalized()*rest.basis.orthonormalized().inverse()
        if solver.profile.PARENTS.has(role):
            var parent:String=solver.profile.PARENTS[role]
            var rest_parent:Transform3D=rests[parent]
            var actual_parent:Transform3D=frames[parent]
            delta=rest_parent.basis.orthonormalized()*actual_parent.basis.orthonormalized().inverse()*delta
        var frame:=joint_basis(role)
        var degrees:Vector3=(frame.inverse()*delta*frame).orthonormalized().get_euler()*180./PI
        angles[role]=clamp_angles(role,degrees)
    var travel:Vector3=(frames.pelvis.origin-rests.pelvis.origin)/leg_length
    return {"angles":angles,"travel":travel.clamp(TRAVEL_MIN,TRAVEL_MAX),"seat":seat}

func apply(pose:Dictionary)->void:
    var skeleton:Skeleton3D=solver.sk
    skeleton.reset_bone_poses()
    for role in ROLES:
        var id:int=solver.bones[role]
        var rest:Transform3D=rests[role]
        var current:=skeleton.get_bone_global_pose(id)
        var frame:=joint_basis(role)
        var rotation:=frame*Basis.from_euler(clamp_angles(role,pose.angles[role])*PI/180.)*frame.inverse()
        current.basis=rotation*rest.basis
        if solver.profile.PARENTS.has(role):
            var parent:String=solver.profile.PARENTS[role]
            var parent_pose:Transform3D=solver.pose(parent)
            current.basis=parent_pose.basis.orthonormalized()*Transform3D(rests[parent]).basis.orthonormalized().inverse()*current.basis
        else:
            var pelvis_in_origin:Vector3=rest.origin+Vector3(pose.travel)*leg_length
            current.origin=skeleton.to_local(origin*pelvis_in_origin)
        skeleton.set_bone_global_pose(id,current)

func snapshot()->Dictionary:
    var skeleton:Skeleton3D=solver.sk
    var rotations:Dictionary={}
    for role in ROLES:rotations[role]=skeleton.get_bone_pose_rotation(solver.bones[role])
    return {"rotations":rotations,"pelvis":skeleton.to_global(solver.pose("pelvis").origin)}

func blend_from(source:Dictionary,progress:float)->void:
    var skeleton:Skeleton3D=solver.sk
    var pelvis:int=solver.bones.pelvis
    var position:=skeleton.to_local(Vector3(source.pelvis).lerp(skeleton.to_global(solver.pose("pelvis").origin),progress))
    for role in ROLES:
        var id:int=solver.bones[role]
        var rotation:=Quaternion(source.rotations[role]).slerp(skeleton.get_bone_pose_rotation(id),progress)
        skeleton.set_bone_pose_rotation(id,rotation)
    var parent:=skeleton.get_bone_parent(pelvis)
    if parent>=0:position=skeleton.get_bone_global_pose(parent).affine_inverse()*position
    skeleton.set_bone_pose_position(pelvis,position)
