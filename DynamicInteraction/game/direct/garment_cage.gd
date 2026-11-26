extends RefCounted

## Malha física reduzida. A malha renderizada amostra os deslocamentos das
## partículas, e as costuras continuam ligadas durante a liberação e a queda.
const CELL := .047
const FLOOR := .035
const STEP := 1.0/120.
const ITERATIONS := 4

var rest:=PackedVector3Array()
var position:=PackedVector3Array()
var previous:=PackedVector3Array()
var bins:Dictionary={}
var springs:Array[Vector4]=[]
var joined:Dictionary={}
var springs_from_shape:Dictionary={}
var quiet_steps:=0

func begin(point:Vector3)->void:
 rest.append(Vector3.ZERO)
 position.append(point)
 previous.append(point)

func cell_of(p:Vector3)->Vector3i:
 return Vector3i((p/CELL).floor())

func particle(p:Vector3, origin:Vector3)->int:
 var cell:=cell_of(p)
 if bins.has(cell):return bins[cell]
 var i:=rest.size()
 bins[cell]=i
 rest.append(p)
 position.append(origin+p)
 previous.append(origin+p)
 return i

func join(a:int,b:int,strength:float)->void:
 if a==b:return
 var key:=Vector2i(mini(a,b),maxi(a,b))
 if joined.has(key):return
 joined[key]=true
 springs.append(Vector4(a,b,rest[a].distance_to(rest[b]),strength))

func triangle(a:int,b:int,c:int)->void:
 connect_triangle_edge(a,b,c)
 connect_triangle_edge(b,c,a)
 connect_triangle_edge(c,a,b)

func connect_triangle_edge(a:int,b:int,opposite:int)->void:
 if a==b:return
 join(a,b,.78)
 if opposite==a or opposite==b:return
 var key:=Vector2i(mini(a,b),maxi(a,b))
 if springs_from_shape.has(key):
  join(int(springs_from_shape[key]),opposite,.15)
 else:
  springs_from_shape[key]=opposite

func pin_neighbors()->void:
 var closest:=1
 for i in range(1,rest.size()):
  if rest[i].length_squared()<rest[closest].length_squared():closest=i
  if rest[i].length_squared()<.087*.087:join(0,i,.84)
 join(0,closest,.88)

func render_binding(p:Vector3,index:int)->Vector3:
 var second:=index
 var best:=.075*.075
 var cell:=cell_of(p)
 for axis in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
  var next:int=bins.get(cell+axis,index)
  if next==index or not joined.has(Vector2i(mini(index,next),maxi(index,next))):continue
  var distance:=rest[next].distance_squared_to(p)
  if distance<best:
   best=distance
   second=next
 var weight:=0.
 if second!=index:
  var a:=p.distance_to(rest[index])
  weight=clampf(a/maxf(.001,a+sqrt(best)),0.,.72)
 return Vector3(index,second,weight)

func simulate(pin:Variant,guide:PackedVector3Array,guide_strength:float,obstacles:Array,collision_weight:float)->void:
 var before:=position.duplicate()
 for i in position.size():
  if i==0 and pin!=null:
   position[i]=pin
   continue
  var movement:Vector3=(position[i]-previous[i]).limit_length(.035)*.967
  position[i]+=movement+Vector3.DOWN*5.2*STEP*STEP
 for iteration in ITERATIONS:
  for spring in springs:
   var a:=int(spring.x)
   var b:=int(spring.y)
   var travel:=position[b]-position[a]
   var distance:=travel.length()
   if distance<.00001:continue
   var fixed:=pin!=null and a==0
   var correction:=travel*((distance-spring.z)/distance*spring.w)
   if not fixed:position[a]+=correction*.5
   position[b]-=correction*(1. if fixed else .5)
  if guide_strength>0.:
   for i in range(1,position.size()):
    position[i]+=(guide[i]-position[i]).limit_length(.045)*guide_strength
  for i in position.size():
   if i==0 and pin!=null:continue
   var p:=position[i]
   p.y=maxf(FLOOR,p.y)
   if collision_weight>0.:
    for capsule in obstacles:
     var center:Vector3=capsule[0]
     var size_:Vector3=capsule[1]
     var offset:Vector3=(p-center)/size_
     var distance:=offset.length_squared()
     if distance>.00001 and distance<1.:
      p=p.lerp(center+offset.normalized()*size_,collision_weight)
   position[i]=p
 var maximum:=0.
 var floor_contact:=false
 for i in position.size():
  var old:=before[i]
  if position[i].y<=FLOOR+.0002 and (i!=0 or pin==null):
   floor_contact=true
   old=position[i].lerp(old,.32)
   old.y=position[i].y
  previous[i]=old
  maximum=maxf(maximum,position[i].distance_squared_to(old))
 quiet_steps=quiet_steps+1 if floor_contact and maximum<.0000013 else 0

func lowest_y()->float:
 var lowest:=INF
 for p in position:lowest=minf(lowest,p.y)
 return lowest

func physical_extent()->AABB:
 var box:=AABB(position[0],Vector3.ZERO)
 for p in position:box=box.expand(p)
 return box
