extends RigidBody3D
var ground_mask:int
var grounded:=false
var support_point:=Vector3.ZERO
func _integrate_forces(state:PhysicsDirectBodyState3D)->void:
 grounded=false
 support_point=Vector3.ZERO
 var count_:=0
 for i in state.get_contact_count():
  var other:=state.get_contact_collider_object(i) as CollisionObject3D
  if other==null or (other.collision_layer & ground_mask)==0:continue
  if state.get_contact_local_normal(i).y<0.45:continue
  support_point+=state.get_contact_collider_position(i)
  count_+=1
 if count_>0:
  grounded=true
  support_point/=count_
