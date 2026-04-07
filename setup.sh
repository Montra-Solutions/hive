#!/bin/bash
# =============================================================================
# H.I.V.E. Setup — Hub for Integrated Visualization & Exploration
# Interactive CLI to generate dashboard.config.json, shared config, and data files.
# Re-run at any time to update your configuration.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/dashboard.config.json"
DATABASES_FILE="$SCRIPT_DIR/data/databases.json"
SHARED_CONFIG_DIR="$HOME/.config/hivemind"
SHARED_CONFIG_FILE="$SHARED_CONFIG_DIR/config.md"
PATHS_ENV_FILE="$SHARED_CONFIG_DIR/paths.env"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

header()  { echo -e "\n${CYAN}${BOLD}$1${RESET}"; echo -e "${CYAN}$(printf -- '-%.0s' {1..60})${RESET}"; }
success() { echo -e "${GREEN}+  $1${RESET}"; }
info()    { echo -e "${CYAN}ℹ  $1${RESET}"; }
warn()    { echo -e "${YELLOW}⚠  $1${RESET}"; }
prompt()  { echo -e "${BOLD}$1${RESET}"; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

ask() {
  # ask "Question" default_value → prints to stderr, result in $REPLY
  local question="$1"
  local default="${2:-}"
  if [[ -n "$default" ]]; then
    printf "${BOLD}%s${RESET} ${CYAN}[%s]${RESET}: " "$question" "$default" >&2
  else
    printf "${BOLD}%s${RESET}: " "$question" >&2
  fi
  read -r REPLY
  if [[ -z "$REPLY" && -n "$default" ]]; then
    REPLY="$default"
  fi
}

json_str() {
  # Escape a string for JSON embedding
  printf '%s' "$1" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null \
    || printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ██╗  ██╗  ██╗██╗   ██╗███████╗"
echo "  ██║  ██║  ██║██║   ██║██╔════╝"
echo "  ███████║  ██║██║   ██║█████╗  "
echo "  ██╔══██║  ██║╚██╗ ██╔╝██╔══╝  "
echo "  ██║  ██║  ██║ ╚████╔╝ ███████╗"
echo "  ╚═╝  ╚═╝  ╚═╝  ╚═══╝  ╚══════╝"
echo -e "${RESET}"
echo -e "${BOLD}  Hub for Integrated Visualization & Exploration${RESET}"
echo -e "  Setup CLI — re-run any time to update your config"
echo ""

# ---------------------------------------------------------------------------
# Check for existing config
# ---------------------------------------------------------------------------
if [[ -f "$CONFIG_FILE" ]]; then
  warn "dashboard.config.json already exists."
  ask "Update it? (y/n)" "y"
  if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
    info "Aborted. No changes made."
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Setup mode selection
# ---------------------------------------------------------------------------
header "Setup Mode"
info "Choose your setup path:"
echo ""
echo -e "  ${BOLD}[1] Full setup${RESET}    — configure repos, services, and integrations"
echo -e "  ${BOLD}[2] Demo mode${RESET}     — minimal config, pair with Drone to see everything"
echo ""
ask "Choose (1 or 2)" "1"
SETUP_MODE="$REPLY"

if [[ "$SETUP_MODE" == "2" ]]; then
  header "Demo Mode"
  info "Generating minimal config for demo use..."

  DEFAULT_PROJECTS_DIR="$(dirname "$SCRIPT_DIR")"
  PROJECTS_DIR="$DEFAULT_PROJECTS_DIR"

  # Auto-detect drone sibling
  DRONE_SIBLING="$DEFAULT_PROJECTS_DIR/drone"
  DEMO_REPOS=("hive")
  if [[ -d "$DRONE_SIBLING" ]]; then
    DEMO_REPOS+=("drone")
    success "Found drone at: $DRONE_SIBLING"
  else
    warn "Drone not found at $DRONE_SIBLING — clone it there for the full demo experience."
  fi

  # Build repos JSON
  DEMO_REPOS_JSON="["
  for i in "${!DEMO_REPOS[@]}"; do
    DEMO_REPOS_JSON+="$(json_str "${DEMO_REPOS[$i]}")"
    [[ $i -lt $((${#DEMO_REPOS[@]} - 1)) ]] && DEMO_REPOS_JSON+=","
  done
  DEMO_REPOS_JSON+="]"

  # Write minimal dashboard.config.json
  cat > "$CONFIG_FILE" <<DEMOEOF
{
  "project": "demo",
  "title": "H.I.V.E. Demo",
  "projectsDir": $(json_str "$PROJECTS_DIR"),
  "repos": $DEMO_REPOS_JSON,
  "services": {
    "web": null,
    "api": null
  },
  "ado": null,
  "github": null
}
DEMOEOF
  success "Created dashboard.config.json (demo mode)"

  # Create data directory and empty files
  mkdir -p "$SCRIPT_DIR/data"
  printf '[]\n' > "$DATABASES_FILE"
  info "Created data/databases.json (empty)"

  # npm install (hive)
  echo ""
  info "Installing HIVE dependencies..."
  cd "$SCRIPT_DIR"
  npm install
  success "HIVE dependencies installed"

  # npm install (drone — if detected)
  DRONE_READY=false
  if [[ -d "$DRONE_SIBLING" ]]; then
    echo ""
    info "Installing Drone dependencies..."
    cd "$DRONE_SIBLING"
    npm install
    success "Drone dependencies installed"
    cd "$SCRIPT_DIR"
    DRONE_READY=true
  fi

  # Write minimal shared config
  echo ""
  info "Writing shared Hivemind config..."
  mkdir -p "$SHARED_CONFIG_DIR"

  GIT_NAME="$(git config --global user.name 2>/dev/null || echo 'Demo User')"
  GIT_EMAIL="$(git config --global user.email 2>/dev/null || echo 'demo@example.com')"

  cat > "$SHARED_CONFIG_FILE" <<SHAREDEOF
# Hivemind Config
# Generated by H.I.V.E. setup (demo mode) — re-run hive/setup.sh to update.
# Location: ~/.config/hivemind/config.md

provider: skip

## Identity
name: ${GIT_NAME}
email: ${GIT_EMAIL}

## Paths
projects_dir: ${PROJECTS_DIR}
hive_dir: ${SCRIPT_DIR}
SHAREDEOF
  success "Created $SHARED_CONFIG_FILE"

  {
    echo "HIVE_DIR=\"$SCRIPT_DIR\""
    echo "PROJECTS_DIR=\"$PROJECTS_DIR\""
  } > "$PATHS_ENV_FILE"
  success "Created $PATHS_ENV_FILE"

  # Summary
  echo ""
  echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${GREEN}${BOLD}  H.I.V.E. demo setup complete!${RESET}"
  echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""

  if [[ "$DRONE_READY" != "true" ]]; then
    echo -e "  ${YELLOW}Drone was not found. Clone it as a sibling and re-run:${RESET}"
    echo -e "  ${CYAN}  git clone <drone-repo-url> $DRONE_SIBLING${RESET}"
    echo -e "  ${CYAN}  ./setup.sh   ${RESET}(choose Demo mode again)"
  else
    echo -e "  ${BOLD}Both HIVE and Drone are ready. Open two terminals:${RESET}"
    echo ""
    echo -e "  ${CYAN}Terminal 1 (HIVE):${RESET}"
    echo -e "    cd $SCRIPT_DIR"
    echo -e "    npm start"
    echo ""
    echo -e "  ${CYAN}Terminal 2 (Drone):${RESET}"
    echo -e "    cd $DRONE_SIBLING"
    echo -e "    npm start"
    echo ""
    echo -e "  ${GREEN}Drone auto-detects HIVE and configures it on startup.${RESET}"
    echo -e "  ${GREEN}Start order doesn't matter — drone retries until HIVE is up.${RESET}"
    echo ""
    echo -e "  ${CYAN}HIVE:           http://localhost:3333${RESET}"
    echo -e "  ${CYAN}Drone Control:  http://localhost:4000${RESET}"
  fi
  echo ""
  exit 0
fi

# ---------------------------------------------------------------------------
# [1/10] Identity
# ---------------------------------------------------------------------------
header "[1/10] Identity"
info "Used by Hivemind skills (/create-pr, /create-bug) and shared across tools."

GIT_NAME="$(git config --global user.name 2>/dev/null || echo '')"
GIT_EMAIL="$(git config --global user.email 2>/dev/null || echo '')"

ask "Your name" "$GIT_NAME"
NAME="${REPLY:-$GIT_NAME}"

ask "Your email" "$GIT_EMAIL"
EMAIL="${REPLY:-$GIT_EMAIL}"

# ---------------------------------------------------------------------------
# [2/10] Provider
# ---------------------------------------------------------------------------
header "[2/10] Provider"
info "Choose your issue tracker / source control provider."
info "Options: ado (Azure DevOps), github, skip"

ask "Provider" "ado"
PROVIDER="${REPLY:-ado}"

# ---------------------------------------------------------------------------
# [3/10] ADO Configuration
# ---------------------------------------------------------------------------
ADO_ORG=""
ADO_PROJECT=""
ADO_TEAM=""
ADO_USERS_JSON="[]"
ADO_PR_REPOS_JSON="[]"
REVIEWERS=()
REPOS_LIST=()

if [[ "$PROVIDER" == "ado" ]]; then
  header "[3/10] Azure DevOps Configuration"

  ask "ADO org name (e.g. mycompany)" ""
  ADO_ORG="$REPLY"

  ask "ADO project name (e.g. My Project)" ""
  ADO_PROJECT="$REPLY"

  ask "ADO team name (e.g. My Team)" ""
  ADO_TEAM="$REPLY"

  echo ""
  info "ADO usernames to track in dashboards. Enter one per line, blank to finish:"
  ADO_USERS=()
  while true; do
    ask "  ADO user display name (or blank to finish)" ""
    [[ -z "$REPLY" ]] && break
    ADO_USERS+=("$REPLY")
    success "Added user: $REPLY"
  done
  if [[ ${#ADO_USERS[@]} -gt 0 ]]; then
    ADO_USERS_JSON="["
    for i in "${!ADO_USERS[@]}"; do
      ADO_USERS_JSON+="$(json_str "${ADO_USERS[$i]}")"
      [[ $i -lt $((${#ADO_USERS[@]} - 1)) ]] && ADO_USERS_JSON+=","
    done
    ADO_USERS_JSON+="]"
  fi

  echo ""
  info "ADO repos for PR tracking in the dashboard. Enter repo names, blank to finish:"
  ADO_PR_REPOS=()
  while true; do
    ask "  ADO repo name (or blank to finish)" ""
    [[ -z "$REPLY" ]] && break
    ADO_PR_REPOS+=("$REPLY")
    success "Added PR repo: $REPLY"
  done
  if [[ ${#ADO_PR_REPOS[@]} -gt 0 ]]; then
    ADO_PR_REPOS_JSON="["
    for i in "${!ADO_PR_REPOS[@]}"; do
      ADO_PR_REPOS_JSON+="$(json_str "${ADO_PR_REPOS[$i]}")"
      [[ $i -lt $((${#ADO_PR_REPOS[@]} - 1)) ]] && ADO_PR_REPOS_JSON+=","
    done
    ADO_PR_REPOS_JSON+="]"
  fi

  echo ""
  info "Default PR reviewers (name or email) for Hivemind /create-pr skill."
  info "Enter one per line, blank to finish:"
  while true; do
    ask "  Reviewer name or email (or blank to finish)" ""
    [[ -z "$REPLY" ]] && break
    REVIEWERS+=("$REPLY")
    success "Added reviewer: $REPLY"
  done

  echo ""
  info "Repositories for Hivemind skills (used by /create-pr for branch reset)."
  info "Enter repo names, blank to finish:"
  while true; do
    ask "  Repo name (or blank to finish)" ""
    [[ -z "$REPLY" ]] && break
    REPOS_LIST+=("$REPLY")
    success "Added repo: $REPLY"
  done
else
  header "[3/10] Azure DevOps Configuration"
  info "Skipped (provider is not ado)."
fi

# ---------------------------------------------------------------------------
# [4/10] GitHub Configuration
# ---------------------------------------------------------------------------
GITHUB_ORG=""
GITHUB_USER=""
GITHUB_USERS_JSON="[]"
GITHUB_PR_REPOS_JSON="[]"
GITHUB_WATCH_REPOS_JSON="[]"
DEFAULT_REVIEWERS=()

if [[ "$PROVIDER" == "github" ]]; then
  header "[4/10] GitHub Configuration"

  ask "GitHub org (e.g. mycompany)" ""
  GITHUB_ORG="$REPLY"

  ask "GitHub username" ""
  GITHUB_USER="$REPLY"

  echo ""
  info "GitHub usernames to track in dashboards. Enter one per line, blank to finish:"
  GITHUB_USERS=()
  while true; do
    ask "  GitHub username (or blank to finish)" ""
    [[ -z "$REPLY" ]] && break
    GITHUB_USERS+=("$REPLY")
    success "Added user: $REPLY"
  done
  if [[ ${#GITHUB_USERS[@]} -gt 0 ]]; then
    GITHUB_USERS_JSON="["
    for i in "${!GITHUB_USERS[@]}"; do
      GITHUB_USERS_JSON+="$(json_str "${GITHUB_USERS[$i]}")"
      [[ $i -lt $((${#GITHUB_USERS[@]} - 1)) ]] && GITHUB_USERS_JSON+=","
    done
    GITHUB_USERS_JSON+="]"
  fi

  echo ""
  info "GitHub repos for PR tracking. Format: owner/repo. Blank to finish:"
  GITHUB_PR_REPOS=()
  while true; do
    ask "  PR repo (owner/repo, or blank to finish)" ""
    [[ -z "$REPLY" ]] && break
    GITHUB_PR_REPOS+=("$REPLY")
    success "Added PR repo: $REPLY"
  done
  if [[ ${#GITHUB_PR_REPOS[@]} -gt 0 ]]; then
    GITHUB_PR_REPOS_JSON="["
    for i in "${!GITHUB_PR_REPOS[@]}"; do
      GITHUB_PR_REPOS_JSON+="$(json_str "${GITHUB_PR_REPOS[$i]}")"
      [[ $i -lt $((${#GITHUB_PR_REPOS[@]} - 1)) ]] && GITHUB_PR_REPOS_JSON+=","
    done
    GITHUB_PR_REPOS_JSON+="]"
  fi

  echo ""
  info "GitHub repos to watch (activity feed). Format: owner/repo. Blank to finish:"
  GITHUB_WATCH_REPOS=()
  while true; do
    ask "  Watch repo (owner/repo, or blank to finish)" ""
    [[ -z "$REPLY" ]] && break
    GITHUB_WATCH_REPOS+=("$REPLY")
    success "Added watch repo: $REPLY"
  done
  if [[ ${#GITHUB_WATCH_REPOS[@]} -gt 0 ]]; then
    GITHUB_WATCH_REPOS_JSON="["
    for i in "${!GITHUB_WATCH_REPOS[@]}"; do
      GITHUB_WATCH_REPOS_JSON+="$(json_str "${GITHUB_WATCH_REPOS[$i]}")"
      [[ $i -lt $((${#GITHUB_WATCH_REPOS[@]} - 1)) ]] && GITHUB_WATCH_REPOS_JSON+=","
    done
    GITHUB_WATCH_REPOS_JSON+="]"
  fi

  echo ""
  info "Default PR reviewers for Hivemind /create-pr skill."
  info "Enter GitHub usernames, blank to finish:"
  while true; do
    ask "  Reviewer username (or blank to finish)" ""
    [[ -z "$REPLY" ]] && break
    DEFAULT_REVIEWERS+=("$REPLY")
    success "Added reviewer: $REPLY"
  done

  echo ""
  info "Repositories for Hivemind skills (used by /create-pr for branch reset)."
  info "Enter repo names, blank to finish:"
  while true; do
    ask "  Repo name (or blank to finish)" ""
    [[ -z "$REPLY" ]] && break
    REPOS_LIST+=("$REPLY")
    success "Added repo: $REPLY"
  done
else
  if [[ "$PROVIDER" != "ado" ]]; then
    header "[4/10] GitHub Configuration"
    info "Skipped (provider is not github)."
  fi
fi

# ---------------------------------------------------------------------------
# [5/10] Project Info
# ---------------------------------------------------------------------------
header "[5/10] Project Info"

ask "Project name (short identifier, e.g. myapp)" "myapp"
PROJECT_NAME="$REPLY"

ask "Dashboard title (shown in browser tab)" "H.I.V.E."
DASHBOARD_TITLE="$REPLY"

# ---------------------------------------------------------------------------
# [6/10] Projects Base Directory
# ---------------------------------------------------------------------------
header "[6/10] Projects Base Directory"
info "This is the parent folder where all your repos are cloned."
info "Example: /Users/you/Projects or /c/Users/you/Projects"

DEFAULT_PROJECTS_DIR="$(dirname "$SCRIPT_DIR")"
ask "Projects base directory" "$DEFAULT_PROJECTS_DIR"
while [[ -z "$REPLY" ]]; do
  warn "Base directory is required."
  ask "Projects base directory" "$DEFAULT_PROJECTS_DIR"
done
PROJECTS_DIR="$REPLY"

# ---------------------------------------------------------------------------
# [7/10] Repos to Watch
# ---------------------------------------------------------------------------
header "[7/10] Repos to Watch"
info "Enter repo directory names (relative to your projects base directory)."
info "Press Enter with no input when done."

REPOS_JSON="[]"
REPOS=()
while true; do
  ask "Repo name (blank to stop)" ""
  [[ -z "$REPLY" ]] && break
  REPOS+=("$REPLY")
  success "Added: $REPLY"
done

if [[ ${#REPOS[@]} -gt 0 ]]; then
  REPOS_JSON="["
  for i in "${!REPOS[@]}"; do
    REPOS_JSON+="$(json_str "${REPOS[$i]}")"
    [[ $i -lt $((${#REPOS[@]} - 1)) ]] && REPOS_JSON+=","
  done
  REPOS_JSON+="]"
fi

# ---------------------------------------------------------------------------
# [8/10] Web Service
# ---------------------------------------------------------------------------
header "[8/10] Web Service (optional)"
info "Configure your frontend dev server (e.g. Vue, React)."

ask "Configure web service? (y/n)" "y"
CONFIGURE_WEB="$REPLY"

WEB_REPO_DIR=""
WEB_PORT="8080"
WEB_START_CMD="npm run dev"

if [[ "$CONFIGURE_WEB" == "y" || "$CONFIGURE_WEB" == "Y" ]]; then
  ask "Web repo directory name (relative to projects base)" ""
  WEB_REPO_DIR="$REPLY"
  ask "Web dev server port" "8080"
  WEB_PORT="$REPLY"
  ask "Web start command" "npm run dev"
  WEB_START_CMD="$REPLY"
fi

# ---------------------------------------------------------------------------
# [9/10] API Service + Databases
# ---------------------------------------------------------------------------
header "[9/10] API Service & Databases (optional)"

info "-- API Service --"
ask "Configure API service? (y/n)" "y"
CONFIGURE_API="$REPLY"

API_REPO_DIR=""
API_PORT="3000"
API_START_CMD="npm run start:dev"

if [[ "$CONFIGURE_API" == "y" || "$CONFIGURE_API" == "Y" ]]; then
  ask "API repo directory name (relative to projects base)" ""
  API_REPO_DIR="$REPLY"
  ask "API server port" "3000"
  API_PORT="$REPLY"
  ask "API start command" "npm run start:dev"
  API_START_CMD="$REPLY"
fi

echo ""
info "-- Database Connections --"
info "Add PostgreSQL connections for DB Explorer and SQL metric widgets."

ask "Add database connections? (y/n)" "y"
CONFIGURE_DBS="$REPLY"

DB_ENTRIES=()

if [[ "$CONFIGURE_DBS" == "y" || "$CONFIGURE_DBS" == "Y" ]]; then
  while true; do
    echo ""
    info "New database connection (blank ID to stop):"
    ask "Connection ID (e.g. local, staging)" ""
    [[ -z "$REPLY" ]] && break
    DB_ID="$REPLY"

    ask "Label (display name)" "$DB_ID"
    DB_LABEL="$REPLY"

    ask "Host" "localhost"
    DB_HOST="$REPLY"

    ask "Port" "5432"
    DB_PORT="$REPLY"

    ask "User" "postgres"
    DB_USER="$REPLY"

    ask "Password" ""
    DB_PASS="$REPLY"

    ask "Database name" ""
    DB_NAME="$REPLY"

    DB_ENTRIES+=("{\"id\":$(json_str "$DB_ID"),\"label\":$(json_str "$DB_LABEL"),\"host\":$(json_str "$DB_HOST"),\"port\":$DB_PORT,\"user\":$(json_str "$DB_USER"),\"password\":$(json_str "$DB_PASS"),\"database\":$(json_str "$DB_NAME")}")
    success "Added connection: $DB_ID ($DB_HOST/$DB_NAME)"
  done
fi

# ---------------------------------------------------------------------------
# Docs directory (for Hivemind /create-bug skill)
# ---------------------------------------------------------------------------
echo ""
info "-- Documentation (optional) --"
info "Used by Hivemind /create-bug to create bug documentation files."

DOCS_DIR=""
DOCS_BUGS_PATH="Bugs/"
SIBLING_DOCS="$(dirname "$SCRIPT_DIR")/docs"
if [[ -d "$SIBLING_DOCS" ]]; then
  success "Found docs sibling at: $SIBLING_DOCS"
  ask "Use this path? (y/n)" "y"
  if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
    DOCS_DIR="$SIBLING_DOCS"
  fi
fi

if [[ -z "$DOCS_DIR" ]]; then
  ask "Docs directory for bug files (or blank to skip)" ""
  DOCS_DIR="$REPLY"
fi

if [[ -n "$DOCS_DIR" ]]; then
  ask "Bugs subdirectory within docs" "$DOCS_BUGS_PATH"
  DOCS_BUGS_PATH="${REPLY:-$DOCS_BUGS_PATH}"
fi

# ---------------------------------------------------------------------------
# [10/10] Generate Files
# ---------------------------------------------------------------------------
header "[10/10] Generating Configuration Files"

# --- Build provider JSON sections ---
ADO_JSON="null"
if [[ "$PROVIDER" == "ado" && -n "$ADO_ORG" ]]; then
  ADO_JSON="{\"org\":$(json_str "$ADO_ORG"),\"project\":$(json_str "$ADO_PROJECT"),\"team\":$(json_str "$ADO_TEAM"),\"users\":$ADO_USERS_JSON,\"prRepos\":$ADO_PR_REPOS_JSON}"
fi

GITHUB_JSON="null"
if [[ "$PROVIDER" == "github" && -n "$GITHUB_ORG" ]]; then
  GITHUB_JSON="{\"org\":$(json_str "$GITHUB_ORG"),\"users\":$GITHUB_USERS_JSON,\"prRepos\":$GITHUB_PR_REPOS_JSON,\"watchRepos\":$GITHUB_WATCH_REPOS_JSON}"
fi

# --- Build services JSON ---
WEB_SERVICE_JSON="null"
if [[ -n "$WEB_REPO_DIR" ]]; then
  WEB_SERVICE_JSON="{\"repoDir\":$(json_str "$WEB_REPO_DIR"),\"port\":$WEB_PORT,\"startCmd\":$(json_str "$WEB_START_CMD")}"
fi

API_SERVICE_JSON="null"
if [[ -n "$API_REPO_DIR" ]]; then
  API_SERVICE_JSON="{\"repoDir\":$(json_str "$API_REPO_DIR"),\"port\":$API_PORT,\"startCmd\":$(json_str "$API_START_CMD")}"
fi

# --- dashboard.config.json ---
cat > "$CONFIG_FILE" <<CONFIGEOF
{
  "project": $(json_str "$PROJECT_NAME"),
  "title": $(json_str "$DASHBOARD_TITLE"),
  "projectsDir": $(json_str "$PROJECTS_DIR"),
  "repos": $REPOS_JSON,
  "services": {
    "web": $WEB_SERVICE_JSON,
    "api": $API_SERVICE_JSON
  },
  "ado": $ADO_JSON,
  "github": $GITHUB_JSON
}
CONFIGEOF
success "Created dashboard.config.json"

# --- data/databases.json ---
mkdir -p "$SCRIPT_DIR/data"
if [[ ${#DB_ENTRIES[@]} -gt 0 ]]; then
  printf '[\n' > "$DATABASES_FILE"
  for i in "${!DB_ENTRIES[@]}"; do
    printf '  %s' "${DB_ENTRIES[$i]}" >> "$DATABASES_FILE"
    [[ $i -lt $((${#DB_ENTRIES[@]} - 1)) ]] && printf ',' >> "$DATABASES_FILE"
    printf '\n' >> "$DATABASES_FILE"
  done
  printf ']\n' >> "$DATABASES_FILE"
  success "Created data/databases.json (${#DB_ENTRIES[@]} connection(s))"
else
  printf '[]\n' > "$DATABASES_FILE"
  info "Created data/databases.json (empty — add connections later)"
fi

# --- run-web.sh ---
if [[ -n "$WEB_REPO_DIR" ]]; then
  cat > "$SCRIPT_DIR/run-web.sh" <<WEBEOF
#!/bin/bash
cd "$(json_str "$PROJECTS_DIR/$WEB_REPO_DIR" | tr -d '"')"
$WEB_START_CMD
WEBEOF
  chmod +x "$SCRIPT_DIR/run-web.sh"
  success "Created run-web.sh"
fi

# --- run-api.sh ---
if [[ -n "$API_REPO_DIR" ]]; then
  cat > "$SCRIPT_DIR/run-api.sh" <<APIEOF
#!/bin/bash
cd "$(json_str "$PROJECTS_DIR/$API_REPO_DIR" | tr -d '"')"
$API_START_CMD
APIEOF
  chmod +x "$SCRIPT_DIR/run-api.sh"
  success "Created run-api.sh"
fi

# --- npm install ---
echo ""
info "Running npm install..."
cd "$SCRIPT_DIR"
npm install
success "Dependencies installed"

# --- Shared config: ~/.config/hivemind/config.md ---
echo ""
info "Writing shared Hivemind config..."
mkdir -p "$SHARED_CONFIG_DIR"

REVIEWERS_BLOCK=""
if [[ ${#REVIEWERS[@]} -gt 0 ]]; then
  REVIEWERS_BLOCK="reviewers:"
  for r in "${REVIEWERS[@]}"; do
    REVIEWERS_BLOCK+=$'\n'"  - $r"
  done
fi

DEFAULT_REVIEWERS_BLOCK=""
if [[ ${#DEFAULT_REVIEWERS[@]} -gt 0 ]]; then
  DEFAULT_REVIEWERS_BLOCK="default_reviewers:"
  for r in "${DEFAULT_REVIEWERS[@]}"; do
    DEFAULT_REVIEWERS_BLOCK+=$'\n'"  - $r"
  done
fi

REPOS_LIST_BLOCK=""
if [[ ${#REPOS_LIST[@]} -gt 0 ]]; then
  REPOS_LIST_BLOCK="repos:"
  for r in "${REPOS_LIST[@]}"; do
    REPOS_LIST_BLOCK+=$'\n'"  - $r"
  done
fi

cat > "$SHARED_CONFIG_FILE" <<SHAREDEOF
# Hivemind Config
# Generated by H.I.V.E. setup — re-run hive/setup.sh to update.
# Location: ~/.config/hivemind/config.md

provider: ${PROVIDER}

## Identity
name: ${NAME}
email: ${EMAIL}

## ADO Configuration (if provider: ado)
ado_org: ${ADO_ORG}
ado_project: ${ADO_PROJECT}

${REVIEWERS_BLOCK}

${REPOS_LIST_BLOCK}

## GitHub Configuration (if provider: github)
github_org: ${GITHUB_ORG}
github_user: ${GITHUB_USER}

${DEFAULT_REVIEWERS_BLOCK}

## Paths
projects_dir: ${PROJECTS_DIR}
hive_dir: ${SCRIPT_DIR}

## Docs (optional — for bug documentation)
docs_dir: ${DOCS_DIR}
docs_bugs_path: ${DOCS_BUGS_PATH}
SHAREDEOF
success "Created $SHARED_CONFIG_FILE"

# --- ~/.config/hivemind/paths.env ---
{
  echo "HIVE_DIR=\"$SCRIPT_DIR\""
  echo "PROJECTS_DIR=\"$PROJECTS_DIR\""
} > "$PATHS_ENV_FILE"
success "Created $PATHS_ENV_FILE"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}  H.I.V.E. setup complete!${RESET}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${BOLD}Start the dashboard:${RESET}"
echo -e "  ${CYAN}  npm start${RESET}"
echo ""
echo -e "  ${BOLD}Then open:${RESET}  ${CYAN}http://localhost:3333${RESET}"
echo ""
echo -e "  ${CYAN}Generated files (gitignored — local only):${RESET}"
echo -e "    dashboard.config.json"
echo -e "    data/databases.json"
[[ -n "$WEB_REPO_DIR" ]] && echo -e "    run-web.sh"
[[ -n "$API_REPO_DIR" ]] && echo -e "    run-api.sh"
echo -e "    $SHARED_CONFIG_FILE"
echo -e "    $PATHS_ENV_FILE"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo -e "    1. Clone Hivemind (if not already) and run its setup.sh"
echo -e "       It will detect the config you just created."
echo -e "    2. Add to your shell profile (~/.zshrc or ~/.bashrc):"
echo -e "       ${CYAN}alias claude='claude --add-dir $PROJECTS_DIR/hivemind'${RESET}"
echo ""
