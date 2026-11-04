class_name RunResult
extends RefCounted
## 한 판의 결과. 기록은 전부 게임 틱 기준 (프레임 드랍 영향 없음).

## 총 기록 (출발 ~ 골렘 1페이즈 격파, 틱)
var total_ticks: int = 0
## 구간별 시작 시점 (출발 기준 누적 틱). 인덱스 0 = 1구간 (= 0), 6 = 7구간
var split_ticks: Array[int] = []
var skill_id: String = ""
var cleared: bool = false
var seed_value: int = 0


## 구간 k(1~7)에 걸린 시간 (틱). 마지막 구간은 격파까지
func segment_ticks(k: int) -> int:
	if k < 1 or k > split_ticks.size():
		return 0
	var start := split_ticks[k - 1]
	var end := total_ticks if k == split_ticks.size() else split_ticks[k]
	return end - start


## 구간 k 를 마친 시점의 누적 틱 (k = 마지막이면 총 기록)
func cumulative_at_end(k: int) -> int:
	if k >= split_ticks.size():
		return total_ticks
	return split_ticks[k]


## 틱 → "m:ss.mmm"
static func format_ticks(ticks: int, tick_rate: int = 60) -> String:
	var ms := int(floor(float(ticks) * 1000.0 / float(tick_rate)))
	var minutes := ms / 60000
	var seconds := (ms / 1000) % 60
	return "%d:%02d.%03d" % [minutes, seconds, ms % 1000]


## 차이 → "+1.234" / "−0.567" (초)
static func format_diff(ticks: int, tick_rate: int = 60) -> String:
	var ms := int(round(absf(float(ticks)) * 1000.0 / float(tick_rate)))
	var sign_text := "+" if ticks > 0 else ("−" if ticks < 0 else "±")
	return "%s%d.%03d" % [sign_text, ms / 1000, ms % 1000]


func to_dict() -> Dictionary:
	return {"total_ticks": total_ticks, "split_ticks": split_ticks, "skill_id": skill_id, "seed": seed_value}
