extends RefCounted
const Solver=preload("res://cloth/xpbd.gd")
var solver:=Solver.new()
var picker
var records:Array=[]
var representatives:Array=[]
var bindings:Array=[]
var local_offsets:=PackedVector3Array()
var normals:=PackedVector3Array()
var frames:Array[Basis]=[]
var radius:=.012
var max_offset:=0.
func build(source_picker,profile:Resource,length_:float)->void:
    picker=source_picker;radius=length_*.014
    var names:Array=profile.mesh_roles.upper_clothes+profile.mesh_roles.lower_clothes
    var points:=PackedVector3Array();var faces:=PackedInt32Array();var bins:Dictionary={}
    var cell:=length_*.18
    for s in picker.surfaces:
        if not str(s.node.name) in names:continue
        picker.update_surface(s)
        var mapping:=PackedInt32Array()
        for i in s.vertices.size():
            var p:Vector3=picker.vertex(s,i)
            var key:=Vector3i((p/cell).floor())
            if not bins.has(key):
                bins[key]=points.size();points.append(p);representatives.append([s,i,s.node.mesh.surface_get_arrays(s.surface_index)[Mesh.ARRAY_NORMAL][i]])
            mapping.append(bins[key])
        for f in range(0,s.indices.size(),3):
            var a:=mapping[s.indices[f]];var b:=mapping[s.indices[f+1]];var c:=mapping[s.indices[f+2]]
            if a!=b and a!=c and b!=c:faces.append_array(PackedInt32Array([a,b,c]))
        records.append({"surface":s,"arrays":s.node.mesh.surface_get_arrays(s.surface_index),"material":s.node.get_active_material(s.surface_index),"original":s.node.mesh,"mapping":mapping,"binding":[],"boundary":{},"rest_normals":PackedVector3Array()})
    for record in records:
        var arrays:Array=record.arrays
        var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
        var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var counts:Dictionary={}
        var geometry:=PackedVector3Array();geometry.resize(vertices.size())
        for f in range(0,ids.size(),3):
            var a:=ids[f];var b:=ids[f+1];var c:=ids[f+2]
            var normal:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
            geometry[a]+=normal;geometry[b]+=normal;geometry[c]+=normal
            for e in [[a,b],[b,c],[c,a]]:
                var key:=Vector2i(mini(e[0],e[1]),maxi(e[0],e[1]))
                counts[key]=int(counts.get(key,0))+1
        for key in counts:
            if counts[key]==1:record.boundary[key.x]=true;record.boundary[key.y]=true
        for i in geometry.size():geometry[i]=geometry[i].normalized()
        record.rest_normals=geometry
    solver.build(points,faces);solver.targets=points.duplicate();solver.tether_radius=radius
    solver.areas.fill(0.)
    for record in records:
        var s:Dictionary=record.surface
        for f in range(0,s.indices.size(),3):
            var a:Vector3=picker.vertex(s,s.indices[f]);var b:Vector3=picker.vertex(s,s.indices[f+1]);var c:Vector3=picker.vertex(s,s.indices[f+2])
            var area:float=(b-a).cross(c-a).length()/6.
            for j in 3:solver.areas[record.mapping[s.indices[f+j]]]+=area
    solver.set_material(solver.material)
    local_offsets.resize(points.size());normals.resize(points.size());frames.resize(points.size())
    # Continuous nearest-three interpolation, shared by duplicated seam vertices.
    for record in records:
        var s:Dictionary=record.surface
        for i in s.vertices.size():
            var p:Vector3=picker.vertex(s,i)
            var nearest:Array=[]
            for j in points.size():nearest.append([p.distance_squared_to(points[j]),j])
            nearest.sort_custom(func(a,b):return a[0]<b[0])
            var ids:=Vector3i(nearest[0][1],nearest[1][1],nearest[2][1])
            var weights:=Vector3(1./maxf(nearest[0][0],.000001),1./maxf(nearest[1][0],.000001),1./maxf(nearest[2][0],.000001))
            record.binding.append([ids,weights/(weights.x+weights.y+weights.z)])
func update_targets()->void:
    for record in records:picker.update_surface(record.surface)
    for i in representatives.size():
        var s:Dictionary=representatives[i][0];var id:int=representatives[i][1]
        solver.targets[i]=picker.vertex(s,id)
        var basis:=Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
        if s.slots.is_empty():basis=s.node.global_basis
        else:
            for j in range(id*4,id*4+4):
                var b:Basis=Transform3D(s.matrix[s.joints[j]]).basis
                var w:float=s.weights[j]
                basis.x+=b.x*w;basis.y+=b.y*w;basis.z+=b.z*w
        normals[i]=(basis*Vector3(representatives[i][2])).normalized()
        frames[i]=basis.orthonormalized().inverse()
func step(h:float,colliders:Array)->void:
    update_targets()
    var before:=solver.position.duplicate()
    solver.step(h,colliders)
    max_offset=0.
    for i in solver.position.size():
        var delta:=solver.position[i]-solver.targets[i]
        var n:=normals[i]
        delta=delta.slide(n).limit_length(radius*.4)+n*clampf(delta.dot(n),0.,radius)
        solver.position[i]=solver.targets[i]+delta
        solver.velocity[i]=(solver.position[i]-before[i])/h
        max_offset=maxf(max_offset,delta.length())
    update_offsets()
func update_offsets()->void:
    for i in representatives.size():local_offsets[i]=frames[i]*(solver.position[i]-solver.targets[i])
func render()->void:
    var meshes:Dictionary={}
    for record in records:
        var node:MeshInstance3D=record.surface.node
        if not meshes.has(node):
            var mesh:=ArrayMesh.new();mesh.blend_shape_mode=record.original.blend_shape_mode
            for i in record.original.get_blend_shape_count():mesh.add_blend_shape(record.original.get_blend_shape_name(i))
            meshes[node]=mesh
        var arrays:Array=record.arrays.duplicate()
        var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
        for i in vertices.size():
            var bind:Array=record.binding[i];var ids:Vector3i=bind[0];var w:Vector3=bind[1]
            if record.boundary.has(i):continue
            var offset:Vector3=local_offsets[ids.x]*w.x+local_offsets[ids.y]*w.y+local_offsets[ids.z]*w.z
            var normal:Vector3=record.arrays[Mesh.ARRAY_NORMAL][i]
            # Preserve fitted boundaries and prevent secondary movement into the original surface.
            vertices[i]+=normal*maxf(0.,offset.dot(normal))+offset.slide(normal)*.15
        arrays[Mesh.ARRAY_VERTEX]=vertices
        var normals_:=PackedVector3Array();normals_.resize(vertices.size())
        var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
        for f in range(0,indices.size(),3):
            var a:=indices[f];var b:=indices[f+1];var c:=indices[f+2]
            var n:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
            normals_[a]+=n;normals_[b]+=n;normals_[c]+=n
        for i in normals_.size():normals_[i]=(Vector3(record.arrays[Mesh.ARRAY_NORMAL][i])+normals_[i].normalized()-Vector3(record.rest_normals[i])).normalized()
        arrays[Mesh.ARRAY_NORMAL]=normals_
        var mesh:ArrayMesh=meshes[node]
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,record.original.surface_get_blend_shape_arrays(record.surface.surface_index))
        mesh.surface_set_material(mesh.get_surface_count()-1,record.material)
    for node in meshes:node.mesh=meshes[node]
func reset()->void:
    solver.release();solver.position=solver.targets.duplicate();solver.velocity.fill(Vector3.ZERO);local_offsets.fill(Vector3.ZERO)
