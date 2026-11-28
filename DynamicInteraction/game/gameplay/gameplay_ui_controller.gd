extends RefCounted
var game
var hud:Control
var dock:VBoxContainer
var panel:PanelContainer
var content:VBoxContainer
var sections:Dictionary={}
var status:Label
var camera_box:VBoxContainer
var restore_button:Button
var camera_panel:PanelContainer
var cloth_readout:Label
var minimal:=false
var mode_menu:OptionButton
var base_menu:OptionButton
var camera_sliders:Dictionary={}
var minimal_toggle:CheckButton
var chosen_action:="squat"
var action_widgets:Dictionary={}
var action_message:Label
var active_list:Label
var muscle_menu:OptionButton
var muscle_name:LineEdit
var muscle_message:Label
var pose_management:OptionButton
var pose_name:LineEdit
var pose_message:Label

func create(owner)->VBoxContainer:
    game=owner
    var layer:=CanvasLayer.new()
    game.add_child(layer)
    hud=Control.new()
    layer.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
    dock=VBoxContainer.new()
    hud.add_child(dock)
    dock.position=Vector2(12,12)
    dock.custom_minimum_size.x=180
    mode_menu=game.dropdown(dock,["Corpo","Vestuário","Câmera"],game.set_interaction)
    game.button(dock,"Menus",func():panel.visible=not panel.visible)
    panel=PanelContainer.new()
    hud.add_child(panel)
    panel.position=Vector2(12,116)
    var scroll:=ScrollContainer.new()
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    content=VBoxContainer.new()
    content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    scroll.add_child(content)
    status=Label.new()
    status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    status.mouse_filter=Control.MOUSE_FILTER_IGNORE
    hud.add_child(status)
    restore_button=Button.new()
    restore_button.text="Mostrar controles"
    restore_button.custom_minimum_size=Vector2(160,44)
    hud.add_child(restore_button)
    restore_button.hide()
    restore_button.pressed.connect(func():dock.show();camera_panel.show();restore_button.hide())
    camera_panel=PanelContainer.new()
    hud.add_child(camera_panel)
    var camera_root:=VBoxContainer.new()
    camera_panel.add_child(camera_root)
    game.button(camera_root,"Câmera",func():camera_box.visible=not camera_box.visible)
    camera_box=VBoxContainer.new()
    camera_root.add_child(camera_box)
    camera_box.hide()
    for entry in [["yaw","Horizontal",-180.,180.],["pitch","Vertical",-65.,65.],["zoom","Zoom",1.,5.]]:
        var key:String=entry[0]
        var label:Label=game.show_message(camera_box,entry[1])
        var slider:=HSlider.new()
        slider.min_value=entry[2]
        slider.max_value=entry[3]
        slider.step=.05 if key=="zoom" else 1.
        slider.custom_minimum_size.y=44
        camera_box.add_child(slider)
        camera_sliders[key]={"slider":slider,"label":label,"title":entry[1]}
        slider.value_changed.connect(func(v):game.framing.set(key,v);game.framing.apply(game.camera))
    game.button(camera_box,"Centralizar",func():game.framing.target=game.core.com;game.framing.apply(game.camera))
    game.button(camera_box,"Restaurar câmera",func():game.framing.reset();game.framing.apply(game.camera))
    return content

func section(title:String)->VBoxContainer:
    var body:=VBoxContainer.new()
    game.button(content,title,func():
        var was_visible:=body.visible
        for node in sections.values():node.hide()
        body.visible=not was_visible)
    content.add_child(body)
    sections[title]=body
    body.hide()
    return body

func build(_unused:VBoxContainer)->void:
    var actions:=section("Ações")
    base_menu=game.dropdown(actions,game.Library.BASES,game.select_base)
    var base_timing:=VBoxContainer.new()
    game.button(actions,"Ritmo da base / caminhada",func():base_timing.visible=not base_timing.visible)
    actions.add_child(base_timing)
    base_timing.hide()
    var base_caption:Label=game.show_message(base_timing,"Ritmo da base · 1.00x")
    var base_slider:=HSlider.new()
    base_slider.min_value=.1
    base_slider.max_value=3.
    base_slider.step=.05
    base_slider.value=1.
    base_slider.custom_minimum_size.y=38
    base_timing.add_child(base_slider)
    base_slider.value_changed.connect(func(v):game.base_speed=v;base_caption.text="Ritmo da base · %.2fx"%v)
    game.checkbox(base_timing,"Pausar evolução da base",false,func(v):game.base_paused=v)
    game.button(base_timing,"Restaurar base 1x",func():base_slider.value=1.)
    game.parameter(actions,"Transição de postura (s)",.15,3.,.05,game.transition_seconds,func(v):game.transition_seconds=v)
    game.move_menu=OptionButton.new()
    actions.add_child(game.move_menu)
    game.move_menu.hide()
    for title in game.MOVES+game.EXTRA_MOVES:game.move_menu.add_item(title)
    game.move_menu.item_selected.connect(game.select_move)
    game.dropdown(actions,game.Library.ACTIONS.values().map(func(a):return a.name),func(i):chosen_action=game.Library.ACTIONS.keys()[i];refresh_actions())
    active_list=game.show_message(actions,"Nenhuma ação complementar ativa")
    action_message=game.show_message(actions,"")
    for entry in [["enabled","Ativar"],["paused","Pausar"],["repeat","Repetir"]]:
        var key:String=entry[0]
        var check:=CheckButton.new()
        check.text=entry[1]
        check.custom_minimum_size.y=42
        actions.add_child(check)
        action_widgets[key]=check
        check.toggled.connect(func(v):
            if key=="enabled":game.request_action(chosen_action,v)
            else:game.composer.set_parameter(chosen_action,key,v)
            refresh_actions())
    for entry in [["intensity","Intensidade",0.,1.],["amplitude","Amplitude",0.,1.],["speed","Ritmo",.1,3.]]:
        var key:String=entry[0]
        var caption:Label=game.show_message(actions,"")
        var slider:=HSlider.new()
        slider.min_value=entry[2]
        slider.max_value=entry[3]
        slider.step=.05
        slider.custom_minimum_size.y=44
        actions.add_child(slider)
        action_widgets[key]=slider
        action_widgets[key+"_label"]=caption
        slider.value_changed.connect(func(v):game.composer.set_parameter(chosen_action,key,v);refresh_actions())
    game.button(actions,"Restaurar ritmo 1x",func():game.composer.set_parameter(chosen_action,"speed",1.);refresh_actions())
    refresh_actions()
    var stimuli:=section("Estímulos externos")
    game.parameter(stimuli,"Intensidade",.05,1.,.05,.3,func(v):game.stimulus.intensity=v)
    game.parameter(stimuli,"Duração (s)",.05,2.,.05,.25,func(v):game.stimulus.duration=v)
    game.dropdown(stimuli,["Frente","Trás","Esquerda","Direita"],func(i):game.stimulus.direction=[Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT][i])
    game.button(stimuli,"Perturbar tronco",game.stimulus.trigger)
    var customize:=section("Personalizações")
    game.reference_menu=game.dropdown(customize,game.REFERENCE_MODES,game.select_reference_mode)
    game.state_menu=game.dropdown(customize,game.Muscle.STATES,game.select_state)
    game.state_menu.select(game.initial_state)
    game.pose_editor=game.PoseEditor.new()
    game.button(customize,"Editar postura",func():
        if game.pose_draft.is_empty():game.capture_custom_pose(false)
        game.pose_editor.visible=not game.pose_editor.visible)
    customize.add_child(game.pose_editor)
    game.pose_editor.build(game)
    game.pose_editor.hide()
    pose_management=game.dropdown(customize,["Posturas salvas"],func(_i):pass)
    pose_name=LineEdit.new()
    pose_name.placeholder_text="Novo nome da postura"
    pose_name.max_length=32
    customize.add_child(pose_name)
    for op in ["Duplicar","Renomear","Excluir"]:
        game.button(customize,op+" postura",manage_pose.bind(op))
    pose_message=game.show_message(customize,"")
    muscle_menu=game.dropdown(customize,["Perfis musculares"],func(_i):pass)
    muscle_name=LineEdit.new()
    muscle_name.placeholder_text="Nome do perfil muscular"
    muscle_name.max_length=32
    customize.add_child(muscle_name)
    for op in ["Salvar","Carregar","Duplicar","Renomear","Excluir"]:
        game.button(customize,op+" perfil",manage_muscles.bind(op))
    muscle_message=game.show_message(customize,"")
    game.button(customize,"Restaurar perfil Natural",func():game.apply_preset(1))
    var tuning:=VBoxContainer.new()
    game.button(customize,"Configurações articulares",func():tuning.visible=not tuning.visible)
    customize.add_child(tuning)
    tuning.hide()
    game.preset_menu=game.dropdown(tuning,game.Muscle.PRESETS,game.apply_preset)
    game.preset_menu.select(1)
    game.dropdown(tuning,game.Muscle.GROUPS,func(i):game.editor_group=i;game.sync_controls())
    for i in game.Muscle.FIELDS.size():
        game.labels.append(game.show_message(tuning,game.NAMES[i]))
        var slider:=HSlider.new()
        slider.min_value=game.Muscle.RANGES[i][0]
        slider.max_value=game.Muscle.RANGES[i][1]
        slider.step=.05 if i in [1,4,5] else 1.
        slider.custom_minimum_size.y=44
        tuning.add_child(slider)
        game.controls.append(slider)
        slider.value_changed.connect(game.edit_value.bind(i))
    game.sync_controls()
    var view:=section("Visualização")
    for entry in [["bone","Esqueleto físico"],["com","Centro de massa"],["ik","Pontos de apoio"],["limit","Limites"]]:
        var key:String=entry[0]
        game.checkbox(view,entry[1],false,func(v):game.draw[key]=v)
    game.checkbox(view,"Esqueleto de referência",false,func(v):game.draw_reference=v)
    game.checkbox(view,"Colisores",false,game.visualization.show_colliders)
    game.checkbox(view,"Forças",false,func(v):game.display_forces=v)
    game.checkbox(view,"Torques",false,func(v):game.display_torque=v)
    game.checkbox(view,"Desempenho e estabilidade",false,func(v):game.performance_visible=v)
    game.readout=game.show_message(view,"")
    game.readout.hide()
    var options:=section("Preferências")
    minimal_toggle=CheckButton.new()
    minimal_toggle.text="Interface mínima"
    minimal_toggle.custom_minimum_size.y=44
    options.add_child(minimal_toggle)
    minimal_toggle.toggled.connect(set_minimal)
    game.button(options,"Ocultar controles",func():dock.hide();panel.hide();camera_panel.hide();restore_button.show())
    game.button(options,"Alisar vestuário",game.interaction_mode.reset)
    var dev:=VBoxContainer.new()
    game.checkbox(options,"Mostrar ferramentas de desenvolvimento",false,func(v):dev.visible=v)
    options.add_child(dev)
    dev.hide()
    for item in [["Active Ragdoll","res://rig/active/lab.tscn"],["Full Body Rig","res://rig/full_body_lab.tscn"],["Articulações","res://direct/articulation_lab.tscn"],["Equilíbrio","res://rig/balance_lab.tscn"],["Controles anteriores","res://direct_touch.tscn"]]:
        var path:String=item[1]
        game.button(dev,item[0],func():game.get_tree().change_scene_to_file(path))
    panel.hide()

func layout()->void:
    if not is_instance_valid(hud):return
    var size_:Vector2=game.get_viewport().get_visible_rect().size
    panel.size=Vector2(280,maxf(180,size_.y-150))
    camera_panel.position=Vector2(size_.x-200,12)
    camera_panel.size.x=188
    status.position=Vector2(12,size_.y-56)
    status.size=Vector2(size_.x-24,48)
    restore_button.position=Vector2(12,12)

func set_minimal(value:bool)->void:
    minimal=value
    if minimal_toggle!=null:minimal_toggle.set_pressed_no_signal(value)
    panel.hide()
    status.visible=not value
    game.preferences.set_value("ui","minimal",value)
    game.preferences.save("user://gameplay_ui.cfg")

func refresh_actions()->void:
    if action_widgets.is_empty():return
    var a:Dictionary=game.composer.actions[chosen_action]
    for key in ["enabled","paused","repeat"]:action_widgets[key].set_pressed_no_signal(a[key])
    for key in ["intensity","amplitude","speed"]:
        action_widgets[key].set_value_no_signal(a[key])
        action_widgets[key+"_label"].text="%s · %.2f%s"%[{"intensity":"Intensidade","amplitude":"Amplitude","speed":"Ritmo"}[key],a[key],"x" if key=="speed" else ""]
    refresh_action_reason()

func refresh_action_reason()->void:
    if action_message!=null:action_message.text=game.Library.ACTIONS[chosen_action].category+"\n"+game.composer.reason(chosen_action)

func refresh_customizations()->void:
    muscle_menu.clear()
    muscle_menu.add_item("Perfis musculares")
    for title in game.customizations.profiles:muscle_menu.add_item(title)
    pose_management.clear()
    pose_management.add_item("Posturas salvas")
    for title in game.pose_library.entries:pose_management.add_item(title)

func manage_muscles(op:String)->void:
    var title:=muscle_menu.get_item_text(muscle_menu.selected)
    var result:=OK
    match op:
        "Salvar":result=game.customizations.save_profile(muscle_name.text,game.muscles)
        "Carregar":
            if not game.customizations.profiles.has(title):result=ERR_DOES_NOT_EXIST
            else:
                for field in game.Muscle.FIELDS:game.muscles.set(field,game.customizations.profiles[title][field].duplicate())
                game.custom=game.muscles.duplicate(true)
                game.preset_menu.select(3)
                game.core.settings=game.muscles
                game.pose_reference.muscles=game.muscles
                game.pose_editor.refresh()
                game.refresh_limits()
                game.sync_controls()
        "Duplicar","Renomear":result=game.customizations.rename(title,muscle_name.text,op=="Duplicar")
        "Excluir":result=game.customizations.remove(title)
    muscle_message.text="Concluído" if result==OK else "Falha · "+error_string(result)
    refresh_customizations()

func manage_pose(op:String)->void:
    var title:=pose_management.get_item_text(pose_management.selected)
    if game.pose_library_error!=OK:
        pose_message.text=error_string(game.pose_library_error)
        return
    if not game.pose_library.entries.has(title):
        pose_message.text="Selecione uma postura."
        return
    var candidate:Dictionary=game.pose_library.entries.duplicate(true)
    var new_name:=pose_name.text.strip_edges()
    if op!="Excluir":
        if new_name.is_empty() or candidate.has(new_name):
            pose_message.text="Use um nome novo."
            return
        candidate[new_name]=candidate[title].duplicate(true)
    if op!="Duplicar":candidate.erase(title)
    var result:int=game.pose_library.replace_entries(candidate)
    pose_message.text="Concluído" if result==OK else "Falha · "+error_string(result)
    if result==OK and game.pose_title==title:
        if op=="Renomear":game.pose_title=new_name
        elif op=="Excluir":game.pose_title="Postura editada"
    game.pose_editor.update_saved()
    refresh_customizations()

func sync_camera()->void:
    for key in camera_sliders:
        var widgets:Dictionary=camera_sliders[key]
        widgets.slider.set_value_no_signal(game.framing.get(key))
        widgets.label.text="%s · %.2f"%[widgets.title,game.framing.get(key)]

func build_cloth_controls()->void:
    cloth_readout=game.show_message(sections["Visualização"],"")
    cloth_readout.hide()
    var panel_:=VBoxContainer.new()
    var parent:VBoxContainer=sections["Personalizações"]
    game.button(parent,"Tecidos",func():panel_.visible=not panel_.visible)
    parent.add_child(panel_);panel_.hide()
    game.checkbox(panel_,"Simular pano independente",game.cloth.accessory_enabled,func(value):
        game.cloth.set_accessory_enabled(value)
        game.save_preferences())
    var sliders_:Dictionary={}
    var labels_:Dictionary={}
    var menu:OptionButton=game.dropdown(panel_,game.cloth.Profile.NAMES,func(index):
        if index<4:game.cloth.set_profile(game.cloth.Profile.preset(index))
        else:game.cloth.load_custom();game.cloth.set_profile(game.cloth.material)
        for key in sliders_:
            sliders_[key].set_value_no_signal(game.cloth.material.get(key))
            labels_[key].text="%s · %.6f"%[game.cloth.Profile.FIELDS[key][0],game.cloth.material.get(key)])
    menu.select(game.cloth.preset_index)
    for field in game.cloth.Profile.FIELDS:
        var bounds:Array=game.cloth.Profile.FIELDS[field]
        var label:Label=game.show_message(panel_,"%s · %.6f"%[bounds[0],game.cloth.material.get(field)])
        var slider:=HSlider.new();slider.min_value=bounds[1];slider.max_value=bounds[2];slider.step=bounds[3];slider.value=game.cloth.material.get(field);slider.custom_minimum_size.y=38
        panel_.add_child(slider);sliders_[field]=slider;labels_[field]=label
        slider.value_changed.connect(func(value):game.cloth.material.set(field,value);game.cloth.set_profile(game.cloth.material);menu.select(4);label.text="%s · %.6f"%[bounds[0],value])
    var quality:OptionButton=game.dropdown(panel_,["Econômico","Equilibrado","Detalhado"],game.cloth.set_quality)
    quality.select(game.cloth.quality)
    var message:Label=game.show_message(panel_,"Vestuário: toque no pano ao lado ou na roupa.")
    game.button(panel_,"Salvar tecido personalizado",func():
        var error:int=game.cloth.save_custom()
        message.text="Tecido salvo" if error==OK else error_string(error))
    game.button(panel_,"Restaurar tecido Natural",func():game.cloth.set_profile(game.cloth.Profile.preset(1));menu.item_selected.emit(1);menu.select(1))
