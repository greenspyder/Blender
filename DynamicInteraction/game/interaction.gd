extends Node3D

enum State { TRAY, DRAGGING, ATTACHED }

@export var snap_radius: float = 0.12
@export var reaction_radius: float = 0.45
@export var mouth_speed: float = 8.0

@onready var camera: Camera3D = $Camera3D
@onready var rose: Node3D = $Rose
@onready var anchor: Marker3D = $Rose/MouthAnchor
@onready var cue: MeshInstance3D = $Rose/MouthAnchor/Cue
@onready var tray: Marker3D = $Tray
@onready var candy: Node3D = $Lollipop
@onready var face: MeshInstance3D = $Rose/Portrait.find_child("Face", true, false)
@onready var status_label: Label = $HUD/Bottom/Controls/Status
@onready var action: Button = $HUD/Bottom/Controls/Action

var state: State = State.TRAY
var opening: float = 0.0
var _target_opening: float = 0.0
var _over_target: bool = false
var _drag_offset: Vector2
var _orbiting: bool = false
var _mouth_index: int
var _blink_time: float = 0.0
var _blink_meshes: Array[MeshInstance3D] = []
var _start_angle: float


func _ready() -> void:
	_start_angle = rose.rotation.y
	_mouth_index = face.find_blend_shape_by_name(&"mouth_open")
	assert(_mouth_index >= 0, "O GLB precisa da shape key mouth_open.")
	for child in $Rose/Portrait.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and child.find_blend_shape_by_name(&"blink_l") >= 0:
			_blink_meshes.append(child)
	action.pressed.connect(toggle_lollipop)
	$HUD/Bottom/Controls/Reset.pressed.connect(reset_demo)
	_return_to_tray()


func _process(delta: float) -> void:
	opening = move_toward(opening, _target_opening, delta * mouth_speed)
	face.set_blend_shape_value(_mouth_index, opening)
	_blink_time = fmod(_blink_time + delta, 4.1)
	var blink := clampf(1.0 - absf(_blink_time - 3.8) / 0.095, 0.0, 1.0)
	for mesh in _blink_meshes:
		mesh.set_blend_shape_value(mesh.find_blend_shape_by_name(&"blink_l"), blink)
		mesh.set_blend_shape_value(mesh.find_blend_shape_by_name(&"blink_r"), blink)
	if state == State.ATTACHED:
		_follow_mouth()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _hits_lollipop(event.position):
			start_drag(event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = true
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:
				toggle_lollipop()
			KEY_R:
				reset_demo()
			KEY_ESCAPE:
				reset_demo()
			_:
				return
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if state == State.DRAGGING:
			drag_to(event.position)
		elif _orbiting:
			rotate_rose(-event.relative.x * 0.006)
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and state == State.DRAGGING:
			finish_drag(event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_orbiting = false
		if state == State.DRAGGING:
			_return_to_tray()


func _hits_lollipop(screen: Vector2) -> bool:
	var tip := camera.unproject_position(candy.global_position)
	var handle := camera.unproject_position(candy.to_global(Vector3(0, -0.31, 0)))
	var nearest := Geometry2D.get_closest_point_to_segment(screen, tip, handle)
	return screen.distance_to(nearest) <= 22.0


func start_drag(screen: Vector2) -> void:
	_drag_offset = camera.unproject_position(candy.global_position) - screen
	state = State.DRAGGING
	_orbiting = false
	drag_to(screen)


func drag_to(screen: Vector2) -> void:
	var cursor := screen + _drag_offset
	var normal := camera.global_transform.basis.z
	var plane := Plane(normal, anchor.global_position)
	var ray_start := camera.project_ray_origin(cursor)
	var ray_dir := camera.project_ray_normal(cursor)
	var point: Variant = plane.intersects_ray(ray_start, ray_dir)
	if point == null:
		return
	var separation: float = point.distance_to(anchor.global_position)
	_over_target = separation <= snap_radius
	_target_opening = 1.0 - smoothstep(snap_radius, reaction_radius, separation)
	# Mantenha o objeto à frente da malha até o encaixe.
	cue.visible = _over_target
	candy.global_transform = Transform3D(tray.global_basis, point + normal * 0.8)
	status_label.text = "  Solte para encaixar" if _over_target else "  Aproxime da boca"


func finish_drag(screen: Vector2) -> void:
	drag_to(screen)
	if _over_target:
		_attach()
	else:
		_return_to_tray()


func _attach() -> void:
	state = State.ATTACHED
	cue.hide()
	_target_opening = 1.0
	_follow_mouth()
	status_label.text = "  Encaixado · arraste para retirar"
	action.text = "Retirar pirulito · Espaço"


func _follow_mouth() -> void:
	var angle := Basis.from_euler(Vector3(-0.65, 0.0, 0.22))
	candy.global_transform = anchor.global_transform * Transform3D(angle, Vector3.ZERO)


func _return_to_tray() -> void:
	state = State.TRAY
	_over_target = false
	_target_opening = 0.0
	cue.hide()
	candy.global_transform = tray.global_transform
	status_label.text = "  Na bandeja"
	action.text = "Oferecer pirulito · Espaço"


func rotate_rose(amount: float) -> void:
	rose.rotation.y = clampf(rose.rotation.y + amount, -0.62, 0.62)
	if state == State.ATTACHED:
		_follow_mouth()


func toggle_lollipop() -> void:
	if state == State.TRAY:
		_attach()
	else:
		_return_to_tray()


func reset_demo() -> void:
	rose.rotation.y = _start_angle
	_orbiting = false
	_return_to_tray()
