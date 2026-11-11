#!/usr/bin/env bash
# 커밋한 뒤 한 번에: main 올리기 → 웹 버전 갱신 → 다운로드 링크(실행 파일) 갱신
# 사용: tools/publish.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# 스토리판 브랜치에서는 실행 금지 (main·웹·다운로드는 스피드런판 것)
if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  echo "publish.sh 는 main 브랜치에서만 실행한다 (지금: $(git rev-parse --abbrev-ref HEAD))" >&2
  exit 1
fi
git push -q origin main
"$ROOT/tools/deploy_web.sh"
"$ROOT/tools/deploy_downloads.sh"
echo "main · 웹 · 다운로드 링크 모두 갱신 ($(git rev-parse --short HEAD))"
