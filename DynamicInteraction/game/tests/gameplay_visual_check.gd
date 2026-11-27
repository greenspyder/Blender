extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
    var game=load("res://gameplay/main.tscn").instantiate()
    root.add_child(game)
    root.size=Vector2i(1100,700)
    for i in 180:await physics_frame
    game.interface.set_minimal(false)
    game.set_interaction(0)
    game.framing.reset()
    game.framing.apply(game.camera)
    await process_frame
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("user://rose-game-landscape.png")
    game.interface.panel.show()
    game.interface.sections["Ações"].show()
    root.size=Vector2i(600,950)
    for i in 15:await process_frame
    var panel:Rect2=game.interface.panel.get_global_rect()
    var camera_panel:Rect2=game.interface.camera_panel.get_global_rect()
    if panel.intersects(camera_panel) or panel.end.y>950:quit(1);return
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("user://rose-game-portrait.png")
    game.free()
    print("Layout portrait/landscape validado; renderização: ",DisplayServer.get_name())
    quit(0)
