extends RefCounted

signal profile_changed

const PATH="user://rose_physics_126.cfg"
const LEGACY_PATH="user://rose_touch_122.cfg"
const PROFILES=["Leve","Natural","Resistente","Personalizada"]
const SPECS={
 "Pressão longa (s)":[.16,.95,.01,.36],
 "Sensibilidade":[.4,2.,.05,1.],
 "Tolerância (px)":[0,10,1,3],
 "Precisão do gesto (px)":[2,28,1,12],
 "Rigidez":[12,100,1,58],
 "Elasticidade":[.25,1.8,.05,1.],
 "Massa (kg)":[.2,5.,.05,.50],
 "Atrito":[0.,12.,.1,2.1],
 "Amortecimento":[.5,1.8,.05,.80],
 "Força máxima":[.15,1.,.05,.85],
 "Recuperação":[.25,2.,.05,1.15],
 "Suavização":[5,35,1,24]}
const PHYSICS_KEYS=["Rigidez","Elasticidade","Massa (kg)","Atrito","Amortecimento","Força máxima","Recuperação","Suavização","Sensibilidade"]
const PRESETS={
 "Leve":[64.,1.10,.25,1.4,.72,.80,1.35,29.,1.12],
 "Natural":[58.,1.,.50,2.1,.80,.85,1.15,24.,1.],
 "Resistente":[61.,.80,1.45,3.4,.95,.95,.88,19.,.82],
}
var values:Dictionary={}
var saved_profiles:Dictionary={}
var active_profile:="Natural"
var indicators:=true
var revision:=0

func _init(path:=PATH,legacy:=LEGACY_PATH)->void:
 storage=path
 var file:=ConfigFile.new()
 var loaded:=file.load(storage)==OK
 if not loaded and not legacy.is_empty():file.load(legacy)
 for key in SPECS:
  values[key]=configured_value(key,file.get_value("gestos",key,SPECS[key][3]))
 indicators=file.get_value("visual","indicadores",true)
 for name_ in PROFILES:
  var defaults:=preset(name_)
  for key in PHYSICS_KEYS:
   var fallback:float=values[key] if name_=="Personalizada" and not loaded else defaults[key]
   defaults[key]=configured_value(key,file.get_value(name_,key,fallback))
  saved_profiles[name_]=defaults
 select_profile(str(file.get_value("perfis","ativo","Natural")) if loaded else "Natural")

var storage:String

static func configured_value(key:String,value:Variant)->float:
 return clampf(float(value),SPECS[key][0],SPECS[key][1])

static func preset(name_:String)->Dictionary:
 var result:Dictionary={}
 var defaults:Array=PRESETS.get(name_,PRESETS.Natural)
 for key in SPECS:result[key]=SPECS[key][3]
 for i in PHYSICS_KEYS.size():result[PHYSICS_KEYS[i]]=defaults[i]
 return result

func select_profile(name_:String)->void:
 if not saved_profiles.has(name_):name_="Natural"
 active_profile=name_
 for key in PHYSICS_KEYS:values[key]=saved_profiles[name_][key]
 revision+=1
 profile_changed.emit()

func set_value(key:String,value:float)->void:
 values[key]=configured_value(key,value)
 if key in PHYSICS_KEYS:saved_profiles[active_profile][key]=values[key]
 revision+=1

func save()->Error:
 var file:=ConfigFile.new()
 for key in SPECS:
  if key not in PHYSICS_KEYS:file.set_value("gestos",key,values[key])
 for name_ in PROFILES:
  for key in PHYSICS_KEYS:file.set_value(name_,key,saved_profiles[name_][key])
 file.set_value("perfis","ativo",active_profile)
 file.set_value("visual","indicadores",indicators)
 return file.save(storage)

func panel(parent:Control)->PopupPanel:
 var popup:=PopupPanel.new()
 parent.add_child(popup)
 var scroll:=ScrollContainer.new()
 popup.add_child(scroll)
 var rows:=VBoxContainer.new()
 scroll.add_child(rows)
 rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var profile_title:=Label.new()
 profile_title.text="Perfil físico"
 rows.add_child(profile_title)
 var profiles:=OptionButton.new()
 profiles.custom_minimum_size.y=42
 rows.add_child(profiles)
 for name_ in PROFILES:profiles.add_item(name_)
 var sliders:Dictionary={}
 var labels:Dictionary={}
 var refresh:=func():
  profiles.select(PROFILES.find(active_profile))
  for key in sliders:
   sliders[key].set_value_no_signal(values[key])
   labels[key].text="%s  %.2f"%[key,values[key]]
 profiles.item_selected.connect(func(index):
  select_profile(PROFILES[index])
  refresh.call())
 popup.about_to_popup.connect(refresh)
 for key in SPECS:
  var label:=Label.new()
  rows.add_child(label)
  var slider:=HSlider.new()
  rows.add_child(slider)
  slider.custom_minimum_size=Vector2(230,32)
  slider.min_value=SPECS[key][0]
  slider.max_value=SPECS[key][1]
  slider.step=SPECS[key][2]
  sliders[key]=slider
  labels[key]=label
  slider.value_changed.connect(func(v):
   set_value(key,v)
   label.text="%s  %.2f"%[key,values[key]])
 refresh.call()
 var show:=CheckButton.new()
 rows.add_child(show)
 show.text="Indicadores de contato"
 show.button_pressed=indicators
 show.toggled.connect(func(v):indicators=v)
 var save_btn:=Button.new()
 rows.add_child(save_btn)
 save_btn.text="Salvar perfis"
 save_btn.custom_minimum_size.y=42
 save_btn.pressed.connect(func():save_btn.text="Perfis salvos" if save()==OK else "Falha ao salvar")
 var close:=Button.new()
 rows.add_child(close)
 close.text="Fechar"
 close.custom_minimum_size.y=42
 close.pressed.connect(popup.hide)
 return popup
