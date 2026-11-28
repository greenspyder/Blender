extends RefCounted
const GroundMotion=preload("res://rig/balance_lab.gd")
const Library=preload("res://gameplay/action_library.gd")
var base:=0
var actions:Dictionary={}
var blocked_reason:=""
var context:Dictionary={"feet":2,"seat":false,"authority":1.,"upright":1.,"outside":0.,"down":.29,"up":.16,"free":false}
var order:Array
var squat_travel:=Vector3.DOWN*.29
var lateral_share:=1.

func _init()->void:
    order=Library.ACTIONS.keys()
    order.sort_custom(func(a,b):return Library.ACTIONS[a].priority>Library.ACTIONS[b].priority)
    for key in order:
        actions[key]={"enabled":false,"paused":false,"repeat":true,"speed":1.,"intensity":1.,"amplitude":1.,"phase":0.,"weight":0.}

func select_base(index:int)->void:
    base=clampi(index,0,Library.BASES.size()-1)

func reason(key:String)->String:
    if not actions.has(key):return "Ação desconhecida."
    if context.free:return "Referência livre. Selecione controle automático ou personalizado."
    if context.authority<.025:return "Os músculos não sustentam a referência neste estado."
    if Library.ACTIONS[key].requires=="muscle":return ""
    if context.feet==0 and not context.seat:return "Nenhum pé ou assento sustenta o corpo."
    if context.upright<.40:return "O tronco precisa recuperar a orientação vertical."
    if context.outside>.28:return "Centro de massa fora da área de apoio."
    if key=="squat" and (context.up if context.seat else context.down)<.012:return "Sem curso livre para a pelve dentro dos limites articulares."
    return ""

func enable(key:String,value:bool)->bool:
    blocked_reason=reason(key) if value else ""
    if not actions.has(key) or not blocked_reason.is_empty():return false
    if value and actions[key].phase>=TAU:actions[key].phase=0.
    actions[key].enabled=value
    return true

func set_parameter(key:String,field:String,value:Variant)->bool:
    if not actions.has(key):return false
    if field in ["repeat","paused"] and value is bool:
        actions[key][field]=value
        return true
    if not Library.PARAMETERS.has(field) or not (value is float or value is int) or not is_finite(float(value)):return false
    var bounds:Vector2=Library.PARAMETERS[field]
    actions[key][field]=clampf(value,bounds.x,bounds.y)
    return true

func advance(dt:float)->void:
    var support:=1. if context.feet==2 else (.46 if context.feet==1 else .25)
    var control:=clampf(context.authority,0.,1.)*(1.-smoothstep(.06,.28,context.outside))
    var travel:=Vector3.DOWN*minf(.29,context.down)
    if context.seat:
        var lift:=minf(.15,context.up)
        travel=Vector3(0.,lift,lift*.34)
    squat_travel=squat_travel.move_toward(travel*support*control,dt*.95)
    lateral_share=move_toward(lateral_share,support*control,dt*3.)
    for key in order:
        var a:Dictionary=actions[key]
        var running:bool=a.enabled and reason(key).is_empty()
        a.weight=move_toward(a.weight,1. if running else 0.,dt*3.)
        if running and not a.paused:
            a.phase+=dt*a.speed*(2. if key=="squat" else TAU*.35)
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
    for key in order:
        if actions[key].enabled:names.append(Library.ACTIONS[key].name+(" · em espera" if not reason(key).is_empty() else (" · pausada" if actions[key].paused else "")))
    return " · ".join(names)

func offsets()->Dictionary:
    var result:Dictionary={}
    for key in order:
        var a:Dictionary=actions[key]
        if a.weight<=0.:continue
        var spec:Dictionary=Library.ACTIONS[key]
        var v:=value(key)
        var contributions:Dictionary={}
        match spec.strategy:
            "leg_travel":
                var cycle:float=GroundMotion.squat_depth(a.phase)/float(spec.limit)
                contributions.pelvis=squat_travel*cycle*float(a.weight)*float(a.intensity)*float(a.amplitude)
            "flexion":
                var used:Vector3=result.get("pelvis",Vector3.ZERO)
                var budget:=maxf(0.,float(context.down)+minf(0.,used.y))
                var amount:=minf(budget,absf(v)*float(spec.limit)*(.5 if context.seat else lateral_share))
                contributions={"pelvis":Vector3.DOWN*amount, "lumbar":Vector3.RIGHT*v*7.}
            "weight_shift":contributions={"pelvis":Vector3.RIGHT*v*float(spec.limit)*lateral_share,"chest":Vector3.BACK*v*5.*lateral_share}
            "shoulders":
                var lift:=Vector3.RIGHT*absf(v)*float(spec.limit)
                contributions={"upper_l":lift,"upper_r":lift}
            "look":contributions.head=Vector3.UP*v*float(spec.limit)
        for role in spec.mask:result[role]=Vector3(result.get(role,Vector3.ZERO))+Vector3(contributions[role])
    return result

func apply(request:Dictionary,length_:float)->void:
    var additions:=offsets()
    for role in additions:
        match role:
            "pelvis":request.travel+=Vector3(additions[role])*length_
            "upper_l","upper_r":request["arm_"+role.right(1)]+=Vector3(additions[role])*1.92
            _:request[role]+=Vector3(additions[role])

func snapshot()->Dictionary:
    var result:Dictionary={}
    for key in order:
        var item:Dictionary=actions[key].duplicate()
        item.merge(Library.ACTIONS[key].duplicate(true))
        item.reason=reason(key)
        item.available=item.reason.is_empty()
        item.suspended=item.enabled and not item.available
        result[key]=item
    return {"base":base,"actions":result,"parameters":Library.PARAMETERS.duplicate(),"supports":context.duplicate()}
