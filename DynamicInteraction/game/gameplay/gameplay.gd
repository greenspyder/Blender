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
    get_window().title="ROSE · Foundation Refinement"
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
    composer.apply(preview,balance.length_scale)

func tick_reference(dt:float)->void:
    composer.advance(dt)
    super(dt)

func compose_custom_reference(target:Dictionary)->Dictionary:
    if mode!=ReferenceMode.CUSTOM:return target
    var additions:=composer.offsets()
    if additions.is_empty():return target
    var result:=target.duplicate(true)
    additions.erase("pelvis") # Na pose salva os apoios e a altura permanecem definidos pelo usuário.
    for role in additions:
        result.angles[role]=pose_reference.clamp_angles(role,result.angles[role]+additions[role])
    return result

func select_reference_mode(value:int)->void:
    super(value)
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
