extends RefCounted
var colliders:Array[MeshInstance3D]=[]
func build(core)->void:
    var material:=StandardMaterial3D.new()
    material.albedo_color=Color(.2,1.,.6,.22)
    material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    for body in core.bodies.values():
        var shape:CollisionShape3D=body.get_child(0)
        var view:=MeshInstance3D.new()
        view.mesh=shape.shape.get_debug_mesh()
        view.material_override=material
        view.transform=shape.transform
        body.add_child(view)
        view.hide()
        colliders.append(view)
func show_colliders(value:bool)->void:
    for view in colliders:view.visible=value
