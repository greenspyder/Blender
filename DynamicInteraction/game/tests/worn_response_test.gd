extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
    var g=load("res://gameplay/main.tscn").instantiate();root.add_child(g)
    g.cloth.set_quality(0)
    var peak:=0.;var square:=0.;var count_:=0;var variation:=0.;var costs:=0.;var last:Dictionary={}
    for base in [0,1,4]:
        g.select_base(base)
        g.composer.enable("head",true)
        if base!=4:g.composer.enable("sway",true)
        for tick in 240:
            await physics_frame
            if tick%8!=0:continue
            var start:=Time.get_ticks_usec()
            g.cloth.worn.render()
            costs+=Time.get_ticks_usec()-start
            for record in g.cloth.worn.records:
                var vertices:PackedVector3Array=record.surface.node.mesh.surface_get_arrays(record.surface.surface_index)[Mesh.ARRAY_VERTEX]
                var original:PackedVector3Array=record.arrays[Mesh.ARRAY_VERTEX]
                var key:String=str(record.surface.node.name)+str(record.surface.surface_index)
                for i in vertices.size():
                    var delta:=vertices[i]-original[i]
                    peak=maxf(peak,delta.length());square+=delta.length_squared();count_+=1
                    if last.has(key):variation=maxf(variation,delta.distance_to(last[key][i]))
                var offsets:=PackedVector3Array()
                for i in vertices.size():offsets.append(vertices[i]-original[i])
                last[key]=offsets
    print("RESPONSE peak_m=%.6f rms_m=%.6f change_m=%.6f render_ms=%.3f"%[peak,sqrt(square/count_),variation,costs/90000.])
    var seam_error:=0.
    var seams:Dictionary={}
    for record in g.cloth.worn.records:
        var vertices:PackedVector3Array=record.surface.node.mesh.surface_get_arrays(record.surface.surface_index)[Mesh.ARRAY_VERTEX]
        var original:PackedVector3Array=record.arrays[Mesh.ARRAY_VERTEX]
        for i in vertices.size():
            var key:String=str(record.surface.node.name)+str(Vector3i((original[i]*100000.).round()))
            var delta:=vertices[i]-original[i]
            if seams.has(key):seam_error=maxf(seam_error,delta.distance_to(seams[key]))
            else:seams[key]=delta
    print("Seam displacement difference: ",seam_error)
    var rms:=sqrt(square/count_)
    var ok:=peak>.018 and rms>.005 and variation>.005 and variation<.06 and seam_error<.001
    print("Resposta visual mensurável: ",ok)
    g.free();quit(0 if ok else 1)
