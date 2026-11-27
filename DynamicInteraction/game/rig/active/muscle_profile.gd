extends Resource
## Ganhos por grupo. Limites em N e N·m para a massa declarada no perfil.
const GROUPS := ["Pelve","Coluna","Pescoço","Ombros","Cotovelos","Punhos","Quadris","Joelhos","Tornozelos"]
const ROLE_GROUP := {"pelvis":0,"lumbar":1,"chest":1,"head":2,"upper":3,"fore":4,"palm":5,"thigh":6,"shin":7,"foot":8}
const STATES := ["Animated","Active","Relaxed","Passive","Recovery"]
const PRESETS := ["Rígido","Natural","Relaxado","Personalizado"]
@export var stiffness := PackedFloat32Array([110,100,68,78,76,50,120,120,95])
@export var damping := PackedFloat32Array([1,1,1,1,1,1,1,1,1])
@export var max_force := PackedFloat32Array([650,600,160,160,110,85,580,480,950])
@export var max_torque := PackedFloat32Array([150,100,24,45,28,12,140,105,75])
@export var limit_scale := PackedFloat32Array([1,1,1,1,1,1,1,1,1])
@export var recovery_speed := PackedFloat32Array([2,2,2.6,2.4,2.8,2.8,1.8,2,2.4])
@export var state_strength := PackedFloat32Array([1.35,1,0.32,0,0.90])
@export_flags_3d_physics var segment_layer := 8
## Raio/segmento, ou raio/perna nas extremidades.
@export var radius_factor := {"pelvis":0.55,"abdomen":0.51,"chest":0.31,"head":0.12,"arm":0.16,"forearm":0.14,"hand":0.055,"thigh":0.21,"shin":0.14}
@export var joint_axes_degrees := {} # Ajuste do referencial anatômico por papel semântico.
@export_range(60,120,10) var physics_hz:=120
@export_range(8,64) var solver_iterations:=48
@export_range(0.,1.) var weight_assist:=0.72
@export_range(0.,2.) var linear_drag:=0.22
@export_range(0.,3.) var angular_drag:=0.8
const FIELDS := ["stiffness","damping","max_force","max_torque","limit_scale","recovery_speed"]
const RANGES := [[5,240],[0.4,2.5],[1,2000],[1,400],[0.1,1.25],[0.2,8]]
func group(role:String)->int:
 return ROLE_GROUP[role.get_slice("_",0)]
func valid()->bool:
 for i in FIELDS.size():
  var values:PackedFloat32Array=get(FIELDS[i])
  if values.size()!=GROUPS.size():return false
  for value in values:
   if not is_finite(value) or value<RANGES[i][0]-.0001 or value>RANGES[i][1]+.0001:return false
 if state_strength.size()!=STATES.size() or segment_layer==0:return false
 for strength in state_strength:
  if not is_finite(strength) or strength<0:return false
 for kind in ["pelvis","abdomen","chest","head","arm","forearm","hand","thigh","shin"]:
  var ratio:float=radius_factor.get(kind,0.)
  if not is_finite(ratio) or ratio<=0. or ratio>=1.:return false
 return state_strength[3]==0
func bounds(role:String,p:Resource)->Array:
 var angular:=Vector3.ZERO
 match role.get_slice("_",0):
  "pelvis":angular=p.pelvis_limit
  "lumbar":angular=p.lumbar_limit
  "chest":angular=p.chest_limit
  "head":angular=p.head_limit
  "upper":angular=Vector3.ONE*p.shoulder_limit
  "fore":angular=Vector3(p.elbow_limit.y,p.wrist_limit,25)
  "palm":angular=Vector3.ONE*p.wrist_limit
  "thigh":angular=p.hip_limit
  "shin":angular=Vector3(p.knee_limit.y,6,6)
  "foot":angular=p.ankle_limit
 angular=(angular*limit_scale[group(role)]).min(Vector3.ONE*170)
 var lower:=-angular
 if role.begins_with("shin"):lower.x=-p.knee_limit.x
 return [lower,angular]
