shader_type spatial;
render_mode unshaded, depth_draw_always;

uniform float alpha : hint_range(0.0, 1.0) = 0.4;

varying float heat_value;

void vertex() {
    heat_value = INSTANCE_CUSTOM.x;
}

void fragment() {
	// amarelo exato do bipolar
	vec3 cold = mix(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), 0.5); 
    vec3 hot = vec3(0.0, 0.0, 0.6);

    vec3 color = mix(cold, hot, heat_value);

    ALBEDO = color;
    ALPHA = alpha;
}