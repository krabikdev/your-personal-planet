shader_type canvas_item;

// Main-menu backdrop: the same dusty space palette as the game, with a big
// quiet planet rising out of the lower right corner and drifting stars.

uniform vec3 deep_color : source_color = vec3(0.024, 0.026, 0.055);
uniform vec3 mid_color : source_color = vec3(0.105, 0.080, 0.145);
uniform vec3 rose_color : source_color = vec3(0.470, 0.255, 0.345);
uniform vec3 cream_color : source_color = vec3(0.960, 0.845, 0.700);

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
		p = p * 2.05 + vec2(3.1, 7.7);
		amp *= 0.5;
	}
	return sum;
}

float stars(vec2 uv, float scale, float threshold, float softness) {
	vec2 p = uv * scale;
	vec2 cell = floor(p);
	vec2 local = fract(p) - 0.5;
	float h = hash12(cell);
	if (h < threshold) {
		return 0.0;
	}
	vec2 offset = vec2(hash12(cell + 3.7), hash12(cell + 9.1)) - 0.5;
	float d = length(local - offset * 0.62);
	float twinkle = 0.75 + 0.25 * sin(TIME * (0.5 + h * 1.6) + h * 44.0);
	return smoothstep(softness, 0.0, d) * pow(h, 5.0) * twinkle;
}

void fragment() {
	vec2 uv = UV;
	vec2 aspect = vec2(1.777, 1.0);
	if (SCREEN_PIXEL_SIZE.y > SCREEN_PIXEL_SIZE.x) {
		aspect = vec2(1.0, 1.777);
	}
	vec2 auv = uv * aspect;

	vec3 col = mix(deep_color, mid_color, smoothstep(0.0, 1.0, uv.y));
	float band = exp(-pow(dot(uv - vec2(0.35, 0.55), vec2(0.55, -0.84)) / 0.30, 2.0));
	float broad = fbm2(auv * 2.4 + vec2(1.7, 4.9));
	float fine = fbm2(auv * 7.1 + vec2(-3.0, 2.0));
	col += rose_color * smoothstep(0.45, 0.9, broad) * (0.12 + band * 0.50);
	col += vec3(0.20, 0.38, 0.37) * smoothstep(0.56, 0.92, fine) * 0.22;
	col += cream_color * smoothstep(0.65, 0.95, broad * fine * 2.0) * 0.08;

	float s1 = stars(auv, 92.0, 0.987, 0.075);
	float s2 = stars(auv, 220.0, 0.972, 0.050);
	col += mix(cream_color, vec3(0.68, 0.82, 1.0), 0.4) * (s1 * 1.5 + s2 * 0.7);

	// Big planet peeking from the bottom-right.
	vec2 planet_center = vec2(aspect.x * 0.80, -0.08);
	float planet_radius = 0.72;
	vec2 pp = (auv - planet_center) / planet_radius;
	float rr = dot(pp, pp);
	float edge = smoothstep(1.0, 0.985, rr);
	if (rr < 1.15) {
		vec3 normal = normalize(vec3(pp.x, pp.y, sqrt(max(0.0, 1.0 - rr))));
		float light = max(dot(normal, normalize(vec3(-0.5, 0.65, 0.55))), 0.0);
		float mottle = 0.82 + 0.18 * fbm2(pp * 5.0 + 2.0);
		vec3 base = vec3(0.42, 0.33, 0.34) * (0.22 + light * 0.95) * mottle;
		base = mix(base, vec3(0.58, 0.44, 0.40), smoothstep(0.5, 0.9, fbm2(pp * 2.4)));
		base *= 0.86 + 0.14 * fbm2(pp * 15.0);
		col = mix(col, base, edge);
		float glow = smoothstep(1.22, 0.98, sqrt(rr)) * (1.0 - edge);
		col += vec3(0.60, 0.45, 0.48) * glow * 0.22;
	}

	// Soft vignette and a touch of grain.
	float vignette = smoothstep(1.25, 0.25, length((uv - 0.5) * vec2(1.2, 1.0)));
	col *= 0.72 + 0.28 * vignette;
	col += (hash12(uv * 900.0 + TIME) - 0.5) * 0.012;
	COLOR = vec4(col, 1.0);
}
