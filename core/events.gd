extends Node
## 이벤트 버스 (오토로드 Events).
## 시스템끼리 서로를 직접 참조하지 않고 여기 시그널로만 연결한다.

@warning_ignore_start("unused_signal")

## 플레이어가 회피를 시작함
signal player_dodged(player: Node2D)
## 탄약 수가 바뀜
signal ammo_changed(current: int, maximum: int)
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
## 플레이어가 맞음 (TODO(M3): 체력 감소)
signal player_hit(hit: HitInfo)

## 디버그: 구간 이동 요청 (delta = -1 이전 구간, +1 다음 구간)
signal debug_section_step(delta: int)
## 디버그: 히트박스 표시·무적 등 플래그가 바뀜
signal debug_flags_changed()

@warning_ignore_restore("unused_signal")
