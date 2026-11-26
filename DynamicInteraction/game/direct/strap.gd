extends RefCounted
## A faixa de seleção é definida no bind da malha, no material do viés.
const NEAR_PIXELS := 15.0

static func contains_hit(hit:Dictionary)->bool:
 if hit.is_empty():return false
 var surface:Dictionary=hit.surface
 if surface.node.name!="Dress" or surface.surface_index!=1:return false
 var first:int=hit.face
 var weights:Vector3=hit.bary
 var bind_point:Vector3=surface.vertices[surface.indices[first]]*weights.x
 bind_point+=Vector3(surface.vertices[surface.indices[first+1]])*weights.y
 bind_point+=Vector3(surface.vertices[surface.indices[first+2]])*weights.z
 return in_strap(bind_point)

static func in_strap(point:Vector3)->bool:
 return point.y>=1.595 and absf(point.x)>=.085

static func nearby(picker, camera:Camera3D, screen:Vector2, primary:Dictionary,prepared:Array=[])->Dictionary:
 if contains_hit(primary):return primary
 if not primary.is_empty() and primary.surface.node.name not in ["Body","Dress"]:return primary
 var candidates:Array[Dictionary]=[]
 for s in picker.surfaces:
  if s.node.name!="Dress" or s.surface_index!=1 or not s.node.is_visible_in_tree():continue
  picker.update_surface(s)
  var cache:Dictionary={}
  for f in range(0,s.indices.size(),3):
   var ids:PackedInt32Array=s.indices
   var bind_center:Vector3=(s.vertices[ids[f]]+s.vertices[ids[f+1]]+s.vertices[ids[f+2]])/3.
   if not in_strap(bind_center):continue
   var triangle:=PackedVector2Array()
   for i in range(f,f+3):
    var vertex_id:=ids[i]
    if not cache.has(vertex_id):
     cache[vertex_id]=camera.unproject_position(picker.vertex(s,vertex_id))
    triangle.append(cache[vertex_id])
   if Geometry2D.point_is_inside_triangle(screen,triangle[0],triangle[1],triangle[2]):continue
   var centroid:Vector2=(triangle[0]+triangle[1]+triangle[2])/3.
   for i in 3:
    var edge:=Geometry2D.get_closest_point_to_segment(screen,triangle[i],triangle[(i+1)%3])
    var point:=edge.lerp(centroid,.15)
    var distance:=point.distance_squared_to(screen)
    if distance<=NEAR_PIXELS*NEAR_PIXELS:candidates.append({"screen":point,"distance":distance})
 candidates.sort_custom(func(a,b):return a.distance<b.distance)
 # Um raio por candidato confirma que cabelo, corpo e objetos não o ocluem.
 var checked:Array[Vector2]=[]
 var query:Array=picker.prepare_query() if prepared.is_empty() and not candidates.is_empty() else prepared
 for candidate in candidates:
  if checked.size()>=7:break
  var point:Vector2=candidate.screen
  if checked.any(func(previous:Vector2):return previous.distance_squared_to(point)<2.25):continue
  checked.append(point)
  var hit:Dictionary=picker.cast(camera,point,0,query)
  if contains_hit(hit):return hit
 return primary
