extends SceneTree
const Game=preload("res://gameplay/main.tscn")
const Picker=preload("res://direct/surface_picker.gd")
var errors:=PackedStringArray()
func _initialize()->void:call_deferred("run")
func check(ok:bool,title:String)->void:
    if not ok:errors.append(title)

func run()->void:
    var g=Game.instantiate()
    root.add_child(g)
    # Um auxiliar de torção pode estar entre pai e filho sem criar outro corpo.
    var sk:Skeleton3D=g.sk.duplicate()
    var fore:int=g.core.ids.fore_l
    var upper:int=g.core.ids.upper_l
    var original:=sk.get_bone_global_rest(fore)
    var helper:=sk.get_bone_count()
    sk.add_bone("auxiliar de torção")
    sk.set_bone_parent(helper,upper)
    sk.set_bone_rest(helper,Transform3D(Basis(Vector3.UP,.23),Vector3(.015,0.,0.)))
    sk.set_bone_parent(fore,helper)
    sk.set_bone_rest(fore,sk.get_bone_global_rest(helper).affine_inverse()*original)
    sk.reset_bone_poses()
    check(g.profile.validate(sk).is_empty(),"hierarquia semântica com auxiliar")
    sk.set_bone_parent(fore,g.core.ids.pelvis)
    check(not g.profile.validate(sk).is_empty(),"cadeia desconectada rejeitada")
    sk.free()
    # Triângulo sem índices com influência significativa no oitavo slot.
    sk=Skeleton3D.new()
    root.add_child(sk)
    var skin:=Skin.new()
    for i in 8:
        var key:="Joint_%d"%i
        sk.add_bone(key)
        skin.add_named_bind(key,Transform3D.IDENTITY)
    sk.set_bone_pose_position(7,Vector3.UP*.2)
    var node:=MeshInstance3D.new()
    var mesh:=ArrayMesh.new()
    var arrays:Array=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
    var bones:=PackedInt32Array()
    var weights:=PackedFloat32Array()
    for i in 3:
        for j in 8:
            bones.append(j)
            weights.append(.125)
    arrays[Mesh.ARRAY_BONES]=bones
    arrays[Mesh.ARRAY_WEIGHTS]=weights
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
    node.mesh=mesh
    node.skin=skin
    sk.add_child(node)
    var picker:=Picker.new()
    picker.configure(sk,sk,[])
    var surface:Dictionary=picker.surfaces[0]
    picker.update_surface(surface)
    check(surface.indices.size()==3 and surface.influences==8 and absf(picker.vertex(surface,0).y-.025)<.0001,"picking com oito pesos e sem índice")
    sk.free()
    var contact:Dictionary=g.core.apply_grip("palm_l",Vector3(.02,0.,0.),Vector3(0,4,0),1./120.)
    var group:int=g.muscles.group("palm_l")
    check(contact.force.length()<=g.muscles.max_force[group]+.001 and contact.torque.length()<=g.muscles.max_torque[group]+.001,"contrato de força e torque")
    check(g.core.apply_grip("ausente",Vector3.ZERO,Vector3.ZERO,.01).is_empty(),"papel desconhecido")
    g.free()
    print("Contrato de integração · ",errors)
    quit(0 if errors.is_empty() else 1)
