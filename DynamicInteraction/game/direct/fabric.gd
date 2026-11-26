extends Node3D
# Rede de partículas com distância de repouso, diagonais e dobra de dois segmentos.
var prefs=preload("res://direct/preferences.gd").new()
var pos:=PackedVector3Array()
var last:=PackedVector3Array()
var rest:=PackedVector3Array()
var edges:Array=[]
var pinned:Dictionary={}
var indices:=PackedInt32Array()
var groups:Array[String]=[]
var holds:Dictionary={}
var visual:=ImmediateMesh.new()
var mat:=StandardMaterial3D.new()
var cam:=Camera3D.new()
var bar:=HFlowContainer.new()
var label:=Label.new()
var popup:PopupPanel
const OBSTACLE=Vector3(0,-.22,.02)
const RADIUS=.19
var tick_left:=0.
var message:="Toque no tecido, mantenha e arraste."

func add_edge(a:int,b:int,weight:float)->void:
 edges.append([a,b,rest[a].distance_to(rest[b]),weight])

func sample_grid(name_:String,cols:int,rows:int,center:float,width:float,handle:bool)->void:
 var start:=pos.size()
 for y in rows:
  for x in cols:
   var u:=float(x)/(cols-1);var v:=float(y)/(rows-1)
   var p:=Vector3(center+(u-.5)*width,.38-v*.70,.015*sin(u*PI))
   if handle:p=Vector3(center-cos(v*PI)*.225+(u-.5)*width,-.30+sin(v*PI)*.56,.06)
   var i:=pos.size();pos.append(p);rest.append(p);last.append(p)
   if (handle and y in [0,rows-1]) or (not handle and y==0 and (cols<=3 or x in [0,cols-1])):pinned[i]=true
   if x>0:add_edge(i,i-1,1)
   if y>0:add_edge(i,i-cols,1)
   if x>1:add_edge(i,i-2,.32)
   if y>1:add_edge(i,i-2*cols,.32)
   if x>0 and y>0:
    add_edge(i,i-cols-1,.62);add_edge(i-1,i-cols,.62)
    indices.append_array(PackedInt32Array([i-cols-1,i-cols,i,i-cols-1,i,i-1]))
    groups.append(name_);groups.append(name_)
 assert(pos.size()==start+rows*cols)

func _ready()->void:
 sample_grid("Amostra",8,9,-.63,.48,false)
 sample_grid("Tira",3,12,0,.10,false)
 sample_grid("Alça de bolsa",3,15,.62,.055,true)
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.vertex_color_use_as_albedo=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 var mesh:=MeshInstance3D.new();mesh.mesh=visual;add_child(mesh)
 var obstacle:=MeshInstance3D.new();obstacle.mesh=SphereMesh.new()
 obstacle.mesh.radius=RADIUS;obstacle.mesh.height=2*RADIUS
 var om:=StandardMaterial3D.new();om.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;om.albedo_color=Color("#665d77")
 obstacle.material_override=om;add_child(obstacle);obstacle.position=OBSTACLE
 add_child(cam);cam.position=Vector3(0,0,2.6);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.keep_aspect=Camera3D.KEEP_WIDTH;cam.size=2.;cam.current=true
 var hud:=CanvasLayer.new();add_child(hud)
 var panel:=Control.new();hud.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.add_child(bar);bar.position=Vector2(8,8);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 popup=prefs.panel(panel)
 for title in ["Rosé","Ajustes","Reiniciar"]:
  var btn:=Button.new();btn.text=title;btn.custom_minimum_size=Vector2(90,48);bar.add_child(btn)
  match title:
   "Rosé":btn.pressed.connect(func():get_tree().change_scene_to_file("res://direct_touch.tscn"))
   "Ajustes":btn.pressed.connect(func():holds.clear();popup.popup_centered_ratio(.8))
   "Reiniciar":btn.pressed.connect(func():holds.clear();pos=rest.duplicate();last=rest.duplicate())
 panel.add_child(label);label.position=Vector2(10,66);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 rebuild()

func pick(screen:Vector2)->Dictionary:
 var offsets:=[Vector2.ZERO]
 for i in 8:offsets.append(Vector2.RIGHT.rotated(i*TAU/8)*float(prefs.values["Tolerância (px)"]))
 for off in offsets:
  var o:=cam.project_ray_origin(screen+Vector2(off));var d:=cam.project_ray_normal(screen+Vector2(off))
  var solid:Variant=Geometry3D.segment_intersects_sphere(o,o+d*8,OBSTACLE,RADIUS)
  var nearest:=INF if solid.is_empty() else o.distance_squared_to(solid[0])
  var hit:Dictionary={}
  for f in range(0,indices.size(),3):
   var a:=pos[indices[f]];var b:=pos[indices[f+1]];var c:=pos[indices[f+2]]
   var p:Variant=Geometry3D.ray_intersects_triangle(o,d,a,b,c)
   if p==null or o.distance_squared_to(p)>=nearest:continue
   nearest=o.distance_squared_to(p)
   hit={"f":f,"base":p,"target":p,"bary":Geometry3D.get_triangle_barycentric_coords(p,a,b,c),"age":0.,"eligible":true,"start":screen,"screen":screen,"name":groups[f/3]}
  if not hit.is_empty():return hit
 return {}

func _input(e:InputEvent)->void:
 if not is_node_ready() or popup.visible:return
 var id:int
 var screen:Vector2
 var press:=false;var release:=false
 if e is InputEventScreenTouch or e is InputEventScreenDrag:
  id=e.index;screen=e.position
  if e is InputEventScreenTouch:press=e.pressed and not e.canceled;release=not press
 elif e is InputEventMouse and e.device!=InputEvent.DEVICE_ID_EMULATION:
  id=-1;screen=e.position
  if e is InputEventMouseButton:
   if e.button_index!=MOUSE_BUTTON_LEFT:return
   press=e.pressed;release=not press
 else:return
 if release:
  if holds.erase(id):message="Solto"
 elif holds.has(id):
  holds[id].screen=screen
  if holds[id].age<prefs.values["Pressão longa (s)"] and screen.distance_to(holds[id].start)>prefs.values["Precisão do gesto (px)"]:holds[id].eligible=false
 elif press and not bar.get_global_rect().has_point(screen):
  var hit:=pick(screen)
  if not hit.is_empty():holds[id]=hit;message="Contato · "+str(hit.name)

func simulate(h:float)->void:
 var damping:=exp(-float(prefs.values["Amortecimento"])*5*h)
 for i in pos.size():
  if pinned.has(i):continue
  var old:=pos[i]
  var recovery:Vector3=(rest[i]-old)*float(prefs.values["Recuperação"])*14.
  pos[i]+=(old-last[i])*damping+(Vector3.DOWN*.95+recovery)*h*h
  last[i]=old
 for hold in holds.values():
  hold.age+=h
  var shift:Vector2=hold.screen-hold.start
  var screen:=cam.unproject_position(hold.base)+shift
  var p:Variant=Plane(Vector3.BACK,hold.base).intersects_ray(cam.project_ray_origin(screen),cam.project_ray_normal(screen))
  var offset:Vector3=(p-Vector3(hold.base))*float(prefs.values["Sensibilidade"])
  var goal:Vector3=hold.base+offset.limit_length(.48*float(prefs.values["Força máxima"]))
  hold.target=Vector3(hold.target).lerp(goal,1-exp(-float(prefs.values["Suavização"])*h))
  if hold.eligible and hold.age>=prefs.values["Pressão longa (s)"]:
   message=("Limite · " if offset.length()>.48*float(prefs.values["Força máxima"]) else "Vinculado · ")+str(hold.name)
 var stiffness:=clampf(float(prefs.values["Rigidez"])/100/float(prefs.values["Elasticidade"]),.08,.95)
 for iteration in 4:
  for edge in edges:
   var a:int=edge[0];var b:int=edge[1];var delta:=pos[b]-pos[a];var length:=delta.length()
   if length<.00001:continue
   var count:=int(not pinned.has(a))+int(not pinned.has(b))
   if count==0:continue
   var correction:=delta*((length-float(edge[2]))/length*stiffness*float(edge[3])/count)
   if not pinned.has(a):pos[a]+=correction
   if not pinned.has(b):pos[b]-=correction
  for hold in holds.values():
   if not hold.eligible or hold.age<prefs.values["Pressão longa (s)"]:continue
   var contact:=Vector3.ZERO;var divisor:=0.
   for j in 3:
    var i:=indices[int(hold.f)+j];var w:float=hold.bary[j]
    contact+=pos[i]*w
    if not pinned.has(i):divisor+=w*w
   if divisor<.0001:continue
   for j in 3:
    var i:=indices[int(hold.f)+j]
    if not pinned.has(i):pos[i]+=(Vector3(hold.target)-contact).limit_length(.018)*float(hold.bary[j])/divisor*.45
  for i in pos.size():
   if pinned.has(i):continue
   var away:=pos[i]-OBSTACLE
   if away.length()<RADIUS+.006:pos[i]=OBSTACLE+away.normalized()*(RADIUS+.006)
   pos[i].y=maxf(pos[i].y,-.55)

func rebuild()->void:
 visual.clear_surfaces();visual.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat)
 for k in indices.size():
  var i:=indices[k]
  var color:=Color("#e4a6b5") if rest[i].x<-.3 else (Color("#9acfc9") if rest[i].x<.3 else Color("#e3bc80"))
  if prefs.indicators:color=color.lerp(Color.CRIMSON,minf(1.,pos[i].distance_to(rest[i])*2))
  visual.surface_set_color(color);visual.surface_add_vertex(pos[i])
 visual.surface_end()

func _physics_process(dt:float)->void:
 tick_left+=minf(.05,dt)
 while tick_left>=1./120:
  simulate(1./120);tick_left-=1./120
 rebuild();label.visible=prefs.indicators;label.text=message

func _notification(what:int)->void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:holds.clear()
