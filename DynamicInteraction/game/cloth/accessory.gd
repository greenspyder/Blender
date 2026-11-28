extends Node3D
const Solver=preload("res://cloth/xpbd.gd")
const DynamicSurface=preload("res://cloth/dynamic_surface.gd")
const Picker=preload("res://direct/surface_picker.gd")
var solver:=Solver.new()
var view:=MeshInstance3D.new()
var columns:=8
var rows:=11
var material:=StandardMaterial3D.new()
var scale_length:=1.
var topology:=PackedInt32Array()
var uv:=PackedVector2Array()
var cells:=PackedInt32Array()
var fractions:=PackedVector2Array()
var dynamic_mesh:=ArrayMesh.new()
var stream:DynamicSurface
func build(origin:Vector3,length_:float)->void:
    scale_length=length_
    var points:=PackedVector3Array();var indices:=PackedInt32Array()
    for y in rows:
        for x in columns:points.append(origin+Vector3((float(x)/(columns-1)-.5)*.48,-float(y)/(rows-1)*.60,.035*sin(float(x)/(columns-1)*TAU))*length_)
    for y in rows-1:
        for x in columns-1:
            var a:=y*columns+x
            indices.append_array(PackedInt32Array([a,a+columns,a+1,a+1,a+columns,a+columns+1]))
    solver.pins={0:points[0],columns-1:points[columns-1]}
    solver.build(points,indices)
    material.albedo_color=Color("a7b9cb")
    material.roughness=.9;material.cull_mode=BaseMaterial3D.CULL_DISABLED
    add_child(view)
    var bar:=MeshInstance3D.new();var beam:=BoxMesh.new()
    beam.size=Vector3(.56,.02,.02)*length_;bar.mesh=beam;bar.position=origin;add_child(bar)
    for x in [-.28,.28]:
        var leg:=MeshInstance3D.new();var pole:=BoxMesh.new()
        pole.size=Vector3(.018,origin.y,.018)
        leg.mesh=pole;leg.position=Vector3(origin.x+x*length_,origin.y*.5,origin.z)
        add_child(leg)
    build_visual_grid()
    render()
func pick(camera:Camera3D,pixel:Vector2)->Dictionary:
    var origin:=camera.project_ray_origin(pixel);var direction:=camera.project_ray_normal(pixel)
    var nearest:=INF;var hit:Dictionary={}
    for f in range(0,solver.triangles.size(),3):
        var p:=Picker.intersection(origin,direction,solver.position[solver.triangles[f]],solver.position[solver.triangles[f+1]],solver.position[solver.triangles[f+2]])
        if p.x>=0. and p.x<nearest:
            nearest=p.x;hit={"face":f,"bary":Vector3(1.-p.y-p.z,p.y,p.z),"point":origin+direction*p.x,"distance":p.x}
    return hit
func build_visual_grid()->void:
    var width:=(columns-1)*2+1
    var height:=(rows-1)*2+1
    for y in height:
        for x in width:
            var cx:=mini(x/2,columns-2)
            var cy:=mini(y/2,rows-2)
            cells.append(cy*columns+cx)
            fractions.append(Vector2(float(x)/2.-cx,float(y)/2.-cy))
            uv.append(Vector2(float(x)/(width-1),float(y)/(height-1)))
    for y in height-1:
        for x in width-1:
            var a:=y*width+x
            topology.append_array(PackedInt32Array([a,a+width,a+1,a+1,a+width,a+width+1]))

func render()->void:
    var vertices:=PackedVector3Array()
    var normals:=PackedVector3Array()
    vertices.resize(cells.size())
    normals.resize(cells.size())
    for i in cells.size():
        var a:=cells[i]
        var u:=fractions[i]
        var upper:=solver.position[a].lerp(solver.position[a+1],u.x)
        var lower:=solver.position[a+columns].lerp(solver.position[a+columns+1],u.x)
        vertices[i]=upper.lerp(lower,u.y)
    for f in range(0,topology.size(),3):
        var a:=topology[f]
        var b:=topology[f+1]
        var c:=topology[f+2]
        var n:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
        normals[a]+=n;normals[b]+=n;normals[c]+=n
    for i in normals.size():normals[i]=-normals[i].normalized()
    var bounds:=AABB(solver.position[0],Vector3.ZERO)
    for p in solver.position:bounds=bounds.expand(p)
    dynamic_mesh.custom_aabb=bounds.grow(solver.material.thickness)
    if stream!=null:
        stream.upload(vertices,normals)
        return
    var first:=view.mesh==null
    if not first:dynamic_mesh.clear_surfaces()
    var arrays:Array=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices
    arrays[Mesh.ARRAY_NORMAL]=normals
    arrays[Mesh.ARRAY_TEX_UV]=uv
    arrays[Mesh.ARRAY_INDEX]=topology
    dynamic_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
    dynamic_mesh.surface_set_material(0,material)
    if first:
        view.mesh=dynamic_mesh
        if DisplayServer.get_name()!="headless":
            stream=DynamicSurface.new()
            if not stream.configure(dynamic_mesh,0,vertices.size()):stream=null
