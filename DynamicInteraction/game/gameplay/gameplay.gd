extends "res://rig/active/lab.gd"
const Composer=preload("res://gameplay/action_composer.gd")
const Library=preload("res://gameplay/action_library.gd")
const Stimulus=preload("res://gameplay/external_stimulus_controller.gd")
const Customizations=preload("res://gameplay/customization_manager.gd")
const CameraOverlay=preload("res://gameplay/camera_overlay.gd")
const Interaction=preload("res://gameplay/interaction_mode_manager.gd")
const Visualization=preload("res://gameplay/visualization_manager.gd")
const UI=preload("res://gameplay/gameplay_ui_controller.gd")
const Cloth=preload("res://cloth/controller.gd")
var cloth:=Cloth.new()
var composer:=Composer.new()
var stimulus:=Stimulus.new()
var customizations:=Customizations.new()
var framing:=CameraOverlay.new()
var interaction_mode:=Interaction.new()
var visualization:=Visualization.new()
var interface:=UI.new()
var gesture_id:=-2
var gesture_previous:=Vector2.ZERO
var camera_gestures:Dictionary={}
var preferences:=ConfigFile.new()
var performance_visible:=false
var base_speed:=1.
var base_paused:=false

func _ready()->void:
    super()
    if not ready_to_pose:return
    get_window().title="ROSE · Adaptive Actions & Cloth Integration"
    for key in draw:draw[key]=false
    draw_reference=false
    display_forces=false
    display_torque=false
    visualization.build(core)
    interaction_mode.configure(core.skin.get_parent(),core,profile)
    add_child(cloth)
    cloth.configure(self,interaction_mode.picker)
    interaction_mode.cloth=cloth
    customizations.load_all()
    interface.refresh_customizations()
    framing.apply(camera)
    if preferences.load("user://gameplay_ui.cfg")==OK:
        cloth.set_accessory_enabled(bool(preferences.get_value("cloth","accessory",true)))
        interface.set_minimal(bool(preferences.get_value("ui","minimal",false)))
        var angles:Vector2=preferences.get_value("camera","angles",Vector2(26,12))
        framing.yaw=clampf(angles.x,-180.,180.)
        framing.pitch=clampf(angles.y,-65.,65.)
        framing.zoom=clampf(float(preferences.get_value("camera","zoom",2.62)),1.,5.)
        interaction_mode.mode=clampi(int(preferences.get_value("ui","mode",0)),0,2)
        interface.mode_menu.select(interaction_mode.mode)
        framing.apply(camera)
    interface.build_cloth_controls()
    get_window().size_changed.connect(resize_game)
    resize_game()

func resize_game()->void:
    var window:=get_window()
    window.content_scale_size=Vector2i(600,950) if window.size.y>window.size.x else Vector2i(1000,600)
    interface.call_deferred("layout")

func create_panel()->VBoxContainer:
    return interface.create(self)

func add_controls(content:VBoxContainer)->void:
    interface.build(content)

func update_camera()->void:
    if camera!=null:framing.apply(camera)

func select_base(index:int)->void:
    if ready_to_pose:start_pose_transition()
    observation_time=0.
    composer.select_base(index)
    if index==5:
        select_reference_mode(ReferenceMode.CUSTOM)
    else:
        select_reference_mode(ReferenceMode.AUTOMATIC)
        select_move(6 if index==1 else (1 if index==4 else 0))
    interface.refresh_actions()

func adjust_reference(dt:float)->void:
    super(dt)
    if composer.base==2:preview.travel.y-=balance.length_scale*.27
    if composer.base==3:
        preview.lumbar=Vector3(17.,0.,0.)
        preview.chest=Vector3(12.,0.,0.)
    var base_height:float=preview.travel.y
    composer.apply(preview,balance.length_scale)
    last_action_height=(preview.travel.y-base_height)/balance.length_scale

var observation_time:=0.
var custom_soles:Dictionary={}
var custom_ik_weight:=0.
var last_action_height:=0.

func observe_actions()->void:
    var leg:float=core.leg
    var pelvis:Vector3=core.physical_pose("pelvis").origin
    var feet:=0
    var down:=1.
    var up:=1.
    for side in ["l","r"]:
        var foot_role:String="foot_"+side
        if not foot_role in core.active_support:continue
        feet+=1
        var hip:Vector3=core.physical_pose("thigh_"+side).origin
        var knee:Vector3=core.physical_pose("shin_"+side).origin
        var foot:Vector3=core.physical_pose(foot_role).origin
        var a:=hip.distance_to(knee)
        var b:=knee.distance_to(foot)
        var horizontal:=Vector2(hip.x-foot.x,hip.z-foot.z).length_squared()
        var limits:Array=pose_reference.limits("shin_"+side)
        var max_angle:=maxf(absf(limits[0].x),absf(limits[1].x))
        var minimum:=a*a+b*b+2.*a*b*cos(deg_to_rad(max_angle))
        var base_height:=hip.y-foot.y-last_action_height*leg
        down=minf(down,(base_height-sqrt(maxf(0.,minimum-horizontal)))/leg)
        up=minf(up,(sqrt(maxf(0.,(a+b)*(a+b)-horizontal))-base_height)/leg)
    var outline:=core.support_outline(seat,true)
    var outside:=0.
    if outline.size()>=3:
        var hull:=Geometry2D.convex_hull(outline)
        var center:=Vector2(core.com.x,core.com.z)
        if not Geometry2D.is_point_in_polygon(center,hull):
            outside=INF
            for i in range(1,hull.size()):outside=minf(outside,center.distance_to(Geometry2D.get_closest_point_to_segment(center,hull[i-1],hull[i]))/leg)
    var seated:=false
    if seat.visible:
        var relative:=seat.to_local(pelvis)/leg
        seated=core.bodies.pelvis.support_body==seat or (absf(relative.x)<.43 and absf(relative.z)<.37 and relative.y<.42)
        if seated:
            var head:Vector3=core.bodies.head.global_position
            var query:=PhysicsRayQueryParameters3D.create(head,head+Vector3.UP*leg*.32,profile.ground_mask)
            var ceiling:=get_world_3d().direct_space_state.intersect_ray(query)
            if not ceiling.is_empty():up=minf(up,maxf(0.,(Vector3(ceiling.position).y-head.y)/leg-.12))
    var upright:float=(core.physical_pose("chest").origin-pelvis).normalized().dot(Vector3.UP)
    var authority:float=muscles.state_strength[core.state]
    if core.state==4:authority*=core.recovery_phase
    composer.context={"feet":feet,"seat":seated,"authority":authority,"upright":upright,"outside":outside,"down":maxf(0.,down),"up":maxf(0.,up),"free":mode==ReferenceMode.FREE}

func tick_reference(dt:float)->void:
    observation_time-=dt
    if observation_time<=0.:
        observe_actions()
        observation_time=.05
    composer.advance(dt)
    super(dt)

func compose_custom_reference(target:Dictionary)->Dictionary:
    custom_soles.clear()
    custom_ik_weight=0.
    if mode!=ReferenceMode.CUSTOM:return target
    var additions:=composer.offsets()
    if additions.is_empty():
        last_action_height=0.
        return target
    var result:=target.duplicate(true)
    var travel:Vector3=additions.get("pelvis",Vector3.ZERO)
    last_action_height=travel.y
    if travel.length_squared()>.00000001:
        pose_reference.apply(target)
        for side in ["l","r"]:
            if not "foot_"+side in core.active_support:continue
            var foot:=solver.pose("foot_"+side)
            custom_soles[side]=Transform3D(foot.basis,foot*profile.sole_offset)
        result.travel=(Vector3(target.travel)+travel).clamp(Pose.TRAVEL_MIN,Pose.TRAVEL_MAX)
        custom_ik_weight=smoothstep(0.,.04,travel.length())
    for role in additions:
        if role!="pelvis":result.angles[role]=pose_reference.clamp_angles(role,result.angles[role]+additions[role])
    return result

func fit_custom_feet()->void:
    for side in custom_soles:
        var ids:Array=[solver.bones["thigh_"+side],solver.bones["shin_"+side],solver.bones["foot_"+side]]
        var authored:Array[Quaternion]=[]
        for id in ids:authored.append(sk.get_bone_pose_rotation(id))
        solver.solve_leg(side,custom_soles[side])
        for i in ids.size():
            var id:int=ids[i]
            sk.set_bone_pose_rotation(id,authored[i].slerp(sk.get_bone_pose_rotation(id),custom_ik_weight))

func request_action(key:String,enabled:bool,parameters:Dictionary={})->Dictionary:
    if not composer.actions.has(key):return {"accepted":false,"reason":"Ação desconhecida."}
    var before:Dictionary=composer.actions[key].duplicate()
    for field in parameters:
        if not composer.set_parameter(key,field,parameters[field]):
            composer.actions[key]=before
            return {"accepted":false,"reason":"Parâmetro inválido: "+str(field)}
    var accepted:=composer.enable(key,enabled)
    if not accepted:composer.actions[key]=before
    return {"accepted":accepted,"reason":composer.blocked_reason}

func action_state()->Dictionary:
    var result:=composer.snapshot()
    result.transition={"active":not transition_from.is_empty(),"progress":clampf(transition_elapsed/maxf(.001,transition_duration),0.,1.) if not transition_from.is_empty() else 1.}
    return result

func select_reference_mode(value:int)->void:
    super(value)
    observation_time=0.
    move_menu.hide()
    if value==ReferenceMode.CUSTOM:composer.select_base(5)
    elif value==ReferenceMode.AUTOMATIC and composer.base==5:composer.base=1 if automatic_movement==6 else (4 if automatic_movement==1 else 0)
    if interface.base_menu!=null:
        interface.base_menu.select(composer.base)
        interface.refresh_actions()

func save_pose(title:String)->Error:
    var result:=super(title)
    if result==OK:interface.refresh_customizations()
    return result

func restore_original()->void:
    select_base(0)
    pose_editor.hide()

func save_preferences()->void:
    preferences.set_value("cloth","accessory",cloth.accessory_enabled)
    preferences.set_value("ui","mode",interaction_mode.mode)
    preferences.set_value("camera","angles",Vector2(framing.yaw,framing.pitch))
    preferences.set_value("camera","zoom",framing.zoom)
    preferences.save("user://gameplay_ui.cfg")

func _exit_tree()->void:
    save_preferences()
    # RefCounted UI closures do not retain the complete scene after switching.
    interface.game=null
    super()

var ui_elapsed:=0.

func needs_diagnostics()->bool:
    return performance_visible or draw.bone or draw.com or draw.ik or draw.limit or draw_reference or display_forces or display_torque

func _physics_process(dt:float)->void:
    super(dt)
    if not ready_to_pose:return
    stimulus.step(core,dt)
    cloth.step(dt)
    ui_elapsed+=dt
    if ui_elapsed<.10:return
    ui_elapsed=0.
    var active_names:=composer.active_text()
    interface.cloth_readout.visible=performance_visible
    if performance_visible:interface.cloth_readout.text="Tecidos · física %.2f ms · malha %.2f ms"%[cloth.physics_us*.001,cloth.render_us*.001]
    var status_text:=cloth.feedback if not cloth.feedback.is_empty() else active_names
    if mode==ReferenceMode.FREE and not active_names.is_empty():status_text="Livre · ações em espera"
    interface.status.text=Library.BASES[composer.base]+" · "+Muscle.STATES[core.state]+"\n"+status_text
    interface.active_list.text="Ativas: "+active_names if not active_names.is_empty() else "Nenhuma ação complementar ativa"
    readout.visible=performance_visible
    if interface.action_widgets.enabled.button_pressed!=composer.actions[interface.chosen_action].enabled:interface.refresh_actions()
    interface.refresh_action_reason()
    if interface.camera_box.is_visible_in_tree():interface.sync_camera()

func set_interaction(index:int)->void:
    end_drag()
    interaction_mode.release(false)
    gesture_id=-2
    camera_gestures.clear()
    interaction_mode.mode=index
    save_preferences()

func _unhandled_input(event:InputEvent)->void:
    if not ready_to_pose:return
    if interaction_mode.mode==0:
        super(event)
        return
    if event is InputEventScreenTouch and event.pressed:
        start_gesture(event.index,event.position)
    elif event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION:
        if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:start_gesture(-1,event.position)
        if interaction_mode.mode==2 and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            framing.zoom=clampf(framing.zoom*(.90 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),1.,5.)
            framing.apply(camera)

func start_gesture(id:int,pixel:Vector2)->void:
    if interaction_mode.mode==2:
        if camera_gestures.size()<2:camera_gestures[id]=pixel
    elif gesture_id==-2 and interaction_mode.begin(camera,pixel):
        gesture_id=id
        gesture_previous=pixel

func _input(event:InputEvent)->void:
    if interaction_mode.mode==0:
        super(event)
        return
    var id:=-3
    var position_:Vector2
    var release:=false
    if event is InputEventScreenTouch:
        id=event.index
        position_=event.position
        release=not event.pressed
    elif event is InputEventScreenDrag:
        id=event.index
        position_=event.position
    elif event is InputEventMouseMotion and event.device!=InputEvent.DEVICE_ID_EMULATION:
        id=-1
        position_=event.position
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device!=InputEvent.DEVICE_ID_EMULATION:
        id=-1
        position_=event.position
        release=not event.pressed
    else:return
    if camera_gestures.has(id):
        if release:camera_gestures.erase(id)
        else:
            var previous:Vector2=camera_gestures[id]
            if camera_gestures.size()==1:framing.orbit(position_-previous)
            else:
                var other_id= camera_gestures.keys().filter(func(key):return key!=id)[0]
                var other:Vector2=camera_gestures[other_id]
                framing.zoom=clampf(framing.zoom*maxf(10.,previous.distance_to(other))/maxf(10.,position_.distance_to(other)),1.,5.)
            camera_gestures[id]=position_
            framing.apply(camera)
        get_viewport().set_input_as_handled()
    elif id==gesture_id:
        if release:
            interaction_mode.release(not (event is InputEventScreenTouch and event.canceled))
            gesture_id=-2
        else:interaction_mode.drag(position_)
        get_viewport().set_input_as_handled()

func _notification(what:int)->void:
    super(what)
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        camera_gestures.clear()
        interaction_mode.release(false)
        gesture_id=-2

func reference_time_delta(dt:float)->float:
    return 0. if base_paused else dt*base_speed
