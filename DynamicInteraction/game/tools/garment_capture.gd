extends SceneTree
## Comparação controlada na peça vestida da Rosé. Executável também sobre 8087f26.
func _initialize()->void:call_deferred("run")

func visible_strap(game)->Vector2:
    var picker=game.interaction_mode.picker
    var query:Array=picker.prepare_query()
    for rec in game.cloth.worn.records:
        var s:Dictionary=rec.surface
        if str(s.node.name)!="Dress" or s.surface_index!=1:continue
        for f in range(0,s.indices.size(),3):
            var bind:=Vector3.ZERO
            var point:=Vector3.ZERO
            for j in 3:bind+=Vector3(s.vertices[s.indices[f+j]])/3.
            if bind.x<.085 or bind.x>.15 or bind.y<1.631 or bind.z<.03:continue
            for j in 3:point+=Vector3(picker.vertex(s,s.indices[f+j]))/3.
            var pixel:Vector2=game.camera.unproject_position(point)
            var hit:Dictionary=picker.cast(game.camera,pixel,0.,query)
            if not hit.is_empty() and is_same(hit.surface,s) and hit.face==f:return pixel
    return Vector2.INF

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=2 or DisplayServer.get_name()=="headless":quit(2);return
    var folder:=args[0]
    DirAccess.make_dir_recursive_absolute(folder)
    root.size=Vector2i(960,720)
    var g=load("res://gameplay/main.tscn").instantiate()
    root.add_child(g)
    g.set_interaction(1)
    g.cloth.set_quality(0)
    g.interface.hud.hide()
    g.framing.yaw=6.;g.framing.pitch=9.;g.framing.target=Vector3(.05,1.54,.0);g.framing.zoom=.72
    g.framing.apply(g.camera)
    for i in 250:await physics_frame
    var pixel:=visible_strap(g)
    if not pixel.is_finite():push_error("Alça não encontrada");quit(1);return
    var touch:=InputEventScreenTouch.new()
    touch.index=3;touch.position=pixel;touch.pressed=true
    var drag:=InputEventScreenDrag.new()
    drag.index=3;drag.position=pixel+Vector2(58,10)
    if args[1]=="grab":
        g._unhandled_input(touch)
        g._input(drag)
    for i in 90:await physics_frame
    await RenderingServer.frame_post_draw
    var err:=root.get_texture().get_image().save_png(folder.path_join("strap.png"))
    # Dados lidos do ArrayMesh efetivamente enviado ao renderer.
    var patch:=PackedVector3Array()
    for record in g.cloth.worn.records:
        var surf:Dictionary=record.surface
        if str(surf.node.name)!="Dress" or surf.surface_index!=1:continue
        var actual:PackedVector3Array=surf.node.mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
        for i in actual.size():
            var p:Vector3=surf.vertices[i]
            if p.x>=.085 and p.x<=.16 and p.y>1.615:patch.append(actual[i]-p)
    var file:=FileAccess.open(folder.path_join("strap.f32"),FileAccess.WRITE)
    file.store_buffer(patch.to_byte_array());file.close()
    print("Entrada ",args[1]," · pixel ",pixel," · captura ",g.cloth.selected_worn," · vértices ",patch.size())
    touch.pressed=false;g._input(touch)
    g.free()
    quit(0 if err==OK and patch.size()>0 else 1)
