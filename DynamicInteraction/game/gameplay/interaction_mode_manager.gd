extends RefCounted
const Picker=preload("res://direct/surface_picker.gd")
var cloth
var mode:=0
var picker:=Picker.new()
var materials:Dictionary={}
func configure(model:Node,core,profile:Resource)->void:
    picker.configure(model,core.skin,[])
    var names:Array=profile.mesh_roles.upper_clothes+profile.mesh_roles.lower_clothes
    for surface in picker.surfaces:
        if str(surface.node.name) in names:materials[surface.node]=surface.node.get_active_material(surface.surface_index)
func begin(camera:Camera3D,pixel:Vector2)->bool:
    var query:=picker.prepare_query()
    var hit:=picker.cast(camera,pixel,0.,query)
    # A alça é mais estreita que um dedo. Cada raio vizinho mantém a oclusão real.
    if cloth.worn.fit_at(hit)==null and (hit.is_empty() or materials.has(hit.surface.node) or str(hit.surface.node.name)==cloth.game.profile.mesh_roles.skin):
        var near_region:=false
        for region in cloth.worn.regions:
            var screen:=camera.unproject_position(cloth.worn.solver.position[region.particle])
            if screen.distance_squared_to(pixel)<70.*70.:
                near_region=true
                break
        if near_region:
            for offset in Picker.selection_offsets(12.):
                if offset==Vector2.ZERO:continue
                var candidate:=picker.cast(camera,pixel+offset,0.,query)
                if cloth.worn.fit_at(candidate)!=null:
                    hit=candidate
                    break
    return cloth.begin(pixel,hit)
func drag(pixel:Vector2)->void:
    cloth.drag(pixel)
func release(commit:=true)->void:
    if cloth!=null:cloth.release(commit)
func reset()->void:
    if cloth!=null:cloth.reset()
