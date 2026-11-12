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
# 주인공: 레퍼런스 디자인(검은 한복풍 도포)을 16x24 로 옮긴 것.
#   큰 머리(삐죽한 검은 머리 + 은 머리장식·붉은 술), 흰 동정, 붉은 고름, 자수·흰 안감의 넓은 소매,
#   허리띠와 고리·흰 술, 발목까지 오는 긴 옷자락(붉은 안감이 비침), 버클 달린 부츠.
#   등 뒤로 휘날리는 붉은 리본 두 가닥은 별도 층(player_cloak).
PLAYER_CMAP: dict[str, str | None] = {
    ".": None,
    "o": "outline",
    "t": "shadow",       # 검은 머리카락
    "d": "stone_dark",   # 머리카락 윤기
    "s": "skin",
    "e": "plum",         # 눈
    "y": "pale",         # 은 머리장식
    "Y": "white",        # 머리장식 빛
    "r": "crimson",      # 붉은 고름·안감·술
    "R": "red",          # 붉은 천 빛 받는 곳
    "W": "white",        # 동정·소매 안감·속치마
    "P": "pale",         # 허리 고리·흰 술
    "c": "shadow",       # 검은 옷
    "C": "stone_dark",   # 옷 밝은 면 (소매)
    "m": "tan",          # 자수
    "T": "stone",        # 허리띠
    "k": "stone_dark",   # 부츠
    "b": "pale",         # 부츠 버클
}
FB_CMAP = PLAYER_CMAP
PLAYER_BOOT_NEAR = "stone_dark"
PLAYER_BOOT_FAR = "shadow"
PLAYER_BUCKLE = "pale"
PLAYER_ROBE = "shadow"
# 옆모습 (오른쪽을 봄). 0~20행 = 머리·옷(밑단까지), 21~23행 = 부츠 (걷기는 코드로 그린다)
PLAYER_BASE = [
    "......oo........",
    "....ootdooo.....",
    "...otttttttto...",
    "..ottdttttttto..",
    "..otdtttttttto..",
    ".oyottttttstso..",
    ".oYottttssesto..",
    ".oroottsssssso..",
    ".oro.ottsssso...",
    "..o...oosWWo....",
    ".....ocWWrcco...",
    "....occcWrRco...",
    "....ocCCcrcco...",
    "...ocCCCCcrco...",
    "...oCCCCCCTPo...",
    "...ommCCmmcPo...",
    "...oWWWWWWcRo...",
    "....occcccRRo...",
    "...occccccRrco..",
    "...ocmccccrRco..",
    "...oWWWccrrWWo..",
    ".....okko.okko..",
    ".....okkbookkbo.",
    ".....oooo.ooooo.",
]
# 옆모습에서 소매를 뺀 몸통 (12~16행). 걷을 때 소매가 따로 앞뒤로 흔들린다
PLAYER_SIDE_TORSO = [
    "....occccrcco...",
    "....occccrcco...",
    "....occcTTTPo...",
    "....occccccPo...",
    "....occccccRo...",
]
# 가까운 소매 (왼쪽 위 = 몸 그림의 (3, 12)). 자수 띠와 흰 안감
PLAYER_SIDE_SLEEVE = [
    ".oCCo...",
    "oCCCCo..",
    "oCCCCCCo",
    "ommCCmmo",
    "oWWWWWWo",
    ".oooooo.",
]
PLAYER_SLEEVE_AT = (3, 12)
# 쓰러져 누운 모습 (머리 왼쪽, 발 오른쪽)
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
    "................",
    "..ooooo.........",
    ".otttttoooooooo.",
    "oyttdssWccrccckk",
    "ortttseWCmcRrckb",
    "orottsoWccccrooo",
    ".o.ooo.ooooooo..",
]
# 키 (프레임 높이). 발 위치는 16x16 시절과 같게 게임에서 위로 (높이-16)/2 만큼 올려 그린다
PLAYER_H = 24
# 옷 밑단 마지막 줄 (이 아래는 부츠), 총구 높이
PLAYER_HEM_ROW = 20
PLAYER_GUN_Y = 12
# 옆모습 걷기 8프레임: 가까운 발의 (x, 든 높이). 먼 발은 4프레임 늦게 같은 동작
#   앞에 디딤 → 몸 아래 → 뒤로 밀림 → 들어서 앞으로
SIDE_WALK_FEET = [(11, 0), (10, 0), (8, 0), (6, 0), (5, 0), (6, 1), (8, 1), (10, 1)]
SIDE_STAND_FEET = ((10, 0), (6, 0))     # (가까운 발, 먼 발)
SIDE_SPREAD_FEET = ((11, 0), (4, 0))    # 공격·회피 때 벌린 발
# 상체: 체중을 실을 때 1px 내려앉는다. 소매는 발과 엇갈려 앞뒤로 흔들린다
SIDE_WALK_BOB = [0, 1, 0, 0, 0, 1, 0, 0]
SIDE_WALK_SLEEVE = [-1, -1, 0, 1, 1, 1, 0, -1]


def _outline_empty(cv: Canvas, cells: set[tuple[int, int]], min_y: int = 0) -> None:
    """cells 둘레의 빈 칸에 테두리를 친다."""
    for (x, y) in cells:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < cv.w and min_y <= ny < cv.h and (nx, ny) not in cells and cv.px[ny][nx] is None:
                cv.set(nx, ny, c("outline"))


def _draw_boot(cv: Canvas, x: int, lift: int, color: str, toe: int = 1, width: int = 2) -> set[tuple[int, int]]:
    """부츠 한 짝 (width x 2 + 발끝 버클 1칸). lift 만큼 들면 윗부분은 옷자락에 가려진다. toe: +1 오른쪽, 0 없음(정면)."""
    cells: set[tuple[int, int]] = set()
    top = PLAYER_HEM_ROW + 1 - lift
    for dy in range(2):
        for dx in range(width):
            cells.add((x + dx, top + dy))
    for (px, py) in cells:
        if py > PLAYER_HEM_ROW:
            cv.set(px, py, c(color))
    if toe:
        tx, ty = x + 2 * toe if toe > 0 else x - 1, top + 1
        cv.set(tx, ty, c(PLAYER_BUCKLE))
        cells.add((tx, ty))
    return {p for p in cells if p[1] > PLAYER_HEM_ROW}


def side_body(sleeve_dx: int = 0) -> Canvas:
    """옆모습 머리·옷 (부츠 없음). 소매를 sleeve_dx 만큼 앞(+)·뒤(-)로 옮겨 그린다."""
    rows = PLAYER_BASE[:12] + PLAYER_SIDE_TORSO + PLAYER_BASE[17:PLAYER_HEM_ROW + 1] + ["." * 16] * 3
    cv = Canvas.from_rows(rows, PLAYER_CMAP)
    sleeve = Canvas.from_rows(PLAYER_SIDE_SLEEVE, PLAYER_CMAP)
    ox, oy = PLAYER_SLEEVE_AT
    for y in range(sleeve.h):
        for x in range(sleeve.w):
            v = sleeve.px[y][x]
            if v is not None:
                cv.set(ox + sleeve_dx + x, oy + y, v)
    return cv


def press(cv: Canvas, k: int) -> Canvas:
    """몸을 k 줄 낮춘다 (웅크림): 머리~옷을 아래로 밀고 밑단 두 줄과 부츠는 그대로 둔다."""
    if k <= 0:
        return cv.copy()
    out = cv.copy()
    keep_from = PLAYER_HEM_ROW - 1
    for y in range(keep_from):
        src = y - k
        out.px[y] = cv.px[src][:] if src >= 0 else [None] * cv.w
    return out


def side_frame(feet=SIDE_STAND_FEET, sleeve_dx: int = 0, down: int = 0) -> Canvas:
    """옆모습 한 프레임: 부츠(먼 발 → 가까운 발) 위에 몸을 얹는다."""
    cv = Canvas(16, PLAYER_H)
    (nx, nl), (fx, fl) = feet
    cells = _draw_boot(cv, fx, fl, PLAYER_BOOT_FAR)
    near = _draw_boot(cv, nx, nl, PLAYER_BOOT_NEAR)
    # 두 발이 겹치면 가까운 발 뒤쪽에 경계선
    for (x, y) in near:
        if (x - 1, y) in cells and (x - 1, y) not in near:
            cv.set(x - 1, y, c("outline"))
    cells |= near
    _outline_empty(cv, cells, PLAYER_HEM_ROW + 1)
    body = press(side_body(sleeve_dx), down)
    for y in range(PLAYER_HEM_ROW + 1):
        for x in range(16):
            v = body.px[y][x]
            if v is not None:
                cv.set(x, y, v)
    return cv


def side_walk_frames() -> list[Canvas]:
    n = len(SIDE_WALK_FEET)
    frames = []
    for i in range(n):
        fx, fl = SIDE_WALK_FEET[(i + n // 2) % n]
        frames.append(side_frame((SIDE_WALK_FEET[i], (fx - 1, fl)), SIDE_WALK_SLEEVE[i], SIDE_WALK_BOB[i]))
    return frames


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
    """붉은 리본 두 가닥 (24x24, 예전 목도리 꼬리 자리). anchor 에서 back_dir(-1 왼쪽/ +1 오른쪽) 쪽으로 늘어지거나 휘날린다.
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
            t.set(x, y, c("crimson") if not top_open else c("red"))
        else:
            t.set(x, y, c("red") if top_open else c("crimson"))
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
    return scarf_tails((CLOAK_BODY_X + 4, 13), lean, flutter)


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
PLAYER_FRONT = [
    ".......oo.......",
    "....oootdooo....",
    "...ottttdtttto..",
    "..otttdtttttyYo.",
    "..ottdttttttoro.",
    "..otttsttsttoro.",
    "..otssssssssor..",
    "..otsesssseso...",
    "...oossssssoo...",
    "....ooWssWoo....",
    "...occWWWWcco...",
    "..occccRrcccco..",
    ".occCccrRccCcco.",
    ".ocmCcTTPTTcCmo.",
    ".ommcocPccocmmo.",
    ".oWWoccPcRcoWWo.",
    ".ooo.occcRRo.oo.",
    "....occccRrco...",
    "...occcccrRcco..",
    "...ocmccccrmco..",
    "...oWWWccrWWWo..",
    "................",
    "................",
    "................",
]
PLAYER_BACK = [
    ".......oo.......",
    "....oootdooo....",
    "...ottttttttto..",
    ".oYyttdttttttto.",
    "orotttdttttttto.",
    "orootttttdtttto.",
    ".r.otttttttdtto.",
    "...ottdtttttto..",
    "...otttdttttto..",
    "....ootttttoo...",
    "...occWWWWcco...",
    "..occcccccccco..",
    ".occCccccccCcco.",
    ".ocmCcTTTTTcCmo.",
    ".ommcoccccocmmo.",
    ".oWWoccrrccoWWo.",
    ".ooo.ocrRrco.oo.",
    "....occrcrcco...",
    "...occcrccrcco..",
    "...ocmcccccmco..",
    "...oWWWccccWWo..",
    "................",
    "................",
    "................",
]
# 정면·뒷모습 부츠 위치 (왼발 x, 오른발 x)와 소매 범위 (x 시작, x 끝)
FB_FEET_X = (4, 9)
FB_SLEEVES = ((0, 4), (11, 15))
FB_SLEEVE_ROWS = (12, 16)


def fb_arms(cv: Canvas, dy_left: int, dy_right: int) -> Canvas:
    """양 소매를 위아래로 흔든다. 소매가 비킨 자리의 몸 쪽 칸은 옷 색으로 메운다."""
    out = cv.copy()
    y0, y1 = FB_SLEEVE_ROWS
    for (x0, x1), dy, inner in ((FB_SLEEVES[0], dy_left, FB_SLEEVES[0][1]), (FB_SLEEVES[1], dy_right, FB_SLEEVES[1][0])):
        if dy == 0:
            continue
        block = {(x, y): cv.px[y][x] for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}
        for (x, y) in block:
            out.set(x, y, c(PLAYER_ROBE) if x == inner and y < y1 else None)
        for (x, y), v in block.items():
            if v is not None:
                out.set(x, y + dy, v)
    return out


def fb_frame(base: Canvas, lift_l: int = 0, lift_r: int = 0, down: int = 0, arms: tuple[int, int] = (0, 0)) -> Canvas:
    """정면·뒷모습 한 프레임: 부츠 위에 몸을 얹는다."""
    cv = Canvas(16, PLAYER_H)
    cells: set[tuple[int, int]] = set()
    for x0, lift in ((FB_FEET_X[0], lift_l), (FB_FEET_X[1], lift_r)):
        boot = _draw_boot(cv, x0, lift, PLAYER_BOOT_NEAR, toe=0, width=3)
        # 버클: 부츠 윗줄 가운데 (발을 들어 윗줄이 가려지면 안 보인다)
        if (x0 + 1, PLAYER_HEM_ROW + 1) in boot and lift == 0:
            cv.set(x0 + 1, PLAYER_HEM_ROW + 1, c(PLAYER_BUCKLE))
        cells |= boot
    _outline_empty(cv, cells, PLAYER_HEM_ROW + 1)
    body = press(fb_arms(base, *arms), down)
    for y in range(PLAYER_HEM_ROW + 1):
        for x in range(16):
            v = body.px[y][x]
            if v is not None:
                cv.set(x, y, v)
    return cv


def build_player_view(name: str, rows: list[str], back: bool) -> None:
    base = Canvas.from_rows(rows, FB_CMAP)
    idle = [fb_frame(base), fb_frame(base), fb_frame(base, down=1), fb_frame(base, down=1)]
    # 걷기 6프레임: 왼발 듦(2프레임) → 디딤(상체 1px 내려앉음) → 오른발 반복. 양 소매는 엇갈려 흔든다
    # (왼발 든 높이, 오른발 든 높이, 상체 내려앉음, 소매 흔들림)
    walk_plan = [(1, 0, 0, 1), (1, 0, 0, 1), (0, 0, 1, 0), (0, 1, 0, -1), (0, 1, 0, -1), (0, 0, 1, 0)]
    move = [fb_frame(base, ll, lr, dy, (d, -d)) for ll, lr, dy, d in walk_plan]
    # 사격: 몸은 그대로 (총은 따로 그림)
    shoot = [fb_frame(base), fb_frame(base)]
    # 근접: 단검이 앞(정면은 아래, 뒷모습은 위)으로 호를 그림
    blade, tip = c("pale"), c("white")
    m0, m1, m2 = (fb_frame(base) for _ in range(3))
    yy = (lambda y: 23 - y) if not back else (lambda y: y)
    m0.line(13, yy(12), 15, yy(9), blade)
    for x, y in ((3, 2), (5, 1), (8, 1), (11, 1), (13, 2)):
        m1.set(x, yy(y), tip)
    for x, y in ((4, 2), (6, 1), (10, 1), (12, 2)):
        m1.set(x, yy(y), blade)
    m2.line(0, yy(9), 2, yy(12), blade)
    melee = [m0, m1, m2]
    dodge = [fb_frame(base, down=2), fb_frame(base, down=4), fb_frame(base, down=2)]
    for y in (8, 13):
        dodge[1].line(0, y, 1, y, c("pale"))
        dodge[1].line(14, y, 15, y, c("pale"))
    outline = {c("outline")}
    standing = fb_frame(base)
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
        "move": [[0, dy] for _, _, dy, _ in walk_plan],
        "dodge": [[0, 2], [0, 4], [0, 2]],
        "death": [[0, 2], [0, 4], [0, 0], [0, 0]],
    }})


def fb_cloak_frame(back: bool, lean: str, flutter: int) -> Canvas:
    """정면: 목 옆에서 몸 뒤로 (휘날릴 때만 옆으로 보임) / 뒷모습: 목 뒤 매듭에서 등 위로 늘어짐 (몸 앞에 그림)."""
    if back:
        return scarf_tails((4 + 7, 15), lean, flutter, spread=-10.0, angle_scale=0.7)
    return scarf_tails((4 + 3, 13), lean, flutter)


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


def build_player() -> None:
    gy = PLAYER_GUN_Y
    idle = [side_frame(), side_frame(), side_frame(down=1), side_frame(down=1)]
    # 걷기 8프레임: 부츠가 옷자락 아래에서 번갈아 나오고, 디딜 때 상체가 1px 내려앉고, 소매가 앞뒤로 흔들린다
    move = side_walk_frames()
    # 사격: 몸은 서 있는 그대로 (총구 불꽃·반동은 따로 그린 총이 맡는다)
    shoot = [side_frame(), side_frame()]

    # 근접: 단검 (위 → 앞 → 아래), 발을 벌리고 소매가 따라 움직인다
    blade, tip = c("pale"), c("white")
    m0 = side_frame(SIDE_SPREAD_FEET, sleeve_dx=-1)
    m0.line(12, gy - 1, 15, gy - 6, blade)
    m0.set(15, gy - 7, tip)
    m1 = side_frame(SIDE_SPREAD_FEET, sleeve_dx=1)
    for x, y in [(12, gy - 6), (13, gy - 5), (14, gy - 3), (15, gy - 1), (14, gy + 1), (13, gy + 3)]:
        m1.set(x, y, tip)
    for x, y in [(12, gy - 5), (13, gy - 3), (14, gy - 1), (13, gy + 1), (12, gy + 2)]:
        m1.set(x, y, blade)
    m2 = side_frame(SIDE_SPREAD_FEET, sleeve_dx=1)
    m2.line(12, gy + 1, 15, gy + 5, blade)
    m2.set(15, gy + 6, tip)
    melee = [m0, m1, m2]

    # 회피: 몸을 낮추고 소매가 뒤로 쏠림 + 잔상 선
    squash = side_frame(SIDE_SPREAD_FEET, sleeve_dx=-1, down=2)
    ball = side_frame(SIDE_SPREAD_FEET, sleeve_dx=-1, down=4)
    for y in (8, 13, 18):
        ball.line(0, y, 1, y, c("pale"))
    dodge = [squash, ball, squash]

    outline = {c("outline")}
    standing = side_frame()
    hurt = [standing.recolor(outline, c("white")), standing.recolor(outline, c("red"))]

    # 쓰러짐: 주저앉기 → 옆으로 쓰러져 누움 (따로 그린 프레임)
    lying = Canvas.from_rows(PLAYER_LYING, PLAYER_CMAP)
    death = [side_frame(down=2), side_frame(down=4), lying.moved(0, -1), lying]
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
        "shoulder": [7.5, 11.5],
        # 프레임별 상체 이동 [dx(보는 쪽 +), dy(아래 +)] — 게임이 리본 층을 같이 움직이는 데 쓴다
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


# 메뉴용 화살표 포인터 (타이틀·스킬 설정·일시정지·기록 화면). 끝점(핫스폿)은 왼쪽 위 (0, 0)
POINTER = [
    "o.......",
    "oo......",
    "owo.....",
    "owwo....",
    "owwwo...",
    "owwwwo..",
    "owwwppo.",
    "owwpoooo",
    "owpo....",
    "opo.....",
    "oo......",
]


def build_ui() -> None:
    cross = Canvas.from_rows(CROSSHAIR, {".": None, "o": "outline", "w": "white"})
    cross.to_image().save(OUT / "crosshair.png", optimize=False)
    pointer = Canvas.from_rows(POINTER, {".": None, "o": "outline", "w": "white", "p": "pale"})
    pointer.to_image().save(OUT / "pointer.png", optimize=False)
    build_touch_ui()
    build_start_line()


def build_start_line() -> None:
    """출발선 한 칸 16x16: 가운데 4px 폭 체크무늬 (세로로 이어 붙이면 끊김 없이 이어진다)"""
    cv = Canvas(16, 16)
    for y in range(16):
        for x in range(6, 10):
            light = ((x - 6) // 2 + y // 2) % 2 == 0
            cv.set(x, y, c("white") if light else c("outline"))
    cv.to_image().save(OUT / "start_line.png", optimize=False)


def _ring_canvas(size: int, rings: list[tuple[float, float, str]]) -> Canvas:
    """원 여러 겹 (안쪽 반지름, 바깥 반지름, 색). 뒤에 오는 것이 위에 칠해진다."""
    cv = Canvas(size, size)
    ctr = (size - 1) / 2
    for inner, outer, color in rings:
        for y in range(size):
            for x in range(size):
                d = math.hypot(x - ctr, y - ctr)
                if inner <= d < outer:
                    cv.set(x, y, c(color))
    return cv


def build_touch_ui() -> None:
    """안드로이드 터치 조작 (조이스틱 받침·손잡이, 둥근 버튼). 반투명은 게임에서 modulate 로 준다."""
    # 조이스틱 받침 40x40: 테두리 고리 + 어두운 속
    base = _ring_canvas(40, [(0, 20, "outline"), (0, 19, "shadow"), (16, 18, "stone_light"), (8, 9, "stone")])
    base.to_image().save(OUT / "touch_stick_base.png", optimize=False)
    # 조이스틱 손잡이 16x16: 밝은 원 + 위쪽 하이라이트
    knob = _ring_canvas(16, [(0, 8, "outline"), (0, 7, "pale"), (0, 5, "white")])
    for x, y in [(5, 4), (6, 4), (4, 5)]:
        knob.set(x, y, c("cyan"))
    knob.to_image().save(OUT / "touch_stick_knob.png", optimize=False)
    # 둥근 버튼 26x26 (글자는 게임에서 얹는다): 테두리 + 속 + 아래쪽 그늘
    btn = _ring_canvas(26, [(0, 13, "outline"), (0, 12, "stone_light"), (0, 11, "stone")])
    for y in range(26):
        for x in range(26):
            d = math.hypot(x - 12.5, y - 12.5)
            if 9 <= d < 11 and y > 14:
                btn.set(x, y, c("stone_dark"))
    btn.to_image().save(OUT / "touch_button.png", optimize=False)
    # 작은 네모 버튼 30x14 (위쪽 일시정지·스킬 설정 등)
    small = Canvas(30, 14)
    for y in range(14):
        for x in range(30):
            edge = x in (0, 29) or y in (0, 13)
            corner = (x in (0, 29)) and (y in (0, 13))
            if corner:
                continue
            small.set(x, y, c("outline") if edge else c("stone"))
    for x in range(1, 29):
        small.set(x, 12, c("stone_dark"))
    small.to_image().save(OUT / "touch_button_small.png", optimize=False)


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


# ---------------------------------------------------------------------------
# 스토리판: 지역 타일 (연구소·광산촌·숲) — tiles 와 같은 구성(floor, floor_alt, wall_top, wall_face, pit)
# ---------------------------------------------------------------------------
def _save_tileset(name: str, tiles: list[tuple[str, Canvas]], extra: dict | None = None) -> None:
    sheet = Image.new("RGBA", (16 * len(tiles), 16), (0, 0, 0, 0))
    meta: dict = {"tile_size": 16, "tiles": {}}
    if extra:
        meta.update(extra)
    for i, (tile_name, cv) in enumerate(tiles):
        sheet.paste(cv.to_image(), (i * 16, 0))
        meta["tiles"][tile_name] = [i, 0]
    sheet.save(OUT / f"{name}.png", optimize=False)
    write_json(OUT / f"{name}.json", meta)


def _speckle(t: Canvas, rng: random.Random, col: str, n: int) -> None:
    for _ in range(n):
        t.set(rng.randrange(0, 16), rng.randrange(0, 16), c(col))


def _shadowed(floor: Canvas, dark: str) -> Canvas:
    """벽 바로 아래 바닥: 위쪽에 벽 그림자가 드리운다."""
    t = floor.copy()
    for y in range(0, 3):
        t.line(0, y, 15, y, c(dark))
    for x in range(0, 16, 2):
        t.set(x, 3, c(dark))
    return t


def _top_variants(base, deco) -> list[tuple[str, Canvas]]:
    """벽 윗면 16가지: 열린 쪽(n 위 · s 처마 · w 왼 · e 오른) 조합마다 가장자리를 그린다."""
    out: list[tuple[str, Canvas]] = []
    for mask in range(16):
        n, s_, w, e = bool(mask & 1), bool(mask & 2), bool(mask & 4), bool(mask & 8)
        cv = base()
        deco(cv, n, s_, w, e)
        suffix = ("n" if n else "") + ("s" if s_ else "") + ("w" if w else "") + ("e" if e else "")
        out.append(("wall_top" + ("_" + suffix if suffix else ""), cv))
    return out


def build_story_tiles() -> None:
    # ------------------------------------------------------------------
    # 연구소: 금속 판 바닥, 두꺼운 천장 + 패널 벽 (환기구·화면·배관이 섞인다)
    # ------------------------------------------------------------------
    rng = random.Random(2001)

    def lab_floor(kind: int) -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("stone_dark"))
        t.line(0, 0, 15, 0, c("shadow"))
        t.line(0, 0, 0, 15, c("shadow"))
        t.line(1, 1, 15, 1, c("stone"))
        t.line(1, 1, 1, 15, c("stone"))
        for x, y in ((3, 3), (13, 3), (3, 13), (13, 13)):
            t.set(x, y, c("stone_light"))
            t.set(x, y + 1, c("shadow"))
        _speckle(t, rng, "stone", 3)
        if kind == 1:  # 경고 줄무늬
            for i in range(4, 12):
                t.set(i, 8, c("yellow") if (i // 2) % 2 == 0 else c("outline"))
                t.set(i, 9, c("orange") if (i // 2) % 2 == 0 else c("outline"))
        elif kind == 2:  # 배수 격자
            for y in range(5, 11):
                t.line(5, y, 10, y, c("shadow"))
            for x in (6, 8, 10):
                t.line(x, 5, x, 10, c("outline"))
        elif kind == 3:  # 푸른 유도선
            t.line(2, 8, 13, 8, c("navy"))
            t.line(4, 8, 11, 8, c("blue"))
        return t

    def lab_top() -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("shadow"))
        for x, y in ((3, 3), (11, 3), (3, 11), (11, 11)):
            t.set(x, y, c("stone_dark"))
        t.line(7, 0, 7, 15, c("outline"))
        t.line(0, 7, 15, 7, c("outline"))
        return t

    def lab_top_deco(t: Canvas, n: bool, s_: bool, w: bool, e: bool) -> None:
        if n:
            t.line(0, 0, 15, 0, c("outline"))
            t.line(0, 1, 15, 1, c("stone"))
            t.line(0, 2, 15, 2, c("stone_dark"))
        if w:
            t.line(0, 0, 0, 15, c("outline"))
            t.line(1, 1 if n else 0, 1, 15, c("stone_dark"))
        if e:
            t.line(15, 0, 15, 15, c("outline"))
            t.line(14, 1 if n else 0, 14, 15, c("stone_dark"))
        if s_:
            t.line(0, 14, 15, 14, c("stone"))
            t.line(0, 15, 15, 15, c("pale"))

    def lab_face(kind: int = 0) -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("stone_light"))
        t.line(0, 0, 15, 0, c("white"))
        t.line(0, 1, 15, 1, c("pale"))
        t.line(0, 4, 15, 4, c("sky"))
        t.line(0, 5, 15, 5, c("blue"))
        t.line(0, 6, 15, 6, c("navy"))
        t.line(0, 7, 0, 12, c("stone"))
        t.line(8, 7, 8, 12, c("stone"))
        for x in (2, 6, 10, 14):
            t.set(x, 2, c("stone"))
        for y in (12, 13):
            t.line(0, y, 15, y, c("stone"))
        t.line(0, 14, 15, 14, c("stone_dark"))
        t.line(0, 15, 15, 15, c("shadow"))
        if kind == 1:  # 환기구
            for y in range(7, 12):
                t.line(3, y, 12, y, c("stone_dark") if y % 2 else c("outline"))
            t.line(2, 6, 13, 6, c("stone"))
        elif kind == 2:  # 화면
            for y in range(7, 12):
                t.line(4, y, 11, y, c("navy"))
            t.line(4, 6, 11, 6, c("outline"))
            t.line(4, 12, 11, 12, c("outline"))
            t.line(3, 7, 3, 11, c("outline"))
            t.line(12, 7, 12, 11, c("outline"))
            t.line(5, 8, 9, 8, c("cyan"))
            t.line(5, 10, 7, 10, c("sky"))
            t.set(10, 10, c("green_light"))
        elif kind == 3:  # 배관
            for x0 in (3, 11):
                t.line(x0, 2, x0, 15, c("stone_dark"))
                t.line(x0 + 1, 2, x0 + 1, 15, c("pale"))
                t.line(x0 + 2, 2, x0 + 2, 15, c("stone"))
                t.line(x0 - 1, 9, x0 + 3, 9, c("outline"))
        return t

    lab_tiles = [("floor", lab_floor(0)), ("floor_alt", lab_floor(1)), ("floor_alt2", lab_floor(2)),
                 ("floor_alt3", lab_floor(3)), ("floor_shadow", _shadowed(lab_floor(0), "shadow"))]
    lab_tiles += _top_variants(lab_top, lab_top_deco)
    lab_tiles += [("wall_face", lab_face()), ("wall_face_alt1", lab_face(1)), ("wall_face_alt2", lab_face(2)),
                  ("wall_face_alt3", lab_face(3)), ("pit", tile_pit())]
    _save_tileset("tiles_lab", lab_tiles)

    # ------------------------------------------------------------------
    # 광산촌: 흙길(풀·자갈), 벽 = 집 (기와 지붕 + 용마루·처마, 판자벽 + 돌 기초, 문·창문)
    # ------------------------------------------------------------------
    rng = random.Random(2002)

    def dirt(kind: int) -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("brown"))
        _speckle(t, rng, "brown_dark", 9)
        _speckle(t, rng, "tan", 5)
        if kind == 1:  # 자갈
            for x, y in ((4, 5), (5, 5), (4, 6), (10, 11), (11, 11), (11, 10)):
                t.set(x, y, c("stone"))
            t.set(5, 6, c("stone_dark"))
            t.set(10, 10, c("stone_light"))
        elif kind == 2:  # 풀포기
            for x, y in ((3, 11), (4, 10), (5, 11), (4, 12), (11, 4), (12, 3), (13, 4)):
                t.set(x, y, c("green"))
            t.set(4, 11, c("green_light"))
            t.set(12, 4, c("green_light"))
        elif kind == 3:  # 수레 자국
            t.line(0, 6, 15, 6, c("brown_dark"))
            t.line(0, 11, 15, 11, c("brown_dark"))
            for x in range(1, 16, 4):
                t.set(x, 7, c("tan"))
        return t

    def roof() -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("crimson"))
        for y in range(0, 16, 4):
            t.line(0, y + 3, 15, y + 3, c("plum"))
            off = 0 if (y // 4) % 2 == 0 else 4
            for x in range(off, 16, 8):
                t.line(x, y, x, y + 2, c("plum"))
                t.set((x + 2) % 16, y, c("red"))
                t.set((x + 5) % 16, y + 1, c("red"))
        return t

    def roof_deco(t: Canvas, n: bool, s_: bool, w: bool, e: bool) -> None:
        if n:  # 용마루
            t.line(0, 0, 15, 0, c("outline"))
            t.line(0, 1, 15, 1, c("tan"))
            t.line(0, 2, 15, 2, c("brown"))
            t.line(0, 3, 15, 3, c("brown_dark"))
        if w:  # 박공널
            t.line(0, 0, 0, 15, c("outline"))
            t.line(1, 1 if n else 0, 1, 15, c("brown"))
            t.line(2, 4 if n else 0, 2, 15, c("brown_dark"))
        if e:
            t.line(15, 0, 15, 15, c("outline"))
            t.line(14, 1 if n else 0, 14, 15, c("brown"))
            t.line(13, 4 if n else 0, 13, 15, c("brown_dark"))
        if s_:  # 처마
            t.line(0, 13, 15, 13, c("brown"))
            t.line(0, 14, 15, 14, c("brown_dark"))
            t.line(0, 15, 15, 15, c("outline"))

    def house_face(kind: str = "") -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("tan"))
        t.line(0, 0, 15, 0, c("plum"))       # 처마 그림자
        t.line(0, 1, 15, 1, c("brown_dark"))
        t.line(0, 2, 15, 2, c("brown"))
        for x in (3, 7, 11, 15):
            t.line(x, 3, x, 11, c("brown"))
        for x, y in ((1, 5), (9, 8), (5, 10), (13, 4)):
            t.set(x, y, c("skin"))
        for y in (12, 13, 14):               # 돌 기초
            t.line(0, y, 15, y, c("stone"))
        t.line(0, 12, 15, 12, c("stone_light"))
        for x in (4, 12):
            t.set(x, 13, c("stone_dark"))
        t.set(8, 14, c("stone_dark"))
        t.line(0, 15, 15, 15, c("shadow"))
        if kind == "l":
            for x in (0, 1):
                t.line(x, 2, x, 14, c("brown_dark"))
            t.line(0, 0, 0, 15, c("outline"))
        elif kind == "r":
            for x in (14, 15):
                t.line(x, 2, x, 14, c("brown_dark"))
            t.line(15, 0, 15, 15, c("outline"))
        elif kind == "window":
            for y in range(4, 10):
                t.line(4, y, 11, y, c("navy"))
            t.line(3, 3, 12, 3, c("brown_dark"))
            t.line(3, 10, 12, 10, c("brown_dark"))
            t.line(3, 3, 3, 10, c("brown_dark"))
            t.line(12, 3, 12, 10, c("brown_dark"))
            t.line(7, 4, 7, 9, c("brown_dark"))
            t.line(8, 4, 8, 9, c("brown_dark"))
            t.line(4, 6, 11, 6, c("brown_dark"))
            t.set(5, 4, c("sky"))
            t.set(5, 5, c("sky"))
            t.set(10, 7, c("yellow"))
            t.set(10, 8, c("orange"))
            t.line(2, 11, 13, 11, c("brown"))
        elif kind == "door":
            for y in range(3, 15):
                t.line(4, y, 11, y, c("brown"))
            t.line(3, 2, 12, 2, c("brown_dark"))
            t.line(3, 2, 3, 14, c("brown_dark"))
            t.line(12, 2, 12, 14, c("brown_dark"))
            t.line(6, 3, 6, 14, c("brown_dark"))
            t.line(9, 3, 9, 14, c("brown_dark"))
            t.set(10, 9, c("yellow"))
            t.line(5, 4, 10, 4, c("tan"))
            t.line(3, 15, 12, 15, c("stone_light"))
        return t

    vil = [("floor", dirt(0)), ("floor_alt", dirt(1)), ("floor_alt2", dirt(2)), ("floor_alt3", dirt(3)),
           ("floor_shadow", _shadowed(dirt(0), "brown_dark"))]
    vil += _top_variants(roof, roof_deco)
    vil += [("wall_face", house_face()), ("wall_face_l", house_face("l")), ("wall_face_r", house_face("r")),
            ("wall_face_window", house_face("window")), ("wall_face_door", house_face("door")), ("pit", tile_pit())]
    _save_tileset("tiles_village", vil)

    # ------------------------------------------------------------------
    # 숲: 풀 바닥, 벽 = 나무. 수풀 가장자리는 둥글게 뚫려 밑의 풀이 보인다. 베어 내면 그루터기
    # ------------------------------------------------------------------
    rng = random.Random(2003)

    def grass(kind: int) -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("green"))
        _speckle(t, rng, "green_dark", 8)
        _speckle(t, rng, "green_light", 5)
        if kind == 1:  # 풀포기
            for x0, y0 in ((3, 12), (11, 5)):
                t.line(x0, y0, x0, y0 - 2, c("green_light"))
                t.set(x0 - 1, y0 - 1, c("green_light"))
                t.set(x0 + 1, y0 - 1, c("green_light"))
        elif kind == 2:  # 꽃
            for x0, y0, col in ((4, 5, "white"), (11, 10, "yellow"), (7, 13, "white")):
                t.set(x0, y0, c(col))
                t.set(x0, y0 + 1, c("green_dark"))
        elif kind == 3:  # 돌멩이
            for x, y in ((9, 7), (10, 7), (9, 8), (10, 8), (11, 8)):
                t.set(x, y, c("stone"))
            t.set(9, 7, c("stone_light"))
            t.line(9, 9, 11, 9, c("green_dark"))
        return t

    def canopy() -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("green_dark"))
        # 잎 뭉치: 왼쪽 위가 밝은 둥근 덩어리 넷
        for cx, cy in ((4, 4), (12, 3), (3, 12), (11, 11)):
            for y in range(16):
                for x in range(16):
                    d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                    if d <= 3.2:
                        t.set(x, y, c("green"))
            t.set(cx - 1, cy - 2, c("green_light"))
            t.set(cx - 2, cy - 1, c("green_light"))
            t.set(cx, cy - 2, c("green_light"))
        for x, y in ((8, 7), (7, 8), (15, 8), (0, 7), (8, 15), (8, 0)):
            t.set(x, y, c("shadow"))
        return t

    # 가장자리 물결: 그 쪽 가장자리에서 얼마나 파내는지 (칸 안 위치별)
    SCALLOP = [2, 1, 0, 0, 0, 1, 2, 3, 2, 1, 0, 0, 0, 1, 2, 3]

    def canopy_deco(t: Canvas, n: bool, s_: bool, w: bool, e: bool) -> None:
        for i in range(16):
            cut = SCALLOP[i]
            if n:
                for k in range(cut):
                    t.set(i, k, None)
                t.set(i, cut, c("outline"))
                if cut + 1 < 16:
                    t.set(i, cut + 1, c("green_light"))
            if w:
                for k in range(cut):
                    t.set(k, i, None)
                if t.px[i][cut] is not None:
                    t.set(cut, i, c("outline"))
            if e:
                for k in range(cut):
                    t.set(15 - k, i, None)
                if t.px[i][15 - cut] is not None:
                    t.set(15 - cut, i, c("outline"))

    def trunk_face() -> Canvas:
        t = Canvas(16, 16)
        # 위쪽: 수관 아랫자락 (아래로 둥글게)
        for x in range(16):
            depth = 8 - SCALLOP[x]
            for y in range(0, depth):
                t.set(x, y, c("green_dark"))
            t.set(x, depth, c("outline"))
        for x, y in ((3, 2), (4, 1), (11, 3), (12, 2), (7, 4)):
            t.set(x, y, c("green"))
        # 줄기
        for y in range(8, 14):
            t.line(6, y, 9, y, c("brown_dark"))
            t.set(7, y, c("brown"))
            t.set(5, y, c("outline"))
            t.set(10, y, c("outline"))
        t.set(8, 10, c("tan"))
        # 뿌리와 그림자
        t.line(4, 14, 11, 14, c("brown_dark"))
        t.set(4, 14, c("outline"))
        t.set(11, 14, c("outline"))
        t.line(3, 15, 12, 15, c("green_dark"))
        return t

    def stump() -> Canvas:
        t = grass(0)
        for y in range(8, 12):
            t.line(5, y, 10, y, c("brown_dark"))
        t.line(5, 7, 10, 7, c("tan"))
        t.line(6, 6, 9, 6, c("tan"))
        t.line(6, 7, 9, 7, c("skin"))
        t.set(7, 7, c("brown"))
        t.line(4, 12, 11, 12, c("green_dark"))
        t.set(4, 9, c("outline"))
        t.set(11, 9, c("outline"))
        return t

    forest = [("floor", grass(0)), ("floor_alt", grass(1)), ("floor_alt2", grass(2)), ("floor_alt3", grass(3)),
              ("floor_stump", stump())]
    forest += _top_variants(canopy, canopy_deco)
    forest += [("wall_face", trunk_face()), ("pit", tile_pit())]
    _save_tileset("tiles_forest", forest, {"wall_over_floor": True})

    # ------------------------------------------------------------------
    # 철길: 풀밭 위에 자갈 바닥 + 침목 + 레일 두 줄. 이웃 칸과 이어진다 (곧은 것·꺾인 것·끝)
    # ------------------------------------------------------------------
    rng = random.Random(2005)

    def rail(dirs: str) -> Canvas:
        t = grass(0)

        def put(x: int, y: int, col: str) -> None:
            t.set(x, y, c(col))

        def half(d: str) -> None:
            # 가운데(4~11)에서 그 쪽 가장자리까지 반 칸
            for k in range(8):
                along = (15 - k) if d in "es" else k
                for across in range(4, 12):
                    x, y = (along, across) if d in "we" else (across, along)
                    col = "stone_dark" if (along + across) % 5 else "stone"
                    if along % 4 == 1:
                        col = "brown_dark" if across not in (4, 11) else "brown"     # 침목
                    if across in (6, 9):
                        col = "pale"                                                 # 레일
                    elif across in (7, 10) and along % 4 != 1:
                        col = "shadow"                                               # 레일 그림자
                    put(x, y, col)

        for d in dirs:
            half(d)
        # 가운데: 양쪽이 만나는 자리 (꺾이는 곳은 자갈로 메운다)
        straight = dirs in ("we", "ns")
        if not straight:
            for y in range(4, 12):
                for x in range(4, 12):
                    put(x, y, "stone_dark" if (x + y) % 5 else "stone")
            for d in dirs:
                for k in range(4, 8):
                    for across in (6, 9):
                        along = (15 - k) if d in "es" else k
                        x, y = (along, across) if d in "we" else (across, along)
                        put(x, y, "pale")
        return t

    rail_tiles = [(name, cv) for name, cv in forest if not name.startswith("floor") or name == "floor_stump"]
    rail_tiles += [("floor", rail("we")), ("floor_alt", rail("we"))]
    for dirs in ("we", "ns", "ne", "nw", "se", "sw", "n", "s", "w", "e", "nwe", "swe", "nsw", "nse", "nswe"):
        rail_tiles.append((f"floor_{dirs}", rail(dirs)))
    _save_tileset("tiles_rail", rail_tiles, {"wall_over_floor": True, "connect_floor": True})

    # ------------------------------------------------------------------
    # 쓰러진 나무 길: 짓밟힌 풀, 그루터기, 쓰러진 통나무, 부러진 가지 (골렘이 지나간 자리)
    # ------------------------------------------------------------------
    rng = random.Random(2006)

    def trampled(kind: int) -> Canvas:
        t = grass(0)
        for _ in range(16):
            t.set(rng.randrange(0, 16), rng.randrange(0, 16), c("brown"))
        for _ in range(6):
            t.set(rng.randrange(0, 16), rng.randrange(0, 16), c("brown_dark"))
        if kind == 1:  # 쓰러진 통나무 (가로)
            for y in range(6, 10):
                t.line(1, y, 13, y, c("brown_dark"))
            t.line(1, 6, 13, 6, c("brown"))
            t.line(2, 7, 12, 7, c("brown"))
            for y in range(6, 10):
                t.set(14, y, c("tan"))
            t.set(14, 7, c("skin"))
            t.line(1, 10, 14, 10, c("green_dark"))
            t.line(5, 4, 6, 5, c("brown_dark"))       # 부러진 가지
            t.set(4, 3, c("green"))
        elif kind == 2:  # 부러진 가지와 잎
            t.line(3, 4, 8, 7, c("brown_dark"))
            t.line(8, 7, 12, 6, c("brown_dark"))
            t.line(6, 11, 11, 12, c("brown_dark"))
            for x, y in ((2, 3), (12, 5), (13, 6), (5, 12), (12, 13)):
                t.set(x, y, c("green_dark"))
        elif kind == 3:  # 깊이 패인 발자국
            for x0, y0 in ((3, 3), (9, 9)):
                for y in range(y0, y0 + 4):
                    t.line(x0, y, x0 + 3, y, c("brown_dark"))
                t.line(x0, y0, x0 + 3, y0, c("shadow"))
        return t

    # ------------------------------------------------------------------
    # 물 (호수·못): 건널 수 없지만 탄은 지나간다. 물가(위쪽 가장자리)와 물결
    # ------------------------------------------------------------------
    def water(kind: int) -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("blue"))
        for x, y in ((2, 4), (3, 4), (4, 4), (10, 9), (11, 9), (12, 9), (6, 13), (7, 13)):
            t.set(x, y, c("sky"))
        for x, y in ((9, 3), (13, 12), (1, 10)):
            t.set(x, y, c("navy"))
        if kind == 1:  # 물결
            t.line(5, 7, 9, 7, c("sky"))
            t.set(7, 6, c("cyan"))
            t.line(11, 2, 13, 2, c("sky"))
        elif kind == 2:  # 물가: 위쪽에 젖은 흙과 얕은 물
            t.line(0, 0, 15, 0, c("green_dark"))
            t.line(0, 1, 15, 1, c("brown_dark"))
            t.line(0, 2, 15, 2, c("navy"))
            for x in range(0, 16, 3):
                t.set(x, 3, c("sky"))
            t.line(0, 4, 15, 4, c("blue"))
        return t

    water_tiles = [(name, cv) for name, cv in forest if name != "pit"]
    water_tiles += [("pit", water(0)), ("pit_alt", water(1)), ("pit_n", water(2))]
    _save_tileset("tiles_water", water_tiles, {"wall_over_floor": True})

    # ------------------------------------------------------------------
    # 바위 언덕: 벽 = 바위 (벨 수 없다). 윗면은 평평한 바위, 앞면은 절벽. 바닥은 자갈 섞인 풀
    # ------------------------------------------------------------------
    rng = random.Random(2007)

    def gravel(kind: int) -> Canvas:
        t = grass(0)
        for _ in range(10):
            t.set(rng.randrange(0, 16), rng.randrange(0, 16), c("stone"))
        for _ in range(4):
            t.set(rng.randrange(0, 16), rng.randrange(0, 16), c("stone_dark"))
        if kind == 1:
            for x, y in ((5, 6), (6, 6), (5, 7), (6, 7), (7, 7), (11, 11), (12, 11)):
                t.set(x, y, c("stone_light"))
            t.line(5, 8, 7, 8, c("shadow"))
        return t

    def rock_top() -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("stone"))
        rr = random.Random(2008)
        for _ in range(12):
            t.set(rr.randrange(0, 16), rr.randrange(0, 16), c("stone_light"))
        for _ in range(10):
            t.set(rr.randrange(0, 16), rr.randrange(0, 16), c("stone_dark"))
        t.line(3, 5, 7, 6, c("stone_dark"))
        t.line(9, 11, 13, 10, c("stone_dark"))
        return t

    def rock_deco(t: Canvas, n: bool, s_: bool, w: bool, e: bool) -> None:
        if n:
            t.line(0, 0, 15, 0, c("outline"))
            t.line(0, 1, 15, 1, c("pale"))
            t.line(0, 2, 15, 2, c("stone_light"))
        if w:
            t.line(0, 0, 0, 15, c("outline"))
            t.line(1, 1 if n else 0, 1, 15, c("stone_light"))
        if e:
            t.line(15, 0, 15, 15, c("outline"))
            t.line(14, 1 if n else 0, 14, 15, c("stone_dark"))
        if s_:
            t.line(0, 14, 15, 14, c("stone_dark"))
            t.line(0, 15, 15, 15, c("shadow"))

    def cliff() -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("stone_dark"))
        t.line(0, 0, 15, 0, c("stone"))
        for x0, y0, x1, y1 in ((2, 1, 3, 9), (7, 2, 6, 12), (11, 1, 12, 8), (14, 4, 13, 13)):
            t.line(x0, y0, x1, y1, c("shadow"))
            t.line(x0 + 1, y0, x1 + 1, y1, c("stone"))
        t.line(0, 13, 15, 13, c("shadow"))
        t.line(0, 14, 15, 14, c("outline"))
        t.line(0, 15, 15, 15, c("green_dark"))
        return t

    rock_tiles = [("floor", gravel(0)), ("floor_alt", gravel(1)), ("floor_shadow", _shadowed(gravel(0), "green_dark"))]
    rock_tiles += _top_variants(rock_top, rock_deco)
    rock_tiles += [("wall_face", cliff()), ("pit", water(0))]
    _save_tileset("tiles_rock", rock_tiles)

    # ------------------------------------------------------------------
    # 길: 풀밭 위의 흙길 (탑과 탑을 잇는다)
    # ------------------------------------------------------------------
    rng = random.Random(2009)

    def road(kind: int) -> Canvas:
        t = Canvas(16, 16)
        t.fill(c("tan"))
        for _ in range(14):
            t.set(rng.randrange(0, 16), rng.randrange(0, 16), c("brown"))
        for _ in range(6):
            t.set(rng.randrange(0, 16), rng.randrange(0, 16), c("skin"))
        for x, y in ((0, 2), (0, 9), (15, 5), (15, 13), (3, 0), (11, 0), (6, 15), (13, 15)):
            t.set(x, y, c("green"))
        if kind == 1:
            for x, y in ((6, 6), (7, 6), (6, 7), (10, 11)):
                t.set(x, y, c("stone"))
        return t

    road_tiles = [(name, cv) for name, cv in forest if not name.startswith("floor") or name == "floor_stump"]
    road_tiles += [("floor", road(0)), ("floor_alt", road(1))]
    _save_tileset("tiles_path", road_tiles, {"wall_over_floor": True})

    trail_tiles = [(name, cv) for name, cv in forest if not name.startswith("floor")]
    trail_tiles += [("floor", trampled(0)), ("floor_alt", trampled(1)), ("floor_alt2", trampled(2)),
                    ("floor_alt3", trampled(3)), ("floor_stump", stump())]
    _save_tileset("tiles_trail", trail_tiles, {"wall_over_floor": True})


# ---------------------------------------------------------------------------
# 스토리판: 소품 16×16 — 웨이스톤, 획득물, NPC, 잔해
# ---------------------------------------------------------------------------
NPC = [
    "................",
    ".....oooooo.....",
    "....ohhhhhho....",
    "....ohffffho....",
    "....offeffeo....",
    "....offffffo....",
    ".....offffo.....",
    "....occccco.....",
    "...occcccccco...",
    "...ocfccccfco...",
    "...ocfccccfco...",
    "....occccco.....",
    "....opppppo.....",
    "....opo.opo.....",
    "....obo.obo.....",
    "....ooo.ooo.....",
]
RUBBLE_A = [
    "................",
    "................",
    "..........oo....",
    ".....oo..oSSo...",
    "....oSSo.osSo...",
    "...oSsSSooSSSo..",
    "..obSSsSSSsSSo..",
    "..obbSSSSSSSso..",
    ".oSbbbsSSsSSSSo.",
    ".oSSbbSSSSSsSSo.",
    "oSsSSbbsSSSSSsSo",
    "oSSSSSbSSsSSSSSo",
    "oSSsSSSSSSSSsSSo",
    "oooooooooooooooo",
    "................",
    "................",
]


# 웨이스톤 탑 16×32: 꼭대기에 마석(g), 돌탑 몸통, 아래에 문
WAYTOWER = [
    "................",
    ".......gg.......",
    "......gGGg......",
    "......gGGg......",
    ".......gg.......",
    ".....oooooo.....",
    "....oLLLLLLo....",
    "...oLSSSSSSLo...",
    "...ooooooooooo..",
    "....oSLSSSLSo...",
    "....oSSSSSSSo...",
    "....oSgSSSgSo...",
    "....oSSSLSSSo...",
    "....oLSSSSSSo...",
    "....oSSSSSLSo...",
    "....oSSgggSSo...",
    "....oSSgGgSSo...",
    "....oSSgggSSo...",
    "....oSLSSSSSo...",
    "....oSSSSSLSo...",
    "....oSSSSSSSo...",
    "...oSSLSSSSSSo..",
    "...oSSSSSSLSSo..",
    "...oSSSdddSSSo..",
    "...oSLSdDdSSSo..",
    "...oSSSdDdSLSo..",
    "..oSSSSdDdSSSSo.",
    "..oLSSSdDdSSSSo.",
    ".osSSSSSSSSSSSso",
    ".osssssssssssso.",
    "..oooooooooooo..",
    "................",
]


def build_waystone() -> None:
    off = Canvas.from_rows(WAYTOWER, {".": None, "o": "outline", "S": "stone", "L": "stone_light", "s": "stone_dark",
                                      "g": "stone_dark", "G": "shadow", "d": "brown_dark", "D": "outline"})
    on1 = Canvas.from_rows(WAYTOWER, {".": None, "o": "outline", "S": "stone_light", "L": "pale", "s": "stone",
                                      "g": "sky", "G": "cyan", "d": "brown", "D": "navy"})
    on2 = Canvas.from_rows(WAYTOWER, {".": None, "o": "outline", "S": "stone_light", "L": "pale", "s": "stone",
                                      "g": "cyan", "G": "white", "d": "brown", "D": "blue"})
    # 켜진 탑은 꼭대기에서 빛이 번쩍인다
    for cv, col in ((on1, "cyan"), (on2, "white")):
        cv.set(7, 0, c(col))
        cv.set(8, 0, c(col))
    on2.set(5, 2, c("cyan"))
    on2.set(10, 3, c("cyan"))
    save_sheet("waystone", 16, 32, [
        ("off", [off], 1.0, False),
        ("on", [on1, on2], 3.0, True),
    ])


def build_story_props() -> None:

    def npc(hair: str, cloth: str, pants: str) -> list[Canvas]:
        base = Canvas.from_rows(NPC, {".": None, "o": "outline", "h": hair, "f": "skin", "e": "outline",
                                      "c": cloth, "p": pants, "b": "brown_dark"})
        return [base, base.shift_rows(1, 11, 1)]

    rub_a = Canvas.from_rows(RUBBLE_A, {".": None, "o": "outline", "S": "stone", "s": "stone_dark", "b": "brown"})
    rub_b = Canvas.from_rows([row[::-1] for row in RUBBLE_A], {".": None, "o": "outline", "S": "stone_light", "s": "stone", "b": "brown_dark"})

    def sparkle(core: str, k: int) -> Canvas:
        cv = Canvas(16, 16)
        r = 2 + k
        cv.line(8 - r, 8, 8 + r, 8, c(core))
        cv.line(8, 8 - r, 8, 8 + r, c(core))
        cv.set(8, 8, c("white"))
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            cv.set(8 + dx, 8 + dy, c("white") if k else c(core))
        return cv

    def doc(k: int) -> Canvas:
        cv = Canvas(16, 16)
        for y in range(5, 13):
            cv.line(5, y, 10, y, c("white"))
        for y in (4, 13):
            cv.line(5, y, 10, y, c("outline"))
        cv.line(4, 5, 4, 12, c("outline"))
        cv.line(11, 5, 11, 12, c("outline"))
        for y in (7, 9, 11):
            cv.line(6, y, 9, y, c("stone"))
        cv.set(12 + k, 3 - k, c("cyan"))
        cv.set(2 - k, 12, c("cyan"))
        return cv

    save_sheet("story_props", 16, 16, [
        ("pickup", [sparkle("yellow", 0), sparkle("yellow", 1)], 4.0, True),
        ("pickup_doc", [doc(0), doc(1)], 3.0, True),
        ("npc_a", npc("brown_dark", "blue", "navy"), 1.5, True),
        ("npc_b", npc("pale", "green", "green_dark"), 1.5, True),
        ("npc_c", npc("orange", "tan", "brown"), 1.5, True),
        ("rubble_a", [rub_a], 1.0, False),
        ("rubble_b", [rub_b], 1.0, False),
    ])


def build_item_icons() -> None:
    """아이템 아이콘 16×16 (스토리판 인벤토리). 애니메이션 이름 = ItemData.icon"""
    def rect(cv: Canvas, x0: int, y0: int, x1: int, y1: int, col: str) -> None:
        for y in range(y0, y1 + 1):
            cv.line(x0, y, x1, y, c(col))

    def gun(body: str, barrel: str, length: int, thick: int, gem: str) -> Canvas:
        cv = icon_frame()
        # 총열
        rect(cv, 3, 6, 3 + length, 6 + thick - 1, barrel)
        cv.line(3, 5, 3 + length, 5, c("outline"))
        cv.line(3, 6 + thick, 3 + length, 6 + thick, c("outline"))
        # 몸통·손잡이
        rect(cv, 3, 6, 7, 8, body)
        rect(cv, 4, 9, 6, 12, body)
        cv.line(3, 9, 3, 12, c("outline"))
        cv.line(7, 10, 7, 12, c("outline"))
        cv.line(4, 13, 6, 13, c("outline"))
        # 마석
        cv.set(6, 7, c(gem))
        cv.set(3 + length, 6, c(gem))
        return cv

    def armor(cloth: str, trim: str, plate: str | None) -> Canvas:
        cv = icon_frame()
        rect(cv, 5, 3, 10, 12, cloth)
        rect(cv, 3, 4, 4, 8, cloth)
        rect(cv, 11, 4, 12, 8, cloth)
        cv.line(7, 3, 8, 3, c("outline"))
        cv.line(7, 4, 7, 12, c(trim))
        cv.line(5, 13, 10, 13, c("outline"))
        if plate:
            rect(cv, 5, 5, 6, 8, plate)
            rect(cv, 9, 5, 10, 8, plate)
            cv.set(3, 4, c(plate))
            cv.set(12, 4, c(plate))
        return cv

    def vial(liquid: str, shine: str) -> Canvas:
        cv = icon_frame()
        rect(cv, 7, 3, 8, 4, "tan")
        rect(cv, 7, 5, 8, 6, "pale")
        rect(cv, 5, 7, 10, 12, liquid)
        cv.line(5, 7, 10, 7, c("pale"))
        cv.line(4, 8, 4, 12, c("outline"))
        cv.line(11, 8, 11, 12, c("outline"))
        cv.line(5, 13, 10, 13, c("outline"))
        cv.set(6, 9, c(shine))
        cv.set(6, 10, c(shine))
        return cv

    cell = icon_frame()
    rect(cell, 5, 3, 10, 12, "stone")
    rect(cell, 6, 5, 9, 11, "yellow")
    cell.line(6, 7, 9, 7, c("orange"))
    cell.line(6, 9, 9, 9, c("orange"))
    cell.line(6, 2, 9, 2, c("stone_light"))
    cell.line(5, 13, 10, 13, c("outline"))

    shard = icon_frame()
    for y, (x0, x1) in enumerate([(7, 8), (6, 9), (5, 10), (5, 10), (6, 10), (6, 9), (7, 9), (7, 8), (8, 8)]):
        shard.line(x0, 3 + y, x1, 3 + y, c("sky"))
    shard.line(7, 4, 7, 9, c("cyan"))
    shard.set(6, 6, c("white"))
    shard.set(9, 7, c("blue"))
    shard.set(9, 8, c("blue"))

    scrap = icon_frame()
    rect(scrap, 3, 8, 8, 11, "stone")
    rect(scrap, 7, 5, 12, 8, "stone_light")
    rect(scrap, 9, 9, 12, 12, "stone_dark")
    scrap.line(3, 12, 8, 12, c("outline"))
    scrap.set(4, 9, c("pale"))
    scrap.set(8, 6, c("white"))
    scrap.set(10, 10, c("brown"))

    paper = icon_frame()
    rect(paper, 4, 3, 11, 12, "white")
    paper.line(4, 13, 11, 13, c("outline"))
    paper.set(11, 3, c("pale"))
    paper.set(10, 3, c("pale"))
    paper.set(11, 4, c("pale"))
    for y in (5, 7, 9):
        paper.line(5, y, 10, y, c("stone"))
    paper.line(5, 11, 8, 11, c("stone"))

    def helmet(shell: str, band: str, lamp: str | None) -> Canvas:
        cv = icon_frame()
        for y, (x0, x1) in enumerate([(6, 9), (5, 10), (4, 11), (4, 11), (4, 11)]):
            cv.line(x0, 4 + y, x1, 4 + y, c(shell))
        cv.line(3, 9, 12, 9, c(band))
        cv.line(3, 10, 12, 10, c("outline"))
        cv.line(6, 3, 9, 3, c("outline"))
        cv.set(5, 5, c("white"))
        if lamp:
            cv.set(7, 6, c(lamp))
            cv.set(8, 6, c(lamp))
        return cv

    band = icon_frame()
    rect(band, 3, 6, 12, 8, "crimson")
    band.line(3, 5, 12, 5, c("outline"))
    band.line(3, 9, 12, 9, c("outline"))
    rect(band, 7, 6, 8, 8, "cyan")
    band.line(12, 9, 13, 12, c("crimson"))
    band.line(11, 9, 11, 11, c("red"))

    def pants(cloth: str, patch: str) -> Canvas:
        cv = icon_frame()
        rect(cv, 4, 3, 11, 5, cloth)
        rect(cv, 4, 6, 6, 12, cloth)
        rect(cv, 9, 6, 11, 12, cloth)
        cv.line(4, 3, 11, 3, c("tan"))
        cv.line(4, 13, 6, 13, c("outline"))
        cv.line(9, 13, 11, 13, c("outline"))
        rect(cv, 4, 8, 6, 9, patch)
        rect(cv, 9, 8, 11, 9, patch)
        return cv

    wood = icon_frame()
    for y0 in (4, 9):
        rect(wood, 3, y0, 12, y0 + 3, "brown")
        wood.line(3, y0, 12, y0, c("tan"))
        wood.line(3, y0 + 3, 12, y0 + 3, c("brown_dark"))
        rect(wood, 11, y0, 12, y0 + 3, "tan")
        wood.set(11, y0 + 1, c("skin"))
        wood.set(5, y0 + 2, c("brown_dark"))

    icons = [
        ("wood", wood),
        ("helmet_cap", helmet("yellow", "orange", "white")),
        ("helmet_band", band),
        ("pants_work", pants("blue", "navy")),
        ("pants_pad", pants("brown", "tan")),
        ("gun_lab", gun("stone", "stone_light", 9, 2, "cyan")),
        ("gun_heavy", gun("stone_dark", "stone", 9, 3, "orange")),
        ("gun_rapid", gun("blue", "pale", 7, 1, "yellow")),
        ("armor_suit", armor("shadow", "crimson", None)),
        ("armor_plate", armor("brown_dark", "tan", "stone_light")),
        ("armor_light", armor("tan", "white", None)),
        ("vial_heal", vial("red", "white")),
        ("cell_ammo", cell),
        ("shard", shard),
        ("scrap", scrap),
        ("paper", paper),
    ]
    save_sheet("items", 16, 16, [(name, [cv], 1.0, False) for name, cv in icons])


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
    build_item_icons()
    build_story_tiles()
    build_story_props()
    build_waystone()
    build_golem()
    build_icon()
    verify_palette()
    print(f"스프라이트 생성 완료: {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
