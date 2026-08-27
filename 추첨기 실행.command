#!/bin/bash
# 마블 룰렛 실행기 (macOS)
#
# 더블클릭하면 로컬 정적 서버를 띄우고 크롬 앱 창으로 추첨기를 연다.
# 크롬 창을 닫으면 서버도 함께 종료된다. 남는 프로세스 없음.

set -u
cd "$(dirname "$0")"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PROFILE="$HOME/Library/Application Support/roulette-launcher-chrome"

pause_and_exit() {
  echo
  read -n 1 -r -p "엔터 또는 아무 키나 누르면 이 창이 닫힙니다..."
  exit 1
}

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 를 찾을 수 없습니다. Xcode Command Line Tools 를 설치하세요:"
  echo "  xcode-select --install"
  pause_and_exit
fi

if [ ! -d dist ]; then
  echo "빌드 결과(dist)가 없습니다. 빌드를 시작합니다. 처음 한 번은 1분 정도 걸립니다."
  npm run build || { echo; echo "빌드 실패. 위 메시지를 확인하세요."; pause_and_exit; }
fi

# 이미 쓰는 포트면 다음 번호로 비켜간다 (추첨기를 두 개 띄워도 충돌 없음)
PORT=8899
while lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; do
  PORT=$((PORT + 1))
done

python3 -m http.server "$PORT" --directory dist >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null' EXIT

echo "추첨기 실행 중 -> http://localhost:$PORT/"
echo "크롬 창을 닫으면 서버도 자동으로 꺼집니다. 이 창은 그대로 두세요."

if [ -x "$CHROME" ]; then
  # 전용 프로필로 띄워야 기존 크롬에 넘기지 않고 별도 프로세스가 된다.
  # 덕분에 창을 닫을 때까지 이 줄에서 대기할 수 있고, 닫히는 즉시 서버가 정리된다.
  "$CHROME" --app="http://localhost:$PORT/" \
            --user-data-dir="$PROFILE" \
            --window-size=1280,860 \
            --no-first-run --no-default-browser-check >/dev/null 2>&1
else
  echo
  echo "크롬을 찾지 못해 기본 브라우저로 엽니다."
  echo "다 쓰고 나면 이 창에서 Ctrl+C 를 누르세요."
  open "http://localhost:$PORT/"
  wait "$SERVER_PID"
fi

echo "종료했습니다."
