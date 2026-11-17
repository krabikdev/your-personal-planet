shader_type sky;

// A quiet, nostalgic piece of space: dusty nebulae, slow stars, and one
// distant ringed world. Everything is procedural, so the skybox costs no
// texture memory and tiles cleanly in every direction.

uniform vec3 deep_color : source_color = vec3(0.028, 0.030, 0.062);
uniform vec3 mid_color : source_color = vec3(0.095, 0.072, 0.140);
uniform vec3 rose_color : source_color = vec3(0.470, 0.255, 0.340);
uniform vec3 teal_color : source_color = vec3(0.220, 0.400, 0.385);
uniform vec3 cream_color : source_color = vec3(0.960, 0.845, 0.700);
uniform vec3 sun_color : source_color = vec3(1.000, 0.760, 0.560);
uniform vec3 sun_dir = vec3(-0.42, 0.58, 0.36);
uniform vec3 planet_dir = vec3(0.64, 0.28, 0.72);
uniform vec3 planet_color : source_color = vec3(0.760, 0.545, 0.545);
uniform float planet_size = 0.100;
uniform float star_brightness = 1.35;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += value_noise(p) * amp;
		p = p * 2.03 + vec3(1.7, 9.2, 4.1);
		amp *= 0.5;
	}
	return sum;
}

float star_layer(vec3 dir, float scale, float threshold, float softness) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	vec3 local = fract(p) - 0.5;
	float h = hash13(cell);
	if (h < threshold) {
		return 0.0;
	}
	vec3 offset = vec3(
		hash13(cell + vec3(3.7, 1.1, 8.3)),
		hash13(cell + vec3(9.1, 4.2, 2.7)),
		hash13(cell + vec3(17.3, 6.4, 5.9))
	) - 0.5;
	float d = length(local - offset * 0.62);
	float twinkle = 0.78 + 0.22 * sin(TIME * (0.45 + h * 1.4) + h * 41.0);
	return smoothstep(softness, 0.0, d) * pow(h, 5.0) * twinkle;
}

vec3 nebula_color(vec3 dir) {
	float band = exp(-pow(dot(dir, normalize(vec3(0.34, 0.52, -0.78))) / 0.36, 2.0));
	float broad = fbm(dir * 2.35 + vec3(2.4, -1.3, 5.2));
	float fine = fbm(dir * 6.1 + vec3(-3.7, 8.1, 1.2));
	vec3 col = mix(deep_color, mid_color, smoothstep(-0.75, 0.85, dir.y * 0.55 + dir.x * 0.2));
	col += rose_color * smoothstep(0.38, 0.84, broad) * band * 0.90;
	col += teal_color * smoothstep(0.46, 0.90, fine) * (1.0 - band * 0.45) * 0.40;
	col += cream_color * smoothstep(0.58, 0.94, broad * fine * 2.0) * 0.16;
	float dust = smoothstep(0.48, 0.86, fbm(dir * 15.0 + vec3(0.5))) * band;
	col += cream_color * dust * 0.14;
	return col;
}

vec3 distant_world(vec3 dir) {
	vec3 pdir = normalize(planet_dir);
	vec3 pright = normalize(cross(pdir, vec3(0.0, 1.0, 0.0)));
	vec3 pup = cross(pright, pdir);
	vec2 local = vec2(dot(dir, pright), dot(dir, pup)) / planet_size;
	float rr = dot(local, local);
	vec3 col = vec3(0.0);
	if (rr < 2.6) {
		vec3 normal = normalize(vec3(local.x, local.y, sqrt(max(0.0, 1.0 - rr))));
		vec3 world_normal = pright * normal.x + pup * normal.y + pdir * normal.z;
		float light = max(dot(world_normal, normalize(sun_dir)), 0.0);
		float bands = 0.86 + 0.14 * sin(local.y * 9.0 + fbm(pdir * 4.0) * 4.0);
		float mottle = 0.92 + 0.08 * fbm(world_normal * 7.0);
		vec3 base = planet_color * (0.24 + light * 0.98) * bands * mottle;
		base += planet_color * pow(1.0 - max(local.y, 0.0), 6.0) * 0.06;
		float edge = smoothstep(1.02, 0.975, rr);
		col = mix(col, base, edge);
		float glow = smoothstep(1.55, 0.98, sqrt(rr)) * (1.0 - edge);
		col += planet_color * glow * 0.28;

		float ring = length(vec2(local.x, local.y / 0.26));
		float ring_band = smoothstep(0.055, 0.0, abs(ring - 1.42));
		float ring_gap = smoothstep(0.020, 0.0, abs(ring - 1.42));
		col += mix(planet_color, cream_color, 0.45) * ring_band * 0.68;
		col -= vec3(0.05, 0.03, 0.05) * ring_gap;
	}
	return col;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	if (AT_CUBEMAP_PASS) {
		COLOR = nebula_color(dir) * 1.15;
	} else {
		vec3 col = nebula_color(dir);

		float s0 = star_layer(dir, 45.0, 0.9955, 0.160);
		float s1 = star_layer(dir, 92.0, 0.9815, 0.082);
		float s2 = star_layer(dir, 210.0, 0.9640, 0.062);
		float s3 = star_layer(dir, 470.0, 0.9380, 0.048);
		vec3 star_col = mix(cream_color, vec3(0.68, 0.82, 1.0), hash13(floor(dir * 91.0)) * 0.55);
		col += star_col * (s0 * 4.2 + s1 * 3.4 + s2 * 2.1 + s3 * 1.2) * star_brightness;

		float sun_dot = max(dot(dir, normalize(sun_dir)), 0.0);
		col += sun_color * pow(sun_dot, 900.0) * 3.4;
		col += sun_color * pow(sun_dot, 22.0) * 0.055;

		col += distant_world(dir);

		// Gentle vignette toward the "anti-sun" side keeps the frame cosy.
		col *= 0.88 + 0.12 * pow(max(dot(dir, normalize(vec3(0.2, 0.9, 0.1))), 0.0), 1.5);
		COLOR = col;
	}
}
