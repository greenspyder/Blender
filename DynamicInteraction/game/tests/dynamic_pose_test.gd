extends SceneTree

const Lab=preload("res://rig/active/lab.tscn")
const Library=preload("res://rig/active/pose_library.gd")
const Pose=preload("res://rig/active/pose_reference.gd")
var failures:=PackedStringArray()

func _initialize()->void:
    call_deferred("run")

func check(valid:bool,message:String)->void:
    if not valid:failures.append(message)

func occupy(ticks:int)->void:
    for i in ticks:await physics_frame

func check_sustained(lab,pose_name:String,expected:Vector3,with_seat:bool)->void:
    var minimum:=INF
    var maximum:=-INF
    var largest_error:=0.
    var stable_ticks:=0
    for i in 150:
        await physics_frame
        var com:Vector3=lab.core.com
        minimum=minf(minimum,com.y)
        maximum=maxf(maximum,com.y)
        largest_error=maxf(largest_error,lab.core.rms)
        if "foot_l" in lab.core.active_support and "foot_r" in lab.core.active_support:
            if not with_seat or "pelvis" in lab.core.active_support:stable_ticks+=1
    print("%s · COM %.3f–%.3f m · RMS máx. %.1f mm · apoio %d/150"%[
        pose_name,minimum,maximum,largest_error*1000.,stable_ticks])
    check(stable_ticks>=145 and largest_error<.065 and maximum-minimum<.012,pose_name+" sustenta sem travar juntas")
    check(lab.core.com.distance_to(expected)<.055,pose_name+" mantém a geometria esperada")

func run()->void:
    var path:="user://pose-test-%d.cfg"%OS.get_process_id()
    var captured:Dictionary={}
    var positions:Dictionary={}
    var movements:=[0,2,3,6]
    var names:=["Em pé","Agachada","Inclinada","Sentada"]
    for i in movements.size():
        var lab=Lab.instantiate()
        lab.pose_library=Library.new(path)
        root.add_child(lab)
        await occupy(256)
        lab.select_move(movements[i])
        await occupy([60,210,200,290][i])
        positions[names[i]]=lab.core.com
        lab.capture_custom_pose(false)
        check(lab.save_pose(names[i])==OK,names[i]+" grava")
        captured[names[i]]=lab.pose_draft.duplicate(true)
        await occupy(230)
        await check_sustained(lab,names[i],positions[names[i]],i==3)
        lab.free()
        await process_frame

    var lab=Lab.instantiate()
    lab.pose_library=Library.new(path)
    root.add_child(lab)
    await occupy(240)
    check(lab.pose_library_error==OK and lab.pose_library.entries.size()==4,"biblioteca reabre as quatro poses")
    for title in names:
        check(lab.pose_library.entries[title].angles.keys().size()==Pose.ROLES.size(),"serialização por papel semântico")
        for role in Pose.ROLES:
            check(lab.pose_library.entries[title].angles[role].is_equal_approx(captured[title].angles[role]),"ângulo persistido em "+title)
    var editor=lab.pose_editor
    lab.toggle_pose_editor()
    var crouch_index:=0
    for i in editor.saved_menu.item_count:
        if editor.saved_menu.get_item_text(i)=="Agachada":crouch_index=i
    check(crouch_index>0,"poses salvas aparecem no editor")
    var original_pelvis:Vector3=lab.core.bodies.pelvis.position
    var source_height:float=lab.reference_world_bone("pelvis").origin.y
    lab.transition_seconds=1.
    editor.saved_menu.item_selected.emit(crouch_index)
    check(lab.mode==lab.ReferenceMode.CUSTOM and lab.core.state==1,"carrega pelo menu e mantém estado Active")
    check(lab.core.bodies.pelvis.position.is_equal_approx(original_pelvis),"carregar não teleporta o corpo")
    await occupy(61)
    var halfway_height:float=lab.reference_world_bone("pelvis").origin.y
    await occupy(180)
    var target_height:float=lab.reference_world_bone("pelvis").origin.y
    check(halfway_height<source_height-.04 and halfway_height>target_height+.04,"transição gradual por um segundo")
    await check_sustained(lab,"Agachada recarregada",positions["Agachada"],false)

    editor.joint_menu.item_selected.emit(Pose.ROLES.keys().find("lumbar"))
    editor.sliders[0].value=18.
    check(is_equal_approx(lab.pose_draft.angles.lumbar.x,18.) and lab.pose_title=="Postura editada","slider edita uma articulação")
    await occupy(200)
    check(lab.core.bodies.chest.global_position.z-lab.core.bodies.pelvis.global_position.z>.09,"tronco responde à edição enquanto agacha")
    lab.edit_joint("shin_l",2,80.)
    check(lab.pose_draft.angles.shin_l.z==0.,"joelho restringe os outros eixos")
    lab.edit_joint("lumbar",0,90.)
    check(is_equal_approx(lab.pose_draft.angles.lumbar.x,lab.profile.lumbar_limit.x),"limite anatômico")
    lab.restore_original()
    await occupy(350)
    check(lab.mode==lab.ReferenceMode.AUTOMATIC and lab.core.com.y>.92,"original de pé restaurado")

    lab.select_reference_mode(lab.ReferenceMode.CUSTOM)
    lab.capture_custom_pose(false)
    lab.capture_on_release=true
    var touch:=InputEventScreenTouch.new()
    touch.position=lab.camera.unproject_position(lab.core.bodies.chest.global_position)
    touch.index=2
    touch.pressed=true
    lab._unhandled_input(touch)
    await occupy(3)
    check(lab.drag_role=="chest","toque seleciona o tronco")
    var before:float=lab.core.com.y
    var motion:=InputEventScreenDrag.new()
    motion.index=touch.index
    motion.position=lab.camera.unproject_position(lab.drag_goal+Vector3(0.,-.21,.07))
    lab._input(motion)
    await occupy(150)
    touch.pressed=false
    lab._input(touch)
    check(lab.pose_title=="Postura capturada" and lab.drag_role.is_empty(),"soltar fixa a referência e libera a tração")
    await occupy(280)
    print("Captura ao soltar · COM %.3f → %.3f m"%[before,lab.core.com.y])
    check(lab.core.com.y<before-.025 and lab.core.rms<.065,"sustenta a postura capturada após soltar")

    lab.edit_joint("pelvis",0,26.)
    lab.edit_joint("lumbar",0,26.)
    lab.edit_joint("chest",0,28.)
    for side in ["l","r"]:
        lab.edit_joint("thigh_"+side,0,10.)
        lab.edit_joint("shin_"+side,0,35.)
    lab.edit_pelvis(1,-.24)
    await occupy(430)
    print("Referência fora da base · COM %.3f m · assistência %.3f"%[lab.core.com.y,lab.position_support])
    check(lab.core.com.y<.4 and lab.position_support<.05,"referência sem sustentação suficiente cede")
    lab.select_reference_mode(lab.ReferenceMode.FREE)
    await occupy(250)
    check(lab.core.state==1 and is_equal_approx(lab.core.gain.pelvis,.12),"livre modula o estado sem substituí-lo")
    check(is_zero_approx(lab.position_support),"livre desativa assistência posicional")
    lab.select_state(3)
    await occupy(120)
    check(is_zero_approx(lab.core.gain.pelvis),"Passive continua zerando o ganho")
    lab.apply_preset(0)
    check(lab.core.settings.stiffness[0]>lab.original.stiffness[0],"presets musculares continuam independentes")
    check(lab.pose_library.entries["Agachada"].angles.lumbar.is_equal_approx(captured["Agachada"].angles.lumbar),"editar não altera registro salvo")
    var cfg:=ConfigFile.new()
    cfg.set_value("library","version",999)
    cfg.save(path)
    var invalid:=Library.new(path)
    check(invalid.load_all()==ERR_FILE_UNRECOGNIZED,"versão inválida detectada")
    check(invalid.entries.is_empty(),"arquivo inválido não injeta poses")
    DirAccess.remove_absolute(path)
    lab.free()
    print("Dynamic Pose Reference · falhas ",failures.size()," ",failures)
    quit(0 if failures.is_empty() else 1)
