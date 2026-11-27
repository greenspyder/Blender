extends Node3D
# Rede de partículas com distância de repouso, diagonais e dobra de dois segmentos.
const Picker=preload("res://direct/surface_picker.gd")
const Palette=preload("res://direct/fabric_palette.gd")
@export var fabric_profiles:Array[RoseFabricProfile]=[
 preload("res://direct/fabrics/light_cotton.tres"),
 preload("res://direct/fabrics/heavy_cotton.tres"),
 preload("res://direct/fabrics/silk.tres"),
 preload("res://direct/fabrics/stretch.tres"),
]
var fabric:RoseFabricProfile
var palette
var fabric_popup:PopupPanel
var fabric_button:Button
var particle_area:=PackedFloat32Array()
var recovery_share:=PackedFloat32Array()
var multiplier:=PackedFloat32Array()
var prefs=preload("res://direct/preferences.gd").new()
var meter=preload("res://direct/physics_meter.gd").new()
var unchanged_ticks:=0
var rendered_indicators:=true
var dirty:=true
var seen_revision:=-1
var inverse_mass:=PackedFloat32Array()
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

func add_edge(a:int,b:int,weight:float,bending:=false)->void:
 var ma:=inverse_mass[a]
 var mb:=inverse_mass[b]
 if ma+mb>0.:
  edges.append([a,b,rest[a].distance_to(rest[b]),weight,bending])

func sample_grid(name_:String,cols:int,rows:int,center:float,width:float,handle:bool)->void:
 var start:=pos.size()
 var first_edge:=edges.size()
 for y in rows:
  for x in cols:
   var u:=float(x)/(cols-1);var v:=float(y)/(rows-1)
   var p:=Vector3(center+(u-.5)*width,.38-v*.70,.015*sin(u*PI))
   if handle:p=Vector3(center-cos(v*PI)*.225+(u-.5)*width,-.30+sin(v*PI)*.56,.06)
   var i:=pos.size();pos.append(p);rest.append(p);last.append(p)
   if (handle and y in [0,rows-1]) or (not handle and y==0 and (cols<=3 or x in [0,cols-1])):pinned[i]=true
   inverse_mass.append(0. if pinned.has(i) else 1.)
   recovery_share.append(2.2 if handle else 1.)
   if x>0:add_edge(i,i-1,1)
   if y>0:add_edge(i,i-cols,1)
   if x>1:add_edge(i,i-2,.70,true)
   if y>1:add_edge(i,i-2*cols,.70,true)
   if x>0 and y>0:
    add_edge(i,i-cols-1,.62);add_edge(i-1,i-cols,.62)
    indices.append_array(PackedInt32Array([i-cols-1,i-cols,i,i-cols-1,i,i-1]))
    groups.append(name_);groups.append(name_)
 var resistance:=1.25 if name_=="Cordão" else (.85 if name_=="Amostra" else 1.)
 for e in range(first_edge,edges.size()):edges[e][3]*=resistance
 assert(pos.size()==start+rows*cols)

func _ready()->void:
 sample_grid("Amostra",8,9,-.63,.48,false)
 sample_grid("Cordão",2,14,-.255,.020,false)
 sample_grid("Tira",3,12,0,.10,false)
 sample_grid("Alça de bolsa",3,15,.62,.055,true)
 compute_particle_areas()
 palette=Palette.new(fabric_profiles)
 set_fabric(palette.variants[palette.active])
 add_bench_lights()
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
 fabric_popup=palette.panel(panel,set_fabric)
 for title in ["Rosé","Ajustes","Reiniciar",fabric.label]:
  var btn:=Button.new();btn.text=title;btn.custom_minimum_size=Vector2(90,48);bar.add_child(btn)
  match title:
   "Rosé":btn.pressed.connect(func():get_tree().change_scene_to_file("res://direct_touch.tscn"))
   "Ajustes":btn.pressed.connect(func():holds.clear();popup.popup_centered_ratio(.8))
   "Reiniciar":btn.pressed.connect(reset_fabric)
   _:
    fabric_button=btn
    btn.pressed.connect(func():holds.clear();fabric_popup.popup_centered_ratio(.8))
 panel.add_child(label);label.position=Vector2(10,66);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 meter.attach(panel,Vector2(10,94))
 var layout:=func():
  bar.size.x=maxf(100.,panel.size.x-16.)
  label.position.y=bar.position.y+maxf(48.,bar.get_combined_minimum_size().y)+10.
  meter.caption.position.y=label.position.y+27.
 panel.resized.connect(layout)
 layout.call()
 rebuild()

func compute_particle_areas()->void:
 particle_area.resize(rest.size())
 for face in range(0,indices.size(),3):
  var a:=indices[face]
  var b:=indices[face+1]
  var c:=indices[face+2]
  var contribution:=(rest[b]-rest[a]).cross(rest[c]-rest[a]).length()/6.
  particle_area[a]+=contribution
  particle_area[b]+=contribution
  particle_area[c]+=contribution
 multiplier.resize(edges.size())

func set_fabric(profile:RoseFabricProfile)->void:
 fabric=profile
 for i in inverse_mass.size():
  var mass:=maxf(.00001,particle_area[i]*fabric.density*.001)
  inverse_mass[i]=0. if pinned.has(i) else 1./mass
 fabric.apply_material(mat)
 if fabric_button:fabric_button.text=fabric.label
 unchanged_ticks=0
 dirty=true

func add_bench_lights()->void:
 var world:=WorldEnvironment.new()
 world.environment=Environment.new()
 world.environment.background_mode=Environment.BG_COLOR
 world.environment.background_color=Color("#24232f")
 world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color=Color("#f0e8ef")
 world.environment.ambient_light_energy=.58
 add_child(world)
 var key:=DirectionalLight3D.new()
 key.rotation_degrees=Vector3(-32.,-22.,0.)
 key.light_color=Color("#ffeadb")
 key.light_energy=.95
 add_child(key)
 var fill:=DirectionalLight3D.new()
 fill.rotation_degrees=Vector3(18.,42.,0.)
 fill.light_color=Color("#d1dfff")
 fill.light_energy=.45
 add_child(fill)

func reset_fabric()->void:
 holds.clear()
 pos=rest.duplicate()
 last=rest.duplicate()
 unchanged_ticks=0
 dirty=true

func pick(screen:Vector2)->Dictionary:
 var offsets:=Picker.selection_offsets(float(prefs.values["Tolerância (px)"]))
 for off in offsets:
  var o:=cam.project_ray_origin(screen+Vector2(off));var d:=cam.project_ray_normal(screen+Vector2(off))
  var solid:Variant=Geometry3D.segment_intersects_sphere(o,o+d*8,OBSTACLE,RADIUS)
  var nearest:=INF if solid.is_empty() else o.distance_squared_to(solid[0])
  var hit:Dictionary={}
  for f in range(0,indices.size(),3):
   var a:=pos[indices[f]];var b:=pos[indices[f+1]];var c:=pos[indices[f+2]]
   var cross:=Picker.intersection(o,d,a,b,c)
   if cross.x<0:continue
   var p:=o+d*cross.x
   if o.distance_squared_to(p)>=nearest:continue
   nearest=o.distance_squared_to(p)
   hit={"f":f,"base":p,"target":p,"bary":Vector3(1-cross.y-cross.z,cross.y,cross.z),"age":0.,"eligible":true,"start":screen,"screen":screen,"name":groups[f/3]}
  if not hit.is_empty():return hit
 return {}

func _input(e:InputEvent)->void:
 if not is_node_ready() or popup.visible or fabric_popup.visible:return
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
  meter.register_input()
  holds[id].screen=screen
  if holds[id].age<prefs.values["Pressão longa (s)"] and screen.distance_to(holds[id].start)>prefs.values["Precisão do gesto (px)"]:holds[id].eligible=false
 elif press and not bar.get_global_rect().has_point(screen):
  meter.register_input()
  var hit:=pick(screen)
  if not hit.is_empty():
   holds[id]=hit
   unchanged_ticks=0
   message="Contato · "+str(hit.name)

func simulate(h:float)->void:
 var relative_mass:=sqrt(float(prefs.values["Massa (kg)"])/.5*fabric.density/130.)
 var damping:=exp(-fabric.damping*float(prefs.values["Amortecimento"])/.80*h)
 var gravity:=Vector3.DOWN*(9.81*fabric.gravity_scale)
 for i in pos.size():
  if inverse_mass[i]==0.:continue
  var old:=pos[i]
  var recovery:Vector3=(rest[i]-old)*float(prefs.values["Recuperação"])*6.8*recovery_share[i]
  pos[i]+=(old-last[i]).limit_length(.030)*damping+(gravity+recovery)*h*h
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
 var interaction:=clampf(58./float(prefs.values["Rigidez"])*float(prefs.values["Elasticidade"]),.55,2.2)
 var stretch_alpha:=fabric.stretch*interaction/(h*h)
 var bend_alpha:=fabric.bend/(h*h)
 multiplier.fill(0.)
 for iteration in 4:
  for hold in holds.values():
   if not hold.eligible or hold.age<prefs.values["Pressão longa (s)"]:continue
   var contact:=Vector3.ZERO;var divisor:=0.
   for j in 3:
    var i:=indices[int(hold.f)+j];var w:float=hold.bary[j]
    contact+=pos[i]*w
    divisor+=w*w if inverse_mass[i]>0. else 0.
   if divisor<.0001:continue
   for j in 3:
    var i:=indices[int(hold.f)+j]
    var correction:=((Vector3(hold.target)-contact)*float(hold.bary[j])/divisor*.45)
    var maximum:=.0047/maxf(.68,relative_mass)*float(prefs.values["Força máxima"])/.85
    if inverse_mass[i]>0.:pos[i]+=correction.limit_length(maximum)
  for e in edges.size():
   var edge:Array=edges[e]
   var a:int=edge[0]
   var b:int=edge[1]
   var delta:=pos[b]-pos[a]
   var length:=delta.length()
   if length<.00001:continue
   var alpha:float=(bend_alpha if edge[4] else stretch_alpha)/float(edge[3])
   if not edge[4] and length>float(edge[2])*(1.+fabric.strain_limit):
    alpha*=.035
   var lambda_change:=(-(length-float(edge[2]))-alpha*multiplier[e])/(inverse_mass[a]+inverse_mass[b]+alpha)
   multiplier[e]+=lambda_change
   var correction:=delta/length*lambda_change
   pos[a]-=correction*inverse_mass[a]
   pos[b]+=correction*inverse_mass[b]
   if not edge[4] and length>float(edge[2])*(1.+fabric.strain_limit):
    limit_extension(a,b,float(edge[2])*(1.+fabric.strain_limit))
  for i in pos.size():
   if inverse_mass[i]==0.:continue
   var away:=pos[i]-OBSTACLE
   if away.length()<RADIUS+.006 and away.length_squared()>.000001:
    pos[i]=OBSTACLE+away.normalized()*(RADIUS+.006)
   pos[i].y=maxf(pos[i].y,-.55)
 # Limite o escorregamento no contato sem amortecer o tecido no ar.
 for i in pos.size():
  if inverse_mass[i]==0.:continue
  var away:=pos[i]-OBSTACLE
  var normal:=Vector3.ZERO
  if pos[i].y<=-.5499:normal=Vector3.UP
  elif away.length_squared()<(RADIUS+.0061)**2:normal=away.normalized()
  if normal!=Vector3.ZERO:
   var displacement:=pos[i]-last[i]
   var tangent:=displacement.slide(normal)*(1.-fabric.friction*.46)
   last[i]=pos[i]-tangent-normal*maxf(0.,displacement.dot(normal))

func limit_extension(a:int,b:int,maximum:float)->void:
 var delta:=pos[b]-pos[a]
 var length:=delta.length()
 if length<=maximum:return
 var correction:=delta*((length-maximum)/length/(inverse_mass[a]+inverse_mass[b]))
 pos[a]+=correction*inverse_mass[a]
 pos[b]-=correction*inverse_mass[b]

func rebuild()->void:
 var normals:=PackedVector3Array()
 normals.resize(pos.size())
 for f in range(0,indices.size(),3):
  var a:=indices[f]
  var b:=indices[f+1]
  var c:=indices[f+2]
  var normal:=(pos[c]-pos[a]).cross(pos[b]-pos[a])
  normals[a]+=normal
  normals[b]+=normal
  normals[c]+=normal
 for i in normals.size():normals[i]=normals[i].normalized() if normals[i].length_squared()>1.e-12 else Vector3.BACK
 visual.clear_surfaces()
 visual.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat)
 for k in indices.size():
  var i:=indices[k]
  var color:=Color("#e4a6b5") if rest[i].x<-.3 else (Color("#9acfc9") if rest[i].x<.3 else Color("#e3bc80"))
  if absf(rest[i].x+.255)<.02:color=Color("#b1a4d9")
  if prefs.indicators and not holds.is_empty():color=color.lerp(Color.CRIMSON,minf(.28,pos[i].distance_to(rest[i])*.42))
  visual.surface_set_color(color)
  visual.surface_set_normal(normals[i])
  visual.surface_add_vertex(pos[i])
 visual.surface_end()

func _physics_process(dt:float)->void:
 var start:=meter.begin_tick()
 if seen_revision!=prefs.revision:
  seen_revision=prefs.revision
  unchanged_ticks=0
 if unchanged_ticks<18 or not holds.is_empty():
  tick_left+=minf(.05,dt)
  while tick_left>=1./120:
   simulate(1./120)
   tick_left-=1./120
  var max_offset:=0.
  for i in pos.size():max_offset=maxf(max_offset,pos[i].distance_squared_to(last[i]))
  unchanged_ticks=unchanged_ticks+1 if holds.is_empty() and max_offset<1.e-10 else 0
  dirty=true
 meter.end_tick(start)

func _process(_dt:float)->void:
 if rendered_indicators!=prefs.indicators:
  rendered_indicators=prefs.indicators
  dirty=true
 if dirty:
  rebuild()
  dirty=false
 label.visible=prefs.indicators
 label.text=message

func _notification(what:int)->void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:holds.clear()
