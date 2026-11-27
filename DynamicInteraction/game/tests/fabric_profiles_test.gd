extends SceneTree
const Palette=preload("res://direct/fabric_palette.gd")
var bench
var bad:=0
func _initialize()->void:call_deferred("run")

func check(ok:bool,title:String)->void:
 if not ok:
  bad+=1
  push_error(title)

func ticks(count:int)->void:
 for i in count:bench.simulate(1./120.)

func choose_patch()->Dictionary:
 for f in range(0,bench.indices.size(),3):
  if bench.groups[f/3]!="Amostra":continue
  var point:Vector3=(bench.pos[bench.indices[f]]+bench.pos[bench.indices[f+1]]+bench.pos[bench.indices[f+2]])/3.
  if point.y>.11 or point.y<.01:continue
  var screen:Vector2=bench.cam.unproject_position(point)
  var hit:Dictionary=bench.pick(screen)
  if hit.get("name")=="Amostra":return hit
 return {}

func max_strain()->float:
 var maximum:=0.
 for edge in bench.edges:
  if edge[4] or bench.rest[edge[0]].x>-.32:continue
  maximum=maxf(maximum,bench.pos[edge[0]].distance_to(bench.pos[edge[1]])/float(edge[2])-1.)
 return maximum

func run()->void:
 bench=load("res://direct/fabric.tscn").instantiate()
 root.add_child(bench)
 await process_frame
 bench.set_physics_process(false)
 var measurements:Array[float]=[]
 var output:Array=[]
 for profile in bench.palette.variants:
  bench.reset_fabric()
  bench.set_fabric(profile)
  ticks(420)
  check(is_equal_approx(bench.mat.roughness,profile.roughness) and is_equal_approx(bench.mat.metallic_specular,profile.specular),"material sincronizado "+profile.label)
  var hit:=choose_patch()
  check(not hit.is_empty(),"seleção de "+profile.label)
  if hit.is_empty():continue
  bench.holds[1]=hit
  ticks(52)
  hit.screen=hit.start+Vector2(130,23)
  ticks(72)
  var strain:=max_strain()
  measurements.append(strain)
  var coords:Array=[]
  for p:Vector3 in bench.pos:coords.append([p.x,p.y,p.z])
  output.append([profile.label,profile.roughness,profile.specular,coords])
  bench.holds.clear()
  var start:=Time.get_ticks_usec()
  ticks(410)
  var duration:=(Time.get_ticks_usec()-start)/410000.
  var speed:=0.
  for i in bench.pos.size():
   var p:Vector3=bench.pos[i]
   check(p.is_finite() and p.y>=-.5501,"colisão e finitude "+profile.label)
   if not bench.pinned.has(i):
    check(p.distance_to(bench.OBSTACLE)>=bench.RADIUS-.002,"esfera não é atravessada "+profile.label)
   else:
    check(p==bench.rest[i],"pino imóvel "+profile.label)
   speed=maxf(speed,p.distance_to(bench.last[i])*120.)
  check(speed<.16,"dissipação de movimento "+profile.label)
  print("%s · massa %.0f g/m² · extensão máxima %.1f%% · resíduo %.3f m/s · CPU média %.3f ms/subpasso"%[profile.label,profile.density,strain*100.,speed,duration])
 if measurements.size()==4:
  check(measurements[3]>measurements[0]*1.27 and measurements[0]<.23,"elástico cede mais que algodão, sem estiramento excessivo no algodão")
 var temporary:="user://rose_fabrics_test_%d.cfg"%Time.get_ticks_usec()
 var config:=Palette.new(bench.fabric_profiles,temporary)
 config.active=2
 config.variants[2].roughness=.57
 check(config.save()==OK,"salva ajustes de cada tecido")
 var loaded:=Palette.new(bench.fabric_profiles,temporary)
 check(loaded.active==2 and is_equal_approx(loaded.variants[2].roughness,.57) and is_equal_approx(loaded.variants[0].roughness,.91),"carrega ajuste individual sem alterar outro perfil")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty():FileAccess.open(args[0],FileAccess.WRITE).store_string(JSON.stringify([Array(bench.indices),Array(bench.groups),output]))
 print("Perfis de tecidos · falhas: ",bad)
 quit(bad)
