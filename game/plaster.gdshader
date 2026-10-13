shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.7,0.6,0.45,1.0);
varying vec3 world_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) { vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z); }
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float fine=noise(world_position*32.0);
 float stain=noise(world_position*vec3(1.8,0.4,1.8));
 float damp=(1.0-smoothstep(0.25,1.1,world_position.y))*0.2;
 ALBEDO=base_color.rgb*(0.80+fine*0.17+stain*0.12-damp);
 ROUGHNESS=0.94;
}
