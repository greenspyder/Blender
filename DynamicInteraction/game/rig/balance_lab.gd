extends "res://rig/full_body_lab.gd"

const Balance=preload("res://rig/ground_balance.gd")
const MOVES:=["Em pé","Caminhar","Agachar","Inclinar o tronco","Apoio esquerdo","Perturbar e recuperar"]
var balance:=Balance.new()
var movement:=0
var elapsed:=0.
var rest_soles:Dictionary={}
var simulated_time:=0.
var microseconds:=0
var ticks:=0
var mean_ms:=0.
var surface_angle:=0.

func _ready()->void:
 super()
 if not ready_to_pose:return
 profile=profile.duplicate()
 solver.profile=profile
 var leg_length:=0.
 for side in ["l","r"]:
  var thigh:=sk.get_bone_global_rest(solver.bones["thigh_"+side]).origin
  var shin:=sk.get_bone_global_rest(solver.bones["shin_"+side]).origin
  var foot:=sk.get_bone_global_rest(solver.bones["foot_"+side])
  rest_soles[side]=foot*profile.sole_offset
  leg_length+=(thigh.distance_to(shin)+shin.distance_to(foot.origin))*.5
 balance.configure(profile,leg_length)
 solver.calculate_mass()

func add_controls(content:VBoxContainer)->void:
 show_message(content,"Equilíbrio e contato com o chão")
 readout=show_message(content,"")
 dropdown(content,MOVES,func(index):movement=index;elapsed=0.)
 parameter(content,"Inclinação do piso (°)",-12.,12.,1.,0.,func(v):surface_angle=v;$Ground.rotation.x=deg_to_rad(v))
 parameter(content,"Resposta de sustentação (rad/s)",7.,24.,.5,profile.support_frequency,func(v):profile.support_frequency=v)
 parameter(content,"Amortecimento",.4,1.8,.05,profile.support_damping,func(v):profile.support_damping=v)
 parameter(content,"Compensação",0.,1.,.05,profile.balance_gain,func(v):profile.balance_gain=v)
 parameter(content,"Faixa de contato / perna",.01,.12,.005,profile.contact_band,func(v):profile.contact_band=v)
 parameter(content,"Câmera (°)",-180.,180.,1.,orbit,func(v):orbit=v;update_camera())
 for item in [["mass","Massa por segmento"],["bone","Esqueleto"],["ik","Alvos e apoios"]]:
  var key:String=item[0]
  checkbox(content,item[1],draw[key],func(v):draw[key]=v)
 var impulse:=Button.new()
 impulse.text="Impulso vertical"
 impulse.custom_minimum_size.y=42.
 content.add_child(impulse)
 impulse.pressed.connect(func():
  if not balance.contacts.is_empty():
   balance.velocity=sqrt(2.*balance.gravity*balance.length_scale*.18))
 var reset:=Button.new()
 reset.text="Reiniciar ensaio"
 content.add_child(reset)
 reset.pressed.connect(func():get_tree().reload_current_scene())

func parameter(content:VBoxContainer,title:String,minimum:float,maximum:float,increment:float,initial:float,changed:Callable)->void:
 var label:=show_message(content,"%s · %.3f"%[title,initial])
 var slider:=HSlider.new()
 slider.min_value=minimum
 slider.max_value=maximum
 slider.step=increment
 slider.value=initial
 slider.custom_minimum_size.y=32
 content.add_child(slider)
 slider.value_changed.connect(func(v):changed.call(v);label.text="%s · %.3f"%[title,v])

func path_z(time:float)->float:
 return sin(time*.74)*balance.length_scale*.65

func tick(dt:float)->void:
 elapsed+=dt
 var size_:float=balance.length_scale
 var cycle:=elapsed/.98
 var walk:=movement==1
 var z:=path_z(elapsed) if walk else 0.
 var travel:=Vector3(0.,-.018*size_,0.)
 var lean:=0.
 if walk:travel.x=sin(TAU*cycle)*size_*.065
 if movement==2:travel.y-=size_*.29*(.5-.5*cos(elapsed*2.))
 if movement==3:lean=17.*(.5-.5*cos(elapsed*1.8))
 if movement==4:travel.x=-size_*.13
 if movement==5:travel.x=size_*.55*sin(PI*clampf(elapsed/1.8,0.,1.))
 travel+=Vector3(balance.correction.x,0.,balance.correction.y)
 preview.travel=travel
 preview.lumbar=Vector3(lean,0.,-travel.x/size_*12.)
 preview.chest=Vector3(lean*.72,0.,0.)
 var current_z:float=$Model.position.z
 $Model.position=Vector3(0.,balance.height,move_toward(current_z,z,dt*size_*.75))
 var space:=get_world_3d().direct_space_state
 for i in 2:
  var side:String=["l","r"][i]
  var point:Vector3=sk.to_global(rest_soles[side])
  var swing:=false
  if walk:
   var phase:=fposmod(cycle+i*.5,1.)
   var start:=elapsed-phase*.98
   var step_z:=path_z(start+.28)
   if phase>.56:
    var u:=(phase-.56)/.44
    step_z=lerpf(step_z,path_z(start+1.26),smoothstep(0.,1.,u))
    point.y+=size_*.15*sin(PI*u)
    swing=u>.03 and u<.98
   point.z+=step_z-z
  if movement==4 and i==1:
   point.y+=size_*.18*smoothstep(0.,.4,elapsed)
   swing=true
  balance.sense(space,side,point,swing)
  var target:Dictionary=balance.targets[side]
  var rest_basis:=sk.get_bone_global_rest(solver.bones["foot_"+side]).basis
  var normal:Vector3=(sk.global_basis.inverse()*balance.foot_normal(side,dt)).normalized()
  var basis:=Basis(Quaternion(Vector3.UP,normal))*rest_basis
  solver.foot_goals[side]=Transform3D(basis,sk.to_local(target.point))
 solver.apply(preview,Vector2.ONE,dt)
 for side in ["l","r"]:
  balance.verify_support(side,sk.to_global(solver.pose("foot_"+side)*profile.sole_offset))
 balance.integrate(sk.to_global(solver.center_of_mass),dt)

func _physics_process(dt:float)->void:
 if not ready_to_pose:return
 var start:=Time.get_ticks_usec()
 # Subpassos mantêm a integração da mola estável com ticks de 30 a 120 Hz.
 var steps:=maxi(1,ceili(dt*120.-.00001))
 for i in steps:tick(dt/steps)
 microseconds+=Time.get_ticks_usec()-start
 ticks+=1
 simulated_time+=dt
 if simulated_time>=.25:
  mean_ms=float(microseconds)/ticks/1000.
  microseconds=0
  ticks=0
  simulated_time=0.
 interval+=dt
 if interval<.05:return
 interval=0.
 draw_pose()
 var report:=PackedStringArray()
 for i in 2:
  var side:String=["l","r"][i]
  var hit:Dictionary=balance.contacts.get(side,{})
  var limit:bool=solver.contacts.get(side,{}).get("limited",false)
  report.append("%s · %s · %.0f N%s"%[side.to_upper(),str(hit.body.name) if not hit.is_empty() else "livre",balance.loads[i]," · IK no limite" if limit else ""])
 readout.text="%s · %s\n%s\n%.2f ms/tick"%[balance.support_state,balance.balance_state,"\n".join(report),mean_ms]

func draw_pose()->void:
 # A projeção da bancada anterior usava y=0. Aqui o piso pode estar inclinado.
 draw.com=false
 draw.limit=false
 super()
 lines.surface_begin(Mesh.PRIMITIVE_LINES)
 var c:=solver.center_of_mass
 cross_mark(c,.032*balance.length_scale,COLORS.com)
 if draw.ik:
  for i in 2:
   var foot:Dictionary=balance.contacts.get(["l","r"][i],{})
   if foot.is_empty():continue
   var at:=sk.to_local(foot.point)
   var fraction:float=balance.loads[i]/(profile.mass_kg*balance.gravity)
   cross_mark(at,balance.length_scale*.022,COLORS.ik)
   line(at,sk.to_local(Vector3(foot.point)+Vector3.UP*balance.length_scale*.20*fraction),COLORS.com)
 if not balance.hull.is_empty():
  var p:=sk.to_local(balance.projection)
  line(c,p,COLORS.com)
  cross_mark(p,.034*balance.length_scale,COLORS.com)
  var hit:Dictionary=balance.contacts.values()[0]
  var normal:Vector3=hit.normal
  var origin:Vector3=hit.point
  var prior:=Vector3.ZERO
  for i in balance.hull.size():
   var a:Vector2=balance.hull[i]
   var y:=origin.y-(normal.x*(a.x-origin.x)+normal.z*(a.y-origin.z))/normal.y
   var point:=sk.to_local(Vector3(a.x,y+.003,a.y))
   if i>0:line(prior,point,COLORS.ik)
   prior=point
 lines.surface_end()
