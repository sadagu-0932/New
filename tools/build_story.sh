#!/usr/bin/env bash
# 스토리판 Windows 실행 파일을 내보낸다 → export/demo-story.exe, export/demo-story-windows.zip
# 내보내기만 하고 어디에도 올리지 않는다 (main·download·gh-pages 는 스피드런판 것이라 건드리지 않음).
# 사용: tools/build_story.sh   (Godot 4.7 과 Windows 내보내기 템플릿 필요)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p export
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Windows Desktop" export/demo-story.exe
(cd export && rm -f demo-story-windows.zip && zip -q demo-story-windows.zip demo-story.exe)
echo "스토리판 내보내기 완료: export/demo-story.exe · export/demo-story-windows.zip"
