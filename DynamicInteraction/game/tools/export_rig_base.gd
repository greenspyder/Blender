extends SceneTree
## Exporta uma cópia de trabalho vestida e em repouso a partir da bancada.

const Lab=preload("res://rig/full_body_lab.tscn")

func _initialize()->void:call_deferred("export")

func export()->void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=1 or args[0].get_extension().to_lower()!="glb":
  push_error("Informe o caminho de saída .glb após --")
  quit(1)
  return
 var destination:=ProjectSettings.globalize_path(args[0])
 if FileAccess.file_exists(destination):
  push_error("Escolha um arquivo novo. Já existe: "+destination)
  quit(1)
  return
 var lab:=Lab.instantiate()
 root.add_child(lab)
 lab.set_physics_process(false)
 if not lab.ready_to_pose:
  push_error("O perfil da bancada não pôde ser carregado.")
  quit(1)
  return
 lab.sk.reset_bone_poses()
 var document:=GLTFDocument.new()
 var state:=GLTFState.new()
 var result:=document.append_from_scene(lab.get_node("Model"),state)
 if result==OK:result=document.write_to_filesystem(state,destination)
 if result==OK:print("Base editável gravada em ",destination)
 else:push_error("Falha na exportação: "+error_string(result))
 quit(result)
