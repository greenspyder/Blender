extends SceneTree
## Compare duas revisões usando este mesmo script, a mesma versão da Godot e dados de usuário isolados.
var output_dir: String
var images := false
var accessory_off := false
var game
var picker
var body: Dictionary

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var args := OS.get_cmdline_user_args()
    output_dir = args[0] if args.size() else OS.get_user_data_dir()
    images = args.size() > 1 and args[1] == "images"
    accessory_off = args.size() > 1 and args[1] == "without_accessory"
    DirAccess.make_dir_recursive_absolute(output_dir)
    root.size = Vector2i(960, 720)
    game = load("res://gameplay/main.tscn").instantiate()
    root.add_child(game)
    game.framing.reset()
    game.cloth.set_quality(0)
    if accessory_off: game.cloth.set_accessory_enabled(false)
    picker = game.interaction_mode.picker
    for surface in picker.surfaces:
        if str(surface.node.name) == game.profile.mesh_roles.skin:
            body = surface
            break
    if images: game.interface.hud.hide()
    var samples := []
    for base in [0, 1, 2, 4]:
        game.select_base(base)
        game.composer.enable("head", true)
        for i in 180: await physics_frame
        var rms := 0.0
        var gap := 0.0
        var supported := 0
        var cloth_us := 0.
        var peak_speed := 0.
        var physics_times := PackedFloat32Array()
        var visual_times := PackedFloat32Array()
        var last_clock:float = game.cloth.render_clock
        var memory_peak := 0.
        var begin := Time.get_ticks_usec()
        for i in 180:
            await physics_frame
            rms += game.core.rms
            gap = maxf(gap, game.core.max_gap)
            if not game.core.active_support.is_empty(): supported += 1
            for b in game.core.bodies.values(): peak_speed = maxf(peak_speed, b.linear_velocity.length())
            cloth_us += game.cloth.physics_us
            physics_times.append(game.cloth.physics_us * .001)
            if game.cloth.render_clock < last_clock: visual_times.append(game.cloth.render_us * .001)
            last_clock = game.cloth.render_clock
            memory_peak = maxf(memory_peak,Performance.get_monitor(Performance.MEMORY_STATIC))
        var elapsed := Time.get_ticks_usec() - begin
        var result := {"base": base, "host_ms": elapsed / 180000., "cloth_ms": cloth_us / 180000., "body_rms_m": rms / 180., "max_gap_m": gap, "supported_ticks": supported, "peak_speed_m_s": peak_speed}
        physics_times.sort()
        visual_times.sort()
        result.physics_cloth_p95_ms = physics_times[floori(.95*(physics_times.size()-1))]
        result.visual_cloth_median_ms = visual_times[visual_times.size()/2] if visual_times.size() else null
        result.memory_peak_mib = memory_peak / 1048576.
        arm_metrics(result)
        samples.append(result)
        if images:
            for angle in [0, 65, 145]:
                game.framing.yaw = angle
                game.framing.pitch = 6.
                game.framing.zoom = 2.32
                game.framing.apply(game.camera)
                await RenderingServer.frame_post_draw
                var err := root.get_texture().get_image().save_png(output_dir.path_join("pose_%d_%d.png" % [base,angle]))
                if err != OK: quit(1); return
    var file := FileAccess.open(output_dir.path_join("samples.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(samples,"  ")); file.close()
    game.free()
    quit(0)

func arm_metrics(result: Dictionary) -> void:
    picker.update_surface(body)
    var ids: PackedInt32Array = body.indices
    var ratios := PackedFloat32Array()
    var stray := 0
    var distal := 0
    var cache := {}
    for i in body.vertices.size():
        if absf(body.vertices[i].x) < .55: continue
        distal += 1
        for j in range(i*4, i*4+4):
            var role: String = str(game.core.ids.find_key(body.slots[body.joints[j]][0]))
            if (role.begins_with("thigh") or role.begins_with("shin")) and body.weights[j] > .001:
                stray += 1
                break
    for i in range(0, ids.size(), 3):
        for j in 3:
            var a := ids[i+j]
            var b := ids[i+(j+1)%3]
            var pa: Vector3 = body.vertices[a]
            var pb: Vector3 = body.vertices[b]
            if minf(absf(pa.x), absf(pb.x)) < .50 or pa.distance_to(pb) < .001: continue
            if not cache.has(a): cache[a] = picker.vertex(body, a)
            if not cache.has(b): cache[b] = picker.vertex(body, b)
            ratios.append(Vector3(cache[a]).distance_to(cache[b])/pa.distance_to(pb))
    ratios.sort()
    result.distal_vertices = distal
    result.distal_leg_weights = stray
    result.distal_edge_ratio_p95 = ratios[floori(.95*(ratios.size()-1))]
    result.distal_edge_ratio_max = ratios[-1]
    for side in ["l","r"]:
        var shoulder: Vector3 = game.core.physical_pose("upper_"+side).origin
        var elbow: Vector3 = game.core.physical_pose("fore_"+side).origin
        var wrist: Vector3 = game.core.physical_pose("palm_"+side).origin
        result["elbow_deg_"+side] = rad_to_deg((elbow-shoulder).angle_to(wrist-elbow))
