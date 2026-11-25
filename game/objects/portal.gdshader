shader_type spatial;

render_mode unshaded, cull_disabled;

uniform sampler2D noise;

uniform vec4 color : source_color;

uniform float speed = 0.2;
uniform float emission_strength = 5.0;

void fragment() {
	vec2 uv1 = UV + vec2(TIME * speed,0.0);

	vec2 uv2 = UV + vec2(-TIME * speed * 0.6,TIME * speed * 0.4);

	float n1 = texture(noise,uv1).r;

	float n2 = texture(noise,uv2).r;

	float plasma = (n1+n2)*0.5;

	ALBEDO = color.rgb * plasma;

	EMISSION = color.rgb * plasma * emission_strength;

	ALPHA = plasma;
}