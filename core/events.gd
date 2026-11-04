extends Node
## 이벤트 버스 (오토로드 Events).
## 시스템끼리 서로를 직접 참조하지 않고 여기 시그널로만 연결한다.

@warning_ignore_start("unused_signal")

# --- 런 ---
## 새 런(판) 시작 (처음 시작·재시작 모두)
signal run_started()
## 일시정지 켜짐/꺼짐
signal pause_changed(paused: bool)

# --- 플레이어 ---
## 플레이어가 생성됨 (재시작하면 새 플레이어)
signal player_spawned(player: Node2D)
## 플레이어가 회피를 시작함
signal player_dodged(player: Node2D)
## 탄약 수가 바뀜
signal ammo_changed(current: int, maximum: int)
## 체력이 바뀜
signal player_hp_changed(current: int, maximum: int)
## 플레이어가 쐈음
signal player_shot()
## 탄약이 없는데 사격을 눌렀음
signal ammo_empty()
## 근접 공격 시작
signal melee_started()
## 근접으로 적을 맞힘 (맞힌 수)
signal melee_hit(count: int)
## 패링 성공 (perfect = 완벽 패링)
signal parried(perfect: bool)
## 완벽 회피 성공
signal perfect_dodge()
## 투명 상태 시작/끝
signal stealth_changed(active: bool)
## 플레이어가 맞음 (데미지가 들어간 경우만)
signal player_hit(hit: HitInfo)
## 플레이어 사망
signal player_died()

# --- 튜토리얼·레벨 ---
## 구간 입장 (1~7). 스플릿 지점
signal section_entered(index: int)
## 하단 안내 문구 바뀜 (빈 문자열 = 숨김)
signal hint_changed(text: String)
## 구간의 문이 열림
signal gate_opened(section: int)
## 수정 스위치가 켜짐
signal switch_activated(switch: Node2D)
## 스토리 트리거 발동 (데모에서는 비활성이라 발생하지 않음)
signal story_triggered(story_id: String)

# --- 적 ---
## 적이 맞음
signal enemy_damaged(enemy: Node2D, hit: HitInfo)
## 적이 죽음
signal enemy_died(enemy: Node2D)

# --- 디버그 ---
## 디버그: 구간 이동 요청 (delta = -1 이전 구간, +1 다음 구간)
signal debug_section_step(delta: int)
## 디버그: 히트박스 표시·무적 등 플래그가 바뀜
signal debug_flags_changed()

@warning_ignore_restore("unused_signal")
