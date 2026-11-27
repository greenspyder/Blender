extends RefCounted
var yaw:=26.
var pitch:=12.
var zoom:=2.62
var target:=Vector3(0.,1.04,0.)
func apply(camera:Camera3D)->void:
    var direction:=Vector3(sin(deg_to_rad(yaw))*cos(deg_to_rad(pitch)),sin(deg_to_rad(pitch)),cos(deg_to_rad(yaw))*cos(deg_to_rad(pitch)))
    camera.global_position=target+direction*4.6
    camera.look_at(target)
    camera.size=zoom
    camera.h_offset=0.
func reset()->void:
    yaw=26.
    pitch=12.
    zoom=2.62
    target=Vector3(0.,1.04,0.)
func orbit(delta:Vector2)->void:
    yaw-=delta.x*.3
    pitch=clampf(pitch+delta.y*.25,-65.,65.)
