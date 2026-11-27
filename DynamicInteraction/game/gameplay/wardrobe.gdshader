shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color=vec4(.65,.27,.4,1.);
uniform vec3 point_local=vec3(0.);
uniform float amount=0.;
uniform float radius=.14;
void vertex() {
    float w=exp(-pow(distance(VERTEX,point_local)/radius,2.)*3.);
    VERTEX+=NORMAL*(amount*w);
}
void fragment() {
    ALBEDO=tint.rgb;
    ROUGHNESS=.91;
}
