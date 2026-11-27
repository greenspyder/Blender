extends SceneTree

const Profile=preload("res://rig/character_profile.gd")
const Controller=preload("res://rig/full_body_pose.gd")
const LAB=preload("res://rig/full_body_lab.tscn")
const LEGACY=preload("res://assets/rig121.glb")
var errors:=0
var scene
var rig

func _initialize()->void:call_deferred("run")

func check(condition:bool,message:String)->void:
 if not condition:
  errors+=1
  push_error(message)

func step(frames:int=85)->void:
 for i in frames:scene._physics_process(1./60.)

func pos(role:String)->Vector3:
 return rig.pose(role).origin

func knee_angle(side:String)->float:
 var a:=pos("thigh_"+side)
 var b:=pos("shin_"+side)
 var c:=pos("foot_"+side)
 return rad_to_deg((b-a).angle_to(c-b))

func verify_lengths()->void:
 for side in ["l","r"]:
  for pair in [["thigh_","shin_"],["shin_","foot_"],["upper_","fore_"],["fore_","palm_"]]:
   var a:String=pair[0]+side
   var b:String=pair[1]+side
   var sk:Skeleton3D=scene.sk
   var rest:=sk.get_bone_global_rest(rig.bones[a]).origin.distance_to(sk.get_bone_global_rest(rig.bones[b]).origin)
   check(absf(pos(a).distance_to(pos(b))-rest)<.0006,"comprimento preservado: "+a)

func positions(mesh:MeshInstance3D)->PackedVector3Array:
 var arrays:=mesh.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var joints:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var sk:Skeleton3D=scene.sk
 var matrices:Array[Transform3D]=[]
 for i in mesh.skin.get_bind_count():
  matrices.append(sk.get_bone_global_pose(sk.find_bone(mesh.skin.get_bind_name(i)))*mesh.skin.get_bind_pose(i))
 var out:=PackedVector3Array()
 for i in vertices.size():
  var p:=Vector3.ZERO
  var total:=0.
  for j in range(i*4,i*4+4):
   if weights[j]>0.:p+=(matrices[joints[j]]*vertices[i])*weights[j]
   total+=weights[j]
  check(absf(total-1.)<.0002 and p.is_finite(),"pesos válidos de "+str(mesh.name))
  out.append(p)
 return out

func verify_mesh()->void:
 var body:MeshInstance3D=scene.find_child("Body",true,false)
 var short_:MeshInstance3D=scene.find_child("Shorts",true,false)
 for mesh in [body,short_]:
  var p:=positions(mesh)
  var arrays:Array=mesh.mesh.surface_get_arrays(0)
  var rest:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  var ratio:=0.
  for i in range(0,indices.size(),3):
   for k in 3:
    var a:=indices[i+k]
    var b:=indices[i+((k+1)%3)]
    if minf(rest[a].y,rest[b].y)<.14 or maxf(rest[a].y,rest[b].y)>1.14:continue
    if absf(rest[a].x)>.34 or absf(rest[b].x)>.34:continue
    var base:=rest[a].distance_to(rest[b])
    if base>.022:ratio=maxf(ratio,p[a].distance_to(p[b])/base)
  check(ratio>0. and ratio<2.5,"controle de alongamento local de "+str(mesh.name)+": "+str(ratio))
  print("%s · pior razão de aresta da área medida %.2f"%[mesh.name,ratio])

func run()->void:
 var model:=LEGACY.instantiate()
 root.add_child(model)
 var authored:Skeleton3D=model.find_child("Skeleton3D",true,false)
 if authored==null:
  authored=model.find_children("*","Skeleton3D",true,false).front()
 var profile:=Profile.new()
 check(authored.get_bone_count()==9 and profile.validate(authored).size()==7,"GLB 1.2.12 tem nove ossos e sete funções ausentes")
 scene=LAB.instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_physics_process(false)
 check(scene.ready_to_pose and scene.sk.get_bone_count()==16,"bancada deriva 16 ossos e valida o contrato")
 if not scene.ready_to_pose:quit(1);return
 rig=scene.solver
 var authored_base:=authored.get_bone_global_rest(authored.find_bone("Base"))
 var preserved:=authored.get_bone_global_rest(authored.find_bone("ForeR"))
 check(preserved.is_equal_approx(scene.sk.get_bone_global_rest(rig.bones.fore_r)) and authored_base.is_equal_approx(scene.sk.get_bone_global_rest(rig.bones.pelvis)),"matrizes de repouso preexistentes")
 check(authored.get_bone_count()==9 and authored.find_bone("FootL")==-1,"a instância original continua intacta")
 for mesh in scene.find_children("*","MeshInstance3D",true,false):
  if str(mesh.name) in ["Dress","Shorts","Slipper","Slipper.001"]:
   check(mesh.is_visible_in_tree(),"personagem vestida: "+str(mesh.name))
 step()
 var neutral:Vector3=rig.center_of_mass
 var foot_start:=pos("foot_l")
 var standing:=knee_angle("l")
 check(rig.contacts.size()==2 and not rig.contacts.l.limited and not rig.contacts.r.limited,"ambos os apoios válidos em pé")
 var mass:=0.
 for segment in rig.masses:mass+=float(segment.kg)
 check(absf(mass-scene.profile.mass_kg)<.001,"massas somam o valor do perfil")
 verify_lengths()

 scene.choose_pose(1)
 step()
 check(rig.center_of_mass.x<neutral.x-.045 and rig.contacts.has("l") and not rig.contacts.has("r"),"transferência para o pé E")
 scene.choose_pose(2)
 step()
 check(rig.center_of_mass.x>neutral.x+.045 and rig.contacts.has("r") and not rig.contacts.has("l"),"transferência para o pé D")

 scene.choose_pose(4)
 step()
 var seated:=knee_angle("l")
 check(seated>65. and seated<100. and knee_angle("r")>65.,"joelhos dobram para sentar")
 check(pos("shin_l").z>pos("thigh_l").z+.25,"quadril flete e a coxa avança")
 check(pos("pelvis").y<.55,"a pelve é o centro da transição sentada")
 verify_lengths()
 verify_mesh()
 var ankle_before:Basis=rig.pose("foot_l").basis
 scene.preview.ankle_l=Vector3(29.,0.,0.)
 step()
 check(ankle_before.get_rotation_quaternion().angle_to(rig.pose("foot_l").basis.get_rotation_quaternion())>.48,"tornozelo esquerdo responde separadamente")
 var knee_r:=knee_angle("r")
 scene.preview.knee_l=Vector3(240.,0.,0.)
 step()
 check(absf(knee_angle("l")-scene.profile.knee_limit.y)<9. and absf(knee_angle("r")-knee_r)<.01,"limite do joelho E preserva lado D")
 var head_before:Basis=rig.pose("head").basis
 scene.preview.head=Vector3(26.,0.,0.)
 step()
 check(head_before.get_rotation_quaternion().angle_to(rig.pose("head").basis.get_rotation_quaternion())>.38,"cabeça tem controle independente")

 scene.choose_pose(3)
 step()
 check(pos("head").z-pos("pelvis").z>.25 and pos("lumbar").z>pos("pelvis").z+.025,"inclinação distribuída pela coluna")
 scene.choose_pose(5)
 var delta_max:=0.
 var previous:=pos("foot_l")
 for i in 85:
  step(1)
  var foot:=pos("foot_l")
  delta_max=maxf(delta_max,foot.distance_to(previous))
  previous=foot
 var lift:=pos("foot_l").y-foot_start.y
 check(rig.contacts.is_empty() and lift>.24 and pos("foot_r").y-foot_start.y>.24,"a suspensão libera ambos os pés")
 check(delta_max<.095,"transição contínua do apoio à suspensão")
 scene.choose_pose(0)
 step()
 check(pos("foot_l").distance_to(foot_start)<.012 and rig.contacts.size()==2,"retorno ao apoio")
 rig.enabled.feet=false
 step()
 check(rig.contacts.is_empty(),"controle de apoio pode ser desligado")
 rig.enabled.arms=false
 step()
 check(scene.sk.get_bone_pose_rotation(rig.bones.upper_r).is_equal_approx(scene.sk.get_bone_rest(rig.bones.upper_r).basis.get_rotation_quaternion()),"IK de braços pode ser desligado")
 rig.enabled.legs=false
 step()
 check(scene.sk.get_bone_pose_rotation(rig.bones.shin_l).is_equal_approx(scene.sk.get_bone_rest(rig.bones.shin_l).basis.get_rotation_quaternion()),"controle das pernas pode ser desligado")

 var mapped:=Profile.new()
 var index:int=rig.bones.foot_l
 scene.sk.set_bone_name(index,"CustomFoot")
 mapped.bones.foot_l="CustomFoot"
 var imported:=Controller.new()
 check(imported.configure(scene.sk,mapped).is_empty(),"o perfil aceita nome de osso alternativo")
 scene.sk.set_bone_name(index,"FootL")
 print("Joelho E em pé %.1f° · sentado %.1f° · suspensão +%.1f cm · maior passo %.1f cm"%[standing,seated,lift*100.,delta_max*100.])
 print("Rig corporal · falhas: ",errors)
 quit(errors)
