shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(0.0, 1.0, 1.0, 1.0); // Defaults to Cyan
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    // Mix the original color with the flash color based on the modifier
    color.rgb = mix(color.rgb, flash_color.rgb, flash_modifier);
    COLOR = color;
}