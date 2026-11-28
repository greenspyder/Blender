extends RefCounted
## Superfície dinâmica com topologia fixa. O driver dummy não mantém escritas parciais.
var mesh:ArrayMesh
var index:int
var vertex_offset:int
var normal_offset:int
var stride:int
var packed_normals:=PackedByteArray()

func configure(target:ArrayMesh,surface:int,count_:int)->bool:
    mesh=target
    index=surface
    var format:=mesh.surface_get_format(index)
    if RenderingServer.mesh_surface_get_format_vertex_stride(format,count_)!=12:return false
    vertex_offset=RenderingServer.mesh_surface_get_format_offset(format,count_,Mesh.ARRAY_VERTEX)
    normal_offset=RenderingServer.mesh_surface_get_format_offset(format,count_,Mesh.ARRAY_NORMAL)
    stride=RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count_)
    if stride not in [4,8]:return false
    # Uma leitura na criação preserva os bytes exatos das tangentes importadas.
    var surface_data:=RenderingServer.mesh_get_surface(mesh.get_rid(),index)
    var bytes:PackedByteArray=surface_data.get("vertex_data",PackedByteArray())
    if bytes.size()<normal_offset+stride*count_:return false
    packed_normals=bytes.slice(normal_offset,normal_offset+stride*count_)
    return true

func upload(vertices:PackedVector3Array,normals:PackedVector3Array)->void:
    for i in normals.size():
        var encoded:=normals[i].octahedron_encode()
        packed_normals.encode_u16(i*stride,clampi(roundi(encoded.x*65535.),0,65535))
        packed_normals.encode_u16(i*stride+2,clampi(roundi(encoded.y*65535.),0,65535))
    mesh.surface_update_vertex_region(index,vertex_offset,vertices.to_byte_array())
    mesh.surface_update_vertex_region(index,normal_offset,packed_normals)
