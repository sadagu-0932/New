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


## 안내 글 속 키 이름 → 그 키가 맡은 액션 (키 설정을 바꾸면 글도 따라 바뀐다). "" 는 이동 키 네 개 묶음
const KEY_WORDS: Array = [["WASD", ""], ["Space", "dodge"], ["좌클릭", "shoot"], ["우클릭", "melee"],
	["Q 스킬", "skill"], ["Tab", "skill_menu"], ["R 길게", "restart"]]


## 안내 글을 지금 기기·키 설정에 맞게 바꾼다.
## - 터치 기기(APK·폰 브라우저): 키보드·마우스 말을 터치 버튼 이름으로 (목록은 data/touch.tres 의 text_map)
## - PC: 글 속 기본 키 이름을 지금 설정된 키 이름으로
static func for_device(text: String) -> String:
	if TouchControls.is_enabled():
		var map := DB.touch.text_map
		for from: String in map:
			text = text.replace(from, map[from])
		return text
	# 두 번에 나눠 바꾼다 (바꾼 키 이름이 다른 낱말과 겹쳐 또 바뀌지 않게)
	for i in KEY_WORDS.size():
		text = text.replace(KEY_WORDS[i][0], "\u0001%d\u0002" % i)
	for i in KEY_WORDS.size():
		var word: String = KEY_WORDS[i][0]
		var action: String = KEY_WORDS[i][1]
		var key := Settings.move_keys_name() if action.is_empty() else Settings.key_name(StringName(action))
		# "Q 스킬"·"R 길게" 처럼 뒤에 붙은 말은 그대로 둔다
		var tail := word.substr(word.find(" ")) if word.contains(" ") else ""
		text = text.replace("\u0001%d\u0002" % i, key + tail)
	return text
