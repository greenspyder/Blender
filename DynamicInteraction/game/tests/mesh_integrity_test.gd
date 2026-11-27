extends SceneTree
const Picker=preload("res://direct/surface_picker.gd")
var lab
var body:MeshInstance3D
var before:Dictionary
var after:Dictionary
var edges:Dictionary={}
var hip_faces:Array[Vector3i]=[]
var failures:=0

func _initialize()->void:call_deferred("run")

func check(condition:bool,label_:String)->void:
 if not condition:
  failures+=1
  push_error(label_)

func capture(s:Dictionary)->PackedVector3Array:
 lab.picker.update_surface(s)
 var points:=PackedVector3Array()
 for i in s.vertices.size():points.append(lab.picker.vertex(s,i))
 return points

func metrics(points:PackedVector3Array)->Array[float]:
 var reference:PackedVector3Array=after.vertices
 var maximum:=0.
 var minimum:=INF
 var delta_area:=0.
 var rest_area:=0.
 for e:Vector2i in edges:
  var original:=reference[e.x].distance_to(reference[e.y])
  if original<.004:continue
  var ratio:=points[e.x].distance_to(points[e.y])/original
  maximum=maxf(maximum,ratio)
  minimum=minf(minimum,ratio)
 for tri in hip_faces:
  delta_area+=(points[tri.y]-points[tri.x]).cross(points[tri.z]-points[tri.x]).length()
  rest_area+=(reference[tri.y]-reference[tri.x]).cross(reference[tri.z]-reference[tri.x]).length()
 return [maximum,minimum,delta_area/rest_area]

func scenarios(label_:String)->void:
 var a:=metrics(capture(before))
 var b:=metrics(capture(after))
 print("%s · maior aresta antes %.3fx / depois %.3fx · menor %.3fx · área %.3fx"%[label_,a[0],b[0],b[1],b[2]])
 check(b[0]<1.27 and b[1]>.75 and b[2]>.89 and b[2]<1.13,"estabilidade do quadril: "+label_)
 if label_=="Braços elevados + inclinação":
  check(a[0]>2. and b[0]<1.15,"regressão do pico de peso removida")

func run()->void:
 lab=load("res://direct_touch.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab.set_physics_process(false)
 for s in lab.picker.surfaces:
  if s.node.name=="Body":
   after=s
   body=s.node
   break
 var model=load("res://assets/rig121.glb").instantiate()
 var original:MeshInstance3D=model.find_child("Body",true,false)
 var corrected:=body.mesh
 body.mesh=original.mesh
 var original_picker=Picker.new()
 original_picker.skeleton=lab.skeleton
 original_picker.register(body,0)
 before=original_picker.surfaces[0]
 body.mesh=corrected
 model.free()
 check(before.vertices==after.vertices and before.indices==after.indices and before.shapes==after.shapes.slice(0,before.shapes.size()),"topologia, posição de bind e morphs preservados")
 for i in after.vertices.size():
  var sum:=0.
  for j in range(i*4,i*4+4):sum+=after.weights[j]
  check(absf(sum-1.)<.0002,"pesos normalizados")
 for f in range(0,after.indices.size(),3):
  var tri:=Vector3i(after.indices[f],after.indices[f+1],after.indices[f+2])
  var hip_vertices:=0
  for j in 3:
   var p:Vector3=after.vertices[tri[j]]
   if p.y>=.80 and p.y<=1.245 and absf(p.x)<=.33:hip_vertices+=1
   var a:=tri[j]
   var b:=tri[(j+1)%3]
   var q:Vector3=after.vertices[b]
   if p.y>=.80 and p.y<=1.245 and q.y>=.80 and q.y<=1.245 and maxf(absf(p.x),absf(q.x))<=.33 and absf(p.x+q.x)*.5>=.13:
    edges[Vector2i(mini(a,b),maxi(a,b))]=true
  if hip_vertices==3:hip_faces.append(tri)
 check(edges.size()>500 and hip_faces.size()>100,"amostra lateral representativa")
 for i in 60:lab._physics_process(1./60.)
 scenarios("Repouso")
 lab.solver.wardrobe_lift=Vector2.ONE
 lab.solver.body_load=Vector3(.22,.08,-.1)
 for i in 60:lab.solver.solve(lab.skeleton,[],1./60.,1.)
 scenarios("Braços elevados + inclinação")
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty():
  var records:=[
   Array(capture(before)).map(func(v):return [v.x,v.y,v.z]),
   Array(capture(after)).map(func(v):return [v.x,v.y,v.z]),
   edges.keys().map(func(e):return [e.x,e.y])]
  FileAccess.open(args[0],FileAccess.WRITE).store_string(JSON.stringify(records))
 var spine:int=lab.skeleton.find_bone("Spine")
 var local:Quaternion=lab.skeleton.get_bone_pose_rotation(spine)
 lab.skeleton.set_bone_pose_rotation(spine,Quaternion(Vector3.UP,.16)*local)
 scenarios("Rotação de tronco aplicada")
 body.set_blend_shape_value(body.find_blend_shape_by_name("idle_knees"),1.)
 body.set_blend_shape_value(body.find_blend_shape_by_name("lean_left"),.55)
 body.set_blend_shape_value(body.find_blend_shape_by_name("yield_back"),.36)
 scenarios("Flexão visual dos joelhos + morphs")
 lab.solver.wardrobe_lift=Vector2.ZERO
 for i in 180:lab._physics_process(1./60.)
 scenarios("Recuperação")
 print("Integridade da malha · falhas: ",failures)
 quit(failures)
