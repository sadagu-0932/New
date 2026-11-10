#!/usr/bin/env bash
# 커밋한 뒤 한 번에: main 올리기 → 웹 버전 갱신 → 다운로드 링크(실행 파일) 갱신
# 사용: tools/publish.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git push -q origin main
"$ROOT/tools/deploy_web.sh"
"$ROOT/tools/deploy_downloads.sh"
echo "main · 웹 · 다운로드 링크 모두 갱신 ($(git rev-parse --short HEAD))"
