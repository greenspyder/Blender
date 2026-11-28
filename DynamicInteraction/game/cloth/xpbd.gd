extends RefCounted
## Distâncias XPBD, massa por área, dobra por vértices opostos e contato analítico.
const Profile=preload("res://cloth/material_profile.gd")
var material:=Profile.new()
var position:=PackedVector3Array()
var previous:=PackedVector3Array()
var nearby:Array=[]
var lengths:=PackedFloat32Array()
var velocity:=PackedVector3Array()
var rest:=PackedVector3Array()
var areas:=PackedFloat32Array()
var inverse_mass:=PackedFloat32Array()
var triangles:=PackedInt32Array()
var edges:Array=[]
var edge_keys:Dictionary={}
var pins:Dictionary={}
var targets:=PackedVector3Array()
var tether_radius:=0.
var iterations:=4
var hold:Dictionary={}
var quiet_steps:=0
var sleeping:=false
var peak_speed:=0.
var contacts:=0
func build(points:PackedVector3Array,faces:PackedInt32Array)->void:
    position=points.duplicate();rest=points.duplicate();triangles=faces.duplicate()
    velocity.resize(points.size());areas.resize(points.size());inverse_mass.resize(points.size())
    var opposites:Dictionary={}
    for f in range(0,faces.size(),3):
        var a:=faces[f];var b:=faces[f+1];var c:=faces[f+2]
        var area:float=(points[b]-points[a]).cross(points[c]-points[a]).length()/6.
        areas[a]+=area;areas[b]+=area;areas[c]+=area
        for pair in [[a,b,c],[b,c,a],[c,a,b]]:
            join(pair[0],pair[1],false)
            var key:=Vector2i(mini(pair[0],pair[1]),maxi(pair[0],pair[1]))
            if opposites.has(key):join(opposites[key],pair[2],true)
            else:opposites[key]=pair[2]
    nearby.clear()
    for i in points.size():nearby.append([])
    lengths.resize(edges.size())
    set_material(material)
func join(a:int,b:int,bend_:bool)->void:
    if a==b:return
    var key:=Vector3i(mini(a,b),maxi(a,b),int(bend_))
    if edge_keys.has(key):return
    edge_keys[key]=true
    edges.append([a,b,rest[a].distance_to(rest[b]),bend_,0.])
func set_material(profile:Resource)->void:
    if not profile.valid():return
    material=profile
    for i in areas.size():inverse_mass[i]=0. if pins.has(i) else 1./maxf(.00001,areas[i]*material.density*.001)
    wake()
func wake()->void:
    sleeping=false;quiet_steps=0
func begin_hold(face:int,bary:Vector3,goal:Vector3)->void:
    if face<0 or face+2>=triangles.size():return
    begin_weighted_hold(triangles.slice(face,face+3),PackedFloat32Array([bary.x,bary.y,bary.z]),goal)
    hold.face=face
    hold.bary=bary

func begin_weighted_hold(ids:PackedInt32Array,weights:PackedFloat32Array,goal:Vector3)->void:
    hold={"ids":ids,"weights":weights,"goal":goal,"lambda":Vector3.ZERO}
    wake()

func grip_position(ids:PackedInt32Array,weights:PackedFloat32Array)->Vector3:
    var p:=Vector3.ZERO
    for j in ids.size():p+=position[ids[j]]*weights[j]
    return p
func release()->void:
    hold.clear();wake()
func step(h:float,colliders:Array=[])->void:
    if sleeping and targets.is_empty() and hold.is_empty():return
    if position.is_empty():return
    previous=position.duplicate()
    var bounds:=AABB(position[0],Vector3.ZERO)
    for i in position.size():
        nearby[i].clear()
        bounds=bounds.expand(position[i])
        if not targets.is_empty():bounds=bounds.expand(targets[i])
    var padding:=.12+peak_speed*h+tether_radius
    bounds=bounds.grow(padding)
    for collider in colliders:
        var center:Vector3=collider.center
        if collider.kind=="plane":
            var normal:Vector3=collider.normal
            if (bounds.get_center()-center).dot(normal)>bounds.size.dot(normal.abs())*.5:continue
            for i in position.size():
                if (position[i]-center).dot(normal)<padding or (not targets.is_empty() and (targets[i]-center).dot(normal)<padding):nearby[i].append(collider)
            continue
        var radius:float=collider.radius
        if not bounds.grow(radius).has_point(center):continue
        var range_sq:=(radius+padding)*(radius+padding)
        for i in position.size():
            if position[i].distance_squared_to(center)<range_sq or (not targets.is_empty() and targets[i].distance_squared_to(center)<range_sq):nearby[i].append(collider)
    var damp:=exp(-material.damping*h)
    for i in position.size():
        if pins.has(i):position[i]=pins[i];velocity[i]=Vector3.ZERO;continue
        velocity[i]=velocity[i]*damp+Vector3.DOWN*9.81*h
        position[i]+=velocity[i]*h
    var stretch_alpha:float=material.stretch/(h*h)
    var bend_alpha:float=material.bend/(h*h)
    for j in edges.size():
        var e:Array=edges[j]
        e[4]=0.
        lengths[j]=targets[e[0]].distance_to(targets[e[1]]) if not targets.is_empty() else e[2]
    if not hold.is_empty():hold.lambda=Vector3.ZERO
    for pass_ in iterations:
        if not hold.is_empty():solve_hold(h)
        for j in edges.size():
            var e:Array=edges[j]
            var a:int=e[0];var b:int=e[1]
            var delta:=position[b]-position[a];var length_:=delta.length()
            if length_<.000001:continue
            var rest_length:=lengths[j]
            var alpha:=bend_alpha if e[3] else stretch_alpha
            var w:=inverse_mass[a]+inverse_mass[b]
            if w<=0.:continue
            var dl:=(-(length_-rest_length)-alpha*float(e[4]))/(w+alpha)
            e[4]+=dl
            var correction:=delta/length_*dl
            position[a]-=correction*inverse_mass[a];position[b]+=correction*inverse_mass[b]
            if not e[3]:
                delta=position[b]-position[a];length_=delta.length()
                var maximum:=rest_length*(1.+material.strain_limit)
                if length_>maximum:
                    correction=delta/length_*(length_-maximum)/w
                    position[a]+=correction*inverse_mass[a];position[b]-=correction*inverse_mass[b]
        if not targets.is_empty():
            for i in position.size():
                # Coupling to fitted clothing; no modification of rigid-body bones.
                var offset:=position[i]-targets[i]
                position[i]=targets[i]+offset.limit_length(tether_radius)
        contacts=0
        for i in position.size():
            if pins.has(i):continue
            for collider in nearby[i]:
                var p:=project(position[i],collider,material.thickness)
                if not p.is_equal_approx(position[i]):contacts+=1;position[i]=p
    peak_speed=0.
    for i in position.size():
        var v:Vector3=(position[i]-previous[i])/h
        for collider in nearby[i]:
            var p:=project(position[i],collider,material.thickness+.0002)
            var normal:Vector3=p-position[i]
            if normal.length_squared()>1e-12:
                normal=normal.normalized()
                var tangent:=v.slide(normal)
                v=v-tangent*material.friction-normal*minf(v.dot(normal),0.)
        velocity[i]=v if not pins.has(i) else Vector3.ZERO
        peak_speed=maxf(peak_speed,velocity[i].length())
    quiet_steps=quiet_steps+1 if peak_speed<.012 and hold.is_empty() else 0
    sleeping=quiet_steps>120 and targets.is_empty()
func solve_hold(h:float)->void:
    var ids:PackedInt32Array=hold.ids
    var weights:PackedFloat32Array=hold.weights
    var current:=grip_position(ids,weights)
    var weight:=0.
    for j in ids.size():weight+=inverse_mass[ids[j]]*weights[j]*weights[j]
    var alpha:=.0003/(h*h)
    var delta:Vector3=(Vector3(hold.goal)-current-alpha*Vector3(hold.lambda))/(weight+alpha)
    var next:Vector3=(Vector3(hold.lambda)+delta).limit_length(material.grab_force*h*h)
    delta=next-Vector3(hold.lambda);hold.lambda=next
    for j in ids.size():
        position[ids[j]]+=delta*inverse_mass[ids[j]]*weights[j]
static func project(p:Vector3,c:Dictionary,thickness:float)->Vector3:
    if c.kind=="plane":
        var signed:float=(p-Vector3(c.center)).dot(c.normal)
        return p+Vector3(c.normal)*maxf(0.,thickness-signed)
    if p.distance_squared_to(c.center)>float(c.radius)*float(c.radius):return p
    var local:Vector3=c.inverse*p
    var projected:=local
    if c.kind=="sphere" or c.kind=="capsule":
        var center:=Vector3.ZERO
        if c.kind=="capsule":center.y=clampf(local.y,-c.half,c.half)
        var delta:=local-center
        if delta.length()<float(c.r)+thickness:
            projected=center+(delta.normalized() if delta.length()>.000001 else Vector3.FORWARD)*(float(c.r)+thickness)
    else:
        var half:Vector3=c.half+Vector3.ONE*thickness
        if absf(local.x)<half.x and absf(local.y)<half.y and absf(local.z)<half.z:
            var depth:=half-local.abs();var axis:=depth.min_axis_index()
            projected[axis]=(1. if local[axis]>=0 else -1.)*half[axis]
    return p if projected==local else c.transform*projected
func max_strain()->float:
    var maximum:=0.
    for e in edges:
        if e[3] or e[2]<.000001:continue
        var length_:float=targets[e[0]].distance_to(targets[e[1]]) if not targets.is_empty() else e[2]
        maximum=maxf(maximum,position[e[0]].distance_to(position[e[1]])/maxf(length_,.000001)-1.)
    return maximum
