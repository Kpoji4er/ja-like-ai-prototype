shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_pos.xz;
 float n=noise(p*0.65)*0.5+noise(p*4.0)*0.3+noise(p*28.0)*0.2;
 vec3 dirt=mix(vec3(0.28,0.245,0.145),vec3(0.55,0.45,0.28),n);
 float road=1.0-smoothstep(3.7,4.4+noise(p*1.3)*0.3,abs(p.y));
 vec3 asphalt=mix(vec3(0.14,0.145,0.13),vec3(0.25,0.24,0.19),n);
 float edge=smoothstep(2.9,3.7,abs(p.y));
 asphalt=mix(asphalt,dirt,edge*0.7);
 ALBEDO=mix(dirt,asphalt,road);
 ROUGHNESS=0.96;
}
