extends Node3D

const TouchDrag = preload("res://direct/touch_drag.gd")
var input_drag := TouchDrag.new()
var grab_mode := false
var hand_point := Vector3.ZERO
var drag_plane := Plane()
var offset := Vector3.ZERO
var active_finger := -1
var linked := false
var detail := ""
var defaults := Vector3.ZERO
var tools := HBoxContainer.new()
@onready var camera: Camera3D = $Camera3D
@onready var cube: MeshInstance3D = $Cube
@onready var pointer: MeshInstance3D = $Pointer

func _ready() -> void:
 defaults = cube.position
 var controls := Control.new()
 $HUD.add_child(controls)
 controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
 controls.add_child(tools)
 tools.position = Vector2(12,12)
 var modes := OptionButton.new()
 modes.add_item("Tocar")
 modes.add_item("Agarrar")
 modes.select(1)
 tools.add_child(modes)
 grab_mode = true
 modes.item_selected.connect(func(index): clear_drag(); grab_mode=index==1)
 input_drag.add_debug(controls,add_button("Debug toque",func():pass))
 add_button("Reiniciar",func():clear_drag();cube.position=defaults;pointer.hide())
 add_button("Rosé",func():get_tree().change_scene_to_file("res://direct_touch.tscn"))
 var instructions := Label.new()
 controls.add_child(instructions)
 instructions.position = Vector2(12,70)
 instructions.text = "Toque no cubo, arraste e solte."
 instructions.mouse_filter = Control.MOUSE_FILTER_IGNORE

func add_button(title: String, handler: Callable) -> Button:
 var button := Button.new()
 button.text = title
 button.custom_minimum_size = Vector2(90,48)
 tools.add_child(button)
 button.pressed.connect(handler)
 return button

func _input(event: InputEvent) -> void:
 if not is_node_ready():return
 if event is InputEventScreenTouch or event is InputEventScreenDrag:
  if input_drag.capture(event,not tools.get_global_rect().has_point(event.position),begin,move,finish):
   get_viewport().set_input_as_handled()
 elif event is InputEventMouse and event.device!=InputEvent.DEVICE_ID_EMULATION:
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed and not tools.get_global_rect().has_point(event.position):begin(-2,event.position)
   elif not event.pressed:finish(-2,event.position,false)
  elif event is InputEventMouseMotion and active_finger==-2:move(-2,event.position)

func begin(id: int, screen: Vector2) -> bool:
 if active_finger!=-1:
  input_drag.failure = "O cubo aceita um dedo por vez"
  return false
 var local_origin := cube.to_local(camera.project_ray_origin(screen))
 var local_end := cube.to_local(camera.project_ray_origin(screen)+camera.project_ray_normal(screen)*100)
 var hit: Variant = cube.get_aabb().intersects_segment(local_origin,local_end)
 if grab_mode and hit==null:
  input_drag.failure = "O raio não atingiu o cubo"
  return false
 active_finger = id
 drag_plane = Plane(camera.global_basis.z,cube.to_global(hit) if hit!=null else cube.global_position)
 hand_point = TouchDrag.project(camera,drag_plane,screen)
 offset = cube.global_position-hand_point
 linked = grab_mode and hit!=null
 detail = "Cubo" if hit!=null else ""
 move(id,screen)
 return true

func move(id: int, screen: Vector2) -> void:
 if id!=active_finger:return
 var point: Variant = TouchDrag.project(camera,drag_plane,screen)
 if point==null:
  input_drag.failure = "Raio sem interseção com o plano"
  return
 hand_point = point
 pointer.global_position = hand_point+camera.global_basis.z*.012
 pointer.show()
 if linked:cube.global_position=hand_point+offset

func finish(id: int, _screen: Vector2, _canceled: bool) -> void:
 if id==active_finger:clear_drag()

func clear_drag() -> void:
 active_finger = -1
 input_drag.captured.clear()
 linked = false

func _process(_dt: float) -> void:
 input_drag.update_debug(hand_point,detail,linked)

func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:clear_drag()
