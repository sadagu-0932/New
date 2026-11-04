class_name RunSetup
extends RefCounted
## 한 판(런)의 시작 조건. 런은 이것만 받아 독립적으로 돌아간다.
## TODO(M5): 선택한 스킬, TODO(M7): 결과(시간·스플릿·클리어 여부) 돌려주기

var seed_value: int = 0
var map_path: String = ""


static func from_config(config: GameConfig) -> RunSetup:
	var s := RunSetup.new()
	s.seed_value = config.run_seed
	s.map_path = config.start_map_path
	return s
