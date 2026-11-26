extends Node3D

var desired := Vector3.ZERO
var last := Vector3.ZERO
var duration := 0.0
var fade := 0.0
var enabled := false
var side := 1.0
var mark: MeshInstance3D

func piece(p: Vector3, size_: Vector3, color: Color) -> MeshInstance3D:
 var m:=MeshInstance3D.new()
 m.mesh=SphereMesh.new()
 var mat:=StandardMaterial3D.new()
 mat.albedo_color=color
 m.material_override=mat
 add_child(m)
 m.position=p
 m.scale=size_
 return m

func setup(direction: float) -> void:
 side=direction
 var color:=Color("#93c2b6") if side>0 else Color("#baadc7")
 piece(Vector3.ZERO,Vector3(.086,.035,.10),color)
 for i in range(4):
  piece(Vector3((i-1.5)*.020,.003,-.061),Vector3(.017,.021,.067-abs(i-1)*.009),color)
 var thumb:=piece(Vector3(-side*.043,0,-.02),Vector3(.022,.025,.056),color)
 thumb.rotation.y=side*.62
 mark=piece(Vector3.ZERO,Vector3.ONE*.017,Color.CORAL)
 mark.visible=false

func advance(point: Vector3, dt: float, roll: float, debug_on: bool, detector) -> Dictionary:
 fade=move_toward(fade,1.0 if enabled else 0.0,dt*7)
 visible=fade>.005
 scale=Vector3.ONE*maxf(.001,fade)
 desired=desired.lerp(point,1-exp(-dt*16))
 var speed: Vector3=(desired-last)/maxf(.001,dt)
 last=desired
 var c: Dictionary=detector.sample(desired,speed,duration) if enabled else detector.sample(Vector3(10,10,10),Vector3.ZERO,0)
 duration=duration+dt if c.region!="" else 0
 position=c.surface if c.region!="" else desired
 rotation.z=roll*side
 mark.visible=debug_on and c.region!=""
 if mark.visible:mark.position=to_local(c.surface-c.normal*.029)
 return c
