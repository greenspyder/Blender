extends RefCounted

var waiting_since:=0
var input_ms:=-1.
var scene_average:=0.
var caption:Label
var next_refresh:=0

func attach(overlay:Control,position:Vector2)->void:
 caption=Label.new()
 caption.position=position
 caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
 overlay.add_child(caption)

func register_input()->void:
 # Da chegada do evento no jogo ao próximo tick, sem contar o driver da tela.
 if waiting_since==0:waiting_since=Time.get_ticks_usec()

func begin_tick()->int:
 var now:=Time.get_ticks_usec()
 if waiting_since!=0:
  input_ms=(now-waiting_since)*.001
  waiting_since=0
 return now

func end_tick(start:int)->void:
 var now:=Time.get_ticks_usec()
 scene_average=lerpf(scene_average,(now-start)*.001,.10)
 if not caption.visible or now<next_refresh:return
 next_refresh=now+250000
 var global_ms:=1000.*Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
 var input_text:="—" if input_ms<0. else "%.1f ms"%input_ms
 caption.text="%d FPS · Física %.2f ms\nCena %.2f ms · Evento → tick %s"%[Engine.get_frames_per_second(),global_ms,scene_average,input_text]
