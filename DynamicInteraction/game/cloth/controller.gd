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
    set_quality(quality)
    load_custom()
    set_profile(material)
func set_profile(value:Resource)->void:
    if not value.valid():return
    material=value;worn.solver.set_material(value);accessory.solver.set_material(value)
func set_quality(index:int)->void:
    quality=clampi(index,0,2)
    accessory.solver.iterations=[3,4,6][quality];worn.solver.iterations=[2,3,4][quality]
func collision_shapes()->Array:
    var result:Array=[{"kind":"plane","center":game.get_node("Ground").global_position,"normal":game.get_node("Ground").global_basis.y}]
    var bodies:Array=game.core.bodies.values()
    if game.seat.visible:bodies.append(game.seat)
    for body in bodies:
        var shape:CollisionShape3D=body.get_child(0);var s:Shape3D=shape.shape
        var t:=shape.global_transform
        var c:={"center":t.origin,"transform":t,"inverse":t.affine_inverse(),"radius":0.}
        if s is CapsuleShape3D:c.merge({"kind":"capsule","half":s.height*.5-s.radius,"r":s.radius});c.radius=s.height*.5+.04
        elif s is SphereShape3D:c.merge({"kind":"sphere","r":s.radius});c.radius=s.radius+.04
        elif s is BoxShape3D:c.merge({"kind":"box","half":s.size*.5});c.radius=s.size.length()*.5+.04
        else:continue
        result.append(c)
    return result
func step(dt:float)->void:
    if not active:return
    var start:=Time.get_ticks_usec();colliders=collision_shapes()
    if accessory.solver.sleeping:
        var bounds:=AABB(accessory.solver.position[0],Vector3.ZERO)
        for p in accessory.solver.position:bounds=bounds.expand(p)
        for c in colliders:
            if c.kind!="plane" and bounds.grow(c.radius+.03).has_point(c.center):accessory.solver.wake();break
    # The host retains 120 Hz; smaller substeps only if a larger dt is supplied.
    var count_:=maxi(1,ceili(dt*120.-.00001))
    for i in count_:
        accessory.solver.step(dt/count_,colliders)
        worn.step(dt/count_,colliders)
    physics_us=Time.get_ticks_usec()-start
func _process(dt:float)->void:
    if game==null or not active:return
    render_clock+=dt
    if render_clock<1./[15.,24.,30.][quality]:return
    render_clock=0.
    var start:=Time.get_ticks_usec()
    if not accessory.solver.sleeping:accessory.render()
    worn.render()
    render_us=Time.get_ticks_usec()-start
func begin(pixel:Vector2,garment_hit:Dictionary)->bool:
    var hit:=accessory.pick(camera,pixel)
    var cloth_distance:float=INF if garment_hit.is_empty() else camera.project_ray_origin(pixel).distance_to(garment_hit.p)
    if not hit.is_empty() and hit.distance<cloth_distance:
        selected_accessory=true;hold_origin=hit.point;hold_plane=Plane(camera.global_basis.z,hold_origin)
        accessory.solver.begin_hold(hit.face,hit.bary,hit.point)
        return true
    if garment_hit.is_empty():return false
    for record in worn.records:
        if record.surface!=garment_hit.surface:continue
        var vertex:int=record.surface.indices[garment_hit.face]
        var particle:int=record.mapping[vertex]
        # A physical triangle attached to the picked cluster, shared with future hand tools.
        var f:=worn.solver.triangles.find(particle)
        if f<0:return false
        var bary:=Vector3.ZERO;bary[f%3]=1.
        selected_worn=true;hold_origin=garment_hit.p;hold_plane=Plane(camera.global_basis.z,hold_origin)
        worn.solver.begin_hold(f-f%3,bary,hold_origin)
        return true
    return false
func drag(pixel:Vector2)->void:
    var target=hold_plane.intersects_ray(camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))
    if target==null:return
    var solver=accessory.solver if selected_accessory else worn.solver
    if not solver.hold.is_empty():solver.hold.goal=hold_origin+(target-hold_origin).limit_length(game.core.leg*.55)
func release()->void:
    accessory.solver.release();worn.solver.release();selected_accessory=false;selected_worn=false
func reset()->void:
    release();worn.reset();accessory.solver.position=accessory.solver.rest.duplicate();accessory.solver.velocity.fill(Vector3.ZERO)
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
