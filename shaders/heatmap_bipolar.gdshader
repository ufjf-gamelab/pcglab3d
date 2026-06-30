shader_type spatial;
render_mode unshaded, depth_draw_always;

uniform float alpha : hint_range(0.0, 1.0) = 0.4;

varying float heat_value;

void vertex() {
	heat_value = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec3 bad  = vec3(1.0, 0.0, 0.0);
	vec3 good = vec3(0.0, 1.0, 0.0);

    // color = bad * (1.0 - heat_value) + good * heat_value
	vec3 color = mix(bad, good, heat_value);
	
	ALBEDO = color;
	ALPHA = alpha;
}
