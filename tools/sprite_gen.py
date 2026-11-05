#!/usr/bin/env python3
"""스프라이트 생성기.

고정 팔레트만 써서 픽셀 단위로 그린 뒤 스프라이트시트 PNG + 메타데이터 JSON을 만든다.
실행: python3 tools/sprite_gen.py
- 랜덤은 고정 시드만 쓰므로 다시 실행해도 결과가 같다.
- 시트 구조: 한 줄 = 애니메이션 하나, 한 칸 = 프레임 하나 (Aseprite 등에서 고치기 쉽게).
- 테마(세계관)를 바꾸려면 THEME 폴더를 새로 만들고 팔레트·그림 함수를 교체한다.
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
THEME = "dungeon"  # 임시 판타지 던전 테마
OUT = ROOT / "art" / "themes" / THEME

# ---------------------------------------------------------------------------
# 팔레트 (24색). 모든 스프라이트는 이 색만 쓴다. 투명은 None.
# ---------------------------------------------------------------------------
PALETTE: list[tuple[str, str]] = [
    ("outline", "0e0b14"),
    ("shadow", "2a2333"),
    ("stone_dark", "463c51"),
    ("stone", "655a6e"),
    ("stone_light", "8b8296"),
    ("pale", "c2bccb"),
    ("white", "f2eff5"),
    ("brown_dark", "5a2f2a"),
    ("brown", "8a5236"),
    ("tan", "c58a55"),
    ("skin", "f0c79a"),
    ("plum", "3b1f3f"),
    ("crimson", "7a2b45"),
    ("red", "c4404b"),
    ("orange", "f07a4a"),
    ("yellow", "f8c85a"),
    ("green_dark", "2a4a3a"),
    ("green", "3f7a4a"),
    ("green_light", "7cc15a"),
    ("navy", "1e2f55"),
    ("blue", "2f5f9a"),
    ("sky", "4fa3d8"),
    ("cyan", "9fe3f0"),
    ("purple", "6b3fa0"),
]
PAL_INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}
PAL_RGB = [tuple(int(h[i : i + 2], 16) for i in (0, 2, 4)) for _, h in PALETTE]


def c(name: str) -> int:
    """팔레트 이름 → 인덱스."""
    return PAL_INDEX[name]


# ---------------------------------------------------------------------------
# 캔버스: 팔레트 인덱스(또는 None) 2차원 배열
# ---------------------------------------------------------------------------
class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.px: list[list[int | None]] = [[None] * w for _ in range(h)]

    @staticmethod
    def from_rows(rows: list[str], cmap: dict[str, str | None]) -> "Canvas":
        h, w = len(rows), len(rows[0])
        cv = Canvas(w, h)
        for y, row in enumerate(rows):
            assert len(row) == w, f"행 길이 불일치 (y={y}): {row!r}"
            for x, ch in enumerate(row):
                name = cmap[ch]
                cv.px[y][x] = None if name is None else c(name)
        return cv

    def copy(self) -> "Canvas":
        cv = Canvas(self.w, self.h)
        cv.px = [row[:] for row in self.px]
        return cv

    def set(self, x: int, y: int, color: int | None) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = color

    def fill(self, color: int) -> None:
        for y in range(self.h):
            for x in range(self.w):
                self.px[y][x] = color

    def line(self, x0: int, y0: int, x1: int, y1: int, color: int) -> None:
        """브레젠험 직선."""
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.set(x0, y0, color)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def shift_rows(self, top: int, bottom: int, dy: int) -> "Canvas":
        """top~bottom 행 묶음을 dy만큼 아래로 민다 (나머지 행은 유지)."""
        cv = self.copy()
        block = [self.px[y][:] for y in range(top, bottom + 1)]
        for y in range(top, bottom + 1):
            cv.px[y] = [None] * self.w
        for i, row in enumerate(block):
            ty = top + i + dy
            if 0 <= ty < self.h:
                for x, v in enumerate(row):
                    if v is not None:
                        cv.px[ty][x] = v
        return cv

    def recolor(self, keep: set[int], to: int) -> "Canvas":
        cv = self.copy()
        for y in range(self.h):
            for x in range(self.w):
                v = cv.px[y][x]
                if v is not None and v not in keep:
                    cv.px[y][x] = to
        return cv

    def rotate_cw(self) -> "Canvas":
        cv = Canvas(self.h, self.w)
        for y in range(self.h):
            for x in range(self.w):
                cv.px[x][self.h - 1 - y] = self.px[y][x]
        return cv

    def bbox(self) -> tuple[int, int, int, int]:
        xs = [x for y in range(self.h) for x in range(self.w) if self.px[y][x] is not None]
        ys = [y for y in range(self.h) for x in range(self.w) if self.px[y][x] is not None]
        return min(xs), min(ys), max(xs), max(ys)

    def moved(self, dx: int, dy: int) -> "Canvas":
        cv = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                v = self.px[y][x]
                if v is not None:
                    cv.set(x + dx, y + dy, v)
        return cv

    def to_image(self) -> Image.Image:
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                v = self.px[y][x]
                if v is not None:
                    img.putpixel((x, y), (*PAL_RGB[v], 255))
        return img


def save_sheet(name: str, fw: int, fh: int, anims: list[tuple[str, list[Canvas], float, bool]],
               extra: dict | None = None) -> None:
    """애니메이션 목록을 시트 PNG + JSON으로 저장한다. 한 줄 = 애니메이션 하나."""
    cols = max(len(frames) for _, frames, _, _ in anims)
    sheet = Image.new("RGBA", (cols * fw, len(anims) * fh), (0, 0, 0, 0))
    meta: dict = {"frame_width": fw, "frame_height": fh, "animations": {}}
    for row, (anim, frames, fps, loop) in enumerate(anims):
        for col, frame in enumerate(frames):
            assert (frame.w, frame.h) == (fw, fh), f"{name}/{anim} 프레임 크기 불일치"
            sheet.paste(frame.to_image(), (col * fw, row * fh))
        meta["animations"][anim] = {"row": row, "frames": len(frames), "fps": fps, "loop": loop}
    if extra:
        meta.update(extra)
    sheet.save(OUT / f"{name}.png", optimize=False)
    write_json(OUT / f"{name}.json", meta)


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# ---------------------------------------------------------------------------
# 플레이어 (16x16, 오른쪽을 보는 기준. 왼쪽은 게임에서 좌우 반전)
# ---------------------------------------------------------------------------
PLAYER_CMAP: dict[str, str | None] = {
    ".": None,
    "o": "outline",
    "W": "white",        # 망토 빛 받는 테두리
    "P": "pale",         # 밝은 목도리
    "l": "stone_light",  # 목도리 주름 그늘
    "n": "stone",
    "t": "brown",        # 머리카락
    "d": "brown_dark",   # 머리카락 그늘
    "s": "skin",
    "e": "outline",      # 눈
    "y": "yellow",       # 망토 고정 장식
    "b": "sky",          # 옷깃
    "c": "blue",         # 튜닉
    "C": "navy",         # 튜닉 그늘
    "T": "brown",        # 허리띠
    "N": "navy",         # 바지 (먼 다리)
    "L": "blue",         # 가까운 다리 바지
    "K": "brown",        # 가까운 다리 장화
    "h": "tan",          # 장갑
    "g": "stone_light",  # 총
    "G": "stone_dark",
    "k": "brown_dark",   # 장화
}
# 16x24 (키 1.5칸, 오른쪽을 봄). 후드 없이 갈색 머리 + 목에 감은 밝은 흰 목도리.
# 목도리 꼬리 두 가닥은 별도 층(player_cloak)이 움직임에 따라 뒤로 휘날린다.
PLAYER_BASE = [
    "................",
    ".....ooooo......",
    "....ottttto.....",
    "...otttttttoo...",
    "..odttttttttto..",
    "..oddttttsstto..",
    "..oddthtssssso..",
    "...odthsssseso..",
    "...oddtssssso...",
    "...oWPPPPPPlo...",
    "...oWPlPPlPPo...",
    "....occccco.....",
    "....oCcccco.....",
    "....oCcccCo.....",
    "....oCcccCo.....",
    "....oTTTTTo.....",
    "....oCcccCo.....",
    "....oNNNNNo.....",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]
# 쓰러져 누운 모습 (머리 왼쪽, 발 오른쪽, 망토가 몸 아래 깔림)
PLAYER_LYING = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "..oooo..........",
    ".ottttooooooo...",
    "odttssWPcccTNNoo",
    "odtsesPlcccTNNko",
    "oddsssoocccoNNoo",
    ".ooooo..ooo.ooo.",
    "................",
]
# 키 (프레임 높이). 발 위치는 16x16 시절과 같게 게임에서 위로 (높이-16)/2 만큼 올려 그린다
PLAYER_H = 24
# 상체(머리~엉덩이) 마지막 줄, 총구 높이
PLAYER_BODY_LAST = 17
PLAYER_GUN_Y = 12
# 이 줄부터 아래의 등 뒤 망토는 별도 층으로 그린다
CLOAK_FROM_ROW = 11
# (예전) 등 뒤 망토 밑단 — 지금은 쓰지 않음, 망토 층(build_player_cloak) 참고
PLAYER_HEMS = [
    ("oPoPl", ".o.Po", "..o.o"),
    ("oPPoP", "o.oPo", ".o..o"),
    ("ooPPl", ".oPo.", "..o.."),
]
# 다리 (x 5~12, 18~23행)
# 다리 자세: (앞다리 무릎, 앞다리 발, 뒷다리 무릎, 뒷다리 발) — 절대 좌표 (x, y). 엉덩이는 (8,18)/(7,18)
# 앞다리(보는 쪽에 가까운 다리)는 밝게, 뒷다리는 어둡게 칠해 두 다리를 구분한다.
PLAYER_LEG_POSES = {
    "stand": ((8, 20), (9, 23), (7, 20), (6, 23)),
    # 걷기 6프레임: 디딤 → 내려앉음 → 교차(뒷다리 듦) → 반대 디딤 → 내려앉음 → 교차(앞다리 듦)
    "walk_contact": ((9, 20), (10, 23), (6, 20), (5, 23)),
    "walk_down": ((9, 20), (10, 23), (6, 21), (6, 23)),
    "walk_pass": ((8, 20), (8, 23), (9, 20), (8, 22)),
    "walk_contact2": ((7, 20), (6, 23), (8, 20), (10, 23)),
    "walk_down2": ((7, 21), (7, 23), (8, 20), (10, 23)),
    "walk_pass2": ((9, 20), (9, 22), (7, 20), (7, 23)),
    # 달리기 6프레임: 디딤(몸 낮음) → 차고 나감 → 공중(두 발 다 뜸) → 반대쪽 반복
    "run_contact": ((10, 20), (11, 23), (6, 21), (4, 22)),
    "run_push": ((8, 21), (7, 23), (9, 20), (9, 22)),
    "run_flight": ((11, 19), (11, 21), (6, 20), (4, 21)),
    "run_contact2": ((6, 21), (4, 22), (10, 20), (11, 23)),
    "run_push2": ((9, 20), (9, 22), (8, 21), (7, 23)),
    "run_flight2": ((6, 20), (4, 21), (11, 19), (11, 21)),
    # 공격·회피용
    "spread": ((9, 20), (11, 23), (6, 20), (4, 23)),
    "tuck": ((9, 20), (9, 21), (6, 20), (6, 21)),
}
# 옆모습 걷기 (17~23행을 손으로 찍음). L·K = 가까운 다리, N·k = 먼 다리.
# 디딤(앞다리 앞으로) → 내려앉음(뒷발 듦) → 지나감(뒷다리가 무릎 굽혀 앞으로) → 반대쪽은 색만 바꿔 반복
# 걷기 8프레임: 다리마다 (무릎, 발목, 발 모양). 가까운 다리 기준이며 먼 다리는 4프레임 늦게 같은 동작.
#   발 모양: heel 뒤꿈치 착지(발끝 들림) / flat 디딤 / toe 발끝으로 밀기(뒤꿈치 들림) / hang 공중에서 늘어짐
# 디딤 → 체중 실음 → 몸 아래 → 뒤로 밂 → 발끝 떼기 → 무릎 굽혀 앞으로 → 지나감 → 앞으로 뻗음
SIDE_WALK_LEGS = [
    ((9, 19), (10, 21), "heel"),
    ((9, 19), (8, 21), "flat"),
    ((7, 19), (7, 21), "flat"),
    ((6, 19), (5, 21), "flat"),
    ((5, 19), (3, 21), "toe"),
    ((7, 19), (4, 20), "hang"),
    ((9, 19), (7, 20), "hang"),
    ((10, 19), (11, 20), "hang"),
]
# 상체: 체중을 실을 때(내려앉음) 1px 내려간다. 먼 팔(총 안 든 팔)은 가까운 다리와 같이 앞뒤로 흔들린다
SIDE_WALK_BOB = [0, 1, 0, 0, 0, 1, 0, 0]
SIDE_ARM_SHOULDER = (7, 12)
SIDE_ARM_HANDS = [(11, 15), (10, 16), (8, 16), (5, 16), (2, 15), (3, 16), (6, 16), (9, 16)]
SIDE_HIP = {"near": (7, 17), "far": (5, 17)}
# 발 모양: 발목 기준 (dx, dy) 칸들
SIDE_FEET = {
    "flat": [(0, 0), (1, 0), (0, 1), (1, 1), (2, 1)],
    "heel": [(0, 0), (1, 0), (2, -1), (0, 1), (1, 1)],
    "toe": [(0, 0), (1, 0), (1, 1), (2, 1)],
    "hang": [(0, 0), (1, 0), (1, 1)],
}


def _thick_line(x0: int, y0: int, x1: int, y1: int) -> set[tuple[int, int]]:
    cells = set()
    for x, y in _line_points(x0, y0, x1, y1):
        cells.add((x, y))
        cells.add((x + 1, y))
    return cells


def _back_arm(cv: Canvas, shoulder: tuple[int, int], hand: tuple[int, int]) -> None:
    """몸 뒤에 있는 팔: 빈 칸에만 칠해 몸통에 가려지게 한다 (소매 남색 + 장갑)."""
    cells = _thick_line(shoulder[0], shoulder[1], hand[0], hand[1] - 1)
    hand_cells = {(hand[0], hand[1]), (hand[0] + 1, hand[1])}
    drawn = set()
    for (x, y) in sorted(cells | hand_cells):
        if 0 <= x < cv.w and 0 <= y < PLAYER_BODY_LAST and cv.px[y][x] is None:
            cv.set(x, y, c("tan") if (x, y) in hand_cells else c("navy"))
            drawn.add((x, y))
    for (x, y) in list(drawn):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < cv.w and 0 <= ny < PLAYER_BODY_LAST and cv.px[ny][nx] is None:
                cv.set(nx, ny, c("outline"))


# 가까운 팔이 쉬는 자리 (서 있을 때)
SIDE_NEAR_HAND_REST = (8, 16)


def _near_arm(cv: Canvas, shoulder: tuple[int, int], hand: tuple[int, int]) -> None:
    """몸 앞에 있는 팔: 몸통 위에 덧그리고 테두리로 몸통과 구분한다 (소매 파랑 + 장갑)."""
    cells = _thick_line(shoulder[0], shoulder[1], hand[0], hand[1] - 1)
    hand_cells = {(hand[0], hand[1]), (hand[0] + 1, hand[1])}
    arm = {p for p in cells | hand_cells if 0 <= p[0] < cv.w and p[1] < PLAYER_BODY_LAST}
    for (x, y) in arm:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in arm or ny <= shoulder[1] or not (0 <= nx < cv.w and ny < PLAYER_BODY_LAST):
                continue
            cv.set(nx, ny, c("outline"))
    for (x, y) in arm:
        cv.set(x, y, c("tan") if (x, y) in hand_cells else c("blue"))


def with_near_arm(base: Canvas) -> Canvas:
    out = base.copy()
    _near_arm(out, SIDE_ARM_SHOULDER, SIDE_NEAR_HAND_REST)
    return out


def side_walk_frames(base: Canvas) -> list[Canvas]:
    """옆모습 걷기: 허벅지·정강이가 무릎에서 꺾이고, 발이 뒤꿈치 착지 → 디딤 → 발끝 밀기 → 늘어짐으로 바뀐다."""
    n = len(SIDE_WALK_LEGS)
    frames = []
    for i in range(n):
        out = base.copy()
        for y in range(PLAYER_BODY_LAST, PLAYER_H):
            out.px[y] = [None] * out.w
        _back_arm(out, SIDE_ARM_SHOULDER, SIDE_ARM_HANDS[i])
        # 가까운 팔은 먼 팔과 반대로 흔든다 (앞뒤 폭은 조금 좁게)
        hx, hy = SIDE_ARM_HANDS[(i + n // 2) % n]
        _near_arm(out, SIDE_ARM_SHOULDER, (max(4, min(10, hx)), hy))
        if SIDE_WALK_BOB[i]:
            out = out.shift_rows(0, PLAYER_BODY_LAST - 1, SIDE_WALK_BOB[i])
        leg_cells = {}
        for side, phase, pants, boot in (("far", (i + n // 2) % n, "navy", "brown_dark"), ("near", i, "blue", "brown")):
            knee, ankle, foot = SIDE_WALK_LEGS[phase]
            hip = SIDE_HIP[side]
            if side == "far":
                knee, ankle = (knee[0] - 1, knee[1]), (ankle[0] - 1, ankle[1])
            cells = {}
            for p in _thick_line(hip[0], hip[1], knee[0], knee[1]) | _thick_line(knee[0], knee[1], ankle[0], ankle[1]):
                cells[p] = pants
            for dx, dy in SIDE_FEET[foot]:
                cells[(ankle[0] + dx, ankle[1] + dy)] = boot
            leg_cells[side] = cells
        # 엉덩이 줄
        for x in range(5, 10):
            out.set(x, PLAYER_BODY_LAST, c("navy"))
        far, near = leg_cells["far"], leg_cells["near"]
        for (x, y), col in far.items():
            out.set(x, y, c(col))
        # 먼 다리와 가까운 다리 사이 경계선 (가까운 다리 바로 뒤쪽 칸)
        for (x, y) in near:
            if (x - 1, y) in far and (x - 1, y) not in near and y > PLAYER_BODY_LAST:
                out.set(x - 1, y, c("outline"))
        for (x, y), col in near.items():
            out.set(x, y, c(col))
        allc = set(far) | set(near) | {(x, PLAYER_BODY_LAST) for x in range(5, 10)}
        for (x, y) in list(allc):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) in allc or ny < PLAYER_BODY_LAST or not (0 <= nx < 16 and ny < PLAYER_H):
                    continue
                if out.px[ny][nx] is None:
                    out.set(nx, ny, c("outline"))
        frames.append(out)
    return frames


PLAYER_HIP_NEAR = (8, 18)
PLAYER_HIP_FAR = (7, 18)


def _put(cv: Canvas, x0: int, y: int, part: str) -> None:
    for i, ch in enumerate(part):
        name = PLAYER_CMAP[ch]
        cv.set(x0 + i, y, None if name is None else c(name))


def hem(cv: Canvas, pose: int) -> Canvas:
    """몸 그림에서 등 뒤 망토(어깨 아래 x 0~4)를 떼어낸다. 망토는 별도 층(player_cloak)이 움직임에 따라 그린다.
    pose 는 예전 호환용 (쓰지 않음)."""
    return cv.copy()  # 망토가 없어져 떼어낼 것 없음 (목도리 꼬리는 별도 층)


def legs(cv: Canvas, key: str, hip_dx: int = 0, hip_dy: int = 0) -> Canvas:
    """다리를 엉덩이 → 무릎 → 발 두 마디 선(굵기 2)으로 그린다. 뒷다리 먼저, 앞다리를 위에. 발끝 2칸은 장화."""
    out = cv.copy()
    for y in range(PLAYER_BODY_LAST + 1 + min(hip_dy, 0), PLAYER_H):
        for x in range(3, 14):
            if y > PLAYER_BODY_LAST + min(hip_dy, 0) + (0 if hip_dy >= 0 else 0):
                out.set(x, y, None)
    near_knee, near_foot, far_knee, far_foot = PLAYER_LEG_POSES[key]
    mask: set[tuple[int, int]] = set()

    def draw_leg(hip, knee, foot, pants: str, boot: str) -> None:
        for (x0, y0), (x1, y1) in ((hip, knee), (knee, foot)):
            for x, y in _line_points(x0, y0, x1, y1):
                for dx in (0, 1):
                    px, py = x + dx, y
                    if py <= PLAYER_BODY_LAST + hip_dy:
                        continue
                    col = boot if py >= foot[1] - 1 else pants
                    out.set(px, py, c(col))
                    mask.add((px, py))
        # 발끝: 보는 쪽으로 한 칸
        out.set(foot[0] + 2, foot[1], c(boot))
        mask.add((foot[0] + 2, foot[1]))

    far_mask_start = len(mask)
    hip_far = (PLAYER_HIP_FAR[0] + hip_dx, PLAYER_HIP_FAR[1] + hip_dy)
    hip_near = (PLAYER_HIP_NEAR[0] + hip_dx, PLAYER_HIP_NEAR[1] + hip_dy)
    draw_leg(hip_far, far_knee, far_foot, "navy", "brown_dark")
    far_pixels = set(mask)
    draw_leg(hip_near, near_knee, near_foot, "blue", "brown")
    near_pixels = mask - far_pixels
    # 앞다리와 뒷다리가 맞닿는 곳에는 테두리 한 줄 (두 다리가 갈라져 보이게)
    for (x, y) in near_pixels:
        for dx in (-1, 1):
            if (x + dx, y) in far_pixels and (x + dx, y) not in near_pixels:
                out.set(x + dx, y, c("outline"))
    # 바깥 테두리: 빈 칸 중 다리에 닿은 곳. 단, 두 다리 사이 1칸 틈은 비워 둔다
    for (x, y) in list(mask):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in mask or ny <= PLAYER_BODY_LAST + hip_dy or not (0 <= ny < PLAYER_H) or not (0 <= nx < 16):
                continue
            if out.px[ny][nx] is not None:
                continue
            between = ((nx - 1, ny) in near_pixels and (nx + 1, ny) in far_pixels) or \
                      ((nx + 1, ny) in near_pixels and (nx - 1, ny) in far_pixels)
            if not between:
                out.set(nx, ny, c("outline"))
    return out


# ---------------------------------------------------------------------------
# 플레이어 망토 층 (24x24, 몸 그림 뒤에 그림). 몸 기준 x 가 8 만큼 오른쪽 → 뒤로 8px 까지 휘날릴 수 있다.
# 기울기 5단계: 앞으로 쏠림 / 늘어짐 / 살짝 날림 / 크게 날림 / 펄럭 (회피·돌진). 각 2프레임 펄럭임.
# 게임에서 이동 속도·방향을 스프링으로 따라가며 단계를 고른다 (Player._update_cloak).
# ---------------------------------------------------------------------------
CLOAK_W = 24
CLOAK_BODY_X = 8
# 단계 이름 → (등 쪽 밑단 끝 x, y, 앞쪽 밑단 y)  (망토 층 좌표)
CLOAK_LEANS = {
    "fwd": (10, 22, 22),
    "hang": (8, 23, 22),
    "trail1": (5, 21, 21),
    "trail2": (2, 18, 20),
    "billow": (0, 14, 18),
}


# 목도리 꼬리: 단계 이름 → (꼬리 각도°, 길이, 물결 세기). 각도는 "뒤쪽 수평"에서 아래로 잰다
SCARF_LEANS = {
    "fwd": (105, 6, 0.0),
    "hang": (85, 7, 0.3),
    "trail1": (50, 8, 0.8),
    "trail2": (22, 9, 1.2),
    "billow": (6, 10, 1.6),
}


def scarf_tails(anchor: tuple[int, int], lean: str, flutter: int, back_dir: int = -1, spread: float = 18.0,
                angle_scale: float = 1.0) -> Canvas:
    """목도리 꼬리 두 가닥 (24x24). anchor 에서 back_dir(-1 왼쪽/ +1 오른쪽) 쪽으로 늘어지거나 휘날린다.
    뒤 가닥은 조금 짧고 더 아래로, 어둡게. 끝은 올이 풀려 가늘어진다."""
    ang0, length, amp = SCARF_LEANS[lean]
    ang0 = 90 + (ang0 - 90) * angle_scale
    phase = math.pi * flutter
    t = Canvas(CLOAK_W, PLAYER_H)
    shape: dict[tuple[int, int], int] = {}
    for k, (dang, dlen, dph) in enumerate(((spread, -2, 1.3), (0.0, 0, 0.0))):
        a = math.radians(ang0 + dang)
        dx, dy = back_dir * math.cos(a), math.sin(a)
        px, py = -dy, dx
        n = (length + dlen) * 4
        for i in range(n + 1):
            u = i / n
            w = amp * math.sin(2 * math.pi * u * 1.1 + phase + dph) * u
            x = anchor[0] + dx * (length + dlen) * u + px * w
            y = anchor[1] + dy * (length + dlen) * u + py * w
            xi, yi = int(round(x)), int(round(y))
            thick = u < 0.8
            cells = [(xi, yi)]
            if thick:
                cells.append((xi, yi + 1) if abs(dx) > abs(dy) else (xi + 1, yi))
            for cx, cy in cells:
                if 0 <= cx < CLOAK_W and 0 <= cy < PLAYER_H:
                    shape[(cx, cy)] = k
    for (x, y), k in shape.items():
        top_open = (x, y - 1) not in shape
        if k == 0:
            t.set(x, y, c("stone_light") if not top_open else c("pale"))
        else:
            t.set(x, y, c("white") if top_open else c("pale"))
    for y in range(PLAYER_H):
        for x in range(CLOAK_W):
            if (x, y) in shape:
                continue
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + ddx, y + ddy) in shape:
                    t.set(x, y, c("outline"))
                    break
    return t


def _in_poly(px: float, py: float, poly: list[tuple[float, float]]) -> bool:
    inside = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > py) != (y2 > py):
            xi = x1 + (py - y1) * (x2 - x1) / (y2 - y1)
            if px < xi:
                inside = not inside
    return inside


def cloak_frame(lean: str, flutter: int) -> Canvas:
    """옆모습 목도리 꼬리: 목 뒤(몸 x 3, 9행)에서 등 뒤로."""
    return scarf_tails((CLOAK_BODY_X + 3, 9), lean, flutter)


def _line_points(x0: int, y0: int, x1: int, y1: int):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        yield x0, y0
        if x0 == x1 and y0 == y1:
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


# ---------------------------------------------------------------------------
# 플레이어 정면(아래를 볼 때)·뒷모습(위를 볼 때). 몸 16x24 + 망토 층 24x24
#   정면: 망토는 몸 뒤 (양옆으로 보임) / 뒷모습: 망토가 몸 앞을 덮음 (게임에서 그리는 순서를 바꿈)
# ---------------------------------------------------------------------------
PLAYER_SIDE_DEATH: list = []
FB_CMAP = dict(PLAYER_CMAP)
FB_CMAP.update({"E": "brown", "Q": "stone_dark"})
PLAYER_FRONT = [
    "................",
    ".....oooooo.....",
    "....otttttto....",
    "...otttttttto...",
    "..otttttttttto..",
    "..odttsttsttdo..",
    "..odssssssssdo..",
    "..odsessssesdo..",
    "...odssssssdo...",
    "..oWPPPPPPPPlo..",
    "..oWPlPPPlPPlo..",
    ".occcccPlcccoco.",
    ".occcccPlcccoco.",
    ".ohooccccCccoho.",
    ".oooTTTTyTTTooo.",
    "...occccCccco...",
    "..o.occcCccco...",
    "....oNNNoNNNo...",
    "....oNNo.oNNo...",
    "....oNNo.oNNo...",
    "....oNNo.oNNo...",
    "....oNNo.oNNo...",
    "....okko.okko...",
    "....oooo.oooo...",
]
PLAYER_BACK = [
    "................",
    ".....oooooo.....",
    "....otttttto....",
    "...otttttttto...",
    "..otttttttttto..",
    "..odttttttttdo..",
    "..odtttdtttddo..",
    "..oddttttttddo..",
    "...oddtttdddo...",
    "..oWPPPPPPPPlo..",
    ".ooWPPlPPlPPloo.",
    ".occcccccccccco.",
    ".ohoccccccccoho.",
    ".oooTTTTTTTTooo.",
    "...occcccccco...",
    "...occcccccco...",
    "...occcccccco...",
    "....oNNNoNNNo...",
    "....oNNo.oNNo...",
    "....oNNo.oNNo...",
    "....oNNo.oNNo...",
    "....oNNo.oNNo...",
    "....okko.okko...",
    "....oooo.oooo...",
]
# 정면·뒷모습 다리 (18~23행): 서기 / 왼발 듦 / 오른발 듦 / 웅크림
FB_LEGS = {
    "stand": ["....oNNo.oNNo...", "....oNNo.oNNo...", "....oNNo.oNNo...", "....oNNo.oNNo...",
              "....okko.okko...", "....oooo.oooo..."],
    "lift_l": ["....oNNo.oNNo...", "....oNNo.oNNo...", "....okko.oNNo...", "....oooo.oNNo...",
               ".........okko...", ".........oooo..."],
    "lift_r": ["....oNNo.oNNo...", "....oNNo.oNNo...", "....oNNo.okko...", "....oNNo.oooo...",
               "....okko........", "....oooo........"],
    "half_l": ["....oNNo.oNNo...", "....oNNo.oNNo...", "....oNNo.oNNo...", "....okko.oNNo...",
               "....oooo.okko...", ".........oooo..."],
    "half_r": ["....oNNo.oNNo...", "....oNNo.oNNo...", "....oNNo.oNNo...", "....oNNo.okko...",
               "....okko.oooo...", "....oooo........"],
    "tuck": ["....oNNo.oNNo...", "....okko.okko...", "....oooo.oooo...", "................",
             "................", "................"],
}


def fb_legs(cv: Canvas, key: str) -> Canvas:
    out = cv.copy()
    part = Canvas.from_rows(FB_LEGS[key], FB_CMAP)
    for i in range(6):
        out.px[PLAYER_H - 6 + i] = part.px[i][:]
    return out


def fb_arms(cv: Canvas, dy_left: int, dy_right: int) -> Canvas:
    """양팔(화면 왼쪽 x1~2, 오른쪽 x13~14)을 위아래로 흔든다."""
    out = cv.copy()
    for (x0, x1), dy in (((1, 2), dy_left), ((13, 14), dy_right)):
        if dy == 0:
            continue
        rows = range(11, 16)
        block = {(x, y): cv.px[y][x] for y in rows for x in range(x0, x1 + 1)}
        for (x, y) in block:
            out.set(x, y, None)
        for (x, y), v in block.items():
            if v is not None:
                out.set(x, y + dy, v)
    return out


def build_player_view(name: str, rows: list[str], back: bool) -> None:
    base = Canvas.from_rows(rows, FB_CMAP)
    top = PLAYER_BODY_LAST

    def body(dy: int = 0) -> Canvas:
        return base.shift_rows(0, top, dy) if dy else base.copy()

    idle = [fb_legs(body(), "stand"), fb_legs(body(), "stand"), fb_legs(body(1), "stand"), fb_legs(body(1), "stand")]
    # 달리기 6프레임: 다리를 번갈아 들고, 몸이 튀어 오르고, 팔을 흔든다
    # 걷기 6프레임: 왼발 살짝 듦(2프레임) → 디딤(상체 1px 내려앉음) → 오른발 반복. 양팔은 엇갈려 흔든다
    def arms(d: int) -> tuple[int, int]:
        return (d, -d)   # 양팔을 엇갈려 흔든다 (총은 손에 들지 않고 떠 있음)
    run_plan = [("half_l", 0, *arms(1)), ("half_l", 0, *arms(1)), ("stand", 1, *arms(0)),
                ("half_r", 0, *arms(-1)), ("half_r", 0, *arms(-1)), ("stand", 1, *arms(0))]
    move = [fb_legs(fb_arms(body(dy), al, ar), leg) for leg, dy, al, ar in run_plan]
    # 사격: 몸은 그대로 (총은 따로 그림)
    shoot = [fb_legs(body(), "stand"), fb_legs(body(), "stand")]
    # 근접: 단검이 앞(정면은 아래, 뒷모습은 위)으로 호를 그림
    blade, tip = c("pale"), c("white")
    m0, m1, m2 = (fb_legs(body(), "stand") for _ in range(3))
    yy = (lambda y: 23 - y) if not back else (lambda y: y)
    m0.line(13, yy(12), 15, yy(9), blade)
    for x, y in ((3, 2), (5, 1), (8, 1), (11, 1), (13, 2)):
        m1.set(x, yy(y), tip)
    for x, y in ((4, 2), (6, 1), (10, 1), (12, 2)):
        m1.set(x, yy(y), blade)
    m2.line(0, yy(9), 2, yy(12), blade)
    melee = [m0, m1, m2]
    dodge = [fb_legs(body(2), "tuck"), fb_legs(body(4), "tuck"), fb_legs(body(2), "tuck")]
    for y in (6, 11):
        dodge[1].line(0, y, 1, y, c("pale"))
        dodge[1].line(14, y, 15, y, c("pale"))
    outline = {c("outline")}
    standing = fb_legs(body(), "stand")
    hurt = [standing.recolor(outline, c("white")), standing.recolor(outline, c("red"))]
    death = [cv.copy() for cv in PLAYER_SIDE_DEATH]
    save_sheet(name, 16, PLAYER_H, [
        ("idle", idle, 4.0, True),
        ("move", move, 12.0, True),
        ("shoot", shoot, 12.0, False),
        ("melee", melee, 15.0, False),
        ("dodge", dodge, 15.0, False),
        ("hurt", hurt, 12.0, False),
        ("death", death, 6.0, False),
    ], extra={"shoulder": [2.5, 11.5] if not back else [13.5, 11.5], "body_offsets": {
        "idle": [[0, 0], [0, 0], [0, 1], [0, 1]],
        "move": [[0, dy] for _, dy, _, _ in run_plan],
        "dodge": [[0, 2], [0, 4], [0, 2]],
        "death": [[0, 2], [0, 4], [0, 0], [0, 0]],
    }})


def fb_cloak_frame(back: bool, lean: str, flutter: int) -> Canvas:
    """정면: 목 옆에서 몸 뒤로 (휘날릴 때만 옆으로 보임) / 뒷모습: 목 뒤 매듭에서 등 위로 늘어짐 (몸 앞에 그림)."""
    if back:
        return scarf_tails((4 + 6, 10), lean, flutter, spread=-10.0, angle_scale=0.7)
    return scarf_tails((4 + 3, 9), lean, flutter)


# 총 (손 없이 총만. 게임에서 캐릭터 주위에 떠서 마우스 쪽으로 돈다). 오른쪽을 겨눈 기준, 회전축 = 몸체 가운데
#   룬 권총: 밝은 총신 윗면, 놋쇠 총구 고리, 몸체의 청록 룬, 나무 손잡이, 방아쇠울
GUN_CMAP = {
    ".": None, "o": "outline", "W": "white", "P": "pale", "l": "stone_light", "n": "stone",
    "D": "stone_dark", "y": "yellow", "q": "cyan", "t": "brown", "T": "tan", "h": "tan",
    "c": "blue", "C": "navy", "d": "brown_dark",
}
GUN_W, GUN_H = 14, 10
GUN_ROWS = [
    "..............",
    "..ooo.........",
    ".oDDloooooooo.",
    ".oDnnlWllllyo.",
    ".oDDqnnnnnnyo.",
    ".otDDDoooooo..",
    ".oTtoDo.......",
    ".ottdo........",
    ".otdo.........",
    ".ooo..........",
]
def gun_frame() -> Canvas:
    return Canvas.from_rows([r + "." * (GUN_W - len(r)) for r in GUN_ROWS], GUN_CMAP)


def muzzle_flash_frame(kind: int) -> Canvas:
    """총구 불꽃 (8x8, 왼쪽 가운데가 총구). 0 큰 불꽃 / 1 작은 불꽃 / 2 연기"""
    t = Canvas(8, 8)
    if kind == 0:
        for x, y, col in ((0, 3, "white"), (0, 4, "white"), (1, 3, "white"), (1, 4, "white"), (2, 3, "yellow"),
                          (2, 4, "yellow"), (1, 2, "yellow"), (1, 5, "yellow"), (3, 3, "orange"), (3, 4, "yellow"),
                          (4, 4, "orange"), (2, 1, "orange"), (2, 6, "orange"), (5, 3, "orange")):
            t.set(x, y, c(col))
    elif kind == 1:
        for x, y, col in ((0, 3, "yellow"), (0, 4, "white"), (1, 3, "orange"), (1, 4, "yellow"), (2, 4, "orange")):
            t.set(x, y, c(col))
    else:
        for x, y, col in ((1, 3, "pale"), (2, 2, "stone_light"), (3, 2, "stone_light")):
            t.set(x, y, c(col))
    return t


def build_gun() -> None:
    # 총 그림은 하나만 (게임에서 통째로 돌린다). 반동은 위치로, 불꽃은 따로 그린 그림으로
    save_sheet("gun", GUN_W, GUN_H, [("idle", [gun_frame()], 1.0, True)],
               extra={"pivot": [5.0, 5.0], "muzzle": [13.0, 3.5]})
    save_sheet("muzzle_flash", 8, 8, [
        ("flash", [muzzle_flash_frame(0), muzzle_flash_frame(1), muzzle_flash_frame(2)], 20.0, False),
    ], extra={"origin": [0.0, 3.5]})


def build_player_views() -> None:
    build_player_view("player_front", PLAYER_FRONT, back=False)
    build_player_view("player_back", PLAYER_BACK, back=True)
    fps = {"fwd": 4.0, "hang": 4.0, "trail1": 8.0, "trail2": 10.0, "billow": 14.0}
    for sheet, back in (("player_cloak_front", False), ("player_cloak_back", True)):
        save_sheet(sheet, CLOAK_W, PLAYER_H, [
            ("cloak_" + lean, [fb_cloak_frame(back, lean, 0), fb_cloak_frame(back, lean, 1)], fps[lean], True)
            for lean in CLOAK_LEANS
        ])


def build_player_cloak() -> None:
    fps = {"fwd": 4.0, "hang": 4.0, "trail1": 8.0, "trail2": 10.0, "billow": 14.0}
    save_sheet("player_cloak", CLOAK_W, PLAYER_H, [
        ("cloak_" + lean, [cloak_frame(lean, 0), cloak_frame(lean, 1)], fps[lean], True)
        for lean in CLOAK_LEANS
    ])


def shift_upper(cv: Canvas, dx: int, dy: int) -> Canvas:
    """상체(머리~엉덩이, 0~PLAYER_BODY_LAST 행)를 통째로 옮긴다. 달리기 기울기·튀어 오름용."""
    out = Canvas(cv.w, cv.h)
    for y in range(cv.h):
        for x in range(cv.w):
            v = cv.px[y][x]
            if v is None:
                continue
            if y <= PLAYER_BODY_LAST:
                out.set(x + dx, y + dy, v)
            else:
                out.set(x, y, v)
    return out


def swing_arm(cv: Canvas, dy: int) -> Canvas:
    """총 든 팔(가슴 높이, 오른쪽 부분)을 위아래로 흔든다."""
    if dy == 0:
        return cv
    out = cv.copy()
    x0, x1 = 10, 15
    rows = range(PLAYER_GUN_Y - 1, PLAYER_GUN_Y + 2)
    block = {(x, y): cv.px[y][x] for y in rows for x in range(x0, x1 + 1)}
    for (x, y) in block:
        out.set(x, y, None)
    # 팔 아래로 드러나는 몸통 자리는 튜닉 색으로 메움
    for (x, y), v in block.items():
        if v is not None:
            out.set(x, y + dy, v)
    for y in rows:
        if out.px[y][10] is None and cv.px[y][9] is not None:
            out.set(10, y, c("outline"))
    return out


def build_player() -> None:
    base = Canvas.from_rows(PLAYER_BASE, PLAYER_CMAP)
    top = PLAYER_BODY_LAST
    gy = PLAYER_GUN_Y
    bob = base.shift_rows(0, top, 1)  # 상체 1px 내려앉음 (숨쉬기). 다리는 그대로

    def pose(body: Canvas, h: int, leg: str) -> Canvas:
        return legs(hem(body, h), leg)

    idle = [pose(base, 0, "stand"), pose(base, 1, "stand"), pose(bob, 1, "stand"), pose(bob, 0, "stand")]
    # 달리기 6프레임: 몸 전체가 움직인다
    #   상체를 앞으로 1px 기울이고, 디딜 때 1px 내려앉고, 공중에서 1px 떠오른다.
    #   총 든 팔은 걸음에 맞춰 위아래로 흔들리고, 다리는 보폭을 크게 (공중 프레임엔 두 발 다 뜸)
    # 걷기 6프레임: 손으로 찍은 다리 + 내려앉을 때 상체 1px
    move = side_walk_frames(base)
    base = with_near_arm(base)   # 걷기 말고는 가까운 팔이 옆에 늘어져 있다

    # 사격: 몸은 서 있는 그대로 (총구 불꽃·반동은 따로 그린 총이 맡는다)
    shoot = [pose(base, 0, "stand"), pose(base, 0, "stand")]

    # 근접: 단검 (위 → 앞 → 아래)
    blade, tip = c("pale"), c("white")
    m0 = pose(base, 2, "spread")
    m0.line(12, gy - 1, 15, gy - 6, blade)
    m0.set(15, gy - 7, tip)
    m1 = pose(base, 0, "spread")
    for x, y in [(12, gy - 6), (13, gy - 5), (14, gy - 3), (15, gy - 1), (14, gy + 1), (13, gy + 3)]:
        m1.set(x, y, tip)
    for x, y in [(12, gy - 5), (13, gy - 3), (14, gy - 1), (13, gy + 1), (12, gy + 2)]:
        m1.set(x, y, blade)
    m2 = pose(base, 1, "spread")
    m2.line(12, gy + 1, 15, gy + 5, blade)
    m2.set(15, gy + 6, tip)
    melee = [m0, m1, m2]

    # 회피: 몸을 낮추고 망토가 뒤로 쏠림 + 잔상 선
    squash = pose(base.shift_rows(0, top, 2), 2, "spread")
    ball = pose(base.shift_rows(0, top, 4), 2, "tuck")
    for y in (8, 13, 18):
        ball.line(0, y, 1, y, c("pale"))
    dodge = [squash, ball, squash]

    outline = {c("outline")}
    standing = pose(base, 0, "stand")
    hurt = [standing.recolor(outline, c("white")), standing.recolor(outline, c("red"))]

    # 쓰러짐: 무릎 꿇기 → 옆으로 쓰러져 누움 (따로 그린 프레임)
    lying = Canvas.from_rows(PLAYER_LYING, PLAYER_CMAP)
    death = [pose(base.shift_rows(0, top, 2), 1, "tuck"), pose(base.shift_rows(0, top, 4), 0, "tuck"),
             lying.moved(0, -1), lying]
    PLAYER_SIDE_DEATH.clear()
    PLAYER_SIDE_DEATH.extend(death)

    save_sheet("player", 16, PLAYER_H, [
        ("idle", idle, 4.0, True),
        ("move", move, 14.0, True),
        ("shoot", shoot, 12.0, False),
        ("melee", melee, 15.0, False),
        ("dodge", dodge, 15.0, False),
        ("hurt", hurt, 12.0, False),
        ("death", death, 6.0, False),
    ], extra={
        # 총 든 어깨 (프레임 좌표, 오른쪽을 볼 때). 게임이 총을 여기에 붙여 조준 방향으로 돌린다
        "shoulder": [7.5, 11.5],
        # 프레임별 상체 이동 [dx(보는 쪽 +), dy(아래 +)] — 게임이 망토 층을 같이 움직이는 데 쓴다
        "body_offsets": {
            "idle": [[0, 0], [0, 0], [0, 1], [0, 1]],
            "move": [[0, dy] for dy in SIDE_WALK_BOB],
            "dodge": [[0, 2], [0, 4], [0, 2]],
            "death": [[0, 2], [0, 4], [0, 0], [0, 0]],
        },
    })


# ---------------------------------------------------------------------------
# 타일 (16x16). tiles.json에 이름 → 아틀라스 좌표 기록
# ---------------------------------------------------------------------------
def tile_floor(rng: random.Random, cracked: bool) -> Canvas:
    t = Canvas(16, 16)
    t.fill(c("stone_dark"))
    # 큰 돌판 이음새
    t.line(0, 0, 15, 0, c("shadow"))
    t.line(0, 0, 0, 15, c("shadow"))
    t.line(0, 8, 15, 8, c("shadow"))
    t.line(8, 1, 8, 7, c("shadow"))
    # 밝은 모서리
    t.line(1, 1, 7, 1, c("stone"))
    t.line(9, 1, 15, 1, c("stone"))
    t.line(1, 9, 15, 9, c("stone"))
    for _ in range(6):
        t.set(rng.randrange(1, 16), rng.randrange(1, 16), c("stone"))
    for _ in range(3):
        t.set(rng.randrange(1, 16), rng.randrange(1, 16), c("shadow"))
    if cracked:
        t.line(3, 11, 6, 13, c("shadow"))
        t.line(6, 13, 10, 12, c("shadow"))
        t.line(10, 12, 12, 15, c("shadow"))
    return t


def tile_wall_top() -> Canvas:
    t = Canvas(16, 16)
    t.fill(c("shadow"))
    for y in (3, 11):
        for x in range(0, 16, 4):
            t.set(x + (2 if y == 11 else 0), y, c("stone_dark"))
    return t


def tile_wall_face() -> Canvas:
    t = Canvas(16, 16)
    t.fill(c("stone"))
    for y in (0, 5, 10):
        t.line(0, y, 15, y, c("stone_dark"))
    for row, y0 in enumerate((1, 6, 11)):
        off = 0 if row % 2 == 0 else 4
        for x in range(off, 16, 8):
            t.line(x, y0, x, y0 + 3, c("stone_dark"))
        t.line(0, y0, 15, y0, c("stone_light"))
    t.line(0, 15, 15, 15, c("shadow"))
    t.line(0, 14, 15, 14, c("stone_dark"))
    return t


def tile_pit() -> Canvas:
    """구덩이: 플레이어는 못 건너지만 탄은 지나간다."""
    t = Canvas(16, 16)
    t.fill(c("outline"))
    t.line(0, 0, 15, 0, c("stone_dark"))
    t.line(0, 1, 15, 1, c("shadow"))
    t.line(0, 2, 15, 2, c("shadow"))
    for x in range(0, 16, 5):
        t.set(x + 2, 3, c("shadow"))
    return t


def build_tiles() -> None:
    rng = random.Random(1001)  # 고정 시드
    tiles = [
        ("floor", tile_floor(rng, False)),
        ("floor_alt", tile_floor(rng, True)),
        ("wall_top", tile_wall_top()),
        ("wall_face", tile_wall_face()),
        ("pit", tile_pit()),
    ]
    sheet = Image.new("RGBA", (16 * len(tiles), 16), (0, 0, 0, 0))
    meta: dict = {"tile_size": 16, "tiles": {}}
    for i, (name, cv) in enumerate(tiles):
        sheet.paste(cv.to_image(), (i * 16, 0))
        meta["tiles"][name] = [i, 0]
    sheet.save(OUT / "tiles.png", optimize=False)
    write_json(OUT / "tiles.json", meta)


# ---------------------------------------------------------------------------
# 탄 (8x8). 반사탄은 색으로 확실히 구분 (부스 관객용)
# ---------------------------------------------------------------------------
def orb(size: int, r: float, core: str, ring: str, outline: str | None, phase: int) -> Canvas:
    cv = Canvas(size, size)
    cx = cy = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r - 1.2:
                cv.set(x, y, c(core))
            elif d <= r:
                cv.set(x, y, c(ring))
            elif outline and d <= r + 0.9:
                cv.set(x, y, c(outline))
    # 반짝임: 프레임마다 하이라이트 위치가 바뀜
    hx = int(cx - 1 + phase)
    cv.set(hx, int(cy - 1), c("white"))
    return cv


BULLET_MAP = {".": None, "o": "outline", "W": "white", "Y": "yellow", "y": "orange", "r": "red", "R": "crimson",
              "C": "cyan", "c": "sky", "b": "blue", "P": "purple", "p": "plum", "L": "pale", "g": "green_light",
              "S": "stone", "s": "stone_dark", "l": "stone_light"}
# 오른쪽으로 날아가는 기준 (게임에서 진행 방향으로 회전하는 탄)
# 내 탄: 노랑·흰 예광탄
TRACER = [
    ["........", "........", "..ooooo.", ".oyYYWWo", ".oyYYWWo", "..ooooo.", "........", "........"],
    ["........", "........", ".oooooo.", "oyyYYWWo", "oyyYYWWo", ".oooooo.", "........", "........"],
]
# 원거리형(해골 마법사): 주황 불덩이, 뒤로 불꽃 꼬리
FIREBALL = [
    ["........", "..r.oo..", ".ryoyYo.", "ryyYYWYo", "oyyYWWYo", ".oyoYYo.", "..o.oo..", "........"],
    ["........", ".r..oo..", "..ryoYo.", "oryYYWYo", "ryyYWWYo", ".ryoYYo.", "...ooo..", "........"],
    ["........", "...ooo..", ".roryYo.", "oyyYYWYo", "ryyYWWYo", "..ryYYo.", "..r.oo..", "........"],
]
# 반사탄: 하늘색 에너지 볼트
BOLT = [
    ["........", "........", "..ooooo.", ".obcCWWo", ".obcCWWo", "..ooooo.", "........", "........"],
    ["........", "........", ".oooooo.", "obbcCWWo", "obbcCWWo", ".oooooo.", "........", "........"],
]
# 완벽 반사탄: 크고 흰 혜성
COMET = [
    ["........", "...oooo.", ".ocCWWWo", "occCWWWo", "occCWWWo", ".ocCWWWo", "...oooo.", "........"],
    ["...oo...", "..oCooo.", ".occWWWo", "ocCWWWWo", "ocCWWWWo", ".occWWWo", "..oCooo.", "...oo..."],
]


def shard_frame(k: int) -> Canvas:
    """탄막형: 보라 수정 조각 (회전하며 날아감, 4프레임)"""
    shapes = [
        ["...oo...", "..oWLo..", "..oLPo..", ".oLPPPo.", ".oPPPPo.", "..oPPo..", "..oPPo..", "...oo..."],
        ["........", "......o.", "....ooWo", "..ooLLPo", ".oLPPPo.", "oPPPPo..", ".oooo...", "........"],
        ["........", "..oooo..", ".oWLLLo.", "oLPPPPPo", "oPPPPPo.", ".oPPoo..", "..oo....", "........"],
        ["........", ".o......", "oWoo....", "oLLLoo..", ".oPPPPo.", "..ooPPPo", "....ooo.", "........"],
    ]
    return Canvas.from_rows(shapes[k], BULLET_MAP)


def golem_bullet_frame(k: int) -> Canvas:
    """골렘: 돌덩이 속에서 코어처럼 하늘색으로 빛나는 탄 (맥동 2프레임)"""
    rows = [
        ["..ooo...", ".olSSo..", "olScCSo.", "oScWCso.", "oSCCcso.", ".osssso.", "..oooo..", "........"],
        ["..ooo...", ".olSSo..", "olSCCSo.", "oSCWWCo.", "oSCCCso.", ".osccso.", "..oooo..", "........"],
    ]
    return Canvas.from_rows(rows[k], BULLET_MAP)


def build_bullets() -> None:
    def frames(rows_list):
        return [Canvas.from_rows(r, BULLET_MAP) for r in rows_list]
    save_sheet("bullets", 8, 8, [
        ("player", frames(TRACER), 12.0, True),
        ("enemy", [orb(8, 2.8, "red", "crimson", "outline", p) for p in (0, 1)], 8.0, True),
        ("fireball", frames(FIREBALL), 12.0, True),
        ("shard", [shard_frame(k) for k in range(4)], 12.0, True),
        ("golem", [golem_bullet_frame(k) for k in range(2)], 6.0, True),
        ("reflect", frames(BOLT), 12.0, True),
        ("reflect_perfect", frames(COMET), 14.0, True),
    ], extra={
        # 진행 방향으로 돌려 그릴 탄 (그림은 오른쪽 기준)
        "rotate": ["player", "fireball", "reflect", "reflect_perfect"],
        # 꼬리 잔상: 애니메이션 → 몇 틱마다 남길지
        "trail": {"fireball": 3, "golem": 4, "reflect": 2, "reflect_perfect": 2},
    })


# ---------------------------------------------------------------------------
# 이펙트 (16x16, 오른쪽 기준. 게임에서 회전)
# ---------------------------------------------------------------------------
def arc_pixels(cx: float, cy: float, r: float, a0: float, a1: float, steps: int = 24):
    import math
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        yield round(cx + r * math.cos(a)), round(cy + r * math.sin(a))


def build_effects() -> None:
    import math

    # 근접 베기 호
    slash = []
    for a0, a1 in ((-80, -20), (-75, 75), (20, 80)):
        cv = Canvas(16, 16)
        for x, y in arc_pixels(4, 7.5, 9, a0, a1):
            cv.set(x, y, c("white"))
        for x, y in arc_pixels(4, 7.5, 7.5, a0 + 10, a1 - 10):
            cv.set(x, y, c("pale"))
        slash.append(cv)

    # 패링 불꽃: 별 모양이 퍼짐
    parry = []
    for r in (2, 4, 6):
        cv = Canvas(16, 16)
        for k in range(8):
            a = math.radians(k * 45)
            for t in range(max(1, r - 2), r + 1):
                cv.set(round(7.5 + t * math.cos(a)), round(7.5 + t * math.sin(a)),
                       c("white") if t == r else c("yellow"))
        cv.set(7, 7, c("white"))
        cv.set(8, 8, c("white"))
        parry.append(cv)

    # 완벽 판정: 커지는 이중 고리 (게임에서 2배로 키워 표시)
    perfect = []
    for r in (2.5, 4.5, 6.5, 7.5):
        cv = Canvas(16, 16)
        for y in range(16):
            for x in range(16):
                d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
                if abs(d - r) < 0.6:
                    cv.set(x, y, c("white"))
                elif abs(d - (r - 2)) < 0.5 and r < 7.5:
                    cv.set(x, y, c("cyan"))
        perfect.append(cv)

    # 투명 진입 연기
    puff = []
    rng = random.Random(77)
    for r in (3, 5, 7):
        cv = Canvas(16, 16)
        for _ in range(18):
            a = rng.uniform(0, math.tau)
            d = rng.uniform(r - 2, r)
            cv.set(round(7.5 + d * math.cos(a)), round(7.5 + d * math.sin(a)),
                   c("pale") if rng.random() < 0.6 else c("cyan"))
        puff.append(cv)

    # 탄이 벽·대상에 맞음
    hit = []
    for r in (1, 3):
        cv = Canvas(16, 16)
        for k in range(4):
            a = math.radians(45 + k * 90)
            cv.set(round(7.5 + r * math.cos(a)), round(7.5 + r * math.sin(a)), c("yellow"))
        cv.set(7, 7, c("white"))
        hit.append(cv)

    # --- 맞을 때 이펙트 (종류별) ---
    fx_rng = random.Random(3131)
    # 벽: 밝은 돌 파편(2px)이 튀고 먼지 고리가 퍼짐
    debris = []
    chips = [(k * math.tau / 7 + fx_rng.uniform(-0.3, 0.3), fx_rng.uniform(0.75, 1.0),
              fx_rng.choice(["pale", "stone_light", "white"])) for k in range(7)]
    for step, r in enumerate((2.5, 4.5, 6.5)):
        cv = Canvas(16, 16)
        if step < 2:
            dr = 2.0 + step * 2.0
            for k in range(12):
                a_ = k * math.tau / 12
                cv.set(round(7.5 + dr * math.cos(a_)), round(7.5 + dr * math.sin(a_)), c("stone_light" if step else "pale"))
        for a_, sp_, col in chips:
            x, y = round(7.5 + r * sp_ * math.cos(a_)), round(7.5 + r * sp_ * math.sin(a_) + step)
            size = 2 if step < 2 else 1
            for dx in range(size):
                for dy in range(size):
                    cv.set(x + dx, y + dy, c(col))
            cv.set(x + size, y + size, c("outline"))
        debris.append(cv)
    # 적: 주황·흰 불꽃이 짧게 터짐
    spark = []
    for r in (2, 4, 5):
        cv = Canvas(16, 16)
        for k in range(6):
            a_ = math.radians(k * 60 + 30)
            for t_ in range(max(1, r - 2), r + 1):
                cv.set(round(7.5 + t_ * math.cos(a_)), round(7.5 + t_ * math.sin(a_)),
                       c("white") if t_ == r - 1 else c("orange") if t_ == r else c("yellow"))
        if r == 2:
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                cv.set(7 + dx, 7 + dy, c("white"))
        spark.append(cv)
    # 패링: 금속이 부딪힌 십자 섬광
    clang = []
    for r, core in ((3, "white"), (6, "white"), (7, "yellow")):
        cv = Canvas(16, 16)
        for t_ in range(-r, r + 1):
            col = c(core) if abs(t_) < r - 1 else c("yellow")
            cv.set(7 + t_, 7, col)
            cv.set(7, 7 + t_, col)
        for t_ in range(-(r // 2), r // 2 + 1):
            cv.set(7 + t_, 7 + t_, c("pale"))
            cv.set(7 + t_, 7 - t_, c("pale"))
        clang.append(cv)
    # 흡수 장막: 하늘색 알갱이가 가운데로 빨려듦
    absorb = []
    motes = [(k * math.tau / 8 + 0.3, 1.0) for k in range(8)]
    for r in (7.0, 4.5, 2.0):
        cv = Canvas(16, 16)
        for a_, _ in motes:
            cv.set(round(7.5 + r * math.cos(a_)), round(7.5 + r * math.sin(a_)), c("cyan"))
            cv.set(round(7.5 + (r + 1.2) * math.cos(a_)), round(7.5 + (r + 1.2) * math.sin(a_)), c("sky"))
        if r < 3:
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                cv.set(7 + dx, 7 + dy, c("white"))
        absorb.append(cv)

    save_sheet("effects", 16, 16, [
        ("slash", slash, 20.0, False),
        ("parry", parry, 20.0, False),
        ("perfect", perfect, 16.0, False),
        ("stealth_puff", puff, 12.0, False),
        ("hit", hit, 20.0, False),
        ("enemy_death", build_enemy_death(), 12.0, False),
        ("combo_aura", build_combo_aura(), 10.0, True),
        ("hit_wall", debris, 18.0, False),
        ("hit_enemy", spark, 20.0, False),
        ("hit_parry", clang, 18.0, False),
        ("hit_absorb", absorb, 16.0, False),
    ])


# ---------------------------------------------------------------------------
# 테스트·연습용 소품 (16x16)
# ---------------------------------------------------------------------------
DUMMY = [
    "................",
    "......oooo......",
    ".....otttto.....",
    ".....otetto.....",
    ".....otttto.....",
    "......oooo......",
    "...oooobboooo...",
    "...obbbbbbbbo...",
    "...oooobboooo...",
    "......obbo......",
    ".....otttto.....",
    ".....otttto.....",
    "......obbo......",
    "......obbo......",
    "....oooooooo....",
    "....oBBBBBBo....",
]
TURRET = [
    "................",
    "................",
    "....oooooooo....",
    "...osssssssso...",
    "..osSSSSSSSSso..",
    "..oSSowwwoSSSo..",
    "..oSowrrrwoSSo..",
    "..oSowrRrwoSSo..",
    "..oSSowwwoSSSo..",
    "..osSSSSSSSSso..",
    "...osssssssso...",
    "....oSSSSSSo....",
    "...oSSSSSSSSo...",
    "...oddddddddo...",
    "...oooooooooo...",
    "................",
]


def gate_frame(open_: bool) -> Canvas:
    t = Canvas(16, 16)
    for x in (0, 15):
        t.line(x, 0, x, 15, c("outline"))
    for x in (1, 14):
        t.line(x, 0, x, 15, c("stone_light"))
    if open_:
        t.line(2, 0, 13, 0, c("stone_dark"))
        t.line(2, 1, 13, 1, c("stone"))
        return t
    t.line(2, 0, 13, 0, c("outline"))
    t.line(2, 15, 13, 15, c("outline"))
    for x in (3, 6, 9, 12):
        t.line(x, 1, x, 14, c("stone_light"))
        t.line(x + 1, 1, x + 1, 14, c("stone_dark"))
    t.line(2, 7, 13, 7, c("brown"))
    t.line(2, 8, 13, 8, c("brown_dark"))
    return t


def spike_frame(stage: int) -> Canvas:
    """0 = 내려감(판과 구멍), 1 = 예고(판 테두리가 주황), 2 = 올라옴(큰 가시)"""
    t = Canvas(16, 16)
    rim = c("orange") if stage == 1 else c("shadow")
    for x in range(1, 15):
        t.set(x, 1, rim)
        t.set(x, 14, rim)
    for y in range(1, 15):
        t.set(1, y, rim)
        t.set(14, y, rim)
    for cx, cy in ((5, 6), (10, 6), (5, 12), (10, 12)):
        if stage < 2:
            t.set(cx, cy, c("outline"))
            t.set(cx + 1, cy, c("outline"))
            if stage == 1:
                t.set(cx, cy - 1, c("pale"))
                t.set(cx + 1, cy - 1, c("pale"))
        else:
            # 높이 5, 밑변 4 의 삼각 가시
            for h in range(5):
                half = 2 - h // 2
                for dx in range(-half, half + 1):
                    x = cx + dx if dx <= 0 else cx + dx
                    color = c("white") if dx >= 0 else c("pale")
                    t.set(x, cy - h, color)
            t.set(cx - 2, cy, c("outline"))
            t.set(cx + 3, cy, c("outline"))
    return t


def switch_frame(on: bool) -> Canvas:
    rows = [
        "......oo........",
        ".....occo.......",
        "....occcco......",
        "...occCccco.....",
        "...occCcccco....",
        "..occCCccccco...",
        "..occCccccccco..",
        "...occcccccco...",
        "....occcccco....",
        ".....occcco.....",
        "......occo......",
        ".....oSSSSo.....",
        "....oSSSSSSo....",
        "...oSSSSSSSSo...",
        "...oooooooooo...",
        "................",
    ]
    cmap = {".": None, "o": "outline", "c": "cyan" if on else "blue",
            "C": "white" if on else "sky", "S": "stone"}
    cv = Canvas.from_rows(rows, cmap)
    if on:
        for x, y in ((12, 1), (13, 3), (2, 2)):
            cv.set(x, y, c("yellow"))
    return cv


def boulder_frame(phase: int) -> Canvas:
    t = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            if d <= 6.0:
                t.set(x, y, c("stone"))
            elif d <= 7.0:
                t.set(x, y, c("outline"))
    # 굴러가는 느낌: 금 무늬 위치가 프레임마다 바뀜
    marks = [((5, 5), (6, 6), (9, 10)), ((9, 4), (10, 5), (5, 10))][phase]
    for x, y in marks:
        t.set(x, y, c("stone_dark"))
    t.set(5 + phase * 3, 4, c("stone_light"))
    return t


def build_props() -> None:
    dmap = {".": None, "o": "outline", "t": "tan", "e": "brown_dark", "b": "brown", "B": "brown_dark"}
    dummy = Canvas.from_rows(DUMMY, dmap)
    tmap = {".": None, "o": "outline", "s": "stone_light", "S": "stone", "w": "pale",
            "r": "red", "R": "yellow", "d": "stone_dark"}
    turret = Canvas.from_rows(TURRET, tmap)
    turret_lit = turret.copy()
    for x, y in [(6, 6), (7, 6), (8, 6), (6, 7), (8, 7)]:
        turret_lit.set(x, y, c("orange"))
    save_sheet("props", 16, 16, [
        ("dummy_idle", [dummy], 1.0, True),
        ("dummy_hit", [dummy.recolor({c("outline")}, c("white")), dummy], 12.0, False),
        ("turret_idle", [turret, turret_lit], 2.0, True),
        ("gate_closed", [gate_frame(False)], 1.0, False),
        ("gate_open", [gate_frame(True)], 1.0, False),
        ("spike_down", [spike_frame(0)], 1.0, False),
        ("spike_warn", [spike_frame(1)], 1.0, False),
        ("spike_up", [spike_frame(2)], 1.0, False),
        ("switch_off", [switch_frame(False)], 1.0, False),
        ("switch_on", [switch_frame(True)], 1.0, False),
        ("boulder", [boulder_frame(0), boulder_frame(1)], 8.0, True),
        ("sign", [Canvas.from_rows(SIGN, {".": None, "o": "outline", "b": "tan", "t": "brown_dark", "B": "brown"})], 1.0, False),
    ])


# ---------------------------------------------------------------------------
# 적 (16x16, 오른쪽 기준). 애니메이션: idle / move / attack / hurt
# 사망은 이펙트(enemy_death)로 표현
# ---------------------------------------------------------------------------
# 돌진형: 등에 털 갈기가 선 멧돼지. 하얀 엄니, 빨간 눈, 밝은 배. 발밑 그림자
CHARGER_MAP = {".": None, "o": "outline", "B": "brown_dark", "b": "brown", "t": "tan", "e": "red",
               "W": "white", "h": "stone_dark", "S": "shadow"}
CHARGER = [
    "................",
    "................",
    "....o.o.o.......",
    "...oBoBoBoo.....",
    "..oBBBBBBBbbo...",
    ".obBBBBBbbbbbo..",
    ".obbbbbbbbbbbbo.",
    "obbbbbbbbbbebbbo",
    "obtbbbbbbbbbbbWo",
    "obttbbbbbbbbbWWo",
    ".ottttbbbtttoo..",
    ".ootttoooottoo..",
    "..oBBo..oBBo....",
    "..oBBo..oBBo....",
    ".SSSSSSSSSSSSS..",
    "................",
]
CHARGER_LEGS = {
    "stand": ("..oBBo..oBBo....", "..oBBo..oBBo...."),
    "step_a": ("..oBBo...oBBo...", ".oBBo.....oBBo.."),
    "step_b": ("...oBBooBBo.....", "...oBBooBBo....."),
    "charge": (".oBBo.....oBBo..", "oBBo.......oBBo."),
}
# 원거리형: 해골 마법사. 맨 해골 머리(눈구멍에 주황 불빛), 보라 누더기 로브, 주황 구슬 지팡이
SHOOTER_MAP = {".": None, "o": "outline", "W": "pale", "w": "white", "g": "orange", "P": "purple", "p": "plum",
               "Y": "yellow", "y": "orange", "b": "brown", "h": "pale", "S": "shadow"}
SHOOTER = [
    "................",
    "......ooo....oo.",
    ".....owWWo..oYyo",
    ".....oWWWWo.oyYo",
    ".....ogWgWo..oo.",
    ".....oWWWo....b.",
    "......oWo.....b.",
    "....ooPPPoo...b.",
    "...oPPPpPPPo..b.",
    "...oPpPpPPPhhhb.",
    "...oPpPpPPPo..b.",
    "...oPpPPpPPo..b.",
    "....oPPPpPPo..b.",
    "....oPoPoPo...b.",
    "...SSSSSSSSS.SS.",
    "................",
]


def spreader_frame(spin: int, glow: bool = False, bob: int = 0, flash: bool = False) -> Canvas:
    """탄막형: 초록 수정 껍질 속 큰 눈(세로 동공) + 둘레를 도는 보라 수정 가시. 바닥 그림자와 떨어져 떠 있다."""
    import math
    t = Canvas(16, 16)
    cx, cy = 7.5, 6.5 + bob
    for y in range(16):
        for x in range(16):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= 3.0:
                t.set(x, y, c("pale"))
            elif d <= 4.2:
                lit = (x - cx) + (y - cy) < 0
                t.set(x, y, c("green_light") if lit else c("green"))
            elif d <= 5.0:
                t.set(x, y, c("outline"))
    for k in range(6):
        a = math.radians(k * 60 + spin * 15)
        for r, w in ((5.3, 1.0), (6.2, 0.5), (7.0, 0.0)):
            x, y = cx + r * math.cos(a), cy + r * math.sin(a)
            col = c("orange") if (glow and r < 6.5) else (c("purple") if r < 6.5 else c("outline"))
            t.set(round(x), round(y), col)
            if w:
                nx, ny = -math.sin(a), math.cos(a)
                t.set(round(x + nx * w), round(y + ny * w), c("plum"))
    iris = c("orange") if glow else c("green_dark")
    for x, y in ((7, 5), (8, 5), (6, 6), (7, 6), (8, 6), (9, 6), (6, 7), (7, 7), (8, 7), (9, 7), (7, 8), (8, 8)):
        t.set(x, y + bob, iris)
    for y in (5, 6, 7, 8):
        t.set(8 if y < 7 else 7, y + bob, c("outline"))
    t.set(6, 5 + bob, c("white"))
    for x in range(5, 11):
        t.set(x, 14, c("shadow"))
    for x in range(6, 10):
        t.set(x, 15, c("shadow"))
    if flash:
        t = t.recolor({c("outline"), c("shadow")}, c("white"))
    return t


def legs_swap(base: Canvas, rows: list[str], cmap: dict, top: int) -> Canvas:
    cv = base.copy()
    part = Canvas.from_rows(rows, cmap)
    for i in range(len(rows)):
        cv.px[top + i] = part.px[i][:]
    return cv


def build_enemies() -> None:
    keep = {c("outline"), c("shadow")}

    # --- 돌진형 ---
    ch = Canvas.from_rows(CHARGER, CHARGER_MAP)

    def ch_legs(body: Canvas, key: str) -> Canvas:
        return legs_swap(body, list(CHARGER_LEGS[key]), CHARGER_MAP, 12)

    ch_bob = ch.shift_rows(0, 11, 1)
    idle = [ch_legs(ch, "stand"), ch_legs(ch_bob, "stand")]
    move = [ch_legs(ch, "step_a"), ch_legs(ch_bob, "step_b"), ch_legs(ch, "step_a").moved(0, 0), ch_legs(ch_bob, "step_b")]
    # 돌진 준비: 웅크리고 눈이 노랗게, 콧김 / 돌진: 앞으로 쏠리고 뒤에 흙먼지
    windup = ch_legs(ch.shift_rows(0, 11, 2), "stand")
    windup.set(11, 9, c("yellow"))
    for x, y in ((15, 8), (15, 10), (14, 11)):
        windup.set(x, y, c("pale"))
    charge = ch_legs(ch.shift_rows(0, 11, 1), "charge")
    charge = Canvas.from_rows(["." * 16] * 16, CHARGER_MAP).copy()
    base_charge = ch_legs(ch.shift_rows(0, 11, 1), "charge")
    for y in range(16):
        for x in range(16):
            v = base_charge.px[y][x]
            if v is not None:
                charge.set(x + (1 if y <= 11 else 0), y, v)
    for x, y in ((0, 12), (1, 11), (0, 10)):
        charge.set(x, y, c("stone_light"))
    save_sheet("enemy_charger", 16, 16, [
        ("idle", idle, 3.0, True),
        ("move", move, 8.0, True),
        ("attack", [windup, charge], 10.0, True),
        ("hurt", [ch.recolor(keep, c("white")), ch], 12.0, False),
    ])

    # --- 원거리형 (해골 마법사) ---
    sh = Canvas.from_rows(SHOOTER, SHOOTER_MAP)
    sh_bob = sh.shift_rows(0, 13, 1)
    sh_sway = sh.copy()
    for x, ch_ in zip(range(4, 12), "oPoPoPo."):
        sh_sway.set(x + 1, 13, None if ch_ == "." else c(SHOOTER_MAP[ch_]))
    sh_sway.set(4, 13, None)
    flick = sh.copy()
    flick.set(13, 2, c("orange"))
    flick.set(14, 3, c("yellow"))
    cast_a = sh.moved(0, 0)
    for x, y in ((12, 1), (15, 1), (13, 0), (15, 4)):
        cast_a.set(x, y, c("yellow"))
    cast_b = sh.copy()
    for x, y in ((12, 0), (15, 0), (11, 2)):
        cast_b.set(x, y, c("orange"))
    cast_b.set(5, 4, c("yellow"))
    cast_b.set(7, 4, c("yellow"))
    save_sheet("enemy_shooter", 16, 16, [
        ("idle", [sh, flick, sh_bob, flick.shift_rows(0, 13, 1)], 4.0, True),
        ("move", [sh, sh_sway, sh_bob, sh_sway], 6.0, True),
        ("attack", [cast_a, cast_b], 10.0, True),
        ("hurt", [sh.recolor(keep, c("white")), sh], 12.0, False),
    ])

    # --- 탄막형 (떠 있는 눈) ---
    bobs = (0, 0, 1, 1)
    sp = [spreader_frame(i, bob=bobs[i]) for i in range(4)]
    save_sheet("enemy_spreader", 16, 16, [
        ("idle", sp, 6.0, True),
        ("move", sp, 8.0, True),
        ("attack", [spreader_frame(0, glow=True), spreader_frame(1, glow=True, bob=1)], 10.0, True),
        ("hurt", [spreader_frame(0, flash=True), sp[0]], 12.0, False),
    ])


def build_combo_aura() -> list[Canvas]:
    """콤보 단계 표시: 발밑을 도는 불꽃 고리 (게임에서 단계별 색·크기)."""
    import math
    frames = []
    for phase in range(4):
        cv = Canvas(16, 16)
        for k in range(6):
            a = math.radians(k * 60 + phase * 15)
            x, y = round(7.5 + 6.5 * math.cos(a)), round(9.5 + 4.0 * math.sin(a))
            cv.set(x, y, c("white"))
            cv.set(x, y - 1, c("yellow"))
        frames.append(cv)
    return frames


def build_enemy_death() -> list[Canvas]:
    import math
    frames = []
    rng = random.Random(4242)
    pieces = [(rng.uniform(0, math.tau), rng.uniform(0.6, 1.0)) for _ in range(10)]
    for step in (2, 4, 6, 7):
        cv = Canvas(16, 16)
        for a, sp in pieces:
            r = step * sp
            cv.set(round(7.5 + r * math.cos(a)), round(7.5 + r * math.sin(a)),
                   c("crimson") if step < 6 else c("stone"))
        if step == 2:
            for x, y in [(7, 7), (8, 7), (7, 8), (8, 8)]:
                cv.set(x, y, c("white"))
        frames.append(cv)
    return frames



# ---------------------------------------------------------------------------
# 스킬 아이콘 (16x16) · 스킬 이펙트
# ---------------------------------------------------------------------------
def icon_frame() -> Canvas:
    t = Canvas(16, 16)
    t.fill(c("shadow"))
    t.line(0, 0, 15, 0, c("outline"))
    t.line(0, 15, 15, 15, c("outline"))
    t.line(0, 0, 0, 15, c("outline"))
    t.line(15, 0, 15, 15, c("outline"))
    t.line(1, 1, 14, 1, c("stone_dark"))
    return t


def build_skill_icons() -> None:
    import math
    # 블링크: 화살표 + 잔상
    blink = icon_frame()
    for i, col in enumerate(("stone", "sky", "cyan")):
        x = 3 + i * 3
        blink.line(x, 5, x, 10, c(col))
    blink.line(11, 4, 13, 7, c("white"))
    blink.line(13, 8, 11, 11, c("white"))
    blink.line(10, 7, 13, 7, c("white"))
    blink.line(10, 8, 13, 8, c("white"))
    # 흡수 장막: 호 + 빨려드는 탄
    absorb = icon_frame()
    for x, y in arc_pixels(4, 7.5, 7, -70, 70):
        absorb.set(x, y, c("cyan"))
    for x, y in arc_pixels(4, 7.5, 6, -55, 55):
        absorb.set(x, y, c("sky"))
    absorb.set(5, 7, c("red"))
    absorb.set(6, 8, c("red"))
    absorb.set(3, 8, c("yellow"))
    # 미끼 분신: 사람 두 개 (하나는 흐림)
    decoy = icon_frame()
    for ox, col in ((2, "stone"), (7, "blue")):
        decoy.line(ox + 2, 3, ox + 4, 3, c(col))
        for y in range(4, 7):
            decoy.line(ox + 1, y, ox + 5, y, c(col))
        for y in range(7, 12):
            decoy.line(ox + 2, y, ox + 4, y, c(col))
        decoy.set(ox + 4, 5, c("skin") if col == "blue" else c("pale"))
    # 충격파: 동심원
    shock = icon_frame()
    for r, col in ((2, "white"), (4.5, "yellow"), (6.5, "orange")):
        for y in range(16):
            for x in range(16):
                d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
                if abs(d - r) < 0.55 and 1 <= x <= 14 and 2 <= y <= 14:
                    shock.set(x, y, c(col))
    # 표식: 과녁
    mark = icon_frame()
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            if abs(d - 5.5) < 0.6 or abs(d - 2.5) < 0.6:
                mark.set(x, y, c("red"))
    mark.line(7, 2, 7, 4, c("white"))
    mark.line(8, 11, 8, 13, c("white"))
    mark.line(2, 8, 4, 8, c("white"))
    mark.line(11, 7, 13, 7, c("white"))
    save_sheet("skill_icons", 16, 16, [
        ("blink", [blink], 1.0, False),
        ("absorb", [absorb], 1.0, False),
        ("decoy", [decoy], 1.0, False),
        ("shockwave", [shock], 1.0, False),
        ("mark", [mark], 1.0, False),
    ])

    # 흡수 장막: 오른쪽 기준 큰 호 (게임에서 회전)
    barrier = []
    for phase in (0, 1):
        cv = Canvas(16, 16)
        for x, y in arc_pixels(2, 7.5, 11, -60, 60, 40):
            cv.set(x, y, c("cyan"))
        for x, y in arc_pixels(2, 7.5, 10, -50, 50, 40):
            cv.set(x, y, c("sky") if (x + y + phase) % 2 == 0 else c("cyan"))
        barrier.append(cv)
    # 충격파 고리 (게임에서 크게)
    wave = []
    for r in (2.5, 4.5, 6.5, 7.5):
        cv = Canvas(16, 16)
        for y in range(16):
            for x in range(16):
                d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
                if abs(d - r) < 0.6:
                    cv.set(x, y, c("yellow") if r < 6 else c("orange"))
        wave.append(cv)
    # 표식: 적 머리 위 과녁 (8x8 를 16 칸 가운데에)
    mk = []
    for phase in (0, 1):
        cv = Canvas(16, 16)
        for y in range(16):
            for x in range(16):
                d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
                if abs(d - (3.5 if phase == 0 else 3.0)) < 0.6:
                    cv.set(x, y, c("red"))
        cv.set(7, 7, c("white"))
        cv.set(8, 8, c("white"))
        mk.append(cv)
    save_sheet("skill_fx", 16, 16, [
        ("barrier", barrier, 10.0, True),
        ("shockwave", wave, 16.0, False),
        ("mark", mk, 4.0, True),
    ])


SIGN = [
    "................",
    "..oooooooooooo..",
    "..obbbbbbbbbbo..",
    "..obttttttttbo..",
    "..obbbbbbbbbbo..",
    "..obttttttbbbo..",
    "..obbbbbbbbbbo..",
    "..oooooooooooo..",
    "......oBBo......",
    "......oBBo......",
    "......oBBo......",
    "......oBBo......",
    "......oBBo......",
    ".....oBBBBo.....",
    "....oooooooo....",
    "................",
]


# ---------------------------------------------------------------------------
# 탄막 골렘 (48x48). 가슴의 코어가 약점 (반사탄으로만 제대로 맞음)
# 돌덩이 부위를 뒤 → 앞 순서로 쌓아 그린다. 부위마다 테두리 + 왼쪽 위 빛 명암 + 돌 얼룩.
# ---------------------------------------------------------------------------
## 이 높이 이상 들면 주먹을 머리 위로 치켜든 자세로 그린다
RAISED_ARM = 10


class GolemPose:
    """한 프레임의 자세·색. 기본값 = 평소 대기."""

    def __init__(self, **kw):
        self.bob = 0            # 몸통·머리·팔이 내려가는 정도 (숨쉬기)
        self.arm_l = 0          # 왼팔 들어올림 (px)
        self.arm_r = 0          # 오른팔 들어올림
        self.step = 0           # 걸음: -1 왼발 듦 / 1 오른발 듦
        self.slump = 0          # 그로기: 머리·팔 처짐
        self.core = "cyan"      # 코어 색
        self.core_hi = "white"  # 코어 하이라이트
        self.core_glow = False  # 코어 주변 빛 번짐
        self.eye = "yellow"
        self.rune = "blue"      # 어깨 룬 (평소 흐림, 공격 시 밝게)
        self.crack = "shadow"   # 금 색 (각성 시 주황)
        self.stars = -1         # 그로기 별 회전 위치 (-1 = 없음)
        self.sparks = 0         # 각성·필살기 파편 (0 = 없음, 1~ = 프레임)
        for k, v in kw.items():
            setattr(self, k, v)


def _stone_part(t: Canvas, inside, x0: int, y0: int, x1: int, y1: int, seed: int,
                base: str = "stone", hi: str = "stone_light", lo: str = "stone_dark") -> None:
    """inside(x, y) 로 정의된 돌덩이 하나: 테두리(outline) + 위·왼쪽 밝게 + 아래·오른쪽 어둡게 + 얼룩."""
    rng = random.Random(seed)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if not inside(x, y):
                continue
            edge = not (inside(x - 1, y) and inside(x + 1, y) and inside(x, y - 1) and inside(x, y + 1))
            if edge:
                t.set(x, y, c("outline"))
                continue
            top = not inside(x, y - 2)
            left = not inside(x - 2, y)
            bottom = not inside(x, y + 2)
            right = not inside(x + 2, y)
            if top or (left and not bottom):
                col = hi
            elif bottom or right:
                col = lo
            else:
                col = base
            # 돌 얼룩 (같은 시드 = 매번 같은 무늬)
            r = rng.random()
            if col == base and r < 0.07:
                col = lo
            elif col == base and r < 0.10:
                col = hi
            t.set(x, y, c(col))


def _rrect(x0: int, y0: int, x1: int, y1: int, r: int):
    """모서리가 둥근 사각형 안쪽 판정 함수."""
    def inside(x, y):
        if x < x0 or x > x1 or y < y0 or y > y1:
            return False
        cx = min(max(x, x0 + r), x1 - r)
        cy = min(max(y, y0 + r), y1 - r)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5
    return inside


def _trapezoid(x0_top: int, x1_top: int, x0_bot: int, x1_bot: int, y0: int, y1: int, r: int = 2):
    """위가 넓고 아래가 좁은 몸통."""
    def inside(x, y):
        if y < y0 or y > y1:
            return False
        f = (y - y0) / max(y1 - y0, 1)
        left = x0_top + (x0_bot - x0_top) * f
        right = x1_top + (x1_bot - x1_top) * f
        if x < left - 0.01 or x > right + 0.01:
            return False
        # 위쪽 모서리 둥글게
        if y < y0 + r:
            if x < x0_top + r and (x - (x0_top + r)) ** 2 + (y - (y0 + r)) ** 2 > r * r + 0.5:
                return False
            if x > x1_top - r and (x - (x1_top - r)) ** 2 + (y - (y0 + r)) ** 2 > r * r + 0.5:
                return False
        return True
    return inside


def golem_frame(p: GolemPose) -> Canvas:
    t = Canvas(48, 48)
    b = p.bob
    s = p.slump

    # --- 다리·발 (맨 뒤) ---
    for lx, lift in ((12, p.step == -1), (28, p.step == 1)):
        dy = -1 if lift else 0
        _stone_part(t, _rrect(lx + 1, 36 + dy, lx + 7, 44 + dy, 1), lx + 1, 36 + dy, lx + 7, 44 + dy, 11 + lx,
                    base="stone_dark", hi="stone", lo="shadow")
        _stone_part(t, _rrect(lx, 42 + dy, lx + 8, 47 + dy, 2), lx, 42 + dy, lx + 8, 47 + dy, 13 + lx)

    # --- 허리 ---
    _stone_part(t, _rrect(14, 31 + b, 33, 39 + b, 2), 14, 31 + b, 33, 39 + b, 21,
                base="stone_dark", hi="stone", lo="shadow")

    # --- 몸통 (넓은 가슴) ---
    torso = _trapezoid(8, 39, 13, 34, 12 + b, 35 + b, 3)
    _stone_part(t, torso, 8, 12 + b, 39, 35 + b, 31)
    # 가슴 판 이음새
    t.line(15, 30 + b, 32, 30 + b, c("stone_dark"))
    t.line(23, 31 + b, 23, 34 + b, c("stone_dark"))
    # 금
    t.line(12, 16 + b, 15, 22 + b, c(p.crack))
    t.line(15, 22 + b, 14, 26 + b, c(p.crack))
    t.line(36, 15 + b, 33, 20 + b, c(p.crack))
    t.line(30, 31 + b, 33, 34 + b, c(p.crack))

    # --- 코어 (가슴 가운데): 홈 → 코어 → 하이라이트 ---
    cx, cy = 24, 22 + b
    for y in range(cy - 8, cy + 9):
        for x in range(cx - 8, cx + 9):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= 6.6 and d > 5.5:
                t.set(x, y, c("shadow"))          # 홈 테두리
            elif d <= 5.5 and d > 4.6:
                t.set(x, y, c("outline"))
            elif d <= 4.6:
                # 아래·오른쪽은 진하게
                dark = (x - cx) + (y - cy) > 2.5
                t.set(x, y, c(p.core) if not dark else c({"cyan": "sky", "sky": "blue", "orange": "red",
                                                            "yellow": "orange", "red": "crimson",
                                                            "white": "cyan"}.get(p.core, p.core)))
            elif p.core_glow and d <= 7.6 and (x + y) % 2 == 0:
                t.set(x, y, c(p.core))            # 빛 번짐 (점점이)
    t.set(cx - 2, cy - 2, c(p.core_hi))
    t.set(cx - 1, cy - 3, c(p.core_hi))
    t.set(cx - 3, cy - 1, c(p.core_hi))

    # --- 팔 (어깨 아래로 늘어뜨림) + 주먹. 높이 들면(필살기) 머리 위로 올라가므로 나중에 그림 ---
    for side in (-1, 1):
        lift = p.arm_l if side < 0 else p.arm_r
        if lift >= RAISED_ARM:
            continue
        ax0 = 2 if side < 0 else 37
        ay0 = 18 + b + s - lift
        _stone_part(t, _rrect(ax0 + 1, ay0, ax0 + 8, ay0 + 14, 2), ax0 + 1, ay0, ax0 + 8, ay0 + 14, 41 + side)
        fx0 = 0 if side < 0 else 36
        fy0 = ay0 + 12
        _stone_part(t, _rrect(fx0, fy0, fx0 + 11, fy0 + 9, 3), fx0, fy0, fx0 + 11, fy0 + 9, 43 + side)
        # 손가락 마디
        for k in range(3):
            t.set(fx0 + 3 + k * 3, fy0 + 7, c("stone_dark"))

    # --- 어깨 바위 (팔 위를 덮음) + 룬 + 이끼 ---
    for side in (-1, 1):
        sx0 = 1 if side < 0 else 33
        sy0 = 9 + b + s // 2 - (min(p.arm_l if side < 0 else p.arm_r, 6) // 2)
        _stone_part(t, _rrect(sx0, sy0, sx0 + 13, sy0 + 11, 4), sx0, sy0, sx0 + 13, sy0 + 11, 51 + side)
        # 룬: 작은 ㅅ 모양 문양
        rx, ry = sx0 + 6, sy0 + 5
        for dx, dy in ((0, 0), (-1, 1), (1, 1), (0, -1), (-2, 2), (2, 2)):
            t.set(rx + dx, ry + dy, c(p.rune))
        # 이끼 (어깨 윗면)
        for dx in (2, 3, 5, 9, 10):
            t.set(sx0 + dx, sy0 + 1, c("green") if dx % 2 else c("green_dark"))
        t.set(sx0 + 3, sy0 + 2, c("green_dark"))

    # --- 머리 (어깨 사이에 박힘) ---
    hy = 3 + b + s
    _stone_part(t, _rrect(17, hy, 30, hy + 11, 3), 17, hy, 30, hy + 11, 61)
    # 이마 튀어나온 부분
    t.line(18, hy + 4, 29, hy + 4, c("stone_dark"))
    t.line(19, hy + 3, 28, hy + 3, c("stone_light"))
    # 눈 (빛나는 틈)
    for ex in (20, 25):
        t.line(ex, hy + 6, ex + 2, hy + 6, c(p.eye))
        t.set(ex + 1, hy + 7, c(p.eye))
    t.line(20, hy + 9, 27, hy + 9, c("stone_dark"))  # 입
    t.set(19, hy + 1, c("green"))
    t.set(20, hy + 1, c("green_dark"))

    # --- 머리 위로 치켜든 팔·주먹 (어깨·머리보다 앞) ---
    for side in (-1, 1):
        lift = p.arm_l if side < 0 else p.arm_r
        if lift < RAISED_ARM:
            continue
        top = max(0, 14 - lift)                 # 높이 들수록 위로
        ax0 = 6 if side < 0 else 33
        _stone_part(t, _rrect(ax0, top + 6, ax0 + 8, 18 + b, 2), ax0, top + 6, ax0 + 8, 18 + b, 71 + side)
        fx0 = ax0 - 2 + (1 if side < 0 else 0)
        _stone_part(t, _rrect(fx0, top, fx0 + 11, top + 9, 3), fx0, top, fx0 + 11, top + 9, 73 + side)
        for k in range(3):
            t.set(fx0 + 3 + k * 3, top + 2, c("stone_dark"))

    # --- 그로기 별 (머리 위를 도는) ---
    if p.stars >= 0:
        import math
        for k in range(3):
            a = math.radians(p.stars * 40 + k * 120)
            sx, sy = round(24 + 9 * math.cos(a)), round(hy - 2 + 2.5 * math.sin(a))
            for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)):
                t.set(sx + dx, sy + dy, c("yellow") if (dx, dy) != (0, 0) else c("white"))

    # --- 파편 (각성·필살기) ---
    if p.sparks:
        rng = random.Random(900 + p.sparks)
        for _ in range(10):
            x, y = rng.randrange(2, 46), rng.randrange(1, 30)
            if t.px[y][x] is None:
                t.set(x, y, c("orange") if rng.random() < 0.5 else c("yellow"))
    return t


def build_golem() -> None:
    outline = {c("outline")}
    P = GolemPose
    idle = [P(), P(bob=0), P(bob=1, core="sky"), P(bob=1, core="sky")]
    move = [P(step=-1), P(bob=1), P(step=1), P(bob=1)]
    attack = [P(arm_l=4, arm_r=4, core="orange", rune="cyan", core_glow=True),
              P(arm_l=7, arm_r=7, core="yellow", rune="cyan", core_glow=True),
              P(arm_l=5, arm_r=5, core="orange", rune="sky", core_glow=True)]
    base_flash = golem_frame(P())
    hurt = [base_flash.recolor(outline, c("white")), golem_frame(P())]
    core_hit = [golem_frame(P(core="white", core_hi="white", core_glow=True)), golem_frame(P(core="cyan", core_glow=True))]
    groggy = [P(slump=3, core="blue", core_hi="sky", eye="stone_dark", rune="navy", stars=i) for i in range(3)]
    awaken = [P(core="red", eye="red", rune="red", crack="orange", core_glow=True, sparks=1),
              P(bob=1, core="red", eye="orange", rune="orange", crack="orange", core_glow=True, sparks=2),
              P(arm_l=3, arm_r=3, core="white", core_hi="yellow", eye="red", rune="red", crack="orange", core_glow=True, sparks=3)]
    special = [P(arm_l=12, arm_r=12, core="white", core_hi="yellow", eye="red", rune="orange", crack="orange", core_glow=True, sparks=4),
               P(arm_l=14, arm_r=14, core="red", core_hi="white", eye="white", rune="red", crack="orange", core_glow=True, sparks=5)]
    save_sheet("golem", 48, 48, [
        ("idle", [golem_frame(p) for p in idle], 4.0, True),
        ("move", [golem_frame(p) for p in move], 6.0, True),
        ("attack", [golem_frame(p) for p in attack], 8.0, True),
        ("hurt", hurt, 12.0, False),
        ("core_hit", core_hit, 12.0, False),
        ("groggy", [golem_frame(p) for p in groggy], 6.0, True),
        ("awaken", [golem_frame(p) for p in awaken], 6.0, True),
        ("special", [golem_frame(p) for p in special], 8.0, True),
    ])


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
HEART = [
    ".oo.oo..",
    "owrorro.",
    "orrrrro.",
    "orrrrro.",
    ".orrro..",
    "..oro...",
    "...o....",
    "........",
]
AMMO_FULL = [
    "..oo....",
    ".oyyo...",
    ".oyyo...",
    ".oYYo...",
    ".oYYo...",
    ".oBBo...",
    ".oBBo...",
    "..oo....",
]


def build_ui_icons() -> None:
    cmap = {".": None, "o": "outline", "y": "yellow", "Y": "orange", "B": "brown"}
    full = Canvas.from_rows(AMMO_FULL, cmap)
    empty = full.recolor({c("outline")}, c("stone_dark"))
    hmap = {".": None, "o": "outline", "r": "red", "w": "white"}
    heart = Canvas.from_rows(HEART, hmap)
    heart_empty = heart.recolor({c("outline")}, c("stone_dark"))
    save_sheet("ui_icons", 8, 8, [
        ("ammo_full", [full], 1.0, False),
        ("ammo_empty", [empty], 1.0, False),
        ("heart_full", [heart], 1.0, False),
        ("heart_empty", [heart_empty], 1.0, False),
    ])

CROSSHAIR = [
    "....o....",
    "...owo...",
    "...owo...",
    ".oo...oo.",
    "ow..w..wo",
    ".oo...oo.",
    "...owo...",
    "...owo...",
    "....o....",
]


def build_ui() -> None:
    cross = Canvas.from_rows(CROSSHAIR, {".": None, "o": "outline", "w": "white"})
    cross.to_image().save(OUT / "crosshair.png", optimize=False)


# ---------------------------------------------------------------------------
# 팔레트 파일 (Aseprite·GIMP에서 그대로 불러올 수 있는 .gpl + 1px 견본 PNG)
# ---------------------------------------------------------------------------
def build_icon() -> None:
    """창·exe 아이콘 (64x64): 플레이어 상반신을 4배로."""
    base = Canvas.from_rows(PLAYER_BASE, PLAYER_CMAP).to_image().crop((0, 0, 16, 16))
    img = Image.new("RGBA", (64, 64), (*PAL_RGB[c("shadow")], 255))
    img.alpha_composite(base.resize((64, 64), Image.NEAREST))
    img.save(ROOT / "art" / "icon.png", optimize=False)


def build_palette() -> None:
    lines = ["GIMP Palette", f"Name: {THEME}", "Columns: 8", "#"]
    for (name, _), (r, g, b) in zip(PALETTE, PAL_RGB):
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    (OUT / "palette.gpl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    img = Image.new("RGBA", (len(PALETTE), 1))
    for i, rgb in enumerate(PAL_RGB):
        img.putpixel((i, 0), (*rgb, 255))
    img.save(OUT / "palette.png", optimize=False)


def verify_palette() -> None:
    """생성된 모든 PNG가 팔레트 색만 쓰는지 검사한다."""
    allowed = set(PAL_RGB)
    for png in sorted(OUT.glob("*.png")):
        raw = Image.open(png).convert("RGBA").tobytes()
        for i in range(0, len(raw), 4):
            r, g, b, a = raw[i : i + 4]
            if a == 0:
                continue
            assert a == 255 and (r, g, b) in allowed, f"{png.name}: 팔레트 밖 색 {(r, g, b, a)}"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_palette()
    build_player()
    build_player_cloak()
    build_player_views()
    build_gun()
    build_tiles()
    build_ui()
    build_bullets()
    build_effects()
    build_props()
    build_ui_icons()
    build_enemies()
    build_skill_icons()
    build_golem()
    build_icon()
    verify_palette()
    print(f"스프라이트 생성 완료: {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
