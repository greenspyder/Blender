extends Resource
const NAMES=["Leve","Natural","Elástico","Rígido","Personalizado"]
const FIELDS={"density":["Massa (g/m²)",45.,420.,1.],"stretch":["Complacência estrutural",.000001,.002,.000001],"bend":["Complacência à dobra",.0001,.2,.0001],"damping":["Amortecimento (/s)",.6,12.,.1],"friction":["Atrito",0.,.95,.01],"strain_limit":["Extensão máxima",.03,.45,.01]}
@export_range(45,420) var density:=150.
@export var stretch:=.00002
@export var bend:=.025
@export_range(.6,12) var damping:=4.
@export_range(0,.95) var friction:=.5
@export_range(.03,.45) var strain_limit:=.12
@export var thickness:=.004
@export var grab_force:=8.
func valid()->bool:
    for field in FIELDS:
        var v:float=get(field)
        if not is_finite(v) or v<FIELDS[field][1] or v>FIELDS[field][2]:return false
    return thickness>0. and thickness<.03 and grab_force>0. and grab_force<=30.
static func preset(index:int)->Resource:
    var p=load("res://cloth/material_profile.gd").new()
    match index:
        0:p.density=70.;p.bend=.09;p.damping=2.5
        2:p.stretch=.0008;p.strain_limit=.35;p.bend=.05
        3:p.stretch=.000002;p.bend=.0005;p.strain_limit=.05
    return p
