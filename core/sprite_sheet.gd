class_name SpriteSheet
extends RefCounted
## 스프라이트시트 PNG + JSON 메타데이터 → SpriteFrames.
## 시트 규칙: 한 줄 = 애니메이션 하나, 한 칸 = 프레임 하나.


## 한 칸보다 키가 큰 캐릭터를 발 위치 그대로 그리기 위한 오프셋 (프레임 높이 - 16) / 2 만큼 위로.
## 판정(충돌·피격)은 그대로이고 그림만 위로 늘어난다.
static func foot_offset(frames: SpriteFrames, anim: StringName = &"idle") -> Vector2:
	var tex := frames.get_frame_texture(anim, 0)
	if tex == null:
		return Vector2.ZERO
	return Vector2(0, -(tex.get_height() - LevelMap.TILE_SIZE) * 0.5)


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
