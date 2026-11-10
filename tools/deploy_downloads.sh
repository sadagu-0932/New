#!/usr/bin/env bash
# Windows·리눅스 실행 파일을 내보내 download 브랜치에 올린다 (README 의 다운로드 링크가 가리키는 곳).
# 브랜치는 매번 새로 만들어 덮어쓴다 → 큰 파일이 저장소 기록에 쌓이지 않는다.
# 사용: tools/deploy_downloads.sh   (Godot 와 Windows·Linux 내보내기 템플릿 필요)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p export/linux
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Windows Desktop" export/demo.exe >/dev/null 2>&1
godot --headless --path . --export-release "Linux" export/linux/demo.x86_64 >/dev/null 2>&1
STAGE="$(mktemp -d)"
TMP="$(mktemp -d)"
trap 'git -C "$ROOT" worktree remove --force "$TMP" >/dev/null 2>&1 || true; rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/demo"
cp export/demo.exe "$STAGE/demo/"
(cd "$STAGE" && zip -qr demo-windows.zip demo)
(cd export/linux && tar czf "$STAGE/demo-linux.tar.gz" demo.x86_64)
git worktree add -q --detach "$TMP"
cd "$TMP"
git checkout -q --orphan download-new
git rm -rfq .
cp "$STAGE/demo-windows.zip" "$STAGE/demo-linux.tar.gz" .
if [ -f "$ROOT/export/android/demo.apk" ]; then cp "$ROOT/export/android/demo.apk" .; fi
cat > NOTES.md <<'MD'
## 받는 법

| 파일 | 설명 |
|---|---|
| demo-windows.zip | Windows: 압축 풀고 demo.exe 실행 |
| demo-linux.tar.gz | Linux (x86_64): 압축 풀고 demo.x86_64 실행 |
| demo.apk | Android: 폰에서 열어 설치 (있을 때) |

웹 버전: https://sadagu-0932.github.io/New/
MD
cp NOTES.md README.md
git -C "$ROOT" rev-parse --short HEAD > VERSION
# Release 를 만들어 주는 GitHub Actions (download 브랜치에 푸시되면 실행)
mkdir -p .github/workflows
cp "$ROOT/tools/release/release.yml" .github/workflows/release.yml
git add -A
git commit -qm "실행 파일 ($(git -C "$ROOT" rev-parse --short HEAD))"
git push -q -f origin HEAD:download
git checkout -q --detach
git branch -q -D download-new
echo "다운로드 파일 올림 (download 브랜치)"
