shader_type spatial;
render_mode unshaded, depth_draw_always;

uniform float alpha : hint_range(0.0, 1.0) = 0.4;

varying float heat_value;
varying float positive_influence;

void vertex() {
	heat_value = INSTANCE_CUSTOM.x;
	positive_influence = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec3 bad  = vec3(1.0, 0.0, 0.0);
	vec3 good = vec3(0.0, 1.0, 0.0);

	vec3 color;

	if (positive_influence > 0.5) {
		color = mix(good, bad, heat_value);
	} else {
		color = mix(bad, good, heat_value);
	}

	ALBEDO = color;
	ALPHA = alpha;
}
