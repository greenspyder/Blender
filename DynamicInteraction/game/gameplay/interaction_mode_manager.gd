extends RefCounted
const Picker=preload("res://direct/surface_picker.gd")
const Fabric=preload("res://gameplay/wardrobe.gdshader")
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
        var mesh:MeshInstance3D=surface.node
        if not names.has(str(mesh.name)):continue
        if materials.has(mesh):continue
        var original:=mesh.get_active_material(0)
        var shader:=ShaderMaterial.new()
        shader.shader=Fabric
        shader.set_shader_parameter("amount",0.)
        if original is StandardMaterial3D:shader.set_shader_parameter("tint",original.albedo_color)
        mesh.material_override=shader
        shader.set_shader_parameter("radius",core.leg*.16)
        materials[mesh]=shader
func begin(camera:Camera3D,pixel:Vector2)->bool:
    var hit:Dictionary=picker.cast(camera,pixel,0.)
    if hit.is_empty() or not materials.has(hit.surface.node):return false
    selected=hit.surface.node
    var shader:ShaderMaterial=materials[selected]
    # Centro no espaço de repouso obtido pelas coordenadas baricêntricas do triângulo.
    var s:Dictionary=hit.surface
    var face:int=hit.face
    var bary:Vector3=hit.bary
    var point:Vector3=s.vertices[s.indices[face]]*bary.x+s.vertices[s.indices[face+1]]*bary.y+s.vertices[s.indices[face+2]]*bary.z
    shader.set_shader_parameter("point_local",point)
    start_pixel=pixel
    initial=float(shader.get_shader_parameter("amount"))
    return true
func drag(pixel:Vector2)->void:
    if selected==null:return
    # Relevo externo pequeno mantém a peça contínua e a cobertura.
    materials[selected].set_shader_parameter("amount",clampf(initial+(start_pixel.y-pixel.y)*.00012,0.,.018))
func release()->void:
    selected=null
func reset()->void:
    for shader in materials.values():shader.set_shader_parameter("amount",0.)
