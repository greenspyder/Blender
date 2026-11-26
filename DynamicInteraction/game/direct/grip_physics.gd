extends RefCounted
## Mola amortecida avaliada no ponto de contato. As forças de cada dedo
## são somadas antes de integrar o movimento do objeto.
const STEP := 1.0/120.0

static func force_limit(values: Dictionary) -> float:
 return 60.0*float(values["Força máxima"])

static func traction(target:Vector3, anchor:Vector3, velocity:Vector3, values:Dictionary) -> Vector3:
 var stiffness:float=values["Rigidez"]/values["Elasticidade"]
 var damping:=2.0*sqrt(stiffness*float(values["Massa (kg)"]))*float(values["Amortecimento"])
 var extension:Vector3=(target-anchor)*float(values["Sensibilidade"])
 return (extension*stiffness-velocity*damping).limit_length(force_limit(values))

static func drag_velocity(velocity:Vector3, dt:float, values:Dictionary) -> Vector3:
 return velocity*exp(-float(values["Atrito"])*dt)
