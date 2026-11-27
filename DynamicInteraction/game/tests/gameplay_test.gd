extends SceneTree
const Game=preload("res://gameplay/main.tscn")
const Composer=preload("res://gameplay/action_composer.gd")
const Custom=preload("res://gameplay/customization_manager.gd")
const Poses=preload("res://rig/active/pose_library.gd")
var failures:=PackedStringArray()
func _initialize()->void:call_deferred("run")
func check(ok:bool,title:String)->void:
    if not ok:failures.append(title)
func occupy(ticks:int)->void:
    for i in ticks:await physics_frame
func run()->void:
    var composer:=Composer.new()
    composer.select_base(1)
    check(composer.enable("flex",true) and composer.enable("head",true),"ações compatíveis simultâneas")
    composer.advance(.2)
    var head_phase:float=composer.actions.head.phase
    composer.actions.flex.speed=2.
    composer.actions.head.paused=true
    var flex_phase:float=composer.actions.flex.phase
    composer.advance(.1)
    check(is_equal_approx(composer.actions.head.phase,head_phase),"pausa individual")
    check(is_equal_approx(composer.actions.flex.phase-flex_phase,.1*2.*TAU*.35),"ritmo individual em execução")
    composer.select_base(4)
    check(not composer.enable("flex",true) and not composer.actions.flex.enabled,"incompatibilidade com caminhada")
    composer.actions.head.paused=false
    composer.actions.head.repeat=false
    composer.advance(4.)
    check(not composer.actions.head.enabled,"ação termina sem repetição")
    composer.enable("head",true)
    composer.advance(.1)
    check(composer.actions.head.enabled and composer.actions.head.phase<TAU,"reiniciar ação concluída")
    var g=Game.instantiate()
    var test_path:="user://gameplay-test-%d"%OS.get_process_id()
    g.pose_library=Poses.new(test_path+"-poses.cfg")
    g.customizations.path=test_path+"-muscles.cfg"
    root.add_child(g)
    await occupy(260)
    check(g.ready_to_pose and g.core.bodies.size()==16,"jogo inicia com corpo articulado")
    check(not g.interface.panel.visible and not g.draw_reference and not g.draw.bone,"diagnóstico desativado e menu recolhido")
    check(g.interaction_mode.materials.size()>=2,"roupas do CharacterProfile reconhecidas")
    check(not g.interface.sections["Preferências"].visible,"desenvolvimento fechado")
    var rate:=Engine.physics_ticks_per_second
    var physics_id:int=g.core.get_instance_id()
    var chest_before:Vector3=g.core.bodies.chest.global_position
    g.stimulus.intensity=.10
    g.stimulus.direction=Vector3.RIGHT
    g.stimulus.duration=.20
    g.stimulus.trigger()
    await occupy(30)
    check(g.stimulus.remaining<=0. and g.core.bodies.chest.global_position.distance_to(chest_before)>.002,"estímulo externo limitado por duração")
    await occupy(180)
    g.select_base(1)
    g.composer.enable("flex",true)
    g.composer.enable("head",true)
    await occupy(480)
    var max_rms:=0.
    var max_gap:=0.
    var support_count:=0
    for i in 360:
        await physics_frame
        max_rms=maxf(max_rms,g.core.rms)
        max_gap=maxf(max_gap,g.core.max_gap)
        if g.core.active_support.has("pelvis"):support_count+=1
    print("Sentada + flexão + olhar · RMS máx %.4f m · folga %.4f m · apoio banco %d/360"%[max_rms,max_gap,support_count])
    check(max_rms<.09 and max_gap<.04 and support_count>300,"composição sentada sustenta com forças limitadas")
    g.composer.actions.flex.speed=3.
    g.composer.actions.head.paused=true
    g.set_interaction(1)
    await occupy(120)
    check(g.core.get_instance_id()==physics_id and g.composer.actions.flex.enabled,"vestuário mantém corpo e ações")
    g.set_interaction(2)
    var before:Transform3D=g.camera.global_transform
    g.start_gesture(8,Vector2(400,300))
    var motion:=InputEventScreenDrag.new()
    motion.index=8
    motion.position=Vector2(450,320)
    g._input(motion)
    check(not g.camera.global_transform.is_equal_approx(before),"gesto orbita a câmera")
    g.set_interaction(0)
    check(g.camera_gestures.is_empty() and g.drag_id==-2,"troca encerra gestos")
    var saved_preferences:=ConfigFile.new()
    check(saved_preferences.load("user://gameplay_ui.cfg")==OK and saved_preferences.get_value("ui","mode")==0,"modalidade persistida")
    check(Engine.physics_ticks_per_second==rate,"ritmo não altera frequência física")
    check(g.customizations.save_profile("Natural A",g.muscles)==OK,"salvar perfil")
    check(g.customizations.rename("Natural A","Natural B",true)==OK,"duplicar perfil")
    check(g.customizations.rename("Natural B","Natural C",false)==OK,"renomear perfil")
    var reload:=Custom.new()
    reload.path=g.customizations.path
    reload.load_all()
    check(reload.profiles.size()==2 and reload.profiles.has("Natural C"),"reabrir múltiplos perfis")
    check(reload.remove("Natural C")==OK and reload.profiles.size()==1,"excluir perfil")
    g.capture_custom_pose(false)
    check(g.save_pose("Sentada personalizada")==OK,"salvar postura separada")
    var poses:Dictionary=g.pose_library.entries.duplicate(true)
    poses["Cópia"]=poses["Sentada personalizada"].duplicate(true)
    check(g.pose_library.replace_entries(poses)==OK,"duplicar postura")
    check(g.interface.pose_management.item_count==2,"menu atualizado após salvar")
    g.edit_joint("head",1,170.)
    var composed:Dictionary=g.compose_custom_reference(g.pose_draft)
    check(composed.angles.head==g.pose_reference.clamp_angles("head",composed.angles.head),"composição respeita anatomia")
    g.select_base(4)
    g.base_speed=2.
    await occupy(60)
    check(g.elapsed>.9 and g.elapsed<1.1,"ritmo da caminhada altera somente o relógio da referência")
    var clock:float=g.elapsed
    g.base_paused=true
    await occupy(60)
    check(is_equal_approx(g.elapsed,clock) and Engine.physics_ticks_per_second==rate,"base pausada com simulação ativa")
    g.base_paused=false
    g.base_speed=1.
    g.interface.set_minimal(true)
    check(not g.interface.panel.visible and not g.interface.status.visible,"interface mínima")
    g.interface.set_minimal(false)
    g.restore_original()
    g.composer.enable("flex",false)
    g.composer.enable("head",false)
    await occupy(500)
    for base in [2,3,0]:
        g.select_base(base)
        await occupy(360)
        print("Base %d · COM %.3f · RMS %.4f · folga %.4f"%[base,g.core.com.y,g.core.rms,g.core.max_gap])
        check(g.core.com.is_finite() and g.core.rms<.09 and g.core.max_gap<.04,"estabilidade base %d"%base)
    # Consulta real da malha skinned para toque no tecido, sem simular resultado visual.
    var found:=false
    for surface in g.interaction_mode.picker.surfaces:
        if not g.interaction_mode.materials.has(surface.node):continue
        var pixel:Vector2=g.camera.unproject_position(surface.node.global_position+Vector3(0,1.1,0))
        for y in range(220,410,5):
            for x in range(410,590,5):
                if g.interaction_mode.begin(g.camera,Vector2(x,y)):
                    var mesh:MeshInstance3D=g.interaction_mode.selected
                    g.interaction_mode.drag(Vector2(x,y-100))
                    check(float(g.interaction_mode.materials[mesh].get_shader_parameter("amount"))>0.,"toque altera tecido")
                    g.interaction_mode.release()
                    found=true
                    break
            if found:break
        if found:break
    check(found,"toque encontra roupa vestida")
    g.interaction_mode.reset()
    for material in g.interaction_mode.materials.values():check(is_zero_approx(material.get_shader_parameter("amount")),"restaurar vestuário")
    g.free()
    for suffix in ["-poses.cfg","-muscles.cfg"]:DirAccess.remove_absolute(test_path+suffix)
    print("Gameplay 1.3.3.2 · falhas ",failures.size()," ",failures)
    quit(0 if failures.is_empty() else 1)
