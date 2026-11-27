extends RefCounted
## Os recursos editados pelo Inspector são os padrões. O jogo salva cópias
## editadas em user://, um grupo para cada recurso de tecido.
const PATH="user://rose_fabrics_129.cfg"
const Profile=preload("res://direct/fabric_profile.gd")

var variants:Array[RoseFabricProfile]=[]
var defaults:Array[RoseFabricProfile]
var active:=0
var storage:String

func _init(presets:Array[RoseFabricProfile],local_path:=PATH)->void:
 storage=local_path
 defaults=presets.duplicate()
 var file:=ConfigFile.new()
 file.load(storage)
 for i in presets.size():
  var profile:RoseFabricProfile=presets[i].duplicate()
  for key in Profile.PARAMETERS:
   var limits:Array=Profile.PARAMETERS[key]
   var value:Variant=file.get_value("tecido_%d"%i,key,profile.get(key))
   if value is float or value is int:profile.set(key,clampf(float(value),limits[1],limits[2]))
  variants.append(profile)
 var selected:Variant=file.get_value("selecao","ativo",0)
 if selected is int:active=clampi(selected,0,maxi(0,variants.size()-1))

func save()->Error:
 var file:=ConfigFile.new()
 file.set_value("selecao","ativo",active)
 for i in variants.size():
  for key in Profile.PARAMETERS:file.set_value("tecido_%d"%i,key,variants[i].get(key))
 return file.save(storage)

func panel(parent:Control,changed:Callable)->PopupPanel:
 var popup:=PopupPanel.new()
 parent.add_child(popup)
 var scroll:=ScrollContainer.new()
 popup.add_child(scroll)
 var rows:=VBoxContainer.new()
 rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.add_child(rows)
 var choice:=OptionButton.new()
 choice.custom_minimum_size.y=46
 rows.add_child(choice)
 for profile in variants:choice.add_item(profile.label)
 var sliders:Dictionary={}
 var labels:Dictionary={}
 var refresh:=func():
  choice.select(active)
  for field in sliders:
   var value:float=variants[active].get(field)
   sliders[field].set_value_no_signal(value)
   labels[field].text="%s · %.3f"%[Profile.PARAMETERS[field][0],value]
 for key in Profile.PARAMETERS:
  var range_:Array=Profile.PARAMETERS[key]
  var label:=Label.new()
  rows.add_child(label)
  labels[key]=label
  var slider:=HSlider.new()
  slider.min_value=range_[1]
  slider.max_value=range_[2]
  slider.step=range_[3]
  slider.custom_minimum_size=Vector2(235,34)
  rows.add_child(slider)
  sliders[key]=slider
  slider.value_changed.connect(func(v:float):
   variants[active].set(key,v)
   label.text="%s · %.3f"%[range_[0],v]
   changed.call(variants[active]))
 choice.item_selected.connect(func(index:int):
  active=index
  changed.call(variants[active])
  refresh.call())
 popup.about_to_popup.connect(refresh)
 var save_button:=Button.new()
 save_button.text="Salvar tecidos"
 save_button.custom_minimum_size.y=46
 rows.add_child(save_button)
 save_button.pressed.connect(func():save_button.text="Tecidos salvos" if save()==OK else "Falha ao salvar")
 var reset:=Button.new()
 reset.text="Restaurar valores do Inspector"
 reset.custom_minimum_size.y=46
 rows.add_child(reset)
 reset.pressed.connect(func():
  variants[active]=defaults[active].duplicate()
  changed.call(variants[active])
  refresh.call())
 var close:=Button.new()
 close.text="Fechar"
 close.custom_minimum_size.y=46
 rows.add_child(close)
 close.pressed.connect(popup.hide)
 refresh.call()
 return popup
