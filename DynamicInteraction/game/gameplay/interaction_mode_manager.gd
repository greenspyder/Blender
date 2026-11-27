extends RefCounted
const Picker=preload("res://direct/surface_picker.gd")
var cloth
var mode:=0
var picker:=Picker.new()
var materials:Dictionary={}
var selected:MeshInstance3D
var start_pixel:=Vector2.ZERO
var initial:=0.
func configure(model:Node,core,profile:Resource)->void:
    picker.configure(model,core.skin,[])
    var names:Array=profile.mesh_roles.upper_clothes+profile.mesh_roles.lower_clothes
    for surface in picker.surfaces:
        if str(surface.node.name) in names:materials[surface.node]=surface.node.get_active_material(surface.surface_index)
func begin(camera:Camera3D,pixel:Vector2)->bool:
    var hit:Dictionary=picker.cast(camera,pixel,0.)
    return cloth.begin(pixel,hit)
func drag(pixel:Vector2)->void:
    cloth.drag(pixel)
func release()->void:
    selected=null
    if cloth!=null:cloth.release()
func reset()->void:
    if cloth!=null:cloth.reset()
