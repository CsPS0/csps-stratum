
// OLED Span, phone version. Sending a scene to the Wallpaper Engine Android app records it as a
// 30-second 1080x1920 video, which the phone loops and enlarges to fill its screen. So the canvas is
// 1080x1920, and the motion is a closed loop that repeats exactly every 30 seconds (no jump when the
// video restarts). Speed sets how far the pattern travels per loop. One layer per style (STYLE combo).

// [COMBO] {"material":"Style","combo":"STYLE","type":"options","default":0}

#include "common.h"

uniform float g_Time;
uniform float g_Speed; // {"material":"speed","default":1}
uniform float g_Size; // {"material":"size","default":1}
uniform float g_Brightness; // {"material":"brightness","default":1}
uniform float g_TopDim; // {"material":"topdim","default":1}

varying vec2 v_TexCoord;

#define CANVAS vec2(1080.0, 1920.0)
#define LOOP_SECONDS 30.0

// A point on a closed path through the noise: the same value every LOOP_SECONDS.
vec3 drift(float phase) {
	float th = 6.28318530718 * frac(g_Time / LOOP_SECONDS) + phase;
	return vec3(0.10 * cos(th), 0.10 * sin(th), 0.30 * sin(th)) * g_Speed;
}

// 3D simplex noise by Ian McEwan and Stefan Gustavson (Ashima Arts), MIT licence.
vec3 mod289v3(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289v4(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289v4(((x * 34.0) + 10.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
	vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
	vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
	vec3 i = floor(v + dot(v, C.yyy));
	vec3 x0 = v - i + dot(i, C.xxx);
	vec3 g = step(x0.yzx, x0.xyz);
	vec3 l = 1.0 - g;
	vec3 i1 = min(g.xyz, l.zxy);
	vec3 i2 = max(g.xyz, l.zxy);
	vec3 x1 = x0 - i1 + C.xxx;
	vec3 x2 = x0 - i2 + C.yyy;
	vec3 x3 = x0 - D.yyy;
	i = mod289v3(i);
	vec4 p = permute(permute(permute(
			i.z + vec4(0.0, i1.z, i2.z, 1.0))
		+ i.y + vec4(0.0, i1.y, i2.y, 1.0))
		+ i.x + vec4(0.0, i1.x, i2.x, 1.0));
	float n_ = 0.142857142857;
	vec3 ns = n_ * D.wyz - D.xzx;
	vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
	vec4 gx = floor(j * ns.z);
	vec4 gy = floor(j - 7.0 * gx);
	vec4 x = gx * ns.x + ns.yyyy;
	vec4 y = gy * ns.x + ns.yyyy;
	vec4 h = 1.0 - abs(x) - abs(y);
	vec4 b0 = vec4(x.xy, y.xy);
	vec4 b1 = vec4(x.zw, y.zw);
	vec4 s0 = floor(b0) * 2.0 + 1.0;
	vec4 s1 = floor(b1) * 2.0 + 1.0;
	vec4 sh = -step(h, vec4(0.0, 0.0, 0.0, 0.0));
	vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
	vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
	vec3 p0 = vec3(a0.xy, h.x);
	vec3 p1 = vec3(a0.zw, h.y);
	vec3 p2 = vec3(a1.xy, h.z);
	vec3 p3 = vec3(a1.zw, h.w);
	vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
	p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
	vec4 m = max(0.5 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
	m = m * m;
	return 105.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		s += a * snoise(p);
		p = vec3(p.xy * 2.03, p.z * 1.5);
		a *= 0.5;
	}
	return s;
}

float hash(vec2 p) { return frac(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
	// canvas pixel, y pointing down; the canvas is the 1080x1920 frame the phone video is recorded at
	vec2 px = v_TexCoord * CANVAS;
	vec2 p = px / (900.0 * g_Size);
	float c = 0.0;

#if STYLE == 0
	// topographic contour lines, every fifth one brighter
	float n = fbm(vec3(p, 0.0) + drift(0.0));
	float lv = n * 14.0;
	float idx = floor(lv + 0.5);
	float d = abs(lv - idx);
	float w = fwidth(lv);
	float major = step(frac(idx / 5.0 + 0.001), 0.1);
	float stroke = 1.0 - smoothstep(0.0, w * mix(1.0, 1.6, major), d);
	c = stroke * mix(0.24, 0.55, major);
#elif STYLE == 1
	// silk: domain-warped noise turned into thin satin sheens
	vec2 q = p * 0.6;
	float a = fbm(vec3(q, 0.0) + drift(0.0));
	float b = fbm(vec3(q + vec2(5.2, 1.3), 0.0) + drift(2.1));
	float n = fbm(vec3(q + 1.4 * vec2(a, b), 0.0) + drift(4.2));
	float band = 0.5 + 0.5 * sin(9.0 * n + 3.0 * a);
	float sheen = pow(band, 8.0) * smoothstep(-0.35, 0.45, b);
	c = sheen * 0.55 + pow(band, 60.0) * 0.25;
#else
	// halftone: a fixed grid of dots whose size follows the noise
	float cell = 20.0;
	vec2 gp = px / cell;
	vec2 id = floor(gp);
	vec2 f = frac(gp) - 0.5;
	float n = fbm(vec3((id + 0.5) * cell / (900.0 * g_Size), 0.0) + drift(1.0)) * 0.5 + 0.5;
	float r = mix(0.03, 0.42, smoothstep(0.3, 0.85, n));
	float aa = 1.0 / cell;
	float dotv = 1.0 - smoothstep(r - aa, r + aa, length(f));
	c = dotv * mix(0.14, 0.6, smoothstep(0.4, 0.9, n));
#endif

	c *= g_Brightness;
	// the phone enlarges the video 1.25x (1920 -> 2400 rows), so this is ~100-225 px on screen
	c *= mix(1.0, smoothstep(80.0, 180.0, px.y), g_TopDim);
	c += (hash(px) - 0.5) / 255.0;
	gl_FragColor = vec4(max(c, 0.0), max(c, 0.0), max(c, 0.0), 1.0);
}
