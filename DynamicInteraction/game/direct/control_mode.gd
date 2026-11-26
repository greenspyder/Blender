extends RefCounted

enum Mode { AUTO, DESKTOP, TOUCHSCREEN }
const PROFILE="user://rose_controls.cfg"
const MOUSE_TOUCH_ID:=1024
const MOUSE_GRIP_ID:=-10

var choice:=Mode.AUTO
var storage:String

func _init(path:=PROFILE)->void:
 storage=path
 var data:=ConfigFile.new()
 if data.load(storage)==OK:
  var stored:Variant=data.get_value("controles","modo",Mode.AUTO)
  if stored is int and stored in [Mode.AUTO,Mode.DESKTOP,Mode.TOUCHSCREEN]:choice=stored

static func touchscreen(selected:int,on_mobile:bool)->bool:
 return selected==Mode.TOUCHSCREEN or (selected==Mode.AUTO and on_mobile)

func save()->Error:
 var data:=ConfigFile.new()
 data.set_value("controles","modo",choice)
 return data.save(storage)
