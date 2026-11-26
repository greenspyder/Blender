extends MeshInstance3D
## Camada interna de prova ajustada à mesma malha, ao skin e aos morphs do corpo.
const FABRIC_SHADER=preload("res://direct/base_layer.gdshader")
var body:MeshInstance3D
var fabric:=ShaderMaterial.new()

func configure(source:MeshInstance3D, rig:Skeleton3D)->void:
 body=source
 var original:ArrayMesh=source.mesh
 var fitted:=ArrayMesh.new()
 fitted.blend_shape_mode=original.blend_shape_mode
 for i in original.get_blend_shape_count():
  fitted.add_blend_shape(original.get_blend_shape_name(i))
 for i in original.get_surface_count():
  var arrays:=original.surface_get_arrays(i)
  var coords:=PackedVector2Array()
  for v:Vector3 in arrays[Mesh.ARRAY_VERTEX]:coords.append(Vector2(v.x,v.y))
  arrays[Mesh.ARRAY_TEX_UV2]=coords
  fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,original.surface_get_blend_shape_arrays(i))
 fabric.shader=FABRIC_SHADER
 material_override=fabric
 mesh=fitted
 skin=source.skin
 skeleton=get_path_to(rig)
 transform=source.transform
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 hide()

func set_layers(top:bool,bottom:bool)->void:
 fabric.set_shader_parameter("top_visible",top)
 fabric.set_shader_parameter("bottom_visible",bottom)
 visible=top or bottom
 copy_pose()

func copy_pose()->void:
 if not visible:return
 for i in body.mesh.get_blend_shape_count():
  set_blend_shape_value(i,body.get_blend_shape_value(i))
