extends RefCounted
# Alvos em coordenadas do esqueleto. Duas barras rígidas e polo anatômico.
var offsets:=[Vector3.ZERO,Vector3.ZERO]
var reach_targets:={}
var look_target:Variant=null
var gaze:=Vector2.ZERO

func solve(sk:Skeleton3D,contacts:Array,dt:float,influence:float)->void:
 sk.reset_bone_poses()
 var total:=Vector3.ZERO
 for c in contacts:
  if c.region!="":total-=c.normal*float(c.force)*influence
 var aim:=Vector2(clampf(total.x,-1,1)*.12,clampf(total.z,-1,1)*.09)
 if look_target!=null:
  var d:Vector3=look_target-sk.get_bone_global_rest(sk.find_bone("Head")).origin
  aim+=Vector2(clampf(atan2(d.x,d.z),-.45,.45),clampf(-atan2(d.y,Vector2(d.x,d.z).length()),-.25,.25))
 gaze=gaze.lerp(aim,1-exp(-dt*9))
 for name in ["Spine","Head"]:
  var idx:=sk.find_bone(name)
  var p:=sk.get_bone_global_pose(idx)
  var weight:=.35 if name=="Spine" else .75
  p.basis=Basis.from_euler(Vector3(gaze.y,gaze.x,-gaze.x*.3)*weight)*p.basis
  sk.set_bone_global_pose(idx,p)
 for i in range(2):
  var side:="L" if i==0 else "R"
  var sign_:=-1 if i==0 else 1
  var upper:=sk.find_bone("Upper"+side)
  var fore:=sk.find_bone("Fore"+side)
  var palm:=sk.find_bone("Palm"+side)
  var a:=sk.get_bone_global_pose(upper).origin
  var b:=sk.get_bone_global_pose(fore).origin
  var c:=sk.get_bone_global_pose(palm).origin
  var target_offset:=Vector3.ZERO
  for contact in contacts:
   if contact.region!="" and contact.surface.x*sign_>0 and contact.surface.y>1.24:
    target_offset+=(-contact.normal*.105+Vector3(-sign_*.035,.026,0))*float(contact.force)*influence
  if reach_targets.has(side):target_offset=(Vector3(reach_targets[side])-c).limit_length(.19)
  offsets[i]=Vector3(offsets[i]).lerp(target_offset.limit_length(.19),1-exp(-dt*9))
  if Vector3(offsets[i]).length()<.00005:continue
  var axis:Vector3=(c+Vector3(offsets[i])-a).normalized()
  var l1:=a.distance_to(b)
  var l2:=b.distance_to(c)
  var length:=clampf((c+Vector3(offsets[i])-a).length(),absf(l1-l2)+.025,l1+l2-.001)
  var along:=(l1*l1-l2*l2+length*length)/(2*length)
  var pole:=(b-a).slide((c-a).normalized()).slide(axis).normalized()
  var elbow:=a+axis*along+pole*sqrt(maxf(0,l1*l1-along*along))
  align(sk,upper,b-a,elbow-a)
  var end:=sk.get_bone_global_pose(palm).origin
  var mid:=sk.get_bone_global_pose(fore).origin
  align(sk,fore,end-mid,a+axis*length-mid)

func align(sk:Skeleton3D,index:int,old_axis:Vector3,new_axis:Vector3)->void:
 var pose:=sk.get_bone_global_pose(index)
 pose.basis=Basis(Quaternion(old_axis.normalized(),new_axis.normalized()))*pose.basis
 sk.set_bone_global_pose(index,pose)
