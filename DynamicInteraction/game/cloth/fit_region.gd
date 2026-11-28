extends RefCounted
## Um ponto de costura móvel no mesmo solver da peça. Coordenadas do perfil em bind.
var piece: String
var label: String
var center: Vector3
var extent: Vector3
var travel: float
var particle := -1
var vertices: Array = []
var rest_offset := Vector3.ZERO
var offset := Vector3.ZERO
var bias := Vector3.ZERO
var adjusted := false
var previous_rest := Vector3.ZERO
var was_adjusted := false

func weight(p: Vector3) -> float:
    var d := ((p-center)/extent).length()
    return 1.0 - smoothstep(0.38, 1.0, d)

func limited(delta_world: Vector3, normal: Vector3) -> Vector3:
    var outward := clampf(delta_world.dot(normal), 0.0, travel*0.24)
    return (delta_world.slide(normal) + normal*outward).limit_length(travel)
