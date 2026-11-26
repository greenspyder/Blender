extends RefCounted
## Um ponto preso responde com mola, amortecimento e limite. A soma das
## forças ocorre antes da integração, inclusive com dois dedos opostos.
const STEP := 1.0/120.0

static func force_limit(values:Dictionary)->float:
 return 60.0*float(values["Força máxima"])

static func traction(target:Vector3,anchor:Vector3,velocity:Vector3,values:Dictionary)->Vector3:
 var extension:Vector3=(target-anchor)*float(values["Sensibilidade"])
 var span:=extension.length()
 # Mola progressiva. O primeiro trecho tem menor inclinação.
 var gain:=.67+.78*smoothstep(.025,.34,span)
 var stiffness:float=values["Rigidez"]*gain/values["Elasticidade"]
 var damping:=2.0*sqrt(stiffness*float(values["Massa (kg)"]))*float(values["Amortecimento"])
 return (extension*stiffness-velocity*damping).limit_length(force_limit(values))

static func body_stretch(drag:Vector3,values:Dictionary)->Vector3:
 var span:=drag.length()
 if span<.00001:return Vector3.ZERO
 var initial_gain:float=1.18*values["Sensibilidade"]*sqrt(values["Elasticidade"])
 var limit:float=.26*sqrt(values["Força máxima"])
 # Próximo da origem segue o comando. Perto do alcance, o ganho cai continuamente.
 return drag/span*limit*(1.-exp(-span*initial_gain/limit))

static func pose_stiffness(values:Dictionary)->float:
 var scale:float=1.27*sqrt(.50/float(values["Massa (kg)"]))
 var smoothing:=clampf(float(values["Suavização"])/24.,.65,1.40)
 return clampf(float(values["Rigidez"])*scale*smoothing,18.,155.)

static func friction_factor(dt:float,values:Dictionary,held:bool)->float:
 # Durante a pegada já existe amortecimento na mola.
 var coefficient:float=float(values["Atrito"])*(.25 if held else 1.)
 return exp(-coefficient*dt)
