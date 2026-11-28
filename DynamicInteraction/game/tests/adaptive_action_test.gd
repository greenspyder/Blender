extends SceneTree
const Game=preload("res://gameplay/main.tscn")
var game
var failures:=PackedStringArray()

func _initialize()->void:call_deferred("run")
func ticks(count_:int)->void:
    for i in count_:await physics_frame
func check(ok:bool,message:String)->void:
    if not ok:failures.append(message)
func height()->float:return game.core.bodies.pelvis.global_position.y
func knee_angle(side:String)->float:
    var hip:Vector3=game.core.physical_pose("thigh_"+side).origin
    var knee:Vector3=game.core.physical_pose("shin_"+side).origin
    var foot:Vector3=game.core.physical_pose("foot_"+side).origin
    return rad_to_deg((knee-hip).angle_to(foot-knee))

func cycle(label_:String,seated:bool,min_motion:float)->void:
    await ticks(270)
    var initial:=height()
    var previous:=initial
    var low:=initial
    var high:=initial
    var largest_step:=0.
    var gap:=0.
    var knee_peak:=0.
    var supported:=0
    var seat_ticks:=0
    var accepted:Dictionary=game.request_action("squat",true,{"repeat":false,"amplitude":1.})
    check(accepted.accepted,label_+" "+str(accepted.reason))
    game.request_action("head",true)
    for i in 445:
        await physics_frame
        var y:=height()
        low=minf(low,y);high=maxf(high,y)
        largest_step=maxf(largest_step,absf(y-previous));previous=y
        gap=maxf(gap,game.core.max_gap)
        knee_peak=maxf(knee_peak,knee_angle("l"))
        if "foot_l" in game.core.active_support or "foot_r" in game.core.active_support:supported+=1
        if game.core.bodies.pelvis.support_body==game.seat:seat_ticks+=1
    var delta:=high-initial if seated else initial-low
    print("%s · excursão %.2f cm · retorno %.2f mm · passo %.2f mm · apoio %d/445 · banco %d · joelho %.2f° · junta %.2f mm"%[label_,100.*delta,1000.*absf(initial-height()),largest_step*1000.,supported,seat_ticks,knee_peak,gap*1000.])
    check(delta>min_motion,label_+" excursão física")
    check(absf(initial-height())<.045 and largest_step<.012,label_+" continuidade e retorno")
    check(supported>380 and gap<.03 and knee_peak<game.profile.knee_limit.y+8.,label_+" apoios e limites")
    if seated:check(seat_ticks>5 and game.seat.visible,label_+" retorno ao assento")
    check(not game.composer.actions.squat.enabled and game.composer.actions.head.enabled,label_+" relógios independentes")
    game.request_action("head",false)
    game.request_action("squat",false)

func run()->void:
    game=Game.instantiate()
    root.add_child(game)
    game.cloth.set_accessory_enabled(false)
    await cycle("Em pé",false,.15)
    game.select_base(1)
    await cycle("Sentada",true,.025)
    game.select_base(2)
    await cycle("Agachada",false,.035)
    game.select_base(0)
    await ticks(260)
    game.capture_custom_pose(false)
    game.edit_joint("head",1,18.)
    var saved:Dictionary=game.pose_draft.duplicate(true)
    await cycle("Personalizada",false,.045)
    check(game.pose_draft==saved,"pose original preservada")
    await ticks(140)
    var expected:Dictionary=game.pose_reference.snapshot()
    game.pose_reference.apply(saved)
    var actual:Dictionary=game.pose_reference.snapshot()
    check(Vector3(expected.pelvis).distance_to(actual.pelvis)<.002,"raiz da referência restaurada")
    for key in actual.rotations:check(Quaternion(expected.rotations[key]).angle_to(actual.rotations[key])<.004,"restauração "+str(key))
    game.select_state(3)
    await ticks(100)
    var result:Dictionary=game.request_action("squat",true)
    check(not result.accepted and "músculos" in result.reason,"diagnóstico em passivo")
    game.recover_standing()
    await ticks(360)
    check(game.request_action("squat",true).accepted,"ação novamente viável após recuperação")
    check(not game.request_action("squat",true,{"amplitude":NAN}).accepted,"parâmetro não finito rejeitado")
    print("Ações adaptativas · ",failures)
    game.free()
    quit(0 if failures.is_empty() else 1)
