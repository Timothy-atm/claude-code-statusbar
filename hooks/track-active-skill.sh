#!/usr/bin/env bash
# Records the active/last-solicited skill so the statusLine can show it.
# Wired to TWO events:
#   - PreToolUse (matcher: Skill)  -> model-invoked skill (tool_input)
#   - UserPromptExpansion          -> user-typed /skill (command_name)
# Built-in slash commands (/model, /clear, ...) are filtered out: a name only
# counts if it matches a real skill directory. Never blocks (exit 0).
input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
skill=""

if [ "$event" = "UserPromptExpansion" ]; then
  et=$(printf '%s' "$input" | jq -r '.expansion_type // empty' 2>/dev/null)
  [ "$et" = "slash_command" ] || exit 0
  cmd=$(printf '%s' "$input" | jq -r '.command_name // empty' 2>/dev/null)
  cmd="${cmd#/}"                       # strip a leading slash if present
  base="${cmd##*:}"                    # strip plugin: namespace for the dir check
  if [ -n "$cmd" ] && { [ -d "$HOME/.claude/skills/$base" ] || [ -d "$HOME/.agents/skills/$base" ]; }; then
    skill="$cmd"
  fi
else
  skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // .tool_input.command // .tool_input.name // empty' 2>/dev/null)
fi

if [ -n "$skill" ]; then
  # Cumulative per-session list (dedup, order preserved): append only if new.
  if [ -n "$sid" ]; then
    list="/tmp/claude_skills_${sid}"
    grep -qxF "$skill" "$list" 2>/dev/null || printf '%s\n' "$skill" >> "$list"
  fi
  # Single-skill files kept for backward compat (last skill wins).
  [ -n "$sid" ] && printf '%s' "$skill" > "/tmp/claude_active_skill_${sid}" 2>/dev/null
  printf '%s' "$skill" > "$HOME/.claude/.active_skill" 2>/dev/null
fi
exit 0
