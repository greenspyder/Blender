extends SceneTree
const Game=preload("res://gameplay/main.tscn")
var errors:=PackedStringArray()
var g

func _initialize()->void:call_deferred("run")
func check(ok:bool,title:String)->void:
    if not ok:errors.append(title)
func ticks(n:int)->void:
    for i in n:await physics_frame

func visible_grip(label_:String)->Dictionary:
    var picker=g.interaction_mode.picker
    var query:Array=picker.prepare_query()
    for region in g.cloth.worn.regions:
        if region.label!=label_:continue
        for record in g.cloth.worn.records:
            var s:Dictionary=record.surface
            if str(s.node.name)!=region.piece:continue
            for f in range(0,s.indices.size(),3):
                var bind:=Vector3.ZERO
                var point:=Vector3.ZERO
                for j in 3:bind+=Vector3(s.vertices[s.indices[f+j]])/3.
                if region.weight(bind)<.65:continue
                for j in 3:point+=Vector3(picker.vertex(s,s.indices[f+j]))/3.
                var pixel:Vector2=g.camera.unproject_position(point)
                var hit:Dictionary=picker.cast(g.camera,pixel,0.,query)
                if g.cloth.worn.fit_at(hit)==region:return {"pixel":pixel,"region":region}
    return {}

func garment_test(label_:String,number:int)->void:
    var selected:=visible_grip(label_)
    check(not selected.is_empty(),"região visível e selecionável "+label_)
    if selected.is_empty():return
    var touch:=InputEventScreenTouch.new()
    touch.index=number
    touch.position=selected.pixel
    touch.pressed=true
    g._unhandled_input(touch)
    check(g.cloth.worn.held_region==selected.region,"captura da região "+label_)
    var motion:=InputEventScreenDrag.new()
    motion.index=number
    motion.position=selected.pixel+Vector2(48,9)
    g._input(motion)
    await ticks(60)
    var region=selected.region
    # Na mesma pose e no mesmo tick, medir o termo físico do ajuste dentro da malha.
    var worn=g.cloth.worn
    var solved:Vector3=region.offset
    region.offset=Vector3.ZERO
    worn.render()
    var neutral_arrays:Dictionary={}
    for entry in region.vertices:
        var rec:Dictionary=entry[0]
        var index:int=rec.surface.surface_index
        if not neutral_arrays.has(index):
            neutral_arrays[index]=rec.surface.node.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]
    region.offset=solved
    worn.render()
    var drawn:=0.
    var readback:=0.
    var current_arrays:Dictionary={}
    for entry in region.vertices:
        var rec:Dictionary=entry[0]
        var index:int=rec.surface.surface_index
        if not current_arrays.has(index):
            current_arrays[index]=rec.surface.node.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]
        var id:int=entry[1]
        var actual:Vector3=current_arrays[index][id]
        drawn=maxf(drawn,actual.distance_to(neutral_arrays[index][id]))
        readback=maxf(readback,actual.distance_to(rec.render_vertices[id]))
    check(drawn>.002 and drawn<=region.travel+.001,"deslocamento físico visível e limitado "+label_)
    check(readback<.0002,"buffer de vértices corresponde ao apresentado")
    var held:float=region.offset.length()
    touch.pressed=false
    g._input(touch)
    await ticks(180)
    check(g.cloth.worn.held_region==null and region.rest_offset.length()>.002,"acomodação após soltar "+label_)
    var seam_error:=0.
    for seam in g.cloth.worn.seams:
        var first:Vector3=seam.vertices[0][0].render_vertices[seam.vertices[0][1]]
        for entry in seam.vertices:seam_error=maxf(seam_error,first.distance_to(entry[0].render_vertices[entry[1]]))
    check(seam_error<.001,"costuras durante ajuste "+label_)
    print("%s · malha %.2f mm · guia %.2f mm · após soltar %.2f mm · costura %.3f mm · diferença de leitura %.3f mm"%[label_,drawn*1000.,held*1000.,region.offset.length()*1000.,seam_error*1000.,readback*1000.])

func run()->void:
    g=Game.instantiate()
    root.add_child(g)
    g.set_interaction(1)
    g.framing.yaw=0.;g.framing.pitch=6.;g.framing.zoom=2.1;g.framing.apply(g.camera)
    g.cloth.set_quality(0)
    await ticks(240)
    for i in 2:await garment_test(["Alça","Cós"][i],i+3)
    var cloth=g.cloth
    var stable_mesh:Mesh=cloth.worn.records[0].surface.node.mesh
    g.interaction_mode.reset()
    for region in cloth.worn.regions:check(region.offset==Vector3.ZERO and not region.adjusted,"alisar regiões")
    cloth.set_accessory_enabled(false)
    var positions:PackedVector3Array=cloth.accessory.solver.position.duplicate()
    g.save_preferences()
    g.composer.enable("sway",true)
    await ticks(180)
    check(cloth.accessory.solver.position==positions and not cloth.accessory.visible,"pano oculto e suspenso")
    check(cloth.worn.records[0].surface.node.mesh==stable_mesh and cloth.worn.visual_peak>.005,"mesma malha da peça em uso")
    var config:=ConfigFile.new()
    check(config.load("user://gameplay_ui.cfg")==OK and config.get_value("cloth","accessory")==false,"preferência de suspensão persistida")
    cloth.set_accessory_enabled(true)
    var solver=cloth.accessory.solver
    solver.begin_hold(solver.triangles.size()-3,Vector3(.2,.5,.3),solver.position[-1]+Vector3(.03,.15,.12))
    await ticks(60)
    check(cloth.accessory.visible and solver.position!=positions,"retomada física do acessório")
    solver.release()
    var streams:=0
    for part in cloth.worn.part_meshes.values():
        if part.stream:streams+=1
    if DisplayServer.get_name()!="headless":check(streams==cloth.worn.part_meshes.size(),"atualização parcial nas peças do GL")
    print("Malhas em atualização parcial ",streams,"/",cloth.worn.part_meshes.size()," · ",DisplayServer.get_name())
    print("Ajustes físicos · ",errors)
    g.free()
    quit(0 if errors.is_empty() else 1)
