extends RefCounted
const DynamicSurface=preload("res://cloth/dynamic_surface.gd")
const FitRegion=preload("res://cloth/fit_region.gd")
const Solver=preload("res://cloth/xpbd.gd")
var solver:=Solver.new()
var picker
var records:Array=[]
var representatives:Array=[]
var regions:Array[FitRegion]=[]
var held_region:FitRegion
var grip_origin:=Vector3.ZERO
var base_targets:=PackedVector3Array()
var grid_count:=0
var rest_to_world:Array[Basis]=[]
var last_rendered:=PackedVector3Array()
var last_fit:=PackedVector3Array()
var part_meshes:Dictionary={}
var mesh_writes:=0
var local_offsets:=PackedVector3Array()
var normals:=PackedVector3Array()
var frames:Array[Basis]=[]
var seams:Array=[]
var radius:=.012
var visual_peak:=0.
var visual_rms:=0.
var max_offset:=0.
func build(source_picker,profile:Resource,length_:float)->void:
    picker=source_picker;radius=length_*.028
    var names:Array=profile.mesh_roles.upper_clothes+profile.mesh_roles.lower_clothes
    var points:=PackedVector3Array();var faces:=PackedInt32Array();var bins:Dictionary={}
    var cell:=length_*.18
    for s in picker.surfaces:
        if not str(s.node.name) in names:continue
        picker.update_surface(s)
        var source_arrays:Array=s.node.mesh.surface_get_arrays(s.surface_index)
        var mapping:=PackedInt32Array()
        for i in s.vertices.size():
            var p:Vector3=picker.vertex(s,i)
            var key:=Vector3i((p/cell).floor())
            if not bins.has(key):
                bins[key]=points.size();points.append(p);representatives.append([s,i,source_arrays[Mesh.ARRAY_NORMAL][i]])
            mapping.append(bins[key])
        for f in range(0,s.indices.size(),3):
            var a:=mapping[s.indices[f]];var b:=mapping[s.indices[f+1]];var c:=mapping[s.indices[f+2]]
            if a!=b and a!=c and b!=c:faces.append_array(PackedInt32Array([a,b,c]))
        records.append({"surface":s,"arrays":source_arrays,"material":s.node.get_active_material(s.surface_index),"original":s.node.mesh,"mapping":mapping,"binding":[],"boundary":{},"rest_normals":PackedVector3Array()})
    for record in records:
        var arrays:Array=record.arrays
        var ids:PackedInt32Array=record.surface.indices
        var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var counts:Dictionary={}
        var geometry:=PackedVector3Array();geometry.resize(vertices.size())
        for f in range(0,ids.size(),3):
            var a:=ids[f];var b:=ids[f+1];var c:=ids[f+2]
            var normal:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
            geometry[a]+=normal;geometry[b]+=normal;geometry[c]+=normal
            for e in [[a,b],[b,c],[c,a]]:
                var pa:=Vector3i((vertices[e[0]]*100000.).round())
                var pb:=Vector3i((vertices[e[1]]*100000.).round())
                var key:String=(str(pa)+":"+str(pb)) if str(pa)<str(pb) else (str(pb)+":"+str(pa))
                if not counts.has(key):counts[key]={"count":0,"vertices":[]}
                counts[key].count+=1
                counts[key].vertices.append_array(e)
        for key in counts:
            if counts[key].count==1:
                for id in counts[key].vertices:record.boundary[id]=true
        for i in geometry.size():geometry[i]=geometry[i].normalized()
        record.rest_normals=geometry
    var seam_groups:Dictionary={}
    for record in records:
        var vertices:PackedVector3Array=record.arrays[Mesh.ARRAY_VERTEX]
        for i in vertices.size():
            var key:String=str(record.surface.node.get_instance_id())+str(Vector3i((vertices[i]*100000.).round()))
            if not seam_groups.has(key):seam_groups[key]=[]
            seam_groups[key].append([record,i])
    for group in seam_groups.values():
        if group.size()<=1:continue
        var locked:=false
        var directions:Array[Vector3]=[]
        for entry in group:
            locked=locked or entry[0].boundary.has(entry[1])
            var n:Vector3=entry[0].arrays[Mesh.ARRAY_NORMAL][entry[1]]
            var unique:=true
            for direction in directions:
                if direction.dot(n)>.9999:unique=false;break
            if unique:directions.append(n)
        seams.append({"vertices":group,"locked":locked,"directions":directions})
    grid_count=points.size()
    add_fit_regions(profile,length_,points)
    if points.is_empty():return
    solver.build(points,faces);solver.targets=points.duplicate();solver.tether_radius=radius
    solver.areas.fill(0.)
    for record in records:
        var s:Dictionary=record.surface
        for f in range(0,s.indices.size(),3):
            var a:Vector3=picker.vertex(s,s.indices[f]);var b:Vector3=picker.vertex(s,s.indices[f+1]);var c:Vector3=picker.vertex(s,s.indices[f+2])
            var area:float=(b-a).cross(c-a).length()/6.
            for j in 3:solver.areas[record.mapping[s.indices[f+j]]]+=area
    for region in regions:
        # Massa do pequeno trecho guiado pela costura.
        solver.areas[region.particle]=maxf(.0001,region.travel*region.travel*3.)
    solver.set_material(solver.material)
    local_offsets.resize(points.size());normals.resize(points.size());frames.resize(points.size())
    base_targets=points.duplicate();rest_to_world.resize(points.size())
    # Os pontos de ajuste não participam da interpolação neutra.
    for record in records:
        var s:Dictionary=record.surface
        for i in s.vertices.size():
            var p:Vector3=picker.vertex(s,i)
            var ids:=Vector3i.ZERO
            var d:=Vector3(INF,INF,INF)
            for j in grid_count:
                var dist:=p.distance_squared_to(points[j])
                if dist<d.x:
                    d=Vector3(dist,d.x,d.y);ids=Vector3i(j,ids.x,ids.y)
                elif dist<d.y:
                    d=Vector3(d.x,dist,d.y);ids=Vector3i(ids.x,j,ids.y)
                elif dist<d.z:
                    d.z=dist;ids.z=j
            var weights:=Vector3.ONE/d.max(Vector3.ONE*.000001)
            record.binding.append([ids,weights/(weights.x+weights.y+weights.z)])

    prepare_meshes()

func prepare_meshes()->void:
    for record in records:
        var source:ArrayMesh=record.original
        var node:MeshInstance3D=record.surface.node
        if not part_meshes.has(node):
            var mesh:=ArrayMesh.new()
            mesh.blend_shape_mode=source.blend_shape_mode
            for i in source.get_blend_shape_count():mesh.add_blend_shape(source.get_blend_shape_name(i))
            mesh.custom_aabb=source.get_aabb().grow(radius*3.)
            part_meshes[node]={"mesh":mesh,"stream":DisplayServer.get_name()!="headless"}
        var index:int=record.surface.surface_index
        record.shapes=source.surface_get_blend_shape_arrays(index)
        record.surface_name=source.surface_get_name(index)
        var part:Dictionary=part_meshes[node]
        append_surface(part.mesh,record,record.arrays)
        if part.stream:
            record.stream=DynamicSurface.new()
            part.stream=record.stream.configure(part.mesh,index,record.mapping.size())
    for node in part_meshes:
        node.mesh=part_meshes[node].mesh

func append_surface(mesh:ArrayMesh,record:Dictionary,arrays:Array)->void:
    var flags:=Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
    if record.surface.influences==8:flags|=Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,record.shapes,{},flags)
    var index:=mesh.get_surface_count()-1
    mesh.surface_set_material(index,record.material)
    mesh.surface_set_name(index,record.surface_name)

func add_fit_regions(profile:Resource,length_:float,points:PackedVector3Array)->void:
    for spec in profile.garment_fit_regions:
        if not (spec.get("center") is Vector3 and spec.get("extent") is Vector3):continue
        if Vector3(spec.extent)[Vector3(spec.extent).min_axis_index()]<=0.:continue
        for side in ([-1.,1.] if spec.get("mirror",false) else [1.]):
            var region:=FitRegion.new()
            region.piece=spec.get("piece","")
            region.label=spec.get("label",region.piece)
            region.center=Vector3(spec.center)*Vector3(side,1.,1.)
            region.extent=spec.extent
            region.travel=clampf(spec.get("travel",.02),.001,.05)*length_
            var best:=0.
            var anchor:Array=[]
            for record in records:
                var surface:Dictionary=record.surface
                if str(surface.node.name)!=region.piece:continue
                for i in surface.vertices.size():
                    var weight:=region.weight(surface.vertices[i])
                    if weight<=0.:continue
                    region.vertices.append([record,i,weight])
                    if weight>best:
                        best=weight
                        anchor=[surface,i,record.arrays[Mesh.ARRAY_NORMAL][i]]
            if anchor.is_empty():continue
            region.particle=points.size()
            points.append(picker.vertex(anchor[0],anchor[1],false))
            representatives.append(anchor)
            regions.append(region)

func fit_at(hit:Dictionary)->FitRegion:
    if hit.is_empty():return null
    var surface:Dictionary=hit.surface
    var p:=Vector3.ZERO
    for j in 3:p+=Vector3(surface.vertices[surface.indices[hit.face+j]])*float(hit.bary[j])
    var best:=.05
    var selected:FitRegion
    for region in regions:
        if region.piece!=str(surface.node.name):continue
        var amount:=region.weight(p)
        if amount>best:
            best=amount
            selected=region
    return selected

func begin_grip(hit:Dictionary)->bool:
    for record in records:
        if not is_same(record.surface,hit.surface):continue
        var ids:=PackedInt32Array()
        var weights:=PackedFloat32Array()
        held_region=fit_at(hit)
        if held_region:
            ids.append(held_region.particle)
            weights.append(1.)
            held_region.previous_rest=held_region.rest_offset
            held_region.was_adjusted=held_region.adjusted
            held_region.bias=local_offsets[held_region.particle]-held_region.offset
            held_region.adjusted=true
        else:
            # Interpolar o proxy no próprio triângulo visual, inclusive em clusters sem face.
            var influence:Dictionary={}
            for j in 3:
                var binding:Array=record.binding[record.surface.indices[hit.face+j]]
                for k in 3:
                    var id:int=binding[0][k]
                    influence[id]=float(influence.get(id,0.))+float(hit.bary[j])*float(binding[1][k])
            for id in influence:
                ids.append(id)
                weights.append(influence[id])
        grip_origin=solver.grip_position(ids,weights)
        solver.begin_weighted_hold(ids,weights,grip_origin)
        return true
    return false

func move_grip(delta:Vector3)->void:
    if solver.hold.is_empty():return
    var limit:=held_region.travel*2. if held_region else radius*2.
    solver.hold.goal=grip_origin+delta.limit_length(limit)

func release_grip(commit:=true)->void:
    if held_region:
        if commit:held_region.rest_offset=held_region.offset
        else:
            held_region.adjusted=held_region.was_adjusted
            held_region.rest_offset=held_region.previous_rest
            held_region.offset=held_region.rest_offset
            var i:=held_region.particle
            solver.position[i]=base_targets[i]+rest_to_world[i]*(held_region.offset+held_region.bias)
            solver.velocity[i]=Vector3.ZERO
        held_region=null
    solver.release()

func update_targets()->void:
    var skin_frames:Dictionary={}
    for record in records:picker.update_surface(record.surface,skin_frames)
    for i in representatives.size():
        var s:Dictionary=representatives[i][0];var id:int=representatives[i][1]
        base_targets[i]=picker.vertex(s,id,false)
        solver.targets[i]=base_targets[i]
        var basis:=Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
        if s.slots.is_empty():basis=s.node.global_basis
        else:
            var start:int=id*s.influences
            for j in range(start,start+s.influences):
                var b:Basis=Transform3D(s.matrix[s.joints[j]]).basis
                var w:float=s.weights[j]
                basis.x+=b.x*w;basis.y+=b.y*w;basis.z+=b.z*w
        rest_to_world[i]=basis
        normals[i]=(basis*Vector3(representatives[i][2])).normalized()
        frames[i]=basis.inverse() if absf(basis.determinant())>.000001 else basis.orthonormalized().inverse()
    for region in regions:
        solver.targets[region.particle]+=rest_to_world[region.particle]*region.rest_offset

func step(h:float,colliders:Array)->void:
    if representatives.is_empty():return
    update_targets()
    # Elastic fitted support acts only on worn particles. Keep independent cloth unchanged.
    for i in solver.position.size():
        solver.velocity[i]+=(solver.targets[i]-solver.position[i])*450.*h
    solver.step(h,colliders)
    max_offset=0.
    for i in solver.position.size():
        var delta:=solver.position[i]-solver.targets[i]
        var n:=normals[i]
        delta=(delta.slide(n).limit_length(radius*.75)+n*clampf(delta.dot(n),0.,radius)).limit_length(radius)
        solver.position[i]=solver.targets[i]+delta
        solver.velocity[i]=(solver.position[i]-solver.previous[i])/h
        max_offset=maxf(max_offset,delta.length())
    update_offsets()
    for region in regions:
        if not region.adjusted:continue
        var i:=region.particle
        var displacement:=rest_to_world[i]*(local_offsets[i]-region.bias)
        region.offset=frames[i]*region.limited(displacement,normals[i])
func update_offsets()->void:
    for i in representatives.size():local_offsets[i]=frames[i]*(solver.position[i]-base_targets[i])
func needs_upload()->bool:
    if last_rendered.size()!=local_offsets.size():return not local_offsets.is_empty()
    var tolerance:=radius*.008
    for i in grid_count:
        if local_offsets[i].distance_squared_to(last_rendered[i])>tolerance*tolerance:return true
    for i in regions.size():
        if regions[i].offset.distance_squared_to(last_fit[i])>tolerance*tolerance:return true
    return false

func render()->void:
    if not needs_upload():return
    last_rendered=local_offsets.duplicate()
    last_fit.resize(regions.size())
    for i in regions.size():last_fit[i]=regions[i].offset
    mesh_writes+=1
    visual_peak=0.
    var square:=0.
    var vertex_count:=0
    for record in records:
        var vertices:PackedVector3Array=record.arrays[Mesh.ARRAY_VERTEX].duplicate()
        var vertex_normals:PackedVector3Array=record.arrays[Mesh.ARRAY_NORMAL]
        for i in vertices.size():
            if record.boundary.has(i):continue
            var bind:Array=record.binding[i];var ids:Vector3i=bind[0];var w:Vector3=bind[1]
            var offset:Vector3=local_offsets[ids.x]*w.x+local_offsets[ids.y]*w.y+local_offsets[ids.z]*w.z
            var normal:Vector3=vertex_normals[i]
            var applied:Vector3=(normal*maxf(0.,offset.dot(normal))+offset.slide(normal)*.8).limit_length(radius)
            vertices[i]+=applied
        record.render_vertices=vertices
    # UV/material splits share the same displacement; true open borders remain fitted.
    for seam in seams:
        var group:Array=seam.vertices
        var offset:=Vector3.ZERO
        if not seam.locked:
            for entry in group:
                offset+=Vector3(entry[0].render_vertices[entry[1]])-Vector3(entry[0].arrays[Mesh.ARRAY_VERTEX][entry[1]])
            offset/=float(group.size())
            if seam.directions.size()>1:
                for pass_ in 3:
                    for normal in seam.directions:offset-=Vector3(normal)*minf(0.,offset.dot(normal))
        for entry in group:
            var record:Dictionary=entry[0];var id:int=entry[1]
            record.render_vertices[id]=Vector3(record.arrays[Mesh.ARRAY_VERTEX][id])+offset
    # O mesmo campo no bind vale para cópias das costuras em superfícies distintas.
    for region in regions:
        if region.offset.is_zero_approx():continue
        for entry in region.vertices:
            entry[0].render_vertices[entry[1]]+=region.offset*float(entry[2])
    for part in part_meshes.values():
        if not part.stream:part.mesh.clear_surfaces()
    for record in records:
        var part:Dictionary=part_meshes[record.surface.node]
        var arrays:Array=record.arrays.duplicate()
        var vertices:PackedVector3Array=record.render_vertices
        record.surface.display_vertices=vertices
        record.surface.display_margin=Vector3.ONE*(radius*3.)
        var rest_vertices:PackedVector3Array=record.arrays[Mesh.ARRAY_VERTEX]
        for i in vertices.size():
            var applied:=vertices[i]-rest_vertices[i]
            visual_peak=maxf(visual_peak,applied.length())
            square+=applied.length_squared();vertex_count+=1
        arrays[Mesh.ARRAY_VERTEX]=vertices
        var normals_:=PackedVector3Array();normals_.resize(vertices.size())
        var indices:PackedInt32Array=record.surface.indices
        for f in range(0,indices.size(),3):
            var a:=indices[f];var b:=indices[f+1];var c:=indices[f+2]
            var n:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
            normals_[a]+=n;normals_[b]+=n;normals_[c]+=n
        var authored:PackedVector3Array=record.arrays[Mesh.ARRAY_NORMAL]
        var rest_geometry:PackedVector3Array=record.rest_normals
        for i in normals_.size():normals_[i]=(authored[i]+normals_[i].normalized()-rest_geometry[i]).normalized()
        arrays[Mesh.ARRAY_NORMAL]=normals_
        if part.stream:record.stream.upload(vertices,normals_)
        else:append_surface(part.mesh,record,arrays)
    visual_rms=sqrt(square/maxi(1,vertex_count))
func reset()->void:
    release_grip()
    for region in regions:
        region.adjusted=false
        region.rest_offset=Vector3.ZERO
        region.offset=Vector3.ZERO
    solver.targets=base_targets.duplicate()
    solver.position=base_targets.duplicate()
    solver.velocity.fill(Vector3.ZERO)
    local_offsets.fill(Vector3.ZERO)
    last_rendered.clear()
    render()
