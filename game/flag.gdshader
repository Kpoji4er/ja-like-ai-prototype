shader_type spatial;
render_mode cull_disabled;
void vertex() { VERTEX.y+=sin(UV.x*9.0-TIME*3.4)*0.13*UV.x; }
void fragment() {
 vec3 a=vec3(0.20,0.29,0.18);
 vec3 b=vec3(0.61,0.49,0.27);
 ALBEDO=mix(a,b,step(0.34,UV.y)*step(UV.y,0.66));
 ROUGHNESS=0.95;
}
