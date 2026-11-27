extends RefCounted
const Muscle=preload("res://rig/active/muscle_profile.gd")
var profiles:Dictionary={}
var path:="user://gameplay_muscles.cfg"
var error:=OK
func load_all()->void:
    if not FileAccess.file_exists(path):return
    var cfg:=ConfigFile.new()
    error=cfg.load(path)
    if error!=OK:return
    var data=cfg.get_value("profiles","items",{})
    if not data is Dictionary:
        error=ERR_FILE_CORRUPT
        return
    for title in data:
        if not title is String or not valid(data[title]):
            error=ERR_FILE_CORRUPT
            return
    profiles=data
func valid(data:Variant)->bool:
    if not data is Dictionary:return false
    var m:=Muscle.new()
    for field in Muscle.FIELDS:
        if not data.get(field) is PackedFloat32Array:return false
        m.set(field,data[field])
    return m.valid()
func persist(candidate:Dictionary)->Error:
    if error!=OK:return error
    var cfg:=ConfigFile.new()
    cfg.set_value("profiles","items",candidate)
    var result:=cfg.save(path+".tmp")
    if result==OK:result=DirAccess.rename_absolute(path+".tmp",path)
    if result==OK:profiles=candidate
    return result
func save_profile(title:String,muscles:Resource)->Error:
    title=title.strip_edges()
    if title.is_empty() or title.length()>32:return ERR_INVALID_DATA
    var data:Dictionary={}
    for field in Muscle.FIELDS:data[field]=muscles.get(field).duplicate()
    if not valid(data):return ERR_INVALID_DATA
    var candidate:=profiles.duplicate(true)
    candidate[title]=data
    return persist(candidate)
func rename(old:String,new_name:String,duplicate_:bool)->Error:
    new_name=new_name.strip_edges()
    if not profiles.has(old) or new_name.is_empty() or new_name.length()>32 or profiles.has(new_name):return ERR_INVALID_DATA
    var candidate:=profiles.duplicate(true)
    candidate[new_name]=candidate[old].duplicate(true)
    if not duplicate_:candidate.erase(old)
    return persist(candidate)
func remove(title:String)->Error:
    var candidate:=profiles.duplicate(true)
    candidate.erase(title)
    return persist(candidate)
