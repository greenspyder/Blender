extends VBoxContainer
## Controles da bancada. A captura e a simulação pertencem à cena.
const Pose=preload("res://rig/active/pose_reference.gd")
const PoseLibrary=preload("res://rig/active/pose_library.gd")

var lab
var joint_menu:OptionButton
var saved_menu:OptionButton
var title_edit:LineEdit
var message:Label
var seat_check:CheckButton
var labels:Array[Label]=[]
var sliders:Array[HSlider]=[]
var travel_labels:Array[Label]=[]
var travel_sliders:Array[HSlider]=[]
var role:="pelvis"

func build(active_lab)->void:
    lab=active_lab
    lab.button(self,"Capturar postura do corpo",func():lab.capture_custom_pose(true))
    lab.button(self,"Copiar referência visível",func():lab.capture_custom_pose(false))
    lab.checkbox(self,"Capturar ao soltar",false,func(value):lab.capture_on_release=value)
    joint_menu=lab.dropdown(self,Pose.ROLES.values(),func(index):
        role=Pose.ROLES.keys()[index]
        refresh())
    for axis in 3:
        labels.append(lab.show_message(self,""))
        sliders.append(make_slider(func(value):lab.edit_joint(role,axis,value)))
    lab.show_message(self,"Deslocamento da pelve")
    for axis in 3:
        travel_labels.append(lab.show_message(self,""))
        var slider:=make_slider(func(value):lab.edit_pelvis(axis,value))
        slider.min_value=Pose.TRAVEL_MIN[axis]
        slider.max_value=Pose.TRAVEL_MAX[axis]
        slider.step=.01
        travel_sliders.append(slider)
    seat_check=CheckButton.new()
    seat_check.text="Banco como apoio"
    seat_check.custom_minimum_size.y=40.
    add_child(seat_check)
    seat_check.toggled.connect(lab.edit_seat)
    lab.parameter(self,"Transição (s)",.15,3.,.05,lab.transition_seconds,func(value):lab.transition_seconds=value)
    saved_menu=lab.dropdown(self,["Carregar postura salva"],load_selected)
    title_edit=LineEdit.new()
    title_edit.placeholder_text="Nome da postura"
    title_edit.max_length=PoseLibrary.MAX_NAME
    title_edit.custom_minimum_size.y=42.
    add_child(title_edit)
    lab.button(self,"Salvar postura",save_current)
    lab.button(self,"Restaurar postura automática",lab.restore_original)
    message=lab.show_message(self,"")

func make_slider(change:Callable)->HSlider:
    var slider:=HSlider.new()
    slider.custom_minimum_size.y=38.
    slider.step=1.
    add_child(slider)
    slider.value_changed.connect(change)
    return slider

func refresh()->void:
    if lab.pose_draft.is_empty():return
    var angles:Vector3=lab.pose_reference.clamp_angles(role,lab.pose_draft.angles[role])
    var bounds:Array=lab.pose_reference.limits(role)
    for axis in 3:
        var lower:float=bounds[0][axis]
        var upper:float=bounds[1][axis]
        sliders[axis].visible=upper>lower
        labels[axis].visible=upper>lower
        sliders[axis].set_block_signals(true)
        sliders[axis].min_value=lower
        sliders[axis].max_value=upper
        sliders[axis].set_value_no_signal(angles[axis])
        sliders[axis].set_block_signals(false)
        labels[axis].text="%s · %.0f°"%["XYZ"[axis],angles[axis]]
        travel_sliders[axis].set_value_no_signal(lab.pose_draft.travel[axis])
        travel_labels[axis].text="%s · %.0f cm"%[["Lateral","Altura","Frente"][axis],lab.pose_draft.travel[axis]*lab.pose_reference.leg_length*100.]
    seat_check.set_pressed_no_signal(lab.pose_draft.seat)

func update_saved()->void:
    saved_menu.clear()
    saved_menu.add_item("Carregar postura salva")
    var names:Array=lab.pose_library.entries.keys()
    names.sort()
    for saved_name in names:saved_menu.add_item(saved_name)
    saved_menu.select(0)

func save_current()->void:
    var title:=title_edit.text.strip_edges()
    if title.is_empty():
        message.text="Digite um nome para salvar."
        return
    var result:int=lab.save_pose(title)
    message.text="Postura salva." if result==OK else "Falha ao salvar · "+error_string(result)
    if result==OK:update_saved()

func load_selected(index:int)->void:
    if index<=0:return
    var title:=saved_menu.get_item_text(index)
    lab.load_pose(title)
    title_edit.text=title
    message.text="Postura carregada."
    saved_menu.select(0)
