extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
    for scene in ["res://rig/active/lab.tscn","res://gameplay/main.tscn"]:
        var game=load(scene).instantiate()
        root.add_child(game)
        for i in 240:await physics_frame
        var start:=Time.get_ticks_usec()
        var ticks:=Engine.physics_ticks_per_second*6
        for i in ticks:await physics_frame
        var ms:=(Time.get_ticks_usec()-start)*.001
        print("%s · %d ticks · %.3f ms/tick host · %.1f ms/segundo simulado"%[scene,ticks,ms/ticks,ms/6.])
        game.free()
        await process_frame
    quit(0)
