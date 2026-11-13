#!/usr/bin/env bash
# 스토리판 웹 버전을 내보내 GitHub Pages(gh-pages 브랜치)의 story/ 폴더에 올린다.
# 주소: https://sadagu-0932.github.io/New/story/
# 스피드런판 웹(gh-pages 의 맨 위 폴더)은 건드리지 않는다 (story/ 만 바꿈).
# 사용: tools/deploy_story_web.sh   (story-mode 브랜치, Godot 와 Web 내보내기 템플릿 필요)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [ "$(git rev-parse --abbrev-ref HEAD)" != "story-mode" ]; then
  echo "이 스크립트는 story-mode 브랜치에서만 실행한다" >&2
  exit 1
fi
OUT="$ROOT/export/web-story"
rm -rf "$OUT"
mkdir -p "$OUT"
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Web" "$OUT/index.html" >/dev/null 2>&1
TMP="$(mktemp -d)"
trap 'git -C "$ROOT" worktree remove --force "$TMP" >/dev/null 2>&1 || true' EXIT
git fetch -q origin gh-pages
git worktree add -q --detach "$TMP" origin/gh-pages
rm -rf "$TMP/story"
mkdir -p "$TMP/story"
cp "$OUT"/index.* "$TMP/story/"
rm -f "$TMP/story/"*.import
# 브라우저가 예전 게임 데이터(index.pck)를 기억해 옛 버전이 뜨지 않게, 버전마다 파일 이름을 바꾼다
VER="$(git -C "$ROOT" rev-parse --short HEAD)"
mv "$TMP/story/index.pck" "$TMP/story/index-$VER.pck"
sed -i "s/\"executable\":\"index\"/\"executable\":\"index\",\"mainPack\":\"index-$VER.pck\"/; s/\"index.pck\":/\"index-$VER.pck\":/" "$TMP/story/index.html"
touch "$TMP/.nojekyll"
cd "$TMP"
git add -A
if git diff --cached --quiet; then
	echo "스토리판 웹 버전 변경 없음"
	exit 0
fi
git commit -qm "스토리판 웹 버전 갱신 ($VER)"
git push -q origin HEAD:gh-pages
echo "스토리판 웹 버전 올림: https://sadagu-0932.github.io/New/story/"
