extends SceneTree
const Solver=preload("res://cloth/xpbd.gd")
var failures:=PackedStringArray()
func _initialize()->void:call_deferred("run")
func run()->void:
    var travel:Array=[]
    for friction in [.02,.9]:
        var s:=Solver.new()
        s.build(PackedVector3Array([Vector3(-.1,.05,0),Vector3(.1,.05,0),Vector3(0,.05,.2)]),PackedInt32Array([0,1,2]))
        s.material.friction=friction
        s.velocity.fill(Vector3(.7,0,0))
        for i in 180:s.step(1./120.,[{"kind":"plane","center":Vector3.ZERO,"normal":Vector3.UP}])
        travel.append(s.position[1].x-.1)
        for p in s.position:
            if p.y<.0039 or not p.is_finite():failures.append("contato do piso")
    if travel[0]<=travel[1]+.015:failures.append("atrito altera escorregamento")
    var colliders:Array=[
        {"kind":"sphere","center":Vector3.ZERO,"transform":Transform3D.IDENTITY,"inverse":Transform3D.IDENTITY,"radius":.4,"r":.3},
        {"kind":"capsule","center":Vector3.ZERO,"transform":Transform3D.IDENTITY,"inverse":Transform3D.IDENTITY,"radius":.8,"half":.3,"r":.2},
        {"kind":"box","center":Vector3.ZERO,"transform":Transform3D.IDENTITY,"inverse":Transform3D.IDENTITY,"radius":.6,"half":Vector3.ONE*.25}]
    for c in colliders:
        var s:=Solver.new()
        s.build(PackedVector3Array([Vector3(-.05,.05,.02),Vector3(.05,.05,.02),Vector3(0,.1,.02)]),PackedInt32Array([0,1,2]))
        for i in 120:s.step(1./120.,[c])
        for p in s.position:
            if Solver.project(p,c,.0039).distance_to(p)>.00001:failures.append("penetração em "+c.kind)
    print("Contato e atrito · deslocamentos ",travel," · falhas ",failures)
    quit(0 if failures.is_empty() else 1)
