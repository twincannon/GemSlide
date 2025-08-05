shader_type canvas_item;

uniform float hue_shift: hint_range(0.0, 1.0) = 0.0;
uniform float color_scale: hint_range(0.0, 1.0) = 1.0;
uniform float alpha_scale: hint_range(0.0, 1.0) = 1.0;

varying vec4 modulate;

vec4 shift_hue(in vec4 color, in float shift) {
	// The unit gray vector in RGB color space.
	vec3 gray = vec3(0.57735);
	// Project color onto gray axis.
	vec3 projection = gray * dot(gray, color.rgb);
	// Vector from gray axis to original color.
	vec3 U = color.rgb - projection;
	// Vector perpendicular to gray axis and U.
	vec3 V = cross(gray, U);
	// Rotate U and V around the gray axis.
	vec3 shifted = U * cos(shift * 2.0 * PI) + V * sin(shift * 2.0 * PI) + projection;
	return vec4(shifted * color_scale, color.a * alpha_scale);
}

void vertex() {
	modulate = COLOR;
}

void fragment() {
	//COLOR = modulate * shift_hue(texture(TEXTURE, UV), hue_shift);
	
	// Check if red is dominant
	vec4 tex_color = texture(TEXTURE, UV);
	if (tex_color.r > tex_color.g && tex_color.r > tex_color.b) {
		COLOR = modulate * shift_hue(tex_color, hue_shift);
	} else {
		COLOR = modulate * tex_color;
	}
}