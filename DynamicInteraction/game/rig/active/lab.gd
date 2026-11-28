extends "res://rig/balance_lab.gd"
const Core=preload("res://rig/active/active_body.gd")
const Muscle=preload("res://rig/active/muscle_profile.gd")
const Pose=preload("res://rig/active/pose_reference.gd")
const PoseLibrary=preload("res://rig/active/pose_library.gd")
const PoseEditor=preload("res://rig/active/pose_editor.gd")
enum ReferenceMode { AUTOMATIC, CUSTOM, FREE }
const REFERENCE_MODES:=["Automático","Personalizado","Livre"]
const CUSTOM_PATH:="user://active_ragdoll.cfg"
const EXTRA_MOVES:=["Sentar","Queda controlada"]
const NAMES:=["Rigidez (s⁻²)","Amortecimento relativo","Força máxima (N)","Torque máximo (N·m)","Escala dos limites","Recuperação (/s)"]
@export var muscles:Muscle
@export_enum("Animated","Active","Relaxed","Passive","Recovery") var initial_state:=1
@export_enum("Completo","Econômico") var quality:=0
var core:=Core.new()
var original:Muscle
var custom:Muscle
var editor_group:=0
var controls:Array[HSlider]=[]
var labels:Array[Label]=[]
var preset_menu:OptionButton
var state_menu:OptionButton
var display_forces:=false
var display_torque:=false
var draw_reference:=true
var seat:StaticBody3D
var fall_started:=false
var drag_role:=""
var drag_local:=Vector3.ZERO
var drag_goal:=Vector3.ZERO
var drag_plane:=Plane()
var drag_id:=-2
var pending_pixel:=Vector2.ZERO
var grab_force:=Vector3.ZERO
var grab_torque:=Vector3.ZERO
var tick_us:=0
var debug_elapsed:=0.
var previous_iterations:float=-1.
var previous_penetration:float
var previous_hz:int
var physical_support:="Sem apoio"
var mode:=ReferenceMode.AUTOMATIC
var pose_reference:=Pose.new()
var pose_library:=PoseLibrary.new()
var pose_draft:Dictionary={}
var pose_title:="Postura atual"
var pose_library_error:=OK
var pose_editor:PoseEditor
var reference_menu:OptionButton
var move_menu:OptionButton
var automatic_movement:=0
var capture_on_release:=false
var transition_seconds:=.60
var transition_from:Dictionary={}
var transition_elapsed:=0.
var transition_duration:=.60
var free_pose:Dictionary={}
var reference_strength:=1.
var position_support:=1.

func _ready()->void:
    if muscles==null or not muscles.valid():
        show_message(create_panel(),"Perfil muscular inválido.")
        return
    original=muscles
    muscles=original.duplicate(true)
    custom=muscles.duplicate(true)
    read_custom()
    super()
    if not ready_to_pose:return
    var skin:=sk
    # O modelo visível fica no mundo; só a cópia numérica segue a raiz procedural.
    var model:=skin.get_parent_node_3d()
    while model.get_parent()!=$Model:model=model.get_parent_node_3d()
    for player in model.find_children("*","AnimationPlayer",true,false):
        player.stop()
        player.active=false
    for tree in model.find_children("*","AnimationTree",true,false):tree.active=false
    model.top_level=true
    var reference:=Skeleton3D.new()
    $Model.add_child(reference)
    reference.global_transform=skin.global_transform
    for id in skin.get_bone_count():
        reference.add_bone(skin.get_bone_name(id))
    for id in skin.get_bone_count():
        reference.set_bone_parent(id,skin.get_bone_parent(id))
        reference.set_bone_rest(id,skin.get_bone_rest(id))
    reference.reset_bone_poses()
    sk=reference
    solver.configure(reference,profile)
    add_child(core)
    core.build(skin,reference,profile,muscles,balance.length_scale)
    balance.supported_weight_fraction=muscles.weight_assist
    core.select_state(initial_state)
    for role in core.gain:core.gain[role]=muscles.state_strength[initial_state]
    previous_hz=Engine.physics_ticks_per_second
    Engine.physics_ticks_per_second=muscles.physics_hz
    configure_space()
    create_seat()
    pose_reference.configure(solver,muscles,balance.length_scale)
    pose_library_error=pose_library.load_all()
    pose_editor.update_saved()
    if pose_library_error!=OK:pose_editor.message.text="Arquivo de poses indisponível · "+error_string(pose_library_error)

func configure_space()->void:
    if ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT")=="Jolt Physics":return
    previous_penetration=PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION)
    previous_iterations=PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS)
    PhysicsServer3D.space_set_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS,muscles.solver_iterations)
    PhysicsServer3D.space_set_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION,balance.length_scale*.002)

func create_seat()->void:
    var length_:float=balance.length_scale
    seat=StaticBody3D.new()
    seat.collision_layer=profile.ground_mask
    var box:=BoxShape3D.new()
    box.size=Vector3(0.75,0.10,0.48)*length_
    var shape:=CollisionShape3D.new()
    shape.shape=box
    seat.add_child(shape)
    var mesh:=MeshInstance3D.new()
    var surface:=BoxMesh.new()
    surface.size=box.size
    mesh.mesh=surface
    seat.add_child(mesh)
    add_child(seat)
    var hip:Vector3=core.rest("pelvis").origin
    seat.global_position=hip+Vector3(0.,-0.52,-0.45)*length_
    seat.visible=false
    shape.disabled=true

func set_seat_visible(value:bool)->void:
    seat.visible=value
    seat.get_child(0).set_deferred("disabled",not value)

func select_move(value:int)->void:
    automatic_movement=value
    movement=value
    move_menu.select(value)
    elapsed=0.
    fall_started=false
    set_seat_visible(value==6)
    if value==7:select_state(2)

func select_state(value:int)->void:
    core.select_state(value)
    state_menu.select(value)

func adjust_reference(dt:float)->void:
    # A referência de pé compensa parte da deflexão estática da mola das solas.
    # A carga migra progressivamente ao sentar ou iniciar a queda.
    var standing_share:=muscles.weight_assist if movement not in [6,7] else 0.
    balance.supported_weight_fraction=move_toward(balance.supported_weight_fraction,standing_share,dt*2.)
    if core.active_support.size()==1 and core.active_support[0] in ["foot_l","foot_r"]:
        var support:Vector3=core.bodies[core.active_support[0]].support_point
        var error:=support-core.com
        error.y=0.
        preview.travel+=sk.global_basis.inverse()*error.limit_length(balance.length_scale*.06)*profile.balance_gain
    if movement==6:
        var size_:float=balance.length_scale
        var fraction:=smoothstep(0.,1.2,elapsed)
        preview.travel+=Vector3(0.,-.42,-.28)*size_*fraction
        preview.lumbar=Vector3(12.*fraction,0.,0.)
    if movement==7:
        var brace:=smoothstep(0.,.9,elapsed)
        preview.travel+=Vector3(0.,-.30,.10)*balance.length_scale*brace
        preview.lumbar=Vector3(18.*brace,0.,0.)
        preview.arm_l=Vector3(45.,60.,0.)
        preview.arm_r=preview.arm_l
    else:
        preview.arm_l=profile.arm_rest_angles
        preview.arm_r=preview.arm_l
    for i in 2:
        var side:String=FullBody.SIDES[i]
        var swing:=0.
        if movement==1:swing=profile.walk_arm_swing*sin(TAU*(elapsed/.98+i*.5))
        elif movement==6:swing=12.*smoothstep(0.,1.2,elapsed)
        preview["swing_"+side]=Vector3(swing,0.,0.)
    if movement==7 and not fall_started and elapsed>1.:
        fall_started=true
        select_state(3)
        perturb()

func perturb()->void:
    var trunk:RigidBody3D=core.bodies.chest
    trunk.apply_central_impulse(Vector3.BACK*trunk.mass*sqrt(balance.gravity*balance.length_scale)*.95)

func add_controls(content:VBoxContainer)->void:
    show_message(content,"Active Ragdoll · 1.3.3.1")
    button(content,"Voltar à tela inicial",func():
        get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene")))
    readout=show_message(content,"")
    reference_menu=dropdown(content,REFERENCE_MODES,select_reference_mode)
    move_menu=dropdown(content,MOVES+EXTRA_MOVES,select_move)
    state_menu=dropdown(content,Muscle.STATES,select_state)
    state_menu.select(initial_state)
    button(content,"Editor de posturas",toggle_pose_editor)
    pose_editor=PoseEditor.new()
    content.add_child(pose_editor)
    pose_editor.build(self)
    pose_editor.hide()
    var advanced:=VBoxContainer.new()
    button(content,"Músculos e diagnóstico",func():advanced.visible=not advanced.visible)
    content.add_child(advanced)
    advanced.hide()
    add_advanced_controls(advanced)

func add_advanced_controls(content:VBoxContainer)->void:
    preset_menu=dropdown(content,Muscle.PRESETS,apply_preset)
    preset_menu.select(1)
    show_message(content,"Arraste um segmento da personagem para aplicar força. Solte para liberar.")
    button(content,"Perturbar o tronco",perturb)
    button(content,"Recuperar em pé",recover_standing)
    button(content,"Reiniciar ensaio",func():get_tree().reload_current_scene())
    button(content,"Voltar ao equilíbrio 1.3.2",func():get_tree().change_scene_to_file("res://rig/balance_lab.tscn"))
    parameter(content,"Inclinação do chão (°)",-12,12,1,0,func(v):$Ground.rotation.x=deg_to_rad(v))
    show_message(content,"Grupo muscular")
    dropdown(content,Muscle.GROUPS,func(i):editor_group=i;sync_controls())
    for i in Muscle.FIELDS.size():
        labels.append(show_message(content,NAMES[i]))
        var slider:=HSlider.new()
        slider.min_value=Muscle.RANGES[i][0]
        slider.max_value=Muscle.RANGES[i][1]
        slider.step=.05 if i in [1,4,5] else 1.
        slider.custom_minimum_size.y=36
        content.add_child(slider)
        controls.append(slider)
        slider.value_changed.connect(edit_value.bind(i))
    sync_controls()
    button(content,"Salvar preset muscular",save_custom)
    checkbox(content,"Esqueleto físico",true,func(v):draw.bone=v)
    checkbox(content,"Referência",true,func(v):draw_reference=v)
    checkbox(content,"Limites do grupo",true,func(v):draw.limit=v)
    checkbox(content,"Forças",false,func(v):display_forces=v)
    checkbox(content,"Torques",false,func(v):display_torque=v)
    checkbox(content,"Centro de massa",true,func(v):draw.com=v)
    checkbox(content,"Pontos de apoio",true,func(v):draw.ik=v)
    var q:=dropdown(content,["Completo","Econômico"],func(i):quality=i)
    q.select(quality)
    parameter(content,"Câmera (°)",-180,180,1,orbit,func(v):orbit=v;update_camera())

func button(parent:Control,title:String,action:Callable)->void:
    var b:=Button.new()
    b.text=title
    b.custom_minimum_size.y=42
    parent.add_child(b)
    b.pressed.connect(action)

func sync_controls()->void:
    for i in controls.size():
        var v:float=muscles.get(Muscle.FIELDS[i])[editor_group]
        controls[i].set_value_no_signal(v)
        labels[i].text="%s · %.2f"%[NAMES[i],v]

func edit_value(value:float,index:int)->void:
    var key:String=Muscle.FIELDS[index]
    var values:PackedFloat32Array=muscles.get(key)
    values[editor_group]=value
    muscles.set(key,values)
    custom=muscles.duplicate(true)
    preset_menu.select(3)
    if index==4:refresh_limits()
    pose_editor.refresh()
    sync_controls()

func refresh_limits()->void:
    for role in core.joints:core.update_limits(role)

func apply_preset(index:int)->void:
    muscles=custom.duplicate(true) if index==3 else original.duplicate(true)
    if index in [0,2]:
        for i in Muscle.GROUPS.size():
            muscles.stiffness[i]=clampf(muscles.stiffness[i]*(1.45 if index==0 else .55),5,240)
    core.settings=muscles
    pose_reference.muscles=muscles
    refresh_limits()
    pose_editor.refresh()
    sync_controls()

func save_custom(path:String=CUSTOM_PATH)->void:
    var cfg:=ConfigFile.new()
    custom=muscles.duplicate(true)
    for field in Muscle.FIELDS:cfg.set_value("groups",field,custom.get(field))
    var result:=cfg.save(path)
    if result==OK:
        preset_menu.select(3)
        preset_menu.set_item_text(3,"Personalizado · salvo")
    else:preset_menu.set_item_text(3,"Erro ao salvar · %s"%error_string(result))

func read_custom(path:String=CUSTOM_PATH)->void:
    var cfg:=ConfigFile.new()
    if cfg.load(path)!=OK:return
    var candidate:Muscle=custom.duplicate(true)
    for field in Muscle.FIELDS:
        var values=cfg.get_value("groups",field,null)
        if not values is PackedFloat32Array:return
        candidate.set(field,values)
    if candidate.valid():custom=candidate

func _physics_process(dt:float)->void:
    if not ready_to_pose:return
    var start:=Time.get_ticks_usec()
    var steps:=maxi(1,ceili(dt*120.-.00001))
    for i in steps:tick_reference(dt/steps)
    if drag_id!=-2 and drag_role.is_empty():pick_drag()
    var borne_weight:=clampf(grab_force.y/(profile.mass_kg*balance.gravity),0.,1.)
    var wanted_strength:=.12 if mode==ReferenceMode.FREE else 1.
    reference_strength=move_toward(reference_strength,wanted_strength,dt/maxf(transition_seconds,.15))
    var wanted_support:=1.
    if mode==ReferenceMode.FREE:wanted_support=0.
    elif mode==ReferenceMode.CUSTOM:wanted_support=custom_support()
    position_support=move_toward(position_support,wanted_support,dt/maxf(transition_seconds,.15))
    core.drive(dt,balance.contacts,(1.-borne_weight)*position_support,reference_strength)
    pull_segment(dt)
    core.present()
    tick_us=Time.get_ticks_usec()-start
    mean_ms=lerpf(mean_ms,tick_us*.001,.08)
    debug_elapsed+=dt
    if debug_elapsed<(0.20 if quality==1 else 0.065):return
    debug_elapsed=0.
    if not needs_diagnostics():
        if lines.get_surface_count()>0:lines.clear_surfaces()
        return
    draw_pose()
    var feet:=int("foot_l" in core.active_support)+int("foot_r" in core.active_support)
    var points:=core.support_outline(seat,false)
    var hull:=Geometry2D.convex_hull(points) if points.size()>2 else PackedVector2Array()
    var stable:=hull.size()>2 and Geometry2D.is_point_in_polygon(Vector2(core.com.x,core.com.z),hull)
    physical_support="COM dentro da base" if stable else ("Sem contato" if points.is_empty() else "COM fora da base")
    var warning:=" · junta afastada" if core.max_gap>balance.length_scale*.035 else ""
    var automatic_names:=MOVES+EXTRA_MOVES
    var current_pose:String=automatic_names[movement] if mode==ReferenceMode.AUTOMATIC else (pose_title if mode==ReferenceMode.CUSTOM else "Última referência")
    readout.text="%s · %s\n%s\n%s%s · %d pé(s) · %d apoio(s)\nErro RMS %.1f cm · %.2f ms/tick"%[
        REFERENCE_MODES[mode],Muscle.STATES[core.state],current_pose,physical_support,warning,feet,core.active_support.size(),core.rms*100.,mean_ms]

func needs_diagnostics()->bool:
    return true

func draw_pose()->void:
    lines.clear_surfaces()
    lines.surface_begin(Mesh.PRIMITIVE_LINES)
    line(Vector3.ZERO,Vector3.ZERO,Color.TRANSPARENT)
    var scale_:float=balance.length_scale
    for role in core.bodies:
        var b:RigidBody3D=core.bodies[role]
        var pos:=sk.to_local(core.physical_pose(role).origin)
        if profile.PARENTS.has(role):
            var parent:String=profile.PARENTS[role]
            if draw.bone:line(pos,sk.to_local(core.physical_pose(parent).origin),COLORS.ik)
            if draw_reference:line(solver.pose(role).origin,solver.pose(parent).origin,COLORS.bone)
        var center:=sk.to_local(b.global_position)
        var group:=muscles.group(role)
        if role==drag_role:
            line(center,sk.to_local(drag_goal),COLORS.limit)
            if display_forces:line(center,sk.to_local(b.global_position+grab_force*scale_/muscles.max_force[group]),COLORS.limit)
            if display_torque:line(center,sk.to_local(b.global_position+grab_torque*scale_/muscles.max_torque[group]),COLORS.limit)
        if display_forces:line(center,sk.to_local(b.global_position+Vector3(core.applied_force[role])*scale_/muscles.max_force[group]),COLORS.com)
        if display_torque:line(center,sk.to_local(b.global_position+Vector3(core.applied_torque[role])*scale_/muscles.max_torque[group]),COLORS.mass)
        if draw.ik and role in core.active_support:cross_mark(sk.to_local(b.get("support_point")),scale_*.025,COLORS.ik)
        if draw.limit and group==editor_group:
            var bounds:=muscles.bounds(role,profile)
            var frame:=Basis.IDENTITY
            if core.joints.has(role):
                frame=core.bodies[profile.PARENTS[role]].global_basis*Basis.from_euler(Vector3(muscles.joint_axes_degrees.get(role,Vector3.ZERO))*PI/180.)
            for axis in (1 if role.begins_with("shin_") else 3):
                var normal:Vector3=[Vector3.RIGHT,Vector3.UP,Vector3.BACK][axis]
                var ray:Vector3=[Vector3.DOWN,Vector3.RIGHT,Vector3.DOWN][axis]
                for j in 8:
                    var a:=deg_to_rad(lerpf(bounds[0][axis],bounds[1][axis],j/8.))
                    var z:=deg_to_rad(lerpf(bounds[0][axis],bounds[1][axis],(j+1)/8.))
                    line(pos+frame*ray.rotated(normal,a)*scale_*.1,pos+frame*ray.rotated(normal,z)*scale_*.1,COLORS.limit)
    if draw.com:cross_mark(sk.to_local(core.com),scale_*.045,COLORS.com)
    lines.surface_end()

func _exit_tree()->void:
    if previous_hz>0:Engine.physics_ticks_per_second=previous_hz
    if previous_iterations>=0.:
        PhysicsServer3D.space_set_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION,previous_penetration)
        PhysicsServer3D.space_set_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS,previous_iterations)

func _unhandled_input(event:InputEvent)->void:
    if not ready_to_pose:return
    if event is InputEventScreenTouch and event.pressed:
        begin_drag(event.position,event.index)
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.device!=InputEvent.DEVICE_ID_EMULATION:
        begin_drag(event.position,-1)

func begin_drag(pixel:Vector2,pointer:int)->void:
    if drag_id!=-2:return
    pending_pixel=pixel
    drag_id=pointer

func pick_drag()->void:
    var pixel:=pending_pixel
    var origin:=camera.project_ray_origin(pixel)
    var direction:=camera.project_ray_normal(pixel)
    var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*camera.far,muscles.segment_layer)
    var hit:=get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        end_drag()
        return
    var role=core.bodies.find_key(hit.collider)
    if role==null:
        end_drag()
        return
    drag_role=role
    drag_local=hit.collider.to_local(hit.position)
    drag_goal=hit.position
    drag_plane=Plane(camera.global_basis.z.normalized(),drag_goal)

func _input(event:InputEvent)->void:
    if drag_id==-2:return
    var pixel:Vector2
    if event is InputEventScreenTouch and event.index==drag_id and not event.pressed:
        release_drag(not event.canceled)
    elif event is InputEventMouseButton and drag_id==-1 and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
        release_drag(true)
    elif event is InputEventScreenDrag and event.index==drag_id:pixel=event.position
    elif event is InputEventMouseMotion and drag_id==-1:pixel=event.position
    else:return
    if drag_id!=-2 and not drag_role.is_empty():
        var point=drag_plane.intersects_ray(camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))
        if point!=null:drag_goal=point
    get_viewport().set_input_as_handled()

func release_drag(allow_capture:bool)->void:
    var capture:=allow_capture and mode==ReferenceMode.CUSTOM and capture_on_release and not drag_role.is_empty()
    end_drag()
    if capture:capture_custom_pose(true)

func end_drag()->void:
    drag_role=""
    drag_id=-2
    grab_force=Vector3.ZERO
    grab_torque=Vector3.ZERO

func _notification(what:int)->void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:end_drag()

func pull_segment(dt:float)->void:
    if drag_role.is_empty():return
    var applied:=core.apply_grip(drag_role,drag_local,drag_goal,dt)
    if not applied.is_empty():
        grab_force=applied.force
        grab_torque=applied.torque

func toggle_pose_editor()->void:
    pose_editor.visible=not pose_editor.visible
    if pose_editor.visible and pose_draft.is_empty():
        pose_draft=pose_reference.capture(reference_world_bone,seat.visible)
        pose_editor.refresh()

func reference_world_bone(role:String)->Transform3D:
    return sk.global_transform*solver.pose(role)

func start_pose_transition()->void:
    transition_from=pose_reference.snapshot()
    transition_elapsed=0.
    transition_duration=transition_seconds

func select_reference_mode(value:int)->void:
    if value==mode:return
    start_pose_transition()
    if value==ReferenceMode.FREE:
        free_pose=pose_reference.capture(reference_world_bone,seat.visible)
    elif value==ReferenceMode.CUSTOM and pose_draft.is_empty():
        pose_draft=pose_reference.capture(reference_world_bone,seat.visible)
    mode=value
    reference_menu.select(mode)
    move_menu.visible=mode==ReferenceMode.AUTOMATIC
    if mode==ReferenceMode.AUTOMATIC:
        balance.contacts.clear()
        balance.velocity=0.
        balance.height=$Model.position.y
        select_move(automatic_movement)
    elif mode==ReferenceMode.CUSTOM:set_seat_visible(pose_draft.seat)
    pose_editor.refresh()

func capture_custom_pose(from_body:bool)->void:
    if not ready_to_pose:return
    var get_bone:Callable=core.physical_pose if from_body else reference_world_bone
    pose_draft=pose_reference.capture(get_bone,seat.visible)
    pose_title="Postura capturada" if from_body else "Referência copiada"
    select_reference_mode(ReferenceMode.CUSTOM)
    start_pose_transition()
    set_seat_visible(pose_draft.seat)
    pose_editor.refresh()

func edit_joint(role:String,axis:int,value:float)->void:
    if not ready_to_pose:return
    select_reference_mode(ReferenceMode.CUSTOM)
    var angles:Vector3=pose_draft.angles[role]
    angles[axis]=value
    pose_draft.angles[role]=pose_reference.clamp_angles(role,angles)
    edit_pose()

func edit_pelvis(axis:int,value:float)->void:
    if not ready_to_pose:return
    select_reference_mode(ReferenceMode.CUSTOM)
    var travel:Vector3=pose_draft.travel
    travel[axis]=value
    pose_draft.travel=travel.clamp(Pose.TRAVEL_MIN,Pose.TRAVEL_MAX)
    edit_pose()

func edit_seat(value:bool)->void:
    if not ready_to_pose:return
    select_reference_mode(ReferenceMode.CUSTOM)
    pose_draft.seat=value
    set_seat_visible(value)
    edit_pose()

func edit_pose()->void:
    pose_title="Postura editada"
    start_pose_transition()
    pose_editor.refresh()

func save_pose(title:String)->Error:
    if pose_library_error!=OK:return pose_library_error
    var result:=pose_library.save_pose(title,pose_draft)
    if result==OK:pose_title=title.strip_edges()
    return result

func load_pose(title:String)->bool:
    if not pose_library.entries.has(title):return false
    pose_draft=pose_library.entries[title].duplicate(true)
    pose_title=title
    select_reference_mode(ReferenceMode.CUSTOM)
    start_pose_transition()
    set_seat_visible(pose_draft.seat)
    pose_editor.refresh()
    return true

func restore_original()->void:
    select_reference_mode(ReferenceMode.AUTOMATIC)
    pose_editor.hide()

func recover_standing()->void:
    restore_original()
    select_move(0)
    select_state(4)

func tick_reference(dt:float)->void:
    if mode==ReferenceMode.AUTOMATIC:
        tick(dt)
    else:
        $Model.position=Vector3.ZERO
        var target:=pose_draft if mode==ReferenceMode.CUSTOM else free_pose
        pose_reference.apply(compose_custom_reference(target))
        if mode==ReferenceMode.CUSTOM:fit_custom_feet()
    if not transition_from.is_empty():
        transition_elapsed+=dt
        var fraction:=clampf(transition_elapsed/transition_duration,0.,1.)
        pose_reference.blend_from(transition_from,smoothstep(0.,1.,fraction))
        if fraction>=1.:transition_from.clear()
    if mode!=ReferenceMode.AUTOMATIC:
        solver.calculate_mass()
        for side in ["l","r"]:
            var sole:Vector3=sk.to_global(solver.pose("foot_"+side)*profile.sole_offset)
            balance.sense(get_world_3d().direct_space_state,side,sole,false)
            balance.verify_support(side,sole)

func custom_support()->float:
    # A sustentação cede quando a referência desloca o peso para fora dos apoios.
    var points:=core.support_outline(seat,true)
    if points.is_empty():return 0.
    var hull:=Geometry2D.convex_hull(points)
    var target:=sk.to_global(solver.center_of_mass)
    var xy:=Vector2(target.x,target.z)
    if Geometry2D.is_point_in_polygon(xy,hull):return 1.
    var distance:=INF
    for i in range(1,hull.size()):
        var closest:=Geometry2D.get_closest_point_to_segment(xy,hull[i-1],hull[i])
        distance=minf(distance,xy.distance_to(closest))
    return 1.-smoothstep(.08,.28,distance/balance.length_scale)

func compose_custom_reference(target:Dictionary)->Dictionary:
    return target

func fit_custom_feet()->void:
    pass
