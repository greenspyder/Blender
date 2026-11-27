extends "res://direct/garment_pull.gd"
## Os pés têm posição fixa neste rig. A peça desce até os tornozelos e é
## conduzida à frente da ponta dos pés para sair sem afundar no chão.

var rig_origin:=Vector3.ZERO

func configure(model:Node,picker)->void:
 part_names=["Shorts","PocketL","PocketR"]
 whole_piece="Shorts"
 pull_rate=1.20
 super(model,picker)

static func contains_hit(hit:Dictionary)->bool:
 if hit.is_empty() or hit.surface.node.name!="Shorts":return false
 var surface:Dictionary=hit.surface
 var f:int=hit.face
 var w:Vector3=hit.bary
 var y:float=surface.vertices[surface.indices[f]].y*w.x
 y+=float(surface.vertices[surface.indices[f+1]].y)*w.y
 y+=float(surface.vertices[surface.indices[f+2]].y)*w.z
 return y>=1.091

func pull(value:float,screen_target:Vector3)->void:
 demand=clampf(value,0.,1.)
 var end:=path(1.)
 var extra:=motion_frame.inverse()*(screen_target-end)
 extra.x=clampf(extra.x,-.38,.38)
 extra.y=clampf(extra.y,-.018,.30)
 extra.z=clampf(extra.z,-.012,.22)
 carry_target=end+motion_frame*extra

func path(value:float)->Vector3:
 var down:=smoothstep(0.,.88,value)
 var toes:=smoothstep(.70,1.,value)
 var local:=motion_frame.inverse()*(equipped_point-rig_origin)
 var shift:=Vector3(side*.075*toes,(.12-local.y)*down,(.58-local.z)*toes)
 return equipped_point+motion_frame*shift

func write_guide(value:float,offset:Vector3=Vector3.ZERO)->void:
 var pivot:=path(value)
 var flat:=smoothstep(.68,1.,value)
 var swing:=smoothstep(.50,.95,value)
 var spin:=Basis(Vector3.RIGHT,-flat*.53)
 for i in cage.rest.size():
  var original:Vector3=cage.rest[i]
  var hem:=clampf(-original.y/.34,0.,1.)
  var p:=pivot.lerp(path(maxf(0.,value-.12*sin(PI*value)*hem)),hem)
  var adjusted:=original
  adjusted.y*=lerpf(1.,.57,flat)
  adjusted.x*=lerpf(1.,.81,swing)
  var target:=p+spin*adjusted+offset
  target.y=maxf(FLOOR_Y,target.y)
  anchors[i]=target

func has_clearance()->bool:
 if Vector3(cage.position[0]).distance_to(grip_target)>.060:return false
 for point:Vector3 in cage.position:
  if (point-rig_origin).dot(motion_frame.z)<.182:return false
 return true

func arm_weight(_right:bool)->float:
 return 0.
