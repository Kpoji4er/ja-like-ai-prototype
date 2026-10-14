shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.7,0.6,0.45,1.0);
uniform sampler2D plaster_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) { vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z); }
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=MODEL_NORMAL_MATRIX*NORMAL; }
void fragment() {
 float fine=noise(world_position*32.0);
 float stain=noise(world_position*vec3(1.8,0.4,1.8));
 float damp=(1.0-smoothstep(0.25,1.1,world_position.y))*0.2;
 vec2 uv=abs(world_normal.x)>0.5 ? world_position.zy*0.42 : world_position.xy*0.42;
 vec3 surface=texture(plaster_color,uv).rgb;
 ALBEDO=base_color.rgb*(0.67+surface*0.43)*(0.80+fine*0.17+stain*0.12-damp);
 NORMAL_MAP=mix(vec3(0.5,0.5,1.0),texture(plaster_normal,uv).rgb,0.45);
 ROUGHNESS=0.94;
}
