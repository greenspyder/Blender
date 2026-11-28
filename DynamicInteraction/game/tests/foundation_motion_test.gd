extends SceneTree
const Game=preload("res://gameplay/main.tscn")
var errors:=PackedStringArray()
var g

func _initialize()->void:call_deferred("run")

func check(ok:bool,description:String)->void:
    if not ok:errors.append(description)

func wait_ticks(ticks:int)->void:
    for i in ticks:await physics_frame

func angle_at(a:String,b:String,c:String)->float:
    var pa:Vector3=g.core.physical_pose(a).origin
    var pb:Vector3=g.core.physical_pose(b).origin
    var pc:Vector3=g.core.physical_pose(c).origin
    return rad_to_deg((pb-pa).angle_to(pc-pb))

func run()->void:
    g=Game.instantiate()
    root.add_child(g)
    g.cloth.set_quality(0)
    await wait_ticks(200)
    var source=load("res://assets/rig121.glb").instantiate()
    var original:MeshInstance3D=source.find_child(g.profile.mesh_roles.skin,true,false)
    var original_arrays:=original.mesh.surface_get_arrays(0)
    var body:MeshInstance3D=g.core.skin.get_parent().find_child(g.profile.mesh_roles.skin,true,false)
    var adapted:=body.mesh.surface_get_arrays(0)
    var protected_count:=0
    var max_loss:=0.
    for i in original_arrays[Mesh.ARRAY_VERTEX].size():
        var authored:=0.
        var kept:=0.
        for j in range(i*4,i*4+4):
            var name_:String=original.skin.get_bind_name(original_arrays[Mesh.ARRAY_BONES][j])
            if name_.begins_with("Palm") or name_.begins_with("Fore"):authored+=original_arrays[Mesh.ARRAY_WEIGHTS][j]
            name_=body.skin.get_bind_name(adapted[Mesh.ARRAY_BONES][j])
            if name_.begins_with("Palm") or name_.begins_with("Fore"):kept+=adapted[Mesh.ARRAY_WEIGHTS][j]
        if authored>.99:
            protected_count+=1
            max_loss=maxf(max_loss,absf(authored-kept))
    source.free()
    check(protected_count>100 and max_loss<.001,"pesos distais autorais preservados")
    for side in ["l","r"]:
        var bend:=angle_at("upper_"+side,"fore_"+side,"palm_"+side)
        check(bend>8. and bend<34.,"flexão de repouso "+side)
    for shoe_name in g.profile.mesh_roles.shoes:
        var shoe:MeshInstance3D=g.core.skin.get_parent().find_child(shoe_name,true,false)
        check(shoe!=null,"calçado importado "+str(shoe_name))
        if shoe==null:continue
        var arrays:=shoe.mesh.surface_get_arrays(0)
        var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var role:="foot_l" if verts[0].x<0. else "foot_r"
        for i in verts.size():
            if shoe.skin.get_bind_name(arrays[Mesh.ARRAY_BONES][i*4])!=g.profile.bones[role] or arrays[Mesh.ARRAY_WEIGHTS][i*4]<.999:
                errors.append("calçado fora do pé "+role)
                break
    var standing:float=g.core.bodies.pelvis.global_position.y
    var before:=angle_at("thigh_l","shin_l","foot_l")
    var foot_start:Vector3=g.core.physical_pose("foot_l").origin
    g.composer.actions.squat.repeat=false
    g.composer.enable("squat",true)
    g.composer.enable("head",true)
    g.composer.enable("arms",true)
    var deepest:=standing
    var bent:=0.
    var planted:=0
    var foot_drift:=0.
    var peak_gap:=0.
    for i in 405:
        await physics_frame
        deepest=minf(deepest,g.core.bodies.pelvis.global_position.y)
        bent=maxf(bent,angle_at("thigh_l","shin_l","foot_l"))
        foot_drift=maxf(foot_drift,g.core.physical_pose("foot_l").origin.distance_to(foot_start))
        peak_gap=maxf(peak_gap,g.core.max_gap)
        if "foot_l" in g.core.active_support and "foot_r" in g.core.active_support:planted+=1
    var recovered:float=g.core.bodies.pelvis.global_position.y
    check(standing-deepest>.15 and absf(standing-recovered)<.035,"ciclo físico de descida e subida")
    check(bent-before>30. and foot_drift<.05 and planted>350,"cadeia de joelho com os dois pés plantados")
    check(peak_gap<.025,"juntas no agachamento composto")
    check(not g.composer.actions.squat.enabled and g.composer.actions.head.enabled and g.composer.actions.arms.enabled,"fim individual do ciclo")
    check(not g.interface.action_widgets.enabled.button_pressed,"checkbox do ciclo encerrado")
    g.select_base(2)
    check(g.composer.enable("squat",true) and g.composer.enable("flex",true),"variação sobre a base agachada")
    g.composer.enable("squat",false)
    await wait_ticks(250)
    check(g.core.bodies.pelvis.global_position.y<standing-.13,"agachada sustentada")
    g.select_base(4)
    var min_swing:=INF
    var max_swing:=-INF
    for i in 180:
        await physics_frame
        min_swing=minf(min_swing,g.preview.swing_l.x)
        max_swing=maxf(max_swing,g.preview.swing_l.x)
        if absf(g.preview.swing_l.x+g.preview.swing_r.x)>.01:
            errors.append("oposição dos braços na marcha")
            break
    check(max_swing-min_swing>15.,"balanço bilateral na caminhada")
    var requested:Dictionary=g.request_action("squat",true)
    check((requested.accepted or not requested.reason.is_empty()) and Engine.physics_ticks_per_second==120,"viabilidade da marcha e frequência")
    print("Pesos distais ",protected_count," · erro máximo ",max_loss)
    print("Agachar · descida %.1f cm · retorno %.1f mm · joelho %.1f→%.1f° · pés %d/405 · deriva %.1f mm · junta %.1f mm"%[(standing-deepest)*100.,absf(recovered-standing)*1000.,before,bent,planted,foot_drift*1000.,peak_gap*1000.])
    print("Movimento · ",errors)
    g.free()
    quit(0 if errors.is_empty() else 1)
