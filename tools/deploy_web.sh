#!/usr/bin/env bash
# 웹 버전을 내보내고 GitHub Pages(gh-pages 브랜치)에 올린다.
# 주소: https://sadagu-0932.github.io/New/
# 사용: tools/deploy_web.sh   (Godot 와 Web 내보내기 템플릿 필요)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p export/web
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Web" export/web/index.html >/dev/null 2>&1
TMP="$(mktemp -d)"
trap 'git -C "$ROOT" worktree remove --force "$TMP" >/dev/null 2>&1 || true' EXIT
git fetch -q origin gh-pages
git worktree add -q --detach "$TMP" origin/gh-pages
find "$TMP" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp export/web/index.* "$TMP"/
rm -f "$TMP"/*.import
touch "$TMP/.nojekyll"
cd "$TMP"
git add -A
if git diff --cached --quiet; then
	echo "웹 버전 변경 없음"
	exit 0
fi
git commit -qm "웹 버전 갱신 ($(git -C "$ROOT" rev-parse --short HEAD))"
git push -q origin HEAD:gh-pages
echo "웹 버전 올림: https://sadagu-0932.github.io/New/"
