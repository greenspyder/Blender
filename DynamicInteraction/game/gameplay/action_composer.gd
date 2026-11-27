extends RefCounted
const Library=preload("res://gameplay/action_library.gd")
var base:=0
var actions:Dictionary={}
var blocked_reason:=""
func _init()->void:
    for key in Library.ACTIONS:
        actions[key]={"enabled":false,"paused":false,"repeat":true,"speed":1.,"intensity":1.,"amplitude":1.,"phase":0.,"weight":0.}
func select_base(index:int)->void:
    base=index
    for key in actions:
        if index in Library.ACTIONS[key].blocked:actions[key].enabled=false
func enable(key:String,value:bool)->bool:
    if value and base in Library.ACTIONS[key].blocked:
        blocked_reason="Esta ação exige uma postura sem caminhada."
        return false
    if value and actions[key].phase>=TAU:actions[key].phase=0.
    actions[key].enabled=value
    blocked_reason=""
    return true
func advance(dt:float)->void:
    for key in actions:
        var a:Dictionary=actions[key]
        a.weight=move_toward(a.weight,1. if a.enabled else 0.,dt*3.)
        if a.enabled and not a.paused:
            a.phase+=dt*a.speed*TAU*.35
            if a.phase>=TAU:
                if a.repeat:a.phase=fmod(a.phase,TAU)
                else:
                    a.phase=TAU
                    a.enabled=false
func value(key:String)->float:
    var a:Dictionary=actions[key]
    return sin(a.phase)*a.weight*a.intensity*a.amplitude
func active_text()->String:
    var names:=PackedStringArray()
    for key in actions:
        if actions[key].enabled:
            names.append(Library.ACTIONS[key].name+(" · pausada" if actions[key].paused else ""))
    return " · ".join(names)
# Camadas aditivas por papel semântico; nunca escrevem no esqueleto físico.
func offsets()->Dictionary:
    var candidates:={
        "flex":{"pelvis":Vector3(0.,-absf(value("flex"))*(.045 if base==1 else .09),0.),"lumbar":Vector3(value("flex")*7.,0.,0.)},
        "sway":{"pelvis":Vector3(value("sway")*.035,0.,0.),"chest":Vector3(0.,0.,value("sway")*5.)},
        "head":{"head":Vector3(0.,value("head")*24.,0.)},
        "arms":{"upper_l":Vector3(absf(value("arms"))*25.,0.,0.),"upper_r":Vector3(absf(value("arms"))*25.,0.,0.)}}
    var result:Dictionary={}
    for key in Library.ACTIONS:
        for role in Library.ACTIONS[key].mask:
            if candidates[key].has(role):result[role]=result.get(role,Vector3.ZERO)+candidates[key][role]
    return result

func apply(request:Dictionary,length_:float)->void:
    var additions:=offsets()
    request.travel+=Vector3(additions.pelvis)*length_
    for role in ["lumbar","chest"]:request[role]+=Vector3(additions[role])
    request.head=additions.head
    for side in ["l","r"]:
        request["arm_"+side]+=Vector3(additions["upper_"+side])*1.92
