#!/bin/bash
# fullstack-agent: give your AI a full stack — memory, voice, face, hands.
# Copyright (C) 2026 Jared Rhodenizer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Starts the agent's pieces, in the right order:
#   ai-visualizer (the face, opens in your browser)
#   barehands     (the hands, opens in your browser)
#   backtalk      (the voice, runs in this terminal; Ctrl-C stops EVERYTHING)
# Pieces you didn't install are skipped automatically.
#
#   ./start.sh          everything installed
#   ./start.sh voice    the voice and the face (no hands)
#   ./start.sh hands    the voice and the hands board (no face)

HERE="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$(dirname "$HERE")"
MODE="${1:-all}"
PIDS=()

cleanup() {
  trap - EXIT INT TERM
  for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done
  echo
  echo "agent stopped."
}
trap cleanup EXIT INT TERM

echo "fullstack-agent: starting from $HOME_DIR"

free_port() {
  local pids
  pids="$(lsof -ti ":$1" 2>/dev/null)"
  if [ -n "$pids" ]; then
    kill $pids 2>/dev/null
    sleep 0.5
  fi
}

if [ -d "$HOME_DIR/ai-visualizer" ] && [ "$MODE" != "hands" ]; then
  # Single-instance guard: an orphaned server.py from a prior session
  # (however it was launched) squats on the port and wins the bind race,
  # so the new launch fails silently and no browser tab opens. Freeing
  # the configured port directly catches orphans regardless of how their
  # command line looks, unlike matching on argv text.
  vis_port="$(python3 -c "import json;print(json.load(open('$HOME_DIR/ai-visualizer/ai-visualizer.json')).get('port',8790))" 2>/dev/null || echo 8790)"
  free_port "$vis_port"
  (exec python3 "$HOME_DIR/ai-visualizer/server.py") &
  PIDS+=($!)
  echo "  face:  starting (your browser opens on the visualizer)"
fi

if [ -d "$HOME_DIR/barehands" ] && [ "$MODE" != "voice" ]; then
  # Same single-instance guard as the face, above.
  hands_port="$(python3 -c "import json;print(json.load(open('$HOME_DIR/barehands/barehands.json')).get('port',8794))" 2>/dev/null || echo 8794)"
  free_port "$hands_port"
  (exec python3 "$HOME_DIR/barehands/server.py") &
  PIDS+=($!)
  echo "  hands: starting (your browser opens on the board)"
fi

if [ -d "$HOME_DIR/backtalk" ]; then
  echo "  voice: starting (hold your talk key and speak; Ctrl-C here stops everything)"
  cd "$HOME_DIR/backtalk" && ./run.sh
else
  echo
  echo "No voice installed; servers are up. Ctrl-C stops everything."
  wait
fi
