extends Node3D
const Profile=preload("res://cloth/material_profile.gd")
const Accessory=preload("res://cloth/accessory.gd")
const Worn=preload("res://cloth/worn_layer.gd")
var material:=Profile.new()
var accessory:=Accessory.new()
var worn:=Worn.new()
var game
var quality:=0 if OS.get_name()=="Android" else 1
var render_clock:=0.
var physics_us:=0
var render_us:=0
var colliders:Array=[]
var active:=true
var accessory_enabled:=true
var feedback:=""
var body_shapes:Array=[]
var ground:Node3D
var hold_plane:=Plane()
var hold_origin:=Vector3.ZERO
var selected_accessory:=false
var selected_worn:=false
var camera:Camera3D
var preset_index:=1
func configure(owner,picker)->void:
    game=owner;camera=game.camera
    add_child(accessory);accessory.build(Vector3(.82,1.32,.05)*game.core.leg,game.core.leg)
    worn.build(picker,game.profile,game.core.leg)
    ground=game.get_node("Ground")
    for body in game.core.bodies.values():cache_shape(body.get_child(0))
    cache_shape(game.seat.get_child(0))
    set_quality(quality)
    load_custom()
    set_profile(material)
func set_profile(value:Resource)->void:
    if not value.valid():return
    material=value;worn.solver.set_material(value);accessory.solver.set_material(value)
func set_quality(index:int)->void:
    quality=clampi(index,0,2)
    accessory.solver.iterations=[3,4,6][quality];worn.solver.iterations=[2,3,4][quality]
func cache_shape(shape:CollisionShape3D)->void:
    var geometry:=shape.shape
    var c:={"source":shape}
    if geometry is CapsuleShape3D:
        c.merge({"kind":"capsule","half":geometry.height*.5-geometry.radius,"r":geometry.radius,"radius":geometry.height*.5+.04})
    elif geometry is SphereShape3D:
        c.merge({"kind":"sphere","r":geometry.radius,"radius":geometry.radius+.04})
    elif geometry is BoxShape3D:
        c.merge({"kind":"box","half":geometry.size*.5,"radius":geometry.size.length()*.5+.04})
    else:return
    body_shapes.append(c)

func collision_shapes()->Array:
    var result:Array=[{"kind":"plane","center":ground.global_position,"normal":ground.global_basis.y}]
    for c in body_shapes:
        var source:CollisionShape3D=c.source
        if source.disabled:continue
        var frame:=source.global_transform
        c.center=frame.origin
        c.transform=frame
        c.inverse=frame.affine_inverse()
        result.append(c)
    return result

func set_accessory_enabled(value:bool)->void:
    if not value and selected_accessory:release()
    accessory_enabled=value
    accessory.visible=value
    if value:accessory.solver.wake()

func step(dt:float)->void:
    if not active:return
    var start:=Time.get_ticks_usec();colliders=collision_shapes()
    if accessory_enabled and accessory.solver.sleeping:
        var bounds:=AABB(accessory.solver.position[0],Vector3.ZERO)
        for p in accessory.solver.position:bounds=bounds.expand(p)
        for c in colliders:
            if c.kind!="plane" and bounds.grow(c.radius+.03).has_point(c.center):accessory.solver.wake();break
    # The host retains 120 Hz; smaller substeps only if a larger dt is supplied.
    var count_:=maxi(1,ceili(dt*120.-.00001))
    for i in count_:
        if accessory_enabled:accessory.solver.step(dt/count_,colliders)
        worn.step(dt/count_,colliders)
    physics_us=Time.get_ticks_usec()-start
func _process(dt:float)->void:
    if game==null or not active:return
    render_clock+=dt
    if render_clock<1./[15.,24.,30.][quality]:return
    render_clock=0.
    var start:=Time.get_ticks_usec()
    if accessory_enabled and not accessory.solver.sleeping:accessory.render()
    worn.render()
    render_us=Time.get_ticks_usec()-start
func begin(pixel:Vector2,garment_hit:Dictionary)->bool:
    var hit:=accessory.pick(camera,pixel) if accessory_enabled else {}
    var cloth_distance:float=INF if garment_hit.is_empty() else camera.project_ray_origin(pixel).distance_to(garment_hit.p)
    if not hit.is_empty() and hit.distance<cloth_distance:
        feedback="Tecido independente"
        selected_accessory=true;hold_origin=hit.point;hold_plane=Plane(camera.global_basis.z,hold_origin)
        accessory.solver.begin_hold(hit.face,hit.bary,hit.point)
        return true
    if garment_hit.is_empty():return false
    if not worn.begin_grip(garment_hit):return false
    selected_worn=true
    hold_origin=garment_hit.p
    hold_plane=Plane(camera.global_basis.z,hold_origin)
    feedback=worn.held_region.label if worn.held_region else "Tecido"
    return true
func drag(pixel:Vector2)->void:
    var target=hold_plane.intersects_ray(camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))
    if target==null:return
    if selected_worn:worn.move_grip(target-hold_origin)
    elif selected_accessory:accessory.solver.hold.goal=hold_origin+(target-hold_origin).limit_length(game.core.leg*.55)
func release(commit:=true)->void:
    if selected_accessory:accessory.solver.release()
    if selected_worn:worn.release_grip(commit)
    selected_accessory=false
    selected_worn=false
    feedback=""
func reset()->void:
    release()
    worn.reset()
    accessory.solver.release()
    accessory.solver.position=accessory.solver.rest.duplicate()
    accessory.solver.velocity.fill(Vector3.ZERO)
    if accessory_enabled:accessory.render()
func save_custom()->Error:
    var cfg:=ConfigFile.new()
    for field in Profile.FIELDS:cfg.set_value("cloth",field,material.get(field))
    cfg.set_value("cloth","quality",quality)
    var error:=cfg.save("user://cloth_material.cfg.tmp")
    if error==OK:error=DirAccess.rename_absolute("user://cloth_material.cfg.tmp","user://cloth_material.cfg")
    return error
func load_custom()->void:
    var cfg:=ConfigFile.new()
    if cfg.load("user://cloth_material.cfg")!=OK:return
    var candidate:=Profile.new()
    for field in Profile.FIELDS:
        var value=cfg.get_value("cloth",field,candidate.get(field))
        if not (value is float or value is int):return
        candidate.set(field,value)
    if candidate.valid():material=candidate;preset_index=4;set_quality(int(cfg.get_value("cloth","quality",1)))
