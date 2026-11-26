extends Node3D

var desired := Vector3.ZERO
var last := Vector3.ZERO
var duration := 0.0
var fade := 0.0
var enabled := false
var side := 1.0
var mark: MeshInstance3D

func piece(p: Vector3, size_: Vector3, color: Color) -> MeshInstance3D:
 var m:=MeshInstance3D.new()
 m.mesh=SphereMesh.new()
 var mat:=StandardMaterial3D.new()
 mat.albedo_color=color
 m.material_override=mat
 add_child(m)
 m.position=p
 m.scale=size_
 return m

var joints:Array=[]
var tips:Array=[]
var pose_index:=1
var aperture:=1.0
var smoothness:=16.0
var speed_limit:=2.2
var last_offsets:Array[Vector3]=[]
const CURL=[[0.,0.,0.,0.,0.],[.24,.23,.32,.41,.5],[.48,.02,.92,.96,.96],[.64,.80,.90,.92,.92]]

func setup(direction:float)->void:
 side=direction
 var color:=Color("#93c2b6") if side>0 else Color("#baadc7")
 piece(Vector3.ZERO,Vector3(.083,.036,.093),color)
 for finger in range(5):
  var parent:Node3D=self
  var chain:Array=[]
  for segment in range(3):
   var joint:=Node3D.new()
   parent.add_child(joint)
   if segment==0:
    joint.position=Vector3(-side*.038,0,-.006) if finger==0 else Vector3(side*(finger-2.5)*.019,0,-.035)
    if finger==0:joint.rotation.y=side*.88
   else:joint.position.z=-.022
   var phalanx:=piece(Vector3.ZERO,Vector3(.017,.016,.031),color)
   phalanx.reparent(joint,false)
   phalanx.position.z=-.011
   chain.append(joint)
   parent=joint
  var tip:=Marker3D.new()
  parent.add_child(tip)
  tip.position.z=-.022
  tips.append(tip);joints.append(chain)
 mark=piece(Vector3.ZERO,Vector3.ONE*.014,Color.CORAL)
 mark.visible=false

func advance(point:Vector3,dt:float,roll:float,debug_on:bool,detector)->Dictionary:
 var empty:={"region":"","surface":point,"normal":Vector3.ZERO,"force":0.0}
 var old_fade:=fade
 fade=move_toward(fade,1.0 if enabled else 0.0,dt*7)
 visible=fade>.005
 scale=Vector3.ONE*maxf(.001,fade)
 if not enabled:
  last_offsets.clear();duration=0
  return empty
 if old_fade<.005:position=Vector3(point.x,point.y,.58);desired=position
 rotation.z=lerp_angle(rotation.z,roll*side,1-exp(-dt*18))
 for f in range(5):
  for j in range(3):
   var joint:Node3D=joints[f][j]
   var curl:float=clampf(CURL[pose_index][f]+(1-aperture)*.75,0,1.15)
   joint.rotation.x=lerpf(joint.rotation.x,-curl*(.65 if j==0 else 1.05),1-exp(-dt*16))
 var from:=position
 desired=desired.lerp(point,1-exp(-dt*smoothness))
 var dest:=from.move_toward(desired,speed_limit*dt)
 var offsets:Array[Vector3]=[Vector3.ZERO]
 for tip in tips:offsets.append(get_parent().to_local(tip.global_position)-position)
 if last_offsets.size()!=offsets.size():last_offsets=offsets.duplicate()
 var best:=empty
 var earliest:=1.01
 for i in range(offsets.size()):
  var collision:Dictionary=detector.sweep(from+last_offsets[i],dest+offsets[i],.032 if i==0 else .009)
  if collision.is_empty() or collision.t>=earliest:continue
  earliest=collision.t
  best=collision
  var pressure:=maxf(0.0,(from-point).dot(best.normal))
  best.force=clampf(pressure*8+(dest-from).length()/maxf(dt,.001)*.06+minf(.15,duration*.06),.02,1)
 if earliest<=1:
  # Limite a translação no primeiro contato e permita deslizar no quadro seguinte.
  position=from.lerp(dest,maxf(0,earliest-.001))
  var tangent:Vector3=(dest-position).slide(best.normal)
  var permitted:=1.0
  for i in range(offsets.size()):
   var slide_hit:Dictionary=detector.sweep(position+offsets[i],position+offsets[i]+tangent,.032 if i==0 else .009)
   if not slide_hit.is_empty():permitted=minf(permitted,slide_hit.t)
  position+=tangent*permitted
  duration+=dt
 else:
  position=dest;duration=0
 last_offsets=offsets
 mark.visible=debug_on and best.region!=""
 if mark.visible:mark.global_position=get_parent().to_global(best.surface)
 return best
