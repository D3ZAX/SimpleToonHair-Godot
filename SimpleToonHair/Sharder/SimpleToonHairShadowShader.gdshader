shader_type spatial;

#include "Lib/BlenderLib.gdshaderinc"

uniform sampler2D _base_color: source_color, hint_default_black;
uniform float _sharpness: hint_range(0.0, 0.99) = 0.0;
uniform float _thinness: hint_range(0.0, 0.99) = 0.0;
uniform float _density: hint_range(0.0, 200) = 15.7;
uniform float _smoothness: hint_range(-1.0, 0.0) = -0.9;
uniform float _blur: hint_range(0.0, 1.0) = 0.6;
uniform float _height: hint_range(-0.3, 0.4) = 0.0;
uniform float _transparency_0: hint_range(0.0, 1.0) = 0.0;
uniform float _spaces: hint_range(-50.0, 0.0) = -25.6;
uniform float _detail: hint_range(0.0, 5.0) = 1.0;
uniform float _transparency_1: hint_range(0.0, 100.0) = 4.1;
uniform float _overlay_shadow: hint_range(0.0, 1.0) = 0.0;
uniform float _overlaypure_color: hint_range(0.0, 1.0) = 0.0;
uniform float _overlay_hue: hint_range(0.0, 1.0) = 0.55;
uniform float _brightness: hint_range(0.0, 2.0) = 0.4;
uniform float _overlay_saturation: hint_range(0.0, 2.0) = 0.9;
uniform sampler2D _shadow_color: source_color, hint_default_black;
uniform float _shadow_size: hint_range(0.1, 1.0) = 0.57;
uniform float _shadow_opacity: hint_range(0.0, 1.0) = 1.0;
uniform float _shadow_transition: hint_range(0.001, 1.0) = 0.001;
uniform float _smooth_shadow: hint_range(0.0, 1.0) = 0.0;
uniform float _rotate_90_degrees: hint_range(0.0, 1.0) = 0.0;
uniform sampler2D _normal_map: hint_normal;
uniform float _normal_strength: hint_range(0.0, 20.0) = 0.15;

uniform sampler2D _highlight_gradient_1;
uniform sampler2D _highlight_gradient_2;

varying float highlight_ramp;
varying vec4 hsv_overlay;
varying vec4 shadow_color;

//void vertex() {
//}

void fragment() {
	float temp_f0, temp_f1, temp_f2;
	vec4 color_0, color_1;
	
	// highlight
	vec2 uv_fy = vec2(UV.x, 1.0 - UV.y);
	vec3 rot_uv;
	rot_uv = vector_rotate_axis_angle(vec3(uv_fy, 0.0), vec3(0.0), vec3(0.0, 0.0, 1.0), 90, vec3(0.0), 1.0);
	vec2 final_uv = mix(uv_fy, rot_uv.xy, _rotate_90_degrees); // here is mix color origin
	vec4 bc_noise_color;
	color_0 = noise_texture_3d(vec3(final_uv.x), _spaces, _detail, 1.0);
	bc_noise_color = brightness_contrast(color_0, _height, _transparency_1);
	color_0 = noise_texture_3d(vec3(final_uv.x), _density, 0.0, 0.0);
	temp_f0 = color_0.r;
	color_1 = brightness_contrast(color_0, _height, _smoothness);
	temp_f0 = rgbtobw(color_1);
	temp_f0 += -0.5 + final_uv.y;
	vec4 vec_0 = VIEW_MATRIX * vec4(0.0, -1.0, 0.0, 0.0);
	temp_f1 = (-vec_0.z - 0.3) * 0.25;
	temp_f0 -= temp_f1;
	vec4 g1 = texture(_highlight_gradient_1, vec2(temp_f0, 0.5));
	vec4 g2 = texture(_highlight_gradient_2, vec2(temp_f0, 0.5));
	color_0 = mix(g1, g2, _blur);
	temp_f2 = rgbtobw(color_0);
	temp_f0 = rgbtobw(bc_noise_color);
	temp_f1 = map_range(temp_f0, _sharpness, 1.0, 1.0, 0.1);
	temp_f0 = clamp(temp_f2 * temp_f1 - _overlay_shadow, 0.0, 1.0);
	highlight_ramp = clamp((temp_f0 - _thinness) / (1.0 - _thinness), 0.0, 1.0);
	NORMAL = normal_map_mix(_normal_strength, texture(_normal_map, UV).rgb, NORMAL);

	hsv_overlay = vec4(0.0);
	hsv_overlay = composite_hue_saturation_value(vec4(1.0, 0.0, 0.0, 1.0), _overlay_hue, _overlay_saturation, _brightness, 1.0);

	ALBEDO = texture(_base_color, UV).rgb;
	vec4 base_color = vec4(ALBEDO, 1.0);
	shadow_color = texture(_shadow_color, UV);
}

void light() {
	vec4 color_0, color_1;
	float temp_f0, temp_f1;
	vec4 base_color = vec4(ALBEDO, 1.0);
	float light_shadow_rate = map_range(dot(NORMAL, LIGHT), -1.0, 1.0, 0.0, 1.0) * ATTENUATION;
	vec4 color = vec4((light_shadow_rate * (vec4(LIGHT_COLOR, 1.0)) * base_color).rgb, 1.0);
	vec4 mix_base_color;
	mix_base_color = mix(color, base_color, 0.5);
	color_0 = mix_base_color + hsv_overlay;
	color_1 = mix(color_0, hsv_overlay, _overlaypure_color);
	temp_f0 = clamp(highlight_ramp, 0.0, 1.0);
	color_0 = mix(mix_base_color, color_1, temp_f0);
	vec4 light_part;
	light_part = mix(color_0, hsv_overlay, _transparency_0);
	
	temp_f0 = clamp(_shadow_size + _shadow_transition, 0.0, 1.0);
	float map_shadow_rate = map_range(light_shadow_rate, _shadow_size, temp_f0, 0.0, 1.0);
	color_0 = mix(mix_base_color, shadow_color, _shadow_opacity);
	color_1 = brightness_contrast(vec4(vec3(light_shadow_rate), 1.0), 0.0, -0.5);
	color_1 *= color_0;
	vec4 shadow_part;
	shadow_part = mix(color_1, mix_base_color, _smooth_shadow);
	
	color_0 = mix(shadow_part, light_part, map_shadow_rate);
	DIFFUSE_LIGHT += color_0.rgb / ALBEDO;
}
