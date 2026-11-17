shader_type spatial;

// Weathered stone with a dusty, warm grey palette. Noise is evaluated in
// "surface metres" so the detail does not stretch as the planet grows.

uniform float planet_radius = 5.0;
uniform float bump_height = 0.16;
uniform vec3 rock_dark : source_color = vec3(0.215, 0.165, 0.205);
uniform vec3 rock_mid : source_color = vec3(0.420, 0.315, 0.315);
uniform vec3 rock_light : source_color = vec3(0.670, 0.490, 0.440);
uniform vec3 dust_color : source_color = vec3(0.520, 0.310, 0.340);

varying vec3 v_local;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
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
		p = p * 2.07 + vec3(3.1, 7.7, 1.9);
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	float bump = fbm(VERTEX * 6.0) + fbm(VERTEX * 16.0) * 0.35;
	float offset = (bump - 0.52) * bump_height / max(planet_radius, 1.0);
	VERTEX += NORMAL * offset;
	v_local = VERTEX * planet_radius;
}

void fragment() {
	vec3 p = v_local;
	float macro = fbm(p * 0.42);
	float fine = fbm(p * 2.2);
	float grain = fbm(p * 8.0);
	float basins = smoothstep(0.55, 0.92, fbm(p * 0.16 + vec3(7.1, 3.3, 1.7)));

	vec3 col = mix(rock_dark, rock_mid, smoothstep(0.18, 0.82, macro));
	col = mix(col, rock_light, smoothstep(0.48, 0.92, fine) * 0.70);
	col = mix(col, dust_color, smoothstep(0.42, 0.88, macro * fine * 2.0) * 0.40);
	col = mix(col, rock_dark * 1.12, basins * 0.28);
	col = mix(col, vec3(0.470, 0.430, 0.440), smoothstep(0.60, 0.92, fbm(p * 0.33 + vec3(11.0, 2.0, 7.0))) * 0.34);
	col = mix(col, vec3(0.780, 0.640, 0.510), smoothstep(0.70, 0.98, fine) * 0.34);
	col *= 0.90 + grain * 0.20;

	ALBEDO = col;
	ROUGHNESS = 0.95 - fine * 0.08;
	SPECULAR = 0.10;
	AO = 0.72 + 0.28 * fine;
}
