extends RefCounted

const Pose=preload("res://rig/active/pose_reference.gd")
const DEFAULT_PATH:="user://active_ragdoll_poses.cfg"
const MAX_POSES:=48
const MAX_NAME:=32
const FORMAT:=1
var entries:Dictionary={}
var path:String

func _init(storage_path:String=DEFAULT_PATH)->void:
    path=storage_path

func valid_pose(pose:Variant)->bool:
    if not pose is Dictionary or not pose.get("angles") is Dictionary:return false
    if not pose.get("travel") is Vector3 or not pose.get("seat") is bool:return false
    if not pose.travel.is_finite() or pose.travel!=pose.travel.clamp(Pose.TRAVEL_MIN,Pose.TRAVEL_MAX):return false
    for role in Pose.ROLES:
        var angle=pose.angles.get(role)
        if not angle is Vector3 or not angle.is_finite():return false
        if angle.abs()!=angle.abs().min(Vector3.ONE*180.):return false
    return true

func load_all()->Error:
    if not FileAccess.file_exists(path):return OK
    var cfg:=ConfigFile.new()
    var result:=cfg.load(path)
    if result!=OK:return result
    if cfg.get_value("library","version",0)!=FORMAT:return ERR_FILE_UNRECOGNIZED
    var loaded=cfg.get_value("library","poses",{})
    if not loaded is Dictionary or loaded.size()>MAX_POSES:return ERR_FILE_CORRUPT
    for title in loaded:
        if not title is String or title.is_empty() or title.length()>MAX_NAME or not valid_pose(loaded[title]):
            return ERR_FILE_CORRUPT
    entries=loaded
    return OK

func save_pose(title:String,pose:Dictionary)->Error:
    title=title.strip_edges()
    if title.is_empty() or title.length()>MAX_NAME or not valid_pose(pose):return ERR_INVALID_DATA
    if not entries.has(title) and entries.size()>=MAX_POSES:return ERR_OUT_OF_MEMORY
    var candidate:=entries.duplicate()
    candidate[title]=pose.duplicate(true)
    var cfg:=ConfigFile.new()
    cfg.set_value("library","version",FORMAT)
    cfg.set_value("library","poses",candidate)
    var temp:=path+".tmp"
    var result:=cfg.save(temp)
    if result==OK:result=DirAccess.rename_absolute(temp,path)
    if result==OK:entries=candidate
    return result


func replace_entries(candidate:Dictionary)->Error:
    if candidate.size()>MAX_POSES:return ERR_OUT_OF_MEMORY
    for title in candidate:
        if not title is String or title.is_empty() or title.length()>MAX_NAME or not valid_pose(candidate[title]):return ERR_INVALID_DATA
    var cfg:=ConfigFile.new()
    cfg.set_value("library","version",FORMAT)
    cfg.set_value("library","poses",candidate)
    var result:=cfg.save(path+".tmp")
    if result==OK:result=DirAccess.rename_absolute(path+".tmp",path)
    if result==OK:entries=candidate
    return result
