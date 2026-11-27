class_name RoseFabricProfile
extends Resource

const PARAMETERS={
 "density":["Massa por área (g/m²)",45.,420.,1.],
 "stretch":["Complacência ao alongar (m/N)",.002,.24,.001],
 "bend":["Complacência à flexão (m/N)",.035,1.8,.005],
 "strain_limit":["Extensão antes do enrijecimento",.035,.65,.005],
 "damping":["Amortecimento (1/s)",.6,9.,.1],
 "friction":["Atrito tangencial",.02,.95,.01],
 "gravity_scale":["Escala de gravidade",.35,1.4,.01],
 "roughness":["Rugosidade",.2,1.,.01],
 "specular":["Reflexo especular",0.,.65,.01],
}

@export var label:="Algodão leve"
@export_range(45.,420.,1.) var density:=130.
@export_range(.002,.24,.001) var stretch:=.006
@export_range(.035,1.8,.005) var bend:=.34
@export_range(.035,.65,.005) var strain_limit:=.095
@export_range(.6,9.,.1) var damping:=3.7
@export_range(.02,.95,.01) var friction:=.52
@export_range(.35,1.4,.01) var gravity_scale:=1.
@export_range(.2,1.,.01) var roughness:=.91
@export_range(0.,.65,.01) var specular:=.13

func apply_material(material:StandardMaterial3D)->void:
 material.metallic=0.
 material.roughness=roughness
 material.metallic_specular=specular
 material.clearcoat_enabled=false
 material.diffuse_mode=BaseMaterial3D.DIFFUSE_LAMBERT
