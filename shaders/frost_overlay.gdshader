shader_type canvas_item;

// Full-screen frost that creeps in from the edges while the boy drifts away
// from his planet. progress runs 0..1.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 frost_color : source_color = vec3(0.62, 0.80, 0.88);
uniform vec3 deep_tint : source_color = vec3(0.07, 0.12, 0.20);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm2(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += value_noise(p) * amp;
		p = p * 2.11 + vec2(4.7, 1.3);
		amp *= 0.5;
	}
	return sum;
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv * 2.0 - 1.0;
	centered.x *= 1.18;
	float edge = smoothstep(0.42, 1.22, length(centered));

	float n = fbm2(uv * 7.0 + vec2(2.3, 5.7));
	float veins = fbm2(uv * 17.0 - vec2(4.1, 2.9));
	float crystals = smoothstep(0.54, 0.82, n * 0.7 + veins * 0.45 + edge * 0.55);
	float tendrils = smoothstep(0.48, 0.78, fbm2(uv * 4.0 + vec2(8.0, 1.0))) * edge;

	float alpha = progress * (edge * 0.46 + tendrils * 0.20);
	alpha += crystals * progress * 0.42;
	alpha = clamp(alpha, 0.0, 0.9);

	vec3 col = mix(deep_tint, frost_color, 0.35 + crystals * 0.5);
	col = mix(col, vec3(0.90, 0.97, 1.0), crystals * 0.45);
	COLOR = vec4(col, alpha);
}
