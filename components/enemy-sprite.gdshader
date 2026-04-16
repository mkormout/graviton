shader_type canvas_item;

// Discard near-white pixels so the white atlas background becomes transparent.
// Threshold of 0.92 safely covers pure white (#FFFFFF) while preserving
// the lightest ship art (ENM-10 cream/beige tones sit around 0.80-0.85).
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.r > 0.92 && col.g > 0.92 && col.b > 0.92) {
		discard;
	}
	COLOR = col;
}
