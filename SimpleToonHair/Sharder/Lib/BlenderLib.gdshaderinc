// Functions referenced from blender shader source code
#include "Noise.gdshaderinc"

vec3 rotate_around_axis(vec3 p, vec3 axis, float angle)
{
	float costheta = cos(angle);
	float sintheta = sin(angle);
	vec3 r;

	r.x = ((costheta + (1.0 - costheta) * axis.x * axis.x) * p.x) +
		(((1.0 - costheta) * axis.x * axis.y - axis.z * sintheta) * p.y) +
		(((1.0 - costheta) * axis.x * axis.z + axis.y * sintheta) * p.z);

	r.y = (((1.0 - costheta) * axis.x * axis.y + axis.z * sintheta) * p.x) +
		((costheta + (1.0 - costheta) * axis.y * axis.y) * p.y) +
		(((1.0 - costheta) * axis.y * axis.z - axis.x * sintheta) * p.z);

	r.z = (((1.0 - costheta) * axis.x * axis.z - axis.y * sintheta) * p.x) +
		(((1.0 - costheta) * axis.y * axis.z + axis.x * sintheta) * p.y) +
		((costheta + (1.0 - costheta) * axis.z * axis.z) * p.z);

	return r;
}

vec3 vector_rotate_axis_angle(vec3 vector_in, vec3 center, vec3 axis, float angle, vec3 rotation, float invert)
{
	return (length(axis) != 0.0) ?
			rotate_around_axis(vector_in - center, normalize(axis), angle * invert) + center :
			vector_in;
}

// Noise
uint rot(uint x, uint k)
{
	return (((x) << (k)) | ((x) >> (32u - (k))));
}

void final(inout uint a, inout uint b, inout uint c)
{
	c ^= b;
	c -= rot(b, 14u);
	a ^= c;
	a -= rot(c, 11u);
	b ^= a;
	b -= rot(a, 25u);
	c ^= b;
	c -= rot(b, 16u);
	a ^= c;
	a -= rot(c, 4u);
	b ^= a;
	b -= rot(a, 14u);
	c ^= b;
	c -= rot(b, 24u);
}

uint hash_uint2(uint kx, uint ky)
{
	uint a, b, c;
	a = b = c = uint(0xdeadbeef) + (2u << 2u) + 13u;

	b += ky;
	a += kx;
	final(a, b, c);

	return c;
}

float hash_uint2_to_float(uint kx, uint ky)
{
	return float(hash_uint2(kx, ky)) / float(0xFFFFFFFF);
}

float hash_vec2_to_float(vec2 k)
{
	return hash_uint2_to_float(floatBitsToUint(k.x), floatBitsToUint(k.y));
}

vec3 random_vec3_offset(float seed)
{
	return vec3(100.0 + hash_vec2_to_float(vec2(seed, 0.0)) * 100.0,
				100.0 + hash_vec2_to_float(vec2(seed, 1.0)) * 100.0,
				100.0 + hash_vec2_to_float(vec2(seed, 2.0)) * 100.0);
}

float noise_scale3(float result)
{
	return 0.9820 * result;
}

float snoise(vec3 p)
{
	float r = pnoise(p, vec3(0.0));
	return (isinf(r)) ? 0.0 : noise_scale3(r);
}

float noise(vec3 p)
{
	return 0.5 * snoise(p) + 0.5;
}

float fractal_noise(vec3 p, float octaves, float roughness)
{
	float fscale = 1.0;
	float amp = 1.0;
	float maxamp = 0.0;
	float sum = 0.0;
	octaves = clamp(octaves, 0.0, 15.0);
	int n = int(octaves);
	for (int i = 0; i <= n; i++) {
		float t = noise(fscale * p);
		sum += t * amp;
		maxamp += amp;
		amp *= clamp(roughness, 0.0, 1.0);
		fscale *= 2.0;
	}
	float rmd = octaves - floor(octaves);
	if (rmd != 0.0) {
		float t = noise(fscale * p);
		float sum2 = sum + t * amp;
		sum /= maxamp;
		sum2 /= maxamp + amp;
		return (1.0 - rmd) * sum + rmd * sum2;
	}
	else {
		return sum / maxamp;
	}
}

vec4 noise_texture_3d(vec3 co,
	float scale,
	float detail,
	float roughness)
{
	vec3 p = co * scale;
	vec3 rep = vec3(0.0);

	float value = fractal_noise(p, detail, roughness);
	return vec4(value,
				fractal_noise(p + random_vec3_offset(3.0), detail, roughness),
				fractal_noise(p + random_vec3_offset(4.0), detail, roughness),
				1.0);
}
// Noise end

vec4 brightness_contrast(vec4 col, float brightness, float contrast)
{
	float a = 1.0 + contrast;
	float b = brightness - contrast * 0.5;

	vec4 outcol;
	outcol.r = max(a * col.r + b, 0.0);
	outcol.g = max(a * col.g + b, 0.0);
	outcol.b = max(a * col.b + b, 0.0);
	outcol.a = col.a;
	return outcol;
}

float rgbtobw(vec4 color)
{
	vec3 factors = vec3(0.2126, 0.7152, 0.0722);
	return dot(color.rgb, factors);
}

vec3 normal_map_mix(float strength, vec3 newnormal, in vec3 orinormal)
{
	return normalize(mix(orinormal, newnormal, max(strength, 0.0)));
}

float map_range(float value, float from_left, float from_right, float to_left, float to_right) {
	float clamp_value = clamp(value, from_left, from_right);
	return (clamp_value - from_left) / (from_right - from_left) * (to_right - to_left) + to_left;
}

void rgb_to_hsv(vec4 rgb, out vec4 outcol)
{
	float cmax, cmin, h, s, v, cdelta;
	vec3 c;

	cmax = max(rgb[0], max(rgb[1], rgb[2]));
	cmin = min(rgb[0], min(rgb[1], rgb[2]));
	cdelta = cmax - cmin;

	v = cmax;
	if (cmax != 0.0) {
		s = cdelta / cmax;
	}
	else {
		s = 0.0;
		h = 0.0;
	}

	if (s == 0.0) {
		h = 0.0;
	}
	else {
		c = (vec3(cmax) - rgb.xyz) / cdelta;

		if (rgb.x == cmax) {
			h = c[2] - c[1];
		}
		else if (rgb.y == cmax) {
			h = 2.0 + c[0] - c[2];
		}
		else {
			h = 4.0 + c[1] - c[0];
		}

		h /= 6.0;

		if (h < 0.0) {
			h += 1.0;
		}
	}

	outcol = vec4(h, s, v, rgb.w);
}

void hsv_to_rgb(vec4 hsv, out vec4 outcol)
{
	float i, f, p, q, t, h, s, v;
	vec3 rgb;

	h = hsv[0];
	s = hsv[1];
	v = hsv[2];

	if (s == 0.0) {
		rgb = vec3(v, v, v);
	}
	else {
		if (h == 1.0) {
			h = 0.0;
		}

		h *= 6.0;
		i = floor(h);
		f = h - i;
		rgb = vec3(f, f, f);
		p = v * (1.0 - s);
		q = v * (1.0 - (s * f));
		t = v * (1.0 - (s * (1.0 - f)));

		if (i == 0.0) {
			rgb = vec3(v, t, p);
		}
		else if (i == 1.0) {
			rgb = vec3(q, v, p);
		}
		else if (i == 2.0) {
			rgb = vec3(p, v, t);
		}
		else if (i == 3.0) {
			rgb = vec3(p, q, v);
		}
		else if (i == 4.0) {
			rgb = vec3(t, p, v);
		}
		else {
			rgb = vec3(v, p, q);
		}
	}

	outcol = vec4(rgb, hsv.w);
}

vec4 composite_hue_saturation_value(
	vec4 color, float hue, float saturation, float value, float factor)
{
	vec4 hsv;
	rgb_to_hsv(color, hsv);

	hsv.x = fract(hsv.x + hue + 0.5);
	hsv.y = hsv.y * saturation;
	hsv.z = hsv.z * value;

	vec4 result;
	hsv_to_rgb(hsv, result);
	result.rgb = max(result.rgb, vec3(0.0));

	return mix(color, result, factor);
}
