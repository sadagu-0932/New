#!/usr/bin/env python3
"""효과음 생성기 (8비트풍). 다시 실행하면 똑같은 파일이 나온다.

사용: python3 tools/sound_gen.py   → art/audio/*.wav (22050Hz, 16비트, 모노)

소리는 전부 여기서 계산으로 만든다 (파형 + 음 높이 변화 + 크기 변화).
소리를 바꾸고 싶으면 아래 SOUNDS 의 각 함수 수치를 고치고 다시 실행.
게임에서의 크기·연결은 data/audio.tres 와 core/audio_manager.gd.
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "audio"
RATE = 22050
# 잡음용 난수는 고정 시드 (다시 만들어도 같은 결과)
RNG = np.random.default_rng(20240501)


# ---------------------------------------------------------------------------
# 재료
# ---------------------------------------------------------------------------
def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def sweep(seconds: float, f0: float, f1: float, curve: float = 1.0) -> np.ndarray:
    """음 높이가 f0 → f1 로 변하는 주파수 곡선. curve > 1 이면 처음에 빨리 변한다."""
    n = int(RATE * seconds)
    u = np.linspace(0.0, 1.0, n, endpoint=False) ** (1.0 / curve)
    return f0 + (f1 - f0) * u


def phase_of(freq: np.ndarray) -> np.ndarray:
    return np.cumsum(freq) / RATE


def square(freq: np.ndarray, duty: float = 0.5) -> np.ndarray:
    # 폭이 좁은 네모파는 평균이 한쪽으로 쏠리므로(스피커에 "툭" 소리) 평균을 빼서 가운데로 맞춘다
    return np.where((phase_of(freq) % 1.0) < duty, 1.0, -1.0) - (2.0 * duty - 1.0)


def triangle(freq: np.ndarray) -> np.ndarray:
    return 2.0 * np.abs(2.0 * (phase_of(freq) % 1.0) - 1.0) - 1.0


def saw(freq: np.ndarray) -> np.ndarray:
    return 2.0 * (phase_of(freq) % 1.0) - 1.0


def sine(freq: np.ndarray) -> np.ndarray:
    return np.sin(2.0 * np.pi * phase_of(freq))


def noise(seconds: float, hold: int = 1) -> np.ndarray:
    """잡음. hold 가 크면 같은 값을 여러 샘플 유지해 낮고 거친 소리가 된다 (옛 게임기 잡음)."""
    n = int(RATE * seconds)
    raw = RNG.uniform(-1.0, 1.0, n // hold + 1)
    return np.repeat(raw, hold)[:n]


def env(n: int, attack: float, decay_power: float = 2.0, hold: float = 0.0) -> np.ndarray:
    """크기 변화: attack 초 동안 올라가고, hold 비율만큼 유지한 뒤 끝까지 줄어든다."""
    a = max(int(RATE * attack), 1)
    out = np.ones(n)
    out[:min(a, n)] = np.linspace(0.0, 1.0, min(a, n))
    start = min(a + int((n - a) * hold), n)
    rest = n - start
    if rest > 0:
        out[start:] = np.linspace(1.0, 0.0, rest) ** decay_power
    return out


def lowpass(x: np.ndarray, amount: float) -> np.ndarray:
    """간단한 저역 통과 (amount 0~1, 클수록 먹먹하게)."""
    if amount <= 0.0:
        return x
    out = np.empty_like(x)
    acc = 0.0
    k = 1.0 - amount
    for i, v in enumerate(x):
        acc += k * (v - acc)
        out[i] = acc
    return out


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def seq(*parts: np.ndarray) -> np.ndarray:
    return np.concatenate(parts)


def at(x: np.ndarray, seconds: float) -> np.ndarray:
    """앞에 무음을 붙여 seconds 초 뒤에 시작하게 한다."""
    return seq(np.zeros(int(RATE * seconds)), x)


def tone(seconds: float, f0: float, f1: float | None = None, wave_fn=square, attack: float = 0.002,
         decay: float = 2.0, hold: float = 0.0, curve: float = 1.0, **kw) -> np.ndarray:
    freq = sweep(seconds, f0, f0 if f1 is None else f1, curve)
    return wave_fn(freq, **kw) * env(len(freq), attack, decay, hold)


def hiss(seconds: float, hold_samples: int = 1, attack: float = 0.001, decay: float = 2.0,
         hold: float = 0.0, lp: float = 0.0) -> np.ndarray:
    x = lowpass(noise(seconds, hold_samples), lp)
    return x * env(len(x), attack, decay, hold)


def note(semitone: float, base: float = 440.0) -> float:
    return base * 2.0 ** (semitone / 12.0)


# ---------------------------------------------------------------------------
# 효과음 (이름 = 파일 이름 = data/audio.tres 의 슬롯 이름)
# ---------------------------------------------------------------------------
def shoot() -> np.ndarray:
    # 짧고 가벼운 "퓽": 빠르게 떨어지는 네모파 + 첫머리 잡음
    return mix(tone(0.09, 1250, 280, square, duty=0.25, curve=2.2), hiss(0.03, 2) * 0.35)


def empty() -> np.ndarray:
    # 빈 총 "틱틱"
    click = hiss(0.018, 3, decay=3.0) * 0.7 + tone(0.018, 210, 180, square, duty=0.5) * 0.4
    return mix(click, at(click * 0.7, 0.05))


def melee() -> np.ndarray:
    # 휘두르기 "휙": 먹먹한 잡음이 부풀었다 사라짐 + 올라가는 음
    whoosh = lowpass(noise(0.13, 2), 0.55) * np.sin(np.linspace(0.0, np.pi, int(RATE * 0.13))) ** 1.5
    return mix(whoosh * 1.3, tone(0.11, 300, 760, triangle, attack=0.03) * 0.35)


def melee_hit() -> np.ndarray:
    # 벤 손맛 "탁": 거친 잡음 + 낮게 떨어지는 음
    return mix(hiss(0.07, 4, decay=2.5), tone(0.09, 240, 70, square, duty=0.5, curve=2.0) * 0.8)


def parry() -> np.ndarray:
    # 금속성 "챙": 어긋난 높은 음 두 개가 울림
    ring = mix(tone(0.26, 1568, wave_fn=triangle, decay=2.2), tone(0.26, 2217, wave_fn=square, duty=0.5, decay=3.0) * 0.35,
               tone(0.2, 3136, wave_fn=sine, decay=3.0) * 0.3)
    return mix(ring, hiss(0.02, 1) * 0.6)


def perfect_parry() -> np.ndarray:
    # 더 높고 반짝이는 "챙-띠링": 챙 + 빠르게 올라가는 세 음
    sparkle = seq(tone(0.05, note(19), wave_fn=square, duty=0.25, decay=1.0),
                  tone(0.05, note(24), wave_fn=square, duty=0.25, decay=1.0),
                  tone(0.26, note(31), wave_fn=square, duty=0.25, decay=2.0))
    ring = mix(tone(0.4, 2093, wave_fn=triangle, decay=2.0), tone(0.4, 3136, wave_fn=sine, decay=2.5) * 0.4)
    return mix(ring, at(sparkle, 0.03) * 0.7, hiss(0.025, 1) * 0.7)


def dodge() -> np.ndarray:
    # 바람 "슉": 잡음이 빠르게 지나감 + 살짝 내려가는 음
    n = int(RATE * 0.16)
    shape = np.sin(np.linspace(0.0, np.pi, n)) ** 2.0
    return mix(lowpass(noise(0.16, 1), 0.35) * shape * 1.2, tone(0.14, 900, 380, sine, attack=0.02) * 0.25)


def perfect_dodge() -> np.ndarray:
    # 시간이 느려지는 느낌: 슉 + 올라가는 맑은 음 + 메아리
    rise = tone(0.3, note(12), note(24), sine, attack=0.02, decay=1.5)
    chime = tone(0.35, note(31), wave_fn=triangle, decay=2.0)
    return mix(dodge(), rise * 0.6, at(chime, 0.12) * 0.6, at(chime, 0.24) * 0.25)


def hit() -> np.ndarray:
    # 내가 맞음 "퍽": 낮고 묵직하게 + 떨리는 음
    wobble = square(sweep(0.2, 330, 110, 1.5) * (1.0 + 0.06 * np.sin(2 * np.pi * 38 * t_axis(0.2))), 0.5)
    return mix(hiss(0.1, 6, decay=2.0) * 0.9, wobble * env(len(wobble), 0.002, 1.6) * 0.8)


def death() -> np.ndarray:
    # 쓰러짐: 계단처럼 내려가는 음 + 긴 꼬리
    steps = seq(*[tone(0.085, note(s, 330), wave_fn=square, duty=0.5, decay=0.7) for s in (7, 4, 0, -5, -8)])
    tail = tone(0.5, note(-8, 330), note(-20, 330), triangle, decay=1.5)
    return mix(seq(steps, tail), hiss(0.12, 6) * 0.5)


def enemy_hit() -> np.ndarray:
    # 적이 맞음 "틱": 아주 짧게 (자주 나는 소리)
    return mix(tone(0.045, 620, 300, square, duty=0.5, curve=2.0), hiss(0.025, 3) * 0.5)


def enemy_die() -> np.ndarray:
    # 적 처치 "팡": 잡음 터짐 + 떨어지는 음
    return mix(hiss(0.2, 5, decay=2.2), tone(0.2, 520, 60, square, duty=0.5, curve=2.5) * 0.7,
               tone(0.06, 1400, 500, square, duty=0.25) * 0.3)


def skill() -> np.ndarray:
    # 스킬 공통: 마법 느낌으로 올라가는 음
    return mix(tone(0.22, note(0), note(19), triangle, attack=0.01, decay=1.4),
               tone(0.22, note(7), note(26), square, attack=0.01, decay=2.0, duty=0.25) * 0.3)


def skill_blink() -> np.ndarray:
    # 순간이동: 휙 올라갔다 뚝 끊기고 반대편에서 "핏"
    return mix(tone(0.07, 500, 3200, sine, decay=0.6, curve=0.6), at(tone(0.08, 2600, 900, square, duty=0.25), 0.09) * 0.6,
               hiss(0.05, 1) * 0.3)


def skill_absorb() -> np.ndarray:
    # 흡수 장막: 빨아들이듯 웅웅거리며 올라감
    n = int(RATE * 0.35)
    throb = 0.6 + 0.4 * np.sin(2 * np.pi * 22 * np.arange(n) / RATE)
    return mix(triangle(sweep(0.35, 160, 520)) * throb * env(n, 0.05, 1.2), hiss(0.3, 2, attack=0.1, lp=0.6) * 0.5)


def skill_decoy() -> np.ndarray:
    # 미끼 분신: 통통 튀는 두 음
    return seq(tone(0.07, note(7), wave_fn=square, duty=0.5, decay=1.0), tone(0.07, note(4), wave_fn=square, duty=0.5, decay=1.0),
               tone(0.16, note(12), wave_fn=triangle, decay=1.6))


def skill_shockwave() -> np.ndarray:
    # 충격파: 낮게 "쿠웅" 퍼짐
    return mix(tone(0.4, 200, 45, sine, decay=1.3, curve=2.0) * 1.2, hiss(0.3, 8, decay=1.6) * 0.8,
               tone(0.08, 900, 200, square, duty=0.5) * 0.3)


def skill_mark() -> np.ndarray:
    # 표식: 조준 "삑-삑"
    beep = tone(0.05, 1760, wave_fn=square, duty=0.25, decay=0.8)
    return mix(beep, at(tone(0.09, 2349, wave_fn=square, duty=0.25, decay=1.2), 0.07))


def gate() -> np.ndarray:
    # 문 열림: 돌 긁히는 소리 + 덜컹
    grind = lowpass(noise(0.3, 10), 0.3) * env(int(RATE * 0.3), 0.03, 1.0, 0.5)
    return mix(grind * 0.9, tone(0.3, 90, 70, square, duty=0.5, decay=1.0) * 0.4, at(tone(0.12, 140, 60, square, duty=0.5), 0.28) * 0.9,
               at(hiss(0.08, 8), 0.28) * 0.6)


def switch() -> np.ndarray:
    # 수정 스위치: 맑은 "띵"
    return mix(tone(0.4, note(24), wave_fn=sine, decay=2.0), tone(0.4, note(31), wave_fn=triangle, decay=2.5) * 0.5,
               tone(0.03, 3000, wave_fn=square, duty=0.25) * 0.2)


def start() -> np.ndarray:
    # 출발선 통과: 짧은 "띠-링!"
    return seq(tone(0.06, note(12), wave_fn=square, duty=0.25, decay=0.8), tone(0.2, note(19), wave_fn=square, duty=0.25, decay=1.6))


def split() -> np.ndarray:
    # 구간 통과: 가벼운 "띵"
    return mix(tone(0.16, note(16), wave_fn=triangle, decay=1.8), tone(0.16, note(28), wave_fn=sine, decay=2.2) * 0.4)


def boss_start() -> np.ndarray:
    # 골렘 깨어남: 낮게 으르렁 + 불길한 두 음
    n = int(RATE * 0.9)
    growl = saw(sweep(0.9, 48, 72)) * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * np.arange(n) / RATE)) * env(n, 0.15, 1.2, 0.4)
    stab = mix(tone(0.5, note(-21), wave_fn=square, duty=0.5, decay=1.4), tone(0.5, note(-15), wave_fn=square, duty=0.5, decay=1.4))
    return mix(lowpass(growl, 0.5) * 1.4, at(stab, 0.35) * 0.5, hiss(0.6, 12, attack=0.2, lp=0.5) * 0.5)


def boss_groggy() -> np.ndarray:
    # 그로기: 쨍 깨지고 흔들리며 내려감
    n = int(RATE * 0.5)
    fall = square(sweep(0.5, 900, 180) * (1.0 + 0.12 * np.sin(2 * np.pi * 14 * np.arange(n) / RATE)), 0.25) * env(n, 0.002, 1.3)
    return mix(hiss(0.12, 2) * 0.8, fall * 0.7, tone(0.3, 2400, 1200, triangle, decay=2.0) * 0.4)


def boss_defeat() -> np.ndarray:
    # 격파: 큰 폭발 + 승리 음 넷
    boom = mix(hiss(0.7, 7, decay=1.6) * 1.1, tone(0.7, 180, 35, sine, decay=1.3, curve=2.0) * 1.2)
    fanfare = seq(*[tone(d, note(s), wave_fn=square, duty=0.25, decay=dec, hold=0.3)
                    for s, d, dec in ((0, 0.1, 0.6), (4, 0.1, 0.6), (7, 0.1, 0.6), (12, 0.55, 1.6))])
    harmony = seq(np.zeros(int(RATE * 0.3)), tone(0.55, note(7), wave_fn=triangle, decay=1.6))
    return mix(boom, at(fanfare, 0.25) * 0.7, at(harmony, 0.25) * 0.5)


def ui_move() -> np.ndarray:
    return tone(0.03, 1320, wave_fn=square, duty=0.25, decay=1.0)


def ui_confirm() -> np.ndarray:
    return seq(tone(0.04, note(12), wave_fn=square, duty=0.25, decay=0.8), tone(0.1, note(19), wave_fn=square, duty=0.25, decay=1.5))


# (숨은 테크 소리 — 글자 안내가 아니라 발견했을 때의 손맛용)
def execute() -> np.ndarray:
    # 은신 처형: 날카롭게 베고 묵직하게 끝남
    return mix(tone(0.1, 2800, 500, saw, curve=2.0) * 0.7, hiss(0.05, 1) * 0.6, at(tone(0.3, 160, 40, sine, decay=1.4), 0.07) * 1.2,
               at(hiss(0.18, 6, decay=2.0), 0.07) * 0.8)


def reparry() -> np.ndarray:
    # 반사탄 재패링: 챙 + 한 음 더 높은 울림
    return mix(parry(), at(tone(0.3, 2637, wave_fn=triangle, decay=2.0), 0.04) * 0.6)


def dash_slash() -> np.ndarray:
    # 돌진 베기: 슉 + 긴 칼바람
    return mix(dodge(), at(tone(0.16, 600, 2400, saw, attack=0.01, decay=1.5), 0.03) * 0.4, at(hiss(0.1, 1, decay=2.0), 0.1) * 0.5)


def combo() -> np.ndarray:
    # 콤보 단계 오름: 올라가는 화음
    return seq(*[tone(0.05, note(s), wave_fn=square, duty=0.25, decay=0.8) for s in (12, 16, 19)],
               tone(0.22, note(24), wave_fn=triangle, decay=1.6))


# 이름 → (만드는 함수, 최대 크기 0~1). 자주 나는 소리는 작게, 중요한 순간은 크게
SOUNDS = {
    "shoot": (shoot, 0.55), "empty": (empty, 0.5), "melee": (melee, 0.6), "melee_hit": (melee_hit, 0.75),
    "parry": (parry, 0.8), "perfect_parry": (perfect_parry, 0.95), "dodge": (dodge, 0.55),
    "perfect_dodge": (perfect_dodge, 0.9), "hit": (hit, 0.85), "death": (death, 0.8),
    "enemy_hit": (enemy_hit, 0.45), "enemy_die": (enemy_die, 0.7),
    "skill": (skill, 0.7), "skill_blink": (skill_blink, 0.7), "skill_absorb": (skill_absorb, 0.7),
    "skill_decoy": (skill_decoy, 0.65), "skill_shockwave": (skill_shockwave, 0.9), "skill_mark": (skill_mark, 0.6),
    "gate": (gate, 0.7), "switch": (switch, 0.7), "start": (start, 0.6), "split": (split, 0.5),
    "boss_start": (boss_start, 0.9), "boss_groggy": (boss_groggy, 0.85), "boss_defeat": (boss_defeat, 0.95),
    "ui_move": (ui_move, 0.35), "ui_confirm": (ui_confirm, 0.5),
    "execute": (execute, 0.9), "reparry": (reparry, 0.85), "dash_slash": (dash_slash, 0.75), "combo": (combo, 0.7),
}


def finish(x: np.ndarray, peak: float) -> np.ndarray:
    """가장 큰 곳을 peak 로 맞추고, 끝을 아주 짧게 줄여 '틱' 잡음을 없앤다."""
    m = float(np.max(np.abs(x)))
    if m > 0.0:
        x = x / m * peak
    fade = min(int(RATE * 0.004), len(x))
    x = x.copy()
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    return x


def save(name: str, x: np.ndarray) -> None:
    data = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, (fn, peak) in SOUNDS.items():
        x = finish(fn(), peak)
        save(name, x)
        total += len(x) * 2
        print(f"{name:16s} {len(x) / RATE:5.2f}초")
    print(f"{len(SOUNDS)}개, {total / 1024:.0f} KB → {OUT}")


if __name__ == "__main__":
    main()
