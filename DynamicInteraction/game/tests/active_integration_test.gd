extends SceneTree
const Lab=preload("res://rig/active/lab.tscn")
const Core=preload("res://rig/active/active_body.gd")
var failures:=PackedStringArray()
func _initialize()->void:call_deferred("run")
func check(ok:bool,what:String)->void:
 if not ok:failures.append(what)

func run()->void:
 var lab=Lab.instantiate()
 var previous:=Engine.physics_ticks_per_second
 root.add_child(lab)
 for i in 180:await physics_frame
 var touch:=InputEventScreenTouch.new()
 touch.index=2
 touch.position=lab.camera.unproject_position(lab.core.bodies.chest.global_position)
 touch.pressed=true
 lab._unhandled_input(touch)
 for i in 2:await physics_frame
 check(lab.drag_role=="chest","seleção física pela projeção do tórax")
 var motion:=InputEventScreenDrag.new()
 motion.index=2
 motion.position=lab.camera.unproject_position(lab.drag_goal+Vector3.UP*lab.balance.length_scale)
 lab._input(motion)
 var free:=0
 for i in 320:
  await physics_frame
  if lab.core.active_support.is_empty():free+=1
 check(free>120,"suspender os dois pés com tração limitada")
 touch.pressed=false
 lab._input(touch)
 check(lab.drag_id==-2,"liberar captura")
 for i in 480:await physics_frame
 check(lab.core.com.y>.8 and lab.core.active_support.has("foot_l"),"aterrissar após soltar")
 print("Arrasto sintético · %d/320 ticks sem contato"%free)

 # Segundo rig sem GLB nem adaptador, com nomes novos e um ancestral a mais.
 var alt:=Skeleton3D.new()
 var source:Skeleton3D=lab.core.skin
 var profile:Resource=lab.profile.duplicate(true)
 profile.add_legacy_rose_bones=false
 profile.mass_kg=74.
 profile.sole_offset*=1.15
 alt.add_bone("root_model")
 for i in source.get_bone_count():alt.add_bone("mapped_%d"%i)
 for i in source.get_bone_count():
  alt.set_bone_parent(i+1,source.get_bone_parent(i)+1)
  var rest:=source.get_bone_rest(i)
  rest.origin*=1.15
  alt.set_bone_rest(i+1,rest)
 for role in profile.bones:
  profile.bones[role]="mapped_%d"%lab.core.ids[role]
 root.add_child(alt)
 alt.position.x=4.
 alt.reset_bone_poses()
 check(profile.validate(alt).is_empty(),"perfil remapeado")
 var core:=Core.new()
 root.add_child(core)
 core.build(alt,alt,profile,lab.muscles,lab.balance.length_scale*1.15)
 check(core.ids.pelvis!=lab.core.ids.pelvis and core.bodies.size()==16,"papéis sem índices fixos")
 check(is_equal_approx(core.bodies.chest.mass,profile.segment_mass("chest")),"massa do segundo perfil")
 var original:BoxShape3D=lab.core.bodies.foot_l.get_child(0).shape
 var larger:BoxShape3D=core.bodies.foot_l.get_child(0).shape
 check(larger.size.is_equal_approx(original.size*1.15),"colisor redimensionado")
 core.free()
 alt.free()
 lab.free()
 check(Engine.physics_ticks_per_second==previous,"restaurar frequência na saída")
 print("Integração · falhas ",failures.size()," ",failures)
 quit(0 if failures.is_empty() else 1)
