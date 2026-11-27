extends Node3D
const Solver=preload("res://cloth/xpbd.gd")
const Picker=preload("res://direct/surface_picker.gd")
var solver:=Solver.new()
var view:=MeshInstance3D.new()
var columns:=8
var rows:=11
var material:=StandardMaterial3D.new()
var scale_length:=1.
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
    render()
func pick(camera:Camera3D,pixel:Vector2)->Dictionary:
    var origin:=camera.project_ray_origin(pixel);var direction:=camera.project_ray_normal(pixel)
    var nearest:=INF;var hit:Dictionary={}
    for f in range(0,solver.triangles.size(),3):
        var p:=Picker.intersection(origin,direction,solver.position[solver.triangles[f]],solver.position[solver.triangles[f+1]],solver.position[solver.triangles[f+2]])
        if p.x>=0. and p.x<nearest:
            nearest=p.x;hit={"face":f,"bary":Vector3(1.-p.y-p.z,p.y,p.z),"point":origin+direction*p.x,"distance":p.x}
    return hit
func render()->void:
    # Bilinear visual subdivision: 285 visual vertices from 88 physical particles.
    var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
    var w:=(columns-1)*2+1;var h:=(rows-1)*2+1
    for y in h:
        for x in w:
            var cx:=mini(x/2,columns-2);var cy:=mini(y/2,rows-2)
            var u:=float(x)/2.-cx;var v:=float(y)/2.-cy;var a:=cy*columns+cx
            vertices.append(solver.position[a].lerp(solver.position[a+1],u).lerp(solver.position[a+columns].lerp(solver.position[a+columns+1],u),v))
            uv.append(Vector2(float(x)/(w-1),float(y)/(h-1)));normals.append(Vector3.ZERO)
    for y in h-1:
        for x in w-1:
            var a:=y*w+x;indices.append_array(PackedInt32Array([a,a+w,a+1,a+1,a+w,a+w+1]))
    for f in range(0,indices.size(),3):
        var a:=indices[f];var b:=indices[f+1];var c:=indices[f+2]
        var n:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
        normals[a]+=n;normals[b]+=n;normals[c]+=n
    for i in normals.size():normals[i]=-normals[i].normalized()
    var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
    var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,material);view.mesh=mesh
