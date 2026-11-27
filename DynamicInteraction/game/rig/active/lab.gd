extends "res://rig/balance_lab.gd"
const Core=preload("res://rig/active/active_body.gd")
const Muscle=preload("res://rig/active/muscle_profile.gd")
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
    core.select_state(initial_state)
    for role in core.gain:core.gain[role]=muscles.state_strength[initial_state]
    previous_hz=Engine.physics_ticks_per_second
    Engine.physics_ticks_per_second=muscles.physics_hz
    configure_space()
    create_seat()

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

func select_move(value:int)->void:
    movement=value
    elapsed=0.
    fall_started=false
    seat.visible=value==6
    seat.get_child(0).set_deferred("disabled",value!=6)
    if value==7:select_state(2)

func select_state(value:int)->void:
    core.select_state(value)
    state_menu.select(value)

func adjust_reference(_dt:float)->void:
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
        preview.arm_l=Vector3(22.,45.,0.)
        preview.arm_r=preview.arm_l
    if movement==7 and not fall_started and elapsed>1.:
        fall_started=true
        select_state(3)
        perturb()

func perturb()->void:
    var trunk:RigidBody3D=core.bodies.chest
    trunk.apply_central_impulse(Vector3.BACK*trunk.mass*sqrt(balance.gravity*balance.length_scale)*.95)

func add_controls(content:VBoxContainer)->void:
    show_message(content,"Active Ragdoll · 1.3.3")
    button(content,"Voltar à tela inicial",func():
        get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene")))
    readout=show_message(content,"")
    dropdown(content,MOVES+EXTRA_MOVES,select_move)
    state_menu=dropdown(content,Muscle.STATES,select_state)
    state_menu.select(initial_state)
    preset_menu=dropdown(content,Muscle.PRESETS,apply_preset)
    preset_menu.select(1)
    show_message(content,"Arraste um segmento da personagem para aplicar força. Solte para liberar.")
    button(content,"Perturbar o tronco",perturb)
    button(content,"Recuperar em pé",func():select_move(0);select_state(4))
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
    button(content,"Salvar personalizado",save_custom)
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
    sync_controls()

func refresh_limits()->void:
    for role in core.joints:core.update_limits(role)

func apply_preset(index:int)->void:
    muscles=custom.duplicate(true) if index==3 else original.duplicate(true)
    if index in [0,2]:
        for i in Muscle.GROUPS.size():
            muscles.stiffness[i]=clampf(muscles.stiffness[i]*(1.45 if index==0 else .55),5,240)
    core.settings=muscles
    refresh_limits()
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
    for i in steps:tick(dt/steps)
    if drag_id!=-2 and drag_role.is_empty():pick_drag()
    var borne_weight:=clampf(grab_force.y/(profile.mass_kg*balance.gravity),0.,1.)
    core.drive(dt,balance.contacts,1.-borne_weight)
    pull_segment(dt)
    core.present()
    tick_us=Time.get_ticks_usec()-start
    mean_ms=lerpf(mean_ms,tick_us*.001,.08)
    debug_elapsed+=dt
    if debug_elapsed<(0.20 if quality==1 else 0.065):return
    debug_elapsed=0.
    draw_pose()
    var feet:=0
    var points:=PackedVector2Array()
    for role in core.active_support:
        if role.begins_with("foot"):feet+=1
        var body:RigidBody3D=core.bodies[role]
        var support:Vector3=body.get("support_point")
        if role.begins_with("foot"):
            var box:BoxShape3D=body.get_child(0).shape
            for x in [-.5,.5]:
                for z in [-.5,.5]:
                    var corner:=body.to_global(box.size*Vector3(x,-.5,z))
                    points.append(Vector2(corner.x,corner.z))
        else:points.append(Vector2(support.x,support.z))
    var hull:=Geometry2D.convex_hull(points) if points.size()>2 else PackedVector2Array()
    var stable:=hull.size()>2 and Geometry2D.is_point_in_polygon(Vector2(core.com.x,core.com.z),hull)
    physical_support="COM dentro da base" if stable else ("Sem contato" if points.is_empty() else "COM fora da base")
    var warning:=" · junta afastada" if core.max_gap>balance.length_scale*.035 else ""
    readout.text="%s · %s%s · %d pé(s)\nErro RMS %.1f cm · desvio de junta %.1f mm\nControle %.2f ms/tick"%[Muscle.STATES[core.state],physical_support,warning,feet,core.rms*100.,core.max_gap*1000.,mean_ms]

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
        end_drag()
    elif event is InputEventMouseButton and drag_id==-1 and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
        end_drag()
    elif event is InputEventScreenDrag and event.index==drag_id:pixel=event.position
    elif event is InputEventMouseMotion and drag_id==-1:pixel=event.position
    else:return
    if drag_id!=-2 and not drag_role.is_empty():
        var point=drag_plane.intersects_ray(camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))
        if point!=null:drag_goal=point
    get_viewport().set_input_as_handled()

func end_drag()->void:
    drag_role=""
    drag_id=-2
    grab_force=Vector3.ZERO
    grab_torque=Vector3.ZERO

func _notification(what:int)->void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:end_drag()

func pull_segment(dt:float)->void:
    if drag_role.is_empty():return
    var b:RigidBody3D=core.bodies[drag_role]
    var group:=muscles.group(drag_role)
    var arm:=b.global_basis*drag_local
    var velocity:=b.linear_velocity+b.angular_velocity.cross(arm)
    var k:float=muscles.stiffness[group]
    var d:float=2.*sqrt(k)*muscles.damping[group]
    var acceleration:=((drag_goal-b.global_position-arm)*k-velocity*d)/(1.+dt*d)
    var force:=(acceleration*profile.mass_kg).limit_length(muscles.max_force[group])
    b.apply_central_force(force)
    var torque:=arm.cross(force).limit_length(muscles.max_torque[group])
    b.apply_torque(torque)
    grab_force=force
    grab_torque=torque
