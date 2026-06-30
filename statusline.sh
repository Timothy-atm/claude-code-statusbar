#!/usr/bin/env bash
# ~/.claude/statusline-usage.sh
# Affiche une barre de progression de l'usage du context window (et des rate limits si dispo)
# Format : CTX [▓▓▓▓▓░░░░░] 48%  |  5h [▓▓░░░░░░░░] 20%

input=$(cat)

# --- Fonction barre ASCII (10 segments) ---
make_bar() {
  local pct="${1:-0}"
  # Arrondi à l'entier
  local filled=$(printf '%.0f' "$(echo "$pct / 10" | bc -l 2>/dev/null || echo 0)")
  [ "$filled" -gt 10 ] 2>/dev/null && filled=10
  [ "$filled" -lt 0 ] 2>/dev/null && filled=0
  local bar=""
  local i
  for ((i=0; i<filled; i++));  do bar="${bar}▓"; done
  for ((i=filled; i<10; i++)); do bar="${bar}░"; done
  printf "%s" "$bar"
}

# --- Context window ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
ctx_part=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  bar=$(make_bar "$used_pct")
  label=$(printf '%.0f' "$used_pct")
  ctx_part="CTX [${bar}] ${label}%"
fi

# --- Rate limits (Claude.ai abonnement) ---
five_pct=$(echo "$input"  | jq -r '.rate_limits.five_hour.used_percentage  // empty' 2>/dev/null)
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage  // empty' 2>/dev/null)

rate_part=""
if [ -n "$five_pct" ] && [ "$five_pct" != "null" ]; then
  bar=$(make_bar "$five_pct")
  label=$(printf '%.0f' "$five_pct")
  rate_part="5h [${bar}] ${label}%"
fi
if [ -n "$seven_pct" ] && [ "$seven_pct" != "null" ]; then
  bar=$(make_bar "$seven_pct")
  label=$(printf '%.0f' "$seven_pct")
  if [ -n "$rate_part" ]; then
    rate_part="${rate_part}  7j [${bar}] ${label}%"
  else
    rate_part="7j [${bar}] ${label}%"
  fi
fi

# --- Mode caveman (flag persistant, lecture durcie) ---
cm_file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-active"
caveman_part=""
if [ -f "$cm_file" ] && [ ! -L "$cm_file" ]; then
  mode=$(head -c 64 "$cm_file" 2>/dev/null | tr -d '\n\r' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
  case "$mode" in
    lite|full|ultra|wenyan|wenyan-lite|wenyan-full|wenyan-ultra|commit|review|compress)
      caveman_part="🗿 CAVEMAN:$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')" ;;
    *) caveman_part="" ;;   # off / absent / inconnu -> pas de badge (= inactif)
  esac
fi

# --- Skills actives (cumul session, à droite) ---
sid=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
skill_part=""
# Liste cumulative dédupliquée écrite par track-active-skill.sh.
if [ -n "$sid" ] && [ -f "/tmp/claude_skills_${sid}" ]; then
  sk=$(awk '!seen[$0]++{n++; out=(n==1?$0:out", "$0)} END{print out}' "/tmp/claude_skills_${sid}")
  [ -n "$sk" ] && skill_part="🛠 ${sk}"
fi
# Fallback mono-skill si la liste manque.
if [ -z "$skill_part" ]; then
  skill_file=""
  [ -n "$sid" ] && [ -f "/tmp/claude_active_skill_${sid}" ] && skill_file="/tmp/claude_active_skill_${sid}"
  [ -z "$skill_file" ] && [ -f "$HOME/.claude/.active_skill" ] && skill_file="$HOME/.claude/.active_skill"
  if [ -n "$skill_file" ]; then
    sk=$(cat "$skill_file" 2>/dev/null)
    [ -n "$sk" ] && skill_part="🛠 ${sk}"
  fi
fi

# --- Assemblage final ---
output=""
[ -n "$ctx_part"  ] && output="${ctx_part}"
[ -n "$rate_part" ] && {
  [ -n "$output" ] && output="${output}  |  "
  output="${output}${rate_part}"
}

# Si aucune donnée disponible, affichage minimal
[ -z "$output" ] && output="CTX [░░░░░░░░░░] -"

# Modes/skills à droite de tout : caveman (mode) puis skill (transitoire)
[ -n "$caveman_part" ] && output="${output}  |  ${caveman_part}"
[ -n "$skill_part" ]   && output="${output}  |  ${skill_part}"

printf "%s" "$output"
