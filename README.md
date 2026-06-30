# claude-code-statusbar

A status line for [Claude Code](https://code.claude.com) that shows, on one line:

```
CTX [▓▓▓▓▓░░░░░] 50%  |  5h [▓▓░░░░░░░░] 18%  7j [▓▓▓▓░░░░░░] 40%  |  🗿 CAVEMAN:FULL  |  🛠 prez-codex, grill-me
```

- **Context window** usage bar (`CTX`)
- **Rate-limit** bars (`5h` / `7j`) when your plan exposes them
- **🗿 Caveman mode** badge — only if the [caveman](https://github.com/JuliusBrussee/caveman) plugin is installed and active (empty otherwise)
- **🛠 Active skills** — the skills solicited this session (cumulative, deduped)

Caveman and skills are independent: a persistent mode and transient skills show side by side.

## How it works

- `statusline.sh` / `statusline.ps1` is the status line command. It reads the JSON Claude Code pipes on stdin (`context_window`, `rate_limits`, `session_id`), reads the caveman flag file (`~/.claude/.caveman-active`) with hardened parsing, and reads the per-session skills list written by the hook.
- `hooks/track-active-skill.*` records the active skill. It is wired to two events:
  - **PreToolUse** (matcher `Skill`) — when the model invokes a skill via the Skill tool
  - **UserPromptExpansion** — when you type `/skill` directly
  - Built-in slash commands (`/model`, `/clear`, …) are filtered out: a name only counts if it matches a real skill directory.
- A **SessionStart** clear keeps the badge fresh per session.

The caveman badge is fully optional — if `.caveman-active` is absent (caveman not installed), nothing is shown there.

## Requirements

- **macOS / Linux:** `bash`, `jq`, a terminal with UTF-8 (for the emoji/bars)
- **Windows:** PowerShell 7 (`pwsh`), a terminal with UTF-8 (Windows Terminal recommended)

## Install — macOS / Linux

```bash
# 1. Copy the scripts into your Claude config dir
cp statusline.sh ~/.claude/statusline.sh
mkdir -p ~/.claude/hooks
cp hooks/track-active-skill.sh ~/.claude/hooks/track-active-skill.sh
chmod +x ~/.claude/statusline.sh ~/.claude/hooks/track-active-skill.sh
```

2. Merge this into `~/.claude/settings.json` (keep your existing keys):

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/statusline.sh\""
  },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Skill",
        "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/hooks/track-active-skill.sh\"", "timeout": 5 } ] }
    ],
    "UserPromptExpansion": [
      { "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/hooks/track-active-skill.sh\"", "timeout": 5 } ] }
    ],
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "rm -f \"$HOME/.claude/.active_skill\"", "timeout": 5 } ] }
    ]
  }
}
```

3. **Restart Claude Code** (hooks load at session start). The status line refreshes on every render.

## Install — Windows (PowerShell)

```powershell
# 1. Copy the scripts into your Claude config dir
Copy-Item statusline.ps1 "$env:USERPROFILE\.claude\statusline.ps1"
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\hooks" | Out-Null
Copy-Item hooks\track-active-skill.ps1 "$env:USERPROFILE\.claude\hooks\track-active-skill.ps1"
```

2. Merge this into `%USERPROFILE%\.claude\settings.json` (keep your existing keys):

```json
{
  "statusLine": {
    "type": "command",
    "command": "pwsh -NoProfile -Command \"& $env:USERPROFILE\\.claude\\statusline.ps1\""
  },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Skill",
        "hooks": [ { "type": "command", "command": "pwsh -NoProfile -Command \"& $env:USERPROFILE\\.claude\\hooks\\track-active-skill.ps1\"", "timeout": 5 } ] }
    ],
    "UserPromptExpansion": [
      { "hooks": [ { "type": "command", "command": "pwsh -NoProfile -Command \"& $env:USERPROFILE\\.claude\\hooks\\track-active-skill.ps1\"", "timeout": 5 } ] }
    ],
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "pwsh -NoProfile -Command \"Remove-Item -Force $env:USERPROFILE\\.claude\\.active_skill -ErrorAction SilentlyContinue\"", "timeout": 5 } ] }
    ]
  }
}
```

3. **Restart Claude Code.**

> If you run Claude Code under WSL or Git Bash on Windows, use the macOS / Linux (bash) install instead.

## Customising

- **Bars** are 10 segments (`make_bar` / `Bar`). Change the width there.
- **Caveman whitelist** of valid modes is in both scripts — extend it if your caveman build adds modes.
- **Skills source**: the cumulative session list is `"$TMPDIR"/claude_skills_<session_id>` (bash) / `%TEMP%\claude_skills_<session_id>` (PowerShell). The single-skill fallback is `~/.claude/.active_skill`.

## Notes & limitations

- Skills have no "deactivate" signal in Claude Code, so the list shows every skill solicited during the session (deduped), newest appended. SessionStart resets it.
- The Skill tool's exact `tool_input` field is undocumented; the hook tries `skill`, `command`, then `name`. If a model-invoked skill never shows, log `tool_input` to find the field.
- Emoji/box-drawing require a UTF-8 terminal.

## License

MIT
