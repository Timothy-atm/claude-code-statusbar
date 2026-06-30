# track-active-skill.ps1 - records the active/last-solicited skill (Windows / PowerShell)
# Wire to TWO events in settings.json (PreToolUse matcher "Skill" + UserPromptExpansion):
#   "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"%USERPROFILE%\\.claude\\hooks\\track-active-skill.ps1\""
# Built-in slash commands (/model, /clear, ...) are filtered: a name only counts if it
# matches a real skill directory. Never blocks (always exit 0).
$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$cfg = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$sid = $j.session_id
$skill = $null

if ($j.hook_event_name -eq 'UserPromptExpansion') {
  if ($j.expansion_type -ne 'slash_command') { exit 0 }
  $cmd = "$($j.command_name)".TrimStart('/')
  $base = $cmd.Split(':')[-1]
  $skillsDir = Join-Path $cfg 'skills'
  $agentsDir = Join-Path $HOME '.agents\skills'
  if ($cmd -and ((Test-Path (Join-Path $skillsDir $base)) -or (Test-Path (Join-Path $agentsDir $base)))) {
    $skill = $cmd
  }
} else {
  $ti = $j.tool_input
  if ($ti) {
    foreach ($k in @('skill','command','name')) {
      if ($ti.$k) { $skill = "$($ti.$k)"; break }
    }
  }
}

if ($skill) {
  if ($sid) {
    $list = Join-Path $env:TEMP ("claude_skills_{0}" -f $sid)
    $existing = @()
    if (Test-Path $list) { $existing = Get-Content $list -ErrorAction SilentlyContinue }
    if ($existing -notcontains $skill) { Add-Content -Path $list -Value $skill }
    Set-Content -Path (Join-Path $env:TEMP ("claude_active_skill_{0}" -f $sid)) -Value $skill -NoNewline
  }
  Set-Content -Path (Join-Path $cfg '.active_skill') -Value $skill -NoNewline
}
exit 0
