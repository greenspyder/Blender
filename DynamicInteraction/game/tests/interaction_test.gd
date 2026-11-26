extends SceneTree

const DEMO = preload("res://demo.tscn")

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)


func _button(position: Vector2, pressed: bool, index := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = index
	event.pressed = pressed
	root.push_input(event)


func _motion(position: Vector2, relative := Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	root.push_input(event)


func _run() -> void:
	root.size = Vector2i(960, 720)
	var demo := DEMO.instantiate()
	root.add_child(demo)
	await process_frame
	var tray_screen: Vector2 = demo.camera.unproject_position(demo.tray.global_position)
	var mouth_screen: Vector2 = demo.camera.unproject_position(demo.anchor.global_position)

	_button(tray_screen, true)
	_expect(demo.state == demo.State.DRAGGING, "O clique deve pegar o pirulito.")
	_motion(mouth_screen + Vector2(42.0, 0.0))
	demo._process(0.2)
	_expect(demo.opening > 0.0 and demo.opening < 1.0, "A boca deve reagir antes do encaixe.")
	_motion(mouth_screen)
	_expect(demo.cue.visible, "O ponto de encaixe deve ser indicado.")
	_button(mouth_screen, false)
	demo._process(0.2)
	_expect(demo.state == demo.State.ATTACHED, "Soltar no alvo deve encaixar.")
	_expect(is_equal_approx(demo.face.get_blend_shape_value(demo._mouth_index), 1.0), "O encaixe deve abrir a boca.")

	var initial: Vector3 = demo.anchor.global_position
	_button(Vector2(680, 300), true, MOUSE_BUTTON_RIGHT)
	_motion(Vector2(610, 300), Vector2(-70, 0))
	_button(Vector2(610, 300), false, MOUSE_BUTTON_RIGHT)
	_expect(not demo.anchor.global_position.is_equal_approx(initial), "O botão direito deve girar o retrato.")
	_expect(demo.candy.global_position.is_equal_approx(demo.anchor.global_position), "O objeto deve acompanhar o alvo.")

	mouth_screen = demo.camera.unproject_position(demo.anchor.global_position)
	_button(mouth_screen, true)
	_motion(Vector2(790, 450))
	_button(Vector2(790, 450), false)
	demo._process(0.2)
	_expect(demo.state == demo.State.TRAY and is_zero_approx(demo.opening), "Retirar deve voltar à bandeja e fechar a boca.")

	demo.action.pressed.emit()
	_expect(demo.state == demo.State.ATTACHED, "O botão deve oferecer o pirulito.")
	demo.reset_demo()
	_expect(demo.state == demo.State.TRAY and is_equal_approx(demo.rose.rotation.y, demo._start_angle), "Reiniciar deve restaurar a pose.")

	demo._blink_time = 3.8
	demo._process(0.0)
	_expect(demo._blink_meshes.size() == 4, "Rosto, olhos e os dois brilhos devem ter morphs de piscada.")
	for mesh in demo._blink_meshes:
		_expect(is_equal_approx(mesh.get_blend_shape_value(mesh.find_blend_shape_by_name(&"blink_l")), 1.0), "A piscada deve mover todas as malhas juntas.")

	if not failed:
		print("PASSOU: pegar, aproximar, encaixar, girar, retirar, botão, reiniciar e piscada sincronizada.")
	quit(1 if failed else 0)
