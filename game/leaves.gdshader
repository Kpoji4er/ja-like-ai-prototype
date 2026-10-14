shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color = vec4(0.19,0.29,0.10,1.0);
uniform bool use_vertex_color = false;
void vertex() {
 float wind=sin(TIME*1.45+VERTEX.x*0.9+VERTEX.z*0.5);
 VERTEX.x+=wind*0.08*clamp(VERTEX.y/7.0,0.0,1.0);
 VERTEX.z+=cos(TIME*1.13+VERTEX.x)*0.045;
}
void fragment() { ALBEDO=use_vertex_color ? pow(COLOR.rgb,vec3(2.2)) : leaf_color.rgb; ROUGHNESS=0.91; BACKLIGHT=vec3(0.025,0.05,0.012); }
