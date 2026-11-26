extends RefCounted
## Roteia um gesto até a soltura pelo índice atribuído no toque inicial.

var captured: Dictionary = {}
var finger := -1
var touch_count := 0
var drag_count := 0
var last_event := "—"
var failure := ""
var debug := Label.new()

func capture(event: InputEvent, can_start: bool, start: Callable, move: Callable, finish: Callable) -> bool:
 if event is InputEventScreenTouch:
  finger = event.index
  touch_count += 1
  last_event = "Cancelado" if event.canceled else ("Toque" if event.pressed else "Soltura")
  if not event.pressed or event.canceled:
   if not captured.erase(finger):return false
   finish.call(finger, event.position, event.canceled)
   return true
  if captured.has(finger):return true
  if not can_start:
   failure = "Toque reservado à interface ou à câmera"
   return false
  failure = ""
  if start.call(finger, event.position):captured[finger] = true
  return true
 if event is InputEventScreenDrag:
  finger = event.index
  drag_count += 1
  last_event = "Arraste"
  if not captured.has(finger):
   if failure.is_empty():failure = "Arraste sem toque inicial capturado"
   return false
  failure = ""
  move.call(finger, event.position)
  return true
 return false

static func project(camera: Camera3D, plane: Plane, screen: Vector2) -> Variant:
 return plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))

func add_debug(overlay: Control, button: Button) -> void:
 var panel := PanelContainer.new()
 panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 overlay.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 panel.position += Vector2(12,-225)
 panel.hide()
 panel.add_child(debug)
 debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
 button.pressed.connect(func(): panel.visible = not panel.visible)

func update_debug(position: Vector3, element: String, linked: bool) -> void:
 debug.text = "Dedo %s · %s\nToques %d · Arrastes %d\nMão %.3f  %.3f  %.3f m\nAlvo %s · %s\n%s" % [
  "—" if finger < 0 else str(finger), last_event, touch_count, drag_count,
  position.x, position.y, position.z, element if not element.is_empty() else "—",
  "Vinculado" if linked else "Livre", failure if not failure.is_empty() else "—"]
