#!/bin/bash
# Kome flyer - local web server for Mac. Double-click to start.
cd "$(dirname "$0")"
PORT=8765
if command -v python3 >/dev/null 2>&1 && python3 -c "import http.server" >/dev/null 2>&1; then
  while lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; do PORT=$((PORT+1)); done
  echo ""
  echo "  Flyer gia khuyen mai dang chay tai: http://localhost:$PORT/"
  echo "  GIU cua so nay mo trong luc dung. Dong cua so (hoac Ctrl+C) de tat."
  echo ""
  (sleep 1; open "http://localhost:$PORT/") &
  exec python3 -m http.server "$PORT" --bind 127.0.0.1
else
  echo "May chua co python3. Mo truc tiep index.html (khong tu lay anh tu thu muc images)."
  open "index.html"
fi
