extends SceneTree
var failures:=PackedStringArray()
func _initialize()->void:call_deferred("run")
func check(ok:bool,title:String)->void:
    if not ok:failures.append(title)
func run()->void:
    var g=load("res://gameplay/main.tscn").instantiate();root.add_child(g)
    var frequency:=Engine.physics_ticks_per_second
    var mass:float=g.core.bodies.pelvis.mass
    print("Partículas: acessório ",g.cloth.accessory.solver.position.size()," roupa ",g.cloth.worn.solver.position.size())
    for base in [0,1,2,3,4]:
        g.select_base(base);g.composer.enable("head",true)
        if base!=4:g.composer.enable("flex",true)
        var peak_offset:=0.;var peak_gap:=0.;var cost:=0.
        for tick in 360:
            await physics_frame
            peak_offset=maxf(peak_offset,g.cloth.worn.max_offset)
            peak_gap=maxf(peak_gap,g.core.max_gap)
            cost+=g.cloth.physics_us
        print("Base %d · roupa %.4f m · junta %.4f m · tecido %.3f ms/tick"%[base,peak_offset,peak_gap,cost/360000.])
        check(peak_offset<=g.cloth.worn.radius*1.08,"cobertura limitada pela superfície vestida")
        check(peak_gap<.04,"ragdoll sem alongamento")
    for record in g.cloth.worn.records:
        var mesh:Mesh=record.surface.node.mesh;var index:int=record.surface.surface_index
        check(mesh.surface_get_material(index)==record.material,"material e texturas preservados")
        var arrays:Array=mesh.surface_get_arrays(index)
        check(arrays[Mesh.ARRAY_VERTEX].size()==record.arrays[Mesh.ARRAY_VERTEX].size(),"topologia preservada")
        check(arrays[Mesh.ARRAY_INDEX]==record.arrays[Mesh.ARRAY_INDEX],"costuras e índices preservados")
        check(arrays[Mesh.ARRAY_BONES]==record.arrays[Mesh.ARRAY_BONES] and arrays[Mesh.ARRAY_WEIGHTS]==record.arrays[Mesh.ARRAY_WEIGHTS],"pesos e skinning preservados")
        check(arrays[Mesh.ARRAY_TEX_UV]==record.arrays[Mesh.ARRAY_TEX_UV],"UVs preservadas")
        for i in record.boundary:check(arrays[Mesh.ARRAY_VERTEX][i].distance_to(record.arrays[Mesh.ARRAY_VERTEX][i])<.000001,"borda/costura não abre")
        for p in arrays[Mesh.ARRAY_VERTEX]:check(p.is_finite(),"malha finita")
    g.set_interaction(1)
    var s=g.cloth.accessory.solver
    var pixel:Vector2=g.camera.unproject_position(s.position[s.position.size()/2])
    check(g.interaction_mode.begin(g.camera,pixel),"picking do acessório")
    g.interaction_mode.drag(pixel+Vector2(40,-40))
    for tick in 90:await physics_frame
    g.set_interaction(2)
    check(s.hold.is_empty() and g.composer.actions.head.enabled,"troca de modalidade solta tecido sem parar ações")
    check(Engine.physics_ticks_per_second==frequency and g.core.bodies.pelvis.mass==mass,"qualidade corporal preservada")
    var count_:int=s.position.size()
    g.cloth.set_quality(0)
    check(s.position.size()==count_ and Engine.physics_ticks_per_second==frequency,"qualidade sem remontar pano nem reduzir ragdoll")
    var config_path:="user://cloth_material.cfg"
    var had_config:=FileAccess.file_exists(config_path)
    var old_config:=FileAccess.get_file_as_string(config_path) if had_config else ""
    g.cloth.material.density=222.
    check(g.cloth.save_custom()==OK,"salvar material personalizado")
    g.cloth.set_profile(g.cloth.Profile.preset(1))
    g.cloth.load_custom()
    check(is_equal_approx(g.cloth.material.density,222.) and g.cloth.quality==0,"reabrir propriedades e qualidade")
    if had_config:
        var file:=FileAccess.open(config_path,FileAccess.WRITE);file.store_string(old_config);file.close()
    else:DirAccess.remove_absolute(config_path)
    g.free()
    print("Cloth Gameplay · falhas ",failures.size()," ",failures)
    quit(0 if failures.is_empty() else 1)
