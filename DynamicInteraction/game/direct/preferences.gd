extends RefCounted
const PATH="user://rose_touch_122.cfg"
const SPECS={
 "Pressão longa (s)":[.16,.95,.01,.36],
 "Sensibilidade":[.4,2.,.05,1.],
 "Tolerância (px)":[0,10,1,3],
 "Precisão do gesto (px)":[2,28,1,12],
 "Rigidez":[12,100,1,52],
 "Elasticidade":[.25,1.8,.05,1.],
 "Amortecimento":[.5,1.8,.05,.9],
 "Força máxima":[.15,1.,.05,.85],
 "Recuperação":[.25,2.,.05,1.],
 "Suavização":[5,35,1,18]}
var values:Dictionary={}
var indicators:=true
func _init():
 var file:=ConfigFile.new()
 file.load(PATH)
 for key in SPECS:
  var s:Array=SPECS[key]
  values[key]=clampf(float(file.get_value("gestos",key,s[3])),s[0],s[1])
 indicators=file.get_value("visual","indicadores",true)
func save()->Error:
 var file:=ConfigFile.new()
 for key in values:file.set_value("gestos",key,values[key])
 file.set_value("visual","indicadores",indicators)
 return file.save(PATH)
func panel(parent:Control)->PopupPanel:
 var popup:=PopupPanel.new()
 parent.add_child(popup)
 var scroll:=ScrollContainer.new();popup.add_child(scroll)
 var rows:=VBoxContainer.new();scroll.add_child(rows);rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for key in SPECS:
  var label:=Label.new();rows.add_child(label)
  var bar:=HSlider.new();rows.add_child(bar);bar.custom_minimum_size=Vector2(230,30)
  var spec:Array=SPECS[key];bar.min_value=spec[0];bar.max_value=spec[1];bar.step=spec[2];bar.value=values[key]
  popup.about_to_popup.connect(func():bar.value=values[key])
  label.text="%s  %.2f"%[key,bar.value]
  bar.value_changed.connect(func(v):values[key]=v;label.text="%s  %.2f"%[key,v])
 var show:=CheckButton.new();rows.add_child(show);show.text="Indicadores de contato";show.button_pressed=indicators
 show.toggled.connect(func(v):indicators=v)
 var save_btn:=Button.new();rows.add_child(save_btn);save_btn.text="Salvar perfil"
 save_btn.pressed.connect(func():save_btn.text="Perfil salvo" if save()==OK else "Falha ao salvar")
 var close:=Button.new();rows.add_child(close);close.text="Fechar";close.pressed.connect(popup.hide)
 return popup
