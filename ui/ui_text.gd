class_name UiText
extends RefCounted
## 화면 글자 공통 스타일 (Galmuri 픽셀 폰트, 10px 배수에서 또렷하다)

const SIZE_SMALL := 10
const SIZE_LARGE := 20


static func make_label(text: String = "", size: int = SIZE_SMALL) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_shadow_color", Color(0.05, 0.04, 0.08, 1.0))
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
