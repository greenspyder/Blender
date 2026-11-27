extends SceneTree
const Accessory=preload("res://cloth/accessory.gd")
const Profile=preload("res://cloth/material_profile.gd")
var failures:=PackedStringArray()
func _initialize()->void:call_deferred("run")
func check(ok:bool,title:String)->void:
    if not ok:failures.append(title)
func run()->void:
    var end_positions:Array=[]
    for hz in [30,60,120]:
        var cloth:=Accessory.new();root.add_child(cloth);cloth.build(Vector3(0,1,0),1.)
        var s=cloth.solver
        var initial:Vector3=s.position[s.position.size()-1]
        var maximum:=0.
        var colliders:Array=[{"kind":"plane","center":Vector3(0,.15,0),"normal":Vector3.UP}]
        for tick in hz*5:
            for step in 120/hz:s.step(1./120.,colliders)
            maximum=maxf(maximum,s.max_strain())
        print("Pano %d FPS · extensão pico %.4f · velocidade final %.4f"%[hz,maximum,s.peak_speed])
        check(s.position[-1].distance_to(initial)>.02,"gravidade produz acomodação")
        check(maximum<.25,"extensão limitada")
        for p in s.position:check(p.is_finite() and p.y>=.1539,"sem penetração do piso")
        var before:PackedVector3Array=s.position.duplicate()
        var f:int=s.triangles.size()-3
        s.begin_hold(f,Vector3(.3,.3,.4),s.position[-1]+Vector3(.15,.16,.22))
        for tick in 120:s.step(1./120.,colliders)
        var moved:=0
        for i in s.position.size():
            if s.position[i].distance_to(before[i])>.01:moved+=1
        check(moved>10,"força se propaga além do triângulo tocado")
        check(Vector3(s.hold.lambda).length()<=s.material.grab_force/(120.*120.)+.000001,"limite de força no vínculo")
        s.release()
        for tick in 600:s.step(1./120.,colliders)
        check(s.peak_speed<.06,"acomoda após soltar")
        end_positions.append(s.position.duplicate())
        cloth.free()
    check(end_positions[0][-1].distance_to(end_positions[2][-1])<.001,"independência do FPS com passos físicos fixos")
    for index in 4:
        var cloth:=Accessory.new();root.add_child(cloth);cloth.build(Vector3(0,1,0),1.)
        cloth.solver.set_material(Profile.preset(index))
        for tick in 360:cloth.solver.step(1./120.)
        check(cloth.solver.max_strain()<.5,"perfil estável %d"%index)
        cloth.free()
    print("Cloth XPBD · falhas ",failures.size()," ",failures)
    quit(0 if failures.is_empty() else 1)
