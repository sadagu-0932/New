class_name SpriteSheet
extends RefCounted
## 스프라이트시트 PNG + JSON 메타데이터 → SpriteFrames.
## 시트 규칙: 한 줄 = 애니메이션 하나, 한 칸 = 프레임 하나.


static func build_frames(texture: Texture2D, meta: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var fw := int(meta.get("frame_width", 16))
	var fh := int(meta.get("frame_height", 16))
	var anims: Dictionary = meta.get("animations", {})
	for anim_name: String in anims:
		var info: Dictionary = anims[anim_name]
		var anim := StringName(anim_name)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(info.get("fps", 8.0)))
		frames.set_animation_loop(anim, bool(info.get("loop", true)))
		var row := int(info.get("row", 0))
		for col in int(info.get("frames", 1)):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * fw, row * fh, fw, fh)
			frames.add_frame(anim, atlas)
	return frames
