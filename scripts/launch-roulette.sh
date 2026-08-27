#!/bin/bash
# 마블 룰렛 본체 런처.
#
# 추첨기.app 이 이 스크립트를 분리된 프로세스로 띄우고 곧바로 종료한다.
# 앱 번들의 실행 파일이 직접 오래 붙잡고 있으면 LaunchServices 가 실행 완료를
# 기다리다 타임아웃(-1712)내고 앱을 "응답 없음"으로 표시하기 때문이다.
#
# 로컬 정적 서버를 띄우고 크롬 앱 창으로 연다. 크롬 창을 닫으면 서버도 함께 꺼진다.

set -u

# GUI 로 실행되면 PATH 가 최소한만 잡히므로 homebrew 경로를 직접 붙인다.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT" || exit 1

LOG="$PROJECT/launcher.log"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PROFILE="$HOME/Library/Application Support/roulette-launcher-chrome"

alert() {
  osascript \
    -e 'on run argv' \
    -e 'display dialog (item 1 of argv) with title "추첨기" buttons {"확인"} default button 1 with icon caution' \
    -e 'end run' -- "$1" >/dev/null 2>&1
}

fail() {
  alert "$1"
  exit 1
}

command -v python3 >/dev/null 2>&1 ||
  fail "python3 을 찾을 수 없습니다.

터미널에서 아래를 실행한 뒤 다시 시도하세요.
xcode-select --install"

if [ ! -d dist ]; then
  if ! npm run build >"$LOG" 2>&1; then
    fail "빌드에 실패했습니다.

$(tail -n 10 "$LOG")

자세한 내용: $LOG"
  fi
fi

# 이미 쓰는 포트면 다음 번호로 비켜간다
PORT=8899
while lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; do
  PORT=$((PORT + 1))
done

python3 -m http.server "$PORT" --directory dist >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null' EXIT

if [ -x "$CHROME" ]; then
  # 전용 프로필로 띄워야 기존 크롬에 넘기지 않고 별도 프로세스가 된다.
  # 덕분에 창을 닫을 때까지 이 줄에서 대기할 수 있고, 닫히는 즉시 서버가 정리된다.
  "$CHROME" --app="http://localhost:$PORT/" \
            --user-data-dir="$PROFILE" \
            --window-size=1280,860 \
            --no-first-run --no-default-browser-check >/dev/null 2>&1
else
  open "http://localhost:$PORT/"
  alert "크롬을 찾지 못해 기본 브라우저로 열었습니다.

다 쓰고 나면 확인을 누르세요. 그때 서버가 종료됩니다."
fi
