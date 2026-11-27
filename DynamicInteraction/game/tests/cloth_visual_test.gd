extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
    var g=load("res://gameplay/main.tscn").instantiate();root.add_child(g)
    root.size=Vector2i(1100,700)
    g.framing.reset();g.framing.apply(g.camera)
    for base in [0,1,4]:
        g.select_base(base);g.composer.enable("head",true)
        for i in 300:await physics_frame
        if base==0:
            var s=g.cloth.accessory.solver
            s.begin_hold(s.triangles.size()-3,Vector3(.3,.3,.4),s.position[-1]+Vector3(-.12,.2,.2))
            for i in 120:await physics_frame
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("user://cloth-pose-%d.png"%base)
        g.cloth.release()
    g.free()
    print("Visual tecido/posturas · ",DisplayServer.get_name())
    quit(0)
