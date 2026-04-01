---
name: dashboard
description: Launch the browser-based dev dashboard — live git status, service log viewer, and external service health monitoring.
allowed-tools: Bash
---

# Dev Dashboard

Launch the Montra.io dev dashboard in the browser. The dashboard runs as a fully detached process — it survives Claude session restarts, context compression, and new conversations. Installs dependencies on first run.

**Arguments:** $ARGUMENTS

## Resolve Paths

```bash
if [[ -d "/c/Users/Ryan Gordon/Projects/claude-shared" ]]; then
  DASHBOARD_DIR="/c/Users/Ryan Gordon/Projects/claude-shared/scripts/dev-dashboard"
elif [[ -d "/Volumes/ext2G/Developer/montraio/claude-shared" ]]; then
  DASHBOARD_DIR="/Volumes/ext2G/Developer/montraio/claude-shared/scripts/dev-dashboard"
else
  echo "ERROR: Cannot locate claude-shared directory" && exit 1
fi
```

## Parse Arguments

- If `$ARGUMENTS` contains a number, use it as the port. Otherwise default to `3333`.
- If `$ARGUMENTS` contains `stop` or `kill`, stop any running dashboard process and exit.
- If `$ARGUMENTS` contains `status`, check if the dashboard is running and report back.

## Check if Already Running

Before launching, check if the dashboard port is already in use.

On Windows:
```bash
netstat -ano 2>/dev/null | grep ":$PORT " | grep "LISTENING" | awk '{print $5}' | head -1
```

On macOS (use `-sTCP:LISTEN` to match only the server, not browser clients):
```bash
lsof -t -i :$PORT -sTCP:LISTEN 2>/dev/null
```

If the port is in use and the user did NOT ask to stop/kill/restart:
- Report that the dashboard is already running at `http://localhost:<PORT>` and exit.
- Do NOT launch a second instance.

## Stop (if requested)

If the user asked to stop, kill, or restart the dashboard:

On macOS (only kill the LISTEN process, not browser clients connected to it):
```bash
lsof -t -i :$PORT -sTCP:LISTEN 2>/dev/null | xargs kill 2>/dev/null || true
```

On Windows:
```bash
PID=$(netstat -ano 2>/dev/null | grep ":$PORT " | grep "LISTENING" | awk '{print $5}' | head -1)
if [[ -n "$PID" ]]; then
  cmd //c "taskkill /T /F /PID $PID" 2>/dev/null || true
fi
```

If the user only asked to stop/kill, report that the dashboard was stopped and exit.
If the user asked to restart, continue to the Launch step.

## Install Dependencies

```bash
cd "$DASHBOARD_DIR"
if [[ ! -d "node_modules" ]]; then
  npm install
fi
```

## Launch

The dashboard MUST be launched as a fully detached process that is NOT tied to Claude Code's process tree. This is critical — using `run_in_background: true` will cause the dashboard to die when the Claude session ends.

Both Windows (Git Bash) and macOS use the same approach — background with `&` and `disown`:
```bash
cd "$DASHBOARD_DIR" && PORT=$PORT node server.mjs > dashboard.log 2>&1 &
disown $! 2>/dev/null || true
```

Run this using the Bash tool (NOT `run_in_background: true` — let the launch command return immediately on its own). The `&` backgrounds the process and `disown` detaches it from the shell so it survives session cleanup.

Wait 2 seconds, then verify the port is now in use (same check as "Check if Already Running"). If the port is not in use, read the last 20 lines of `dashboard.log` and report the error.

## Launch Dev Services

After the dashboard is confirmed running, check if the Web and API dev servers are already running by checking their ports (8080 for web, 7600 for API).

On Windows:
```bash
WEB_PID=$(netstat -ano 2>/dev/null | grep ":8080 " | grep "LISTENING" | awk '{print $5}' | head -1)
API_PID=$(netstat -ano 2>/dev/null | grep ":7600 " | grep "LISTENING" | awk '{print $5}' | head -1)
```

On macOS:
```bash
WEB_PID=$(lsof -t -i :8080 -sTCP:LISTEN 2>/dev/null)
API_PID=$(lsof -t -i :7600 -sTCP:LISTEN 2>/dev/null)
```

For services that are NOT already running, launch them in **split panes within a single terminal tab** so they're grouped together. The first service opens a new tab; subsequent services split within that tab.

On Windows (Git Bash):
```bash
FIRST_LAUNCH=""
if [[ -z "$WEB_PID" ]]; then
  wt.exe -w 0 new-tab --title "Montra Services" "C:\Program Files\Git\bin\bash.exe" "C:\Users\Ryan Gordon\Projects\claude-shared\scripts\dev-dashboard\run-web.sh"
  FIRST_LAUNCH="done"
  sleep 1
fi
if [[ -z "$API_PID" ]]; then
  if [[ -z "$FIRST_LAUNCH" ]]; then
    wt.exe -w 0 new-tab --title "Montra Services" "C:\Program Files\Git\bin\bash.exe" "C:\Users\Ryan Gordon\Projects\claude-shared\scripts\dev-dashboard\run-api.sh"
  else
    wt.exe -w 0 split-pane --horizontal --title "Montra API" "C:\Program Files\Git\bin\bash.exe" "C:\Users\Ryan Gordon\Projects\claude-shared\scripts\dev-dashboard\run-api.sh"
  fi
fi
```

On macOS:
```bash
if [[ -z "$WEB_PID" ]]; then
  osascript -e "tell application \"Terminal\" to do script \"bash '$DASHBOARD_DIR/run-web.sh'\""
fi
if [[ -z "$API_PID" ]]; then
  osascript -e "tell application \"Terminal\" to do script \"bash '$DASHBOARD_DIR/run-api.sh'\""
fi
```

Report which services were launched and which were already running.

## Output

After a successful launch, tell the user:

```
Dev Dashboard running at http://localhost:<PORT> (detached — survives session restarts)

Services (split panes in a single "Montra Services" tab):
  - Web :8080  — <launched | already running>
  - API :7600  — <launched | already running>

Features:
  - Git status for all core repos (refreshes every 5s)
  - External service monitoring: Montra Dev/Prod, Azure DevOps, Claude (refreshes every 30s)
  - Alarm sounds when a service goes down — mute per-service from the dashboard
  - Live log streaming from Web and API (via ~/.montra/logs/)
  - Live-reload: CSS changes hot-swap instantly, JS/HTML changes auto-refresh the browser

Stop with: /dashboard stop
```

## Notes

- NEVER use `run_in_background: true` — the process must be detached from Claude's process tree
- The dashboard auto-detects Windows vs macOS paths
- Port defaults to 3333 but can be overridden via argument
- If the port is already in use, report it's already running — don't launch a duplicate
- Logs go to `dashboard.log` in the dashboard directory for debugging
- Service logs go to `~/.montra/logs/web.log` and `~/.montra/logs/api.log`
- The wrapper scripts (`run-web.sh`, `run-api.sh`) run as split panes in a single "Montra Services" terminal tab — closing the tab stops both services
- The dashboard server also uses split panes when starting services via the Start button (first service creates a tab, subsequent services split within it)
- The dashboard does NOT manage service lifecycle — it only passively tails log files via `fs.watch` + polling fallback
- Do NOT use `--watch` with the dashboard — it causes EADDRINUSE crashes when files are edited during a session. If you need to restart after code changes, use `/dashboard stop` then `/dashboard`.
