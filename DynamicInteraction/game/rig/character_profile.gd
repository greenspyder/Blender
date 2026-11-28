extends Resource
## Contrato do esqueleto em espaço local da Godot (metros, +Y acima, +Z frente).

const PARENTS := {
 "lumbar":"pelvis", "chest":"lumbar", "head":"chest",
 "upper_l":"chest", "fore_l":"upper_l", "palm_l":"fore_l",
 "upper_r":"chest", "fore_r":"upper_r", "palm_r":"fore_r",
 "thigh_l":"pelvis", "shin_l":"thigh_l", "foot_l":"shin_l",
 "thigh_r":"pelvis", "shin_r":"thigh_r", "foot_r":"shin_r",
}
const MASS_SEGMENTS := [
 ["pelvis","lumbar","pelvis"], ["lumbar","chest","abdomen"], ["chest","head","chest"],
 ["head","head","head"],
 ["upper_l","fore_l","arm"], ["fore_l","palm_l","forearm"], ["palm_l","palm_l","hand"],
 ["upper_r","fore_r","arm"], ["fore_r","palm_r","forearm"], ["palm_r","palm_r","hand"],
 ["thigh_l","shin_l","thigh"], ["shin_l","foot_l","shin"], ["foot_l","foot_l","foot"],
 ["thigh_r","shin_r","thigh"], ["shin_r","foot_r","shin"], ["foot_r","foot_r","foot"],
]

@export var model:PackedScene
@export var add_legacy_rose_bones:=false
@export_node_path("Skeleton3D") var skeleton_path:NodePath
## Região elipsoidal no bind da peça, curso em comprimentos de perna.
@export var garment_fit_regions:Array[Dictionary]=[]
@export var bones:Dictionary={
 "pelvis":"Base", "lumbar":"Lumbar", "chest":"Spine", "head":"Head",
 "upper_l":"UpperL", "fore_l":"ForeL", "palm_l":"PalmL",
 "upper_r":"UpperR", "fore_r":"ForeR", "palm_r":"PalmR",
 "thigh_l":"ThighL", "shin_l":"ShinL", "foot_l":"FootL",
 "thigh_r":"ThighR", "shin_r":"ShinR", "foot_r":"FootR",
}
@export var optional_bones:Dictionary={"neck":"Neck", "clavicle_l":"ClavicleL", "clavicle_r":"ClavicleR", "toe_l":"ToeL", "toe_r":"ToeR"}
@export var shape_keys:PackedStringArray=["blink_l", "blink_r", "smile", "brow_up", "mouth_open", "chest_press", "hip_press"]
@export var mesh_roles:Dictionary={
 "skin":"Body", "face":"Face", "upper_clothes":["Dress","Ribbon"],
 "lower_clothes":["Shorts","PocketL","PocketR"], "shoes":["Slipper","Slipper_001"],
}
@export_group("Limites articulares · graus")
@export var pelvis_limit:=Vector3(28.,32.,20.)
@export var lumbar_limit:=Vector3(26.,24.,18.)
@export var chest_limit:=Vector3(29.,32.,22.)
@export var head_limit:=Vector3(28.,40.,15.)
@export var hip_limit:=Vector3(86.,32.,42.)
@export var knee_limit:=Vector2(4.,116.)
@export var ankle_limit:=Vector3(35.,20.,18.)
@export var arm_rest_angles:=Vector3(13.,24.,0.) # elevação, flexão, rotação axial
@export_range(0.,25.,.5) var walk_arm_swing:=12.
@export var elbow_pole:=Vector3(.40,-.10,-.90) # lado exterior, vertical, frente no tórax
@export var shoulder_limit:=150.
@export var elbow_limit:=Vector2(12.,128.)
@export var wrist_limit:=65.
@export_group("Apoios e massa")
@export var sole_offset:=Vector3(0.,-.077,.035)
@export_range(20.,180.,.5) var mass_kg:=56.
@export var mass_proportions:Dictionary={
 "pelvis":.15,"abdomen":.10,"chest":.20,"head":.08,
 "arm":.027,"forearm":.016,"hand":.006,"thigh":.112,"shin":.046,"foot":.012,
}
@export_range(1.,20.,.1) var pose_response:=8.

@export_group("Equilíbrio e contato · fatores do comprimento da perna")
@export_range(.01,.12,.005) var contact_band:=.045
@export_range(.03,.16,.005) var sole_half_width:=.075
@export_range(.07,.24,.005) var sole_half_length:=.14
@export_range(7.,24.,.5) var support_frequency:=15.
@export_range(.4,1.8,.05) var support_damping:=1.
@export_range(0.,1.,.05) var balance_gain:=.65
@export_flags_3d_physics var ground_mask:=1

func resolve(sk:Skeleton3D)->Dictionary:
 var ids:Dictionary={}
 for role in bones:ids[role]=sk.find_bone(bones[role])
 return ids

func validate(sk:Skeleton3D)->PackedStringArray:
 var ids:=resolve(sk)
 var issues:=PackedStringArray()
 var used:Dictionary={}
 if not is_finite(mass_kg) or mass_kg<=0.:issues.append("Massa corporal inválida")
 for category in mass_proportions:
  var mass:float=mass_proportions[category]
  if not is_finite(mass) or mass<=0.:issues.append("Fração de massa inválida · "+str(category))
 for segment in MASS_SEGMENTS:
  if not mass_proportions.has(segment[2]):issues.append("Falta a fração de massa · "+str(segment[2]))
 for role in PARENTS.keys()+["pelvis"]:
  var bone:int=ids.get(role,-1)
  if bone<0:
   issues.append("Falta %s (%s)"%[role,bones.get(role,"sem nome")])
   continue
  if used.has(bone):
   issues.append("Osso compartilhado por %s e %s"%[used[bone],role])
  used[bone]=role
  if not PARENTS.has(role):continue
  var parent:int=ids.get(PARENTS[role],-1)
  if parent>=0 and not descends_from(sk,bone,parent):
   issues.append("Hierarquia inválida · %s deve descender de %s"%[role,PARENTS[role]])
 for pair in [["thigh_l","shin_l"],["shin_l","foot_l"],["thigh_r","shin_r"],["shin_r","foot_r"],
              ["upper_l","fore_l"],["fore_l","palm_l"],["upper_r","fore_r"],["fore_r","palm_r"]]:
  var a:int=ids.get(pair[0],-1)
  var b:int=ids.get(pair[1],-1)
  if a>=0 and b>=0:
   if sk.get_bone_global_rest(a).origin.distance_to(sk.get_bone_global_rest(b).origin)<.01:
    issues.append("Segmento degenerado · %s → %s"%pair)
 return issues

static func descends_from(sk:Skeleton3D,bone:int,ancestor:int)->bool:
 var index:=sk.get_bone_parent(bone)
 while index>=0:
  if index==ancestor:return true
  index=sk.get_bone_parent(index)
 return false

func mass_total()->float:
 var total:=0.
 for segment in MASS_SEGMENTS:total+=maxf(0.,mass_proportions.get(segment[2],0.))
 return total

func segment_mass(kind:String,sum:float=-1.)->float:
 if sum<0.:sum=mass_total()
 if sum<=0.:return 0.
 return mass_kg*maxf(0.,mass_proportions.get(kind,0.))/sum
