extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
    for quality in [-1,0,1,2]:
        var g=load("res://gameplay/main.tscn").instantiate();root.add_child(g)
        g.cloth.active=quality>=0
        if quality>=0:g.cloth.set_quality(quality)
        g.select_base(4)
        for i in 120:await physics_frame
        var begin:=Time.get_ticks_usec();var physical:=0.;var visual:=0.;var samples:=0
        for i in 360:
            await physics_frame
            physical+=g.cloth.physics_us if quality>=0 else 0
            visual+=g.cloth.render_us if quality>=0 else 0
            samples+=1
        print("Qualidade %d · %.3f ms/tick host · física tecido %.3f ms · reconstrução visual %.3f ms"%[quality,float(Time.get_ticks_usec()-begin)/360000.,physical/samples/1000.,visual/samples/1000.])
        g.free();await process_frame
    quit(0)
