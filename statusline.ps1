# statusline.ps1 - Claude Code status line (Windows / PowerShell)
# Shows: context window + rate-limit bars  |  caveman mode (if installed)  |  active skills
# Wire in settings.json (launched via cmd, which calls Windows PowerShell):
#   "statusLine": { "type": "command",
#     "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"%USERPROFILE%\\.claude\\statusline.ps1\"" }
$ErrorActionPreference = 'SilentlyContinue'

$raw = [Console]::In.ReadToEnd()
try { $j = $raw | ConvertFrom-Json } catch { $j = $null }

function Bar([double]$pct) {
  $f = [math]::Round($pct / 10)
  if ($f -gt 10) { $f = 10 }
  if ($f -lt 0)  { $f = 0 }
  ('▓' * $f) + ('░' * (10 - $f))
}

$parts = @()

# --- Context window ---
$ctx = $j.context_window.used_percentage
if ($null -ne $ctx) { $parts += ("CTX [{0}] {1}%" -f (Bar $ctx), [math]::Round($ctx)) }

# --- Rate limits ---
$rate = @()
$f5 = $j.rate_limits.five_hour.used_percentage
if ($null -ne $f5) { $rate += ("5h [{0}] {1}%" -f (Bar $f5), [math]::Round($f5)) }
$f7 = $j.rate_limits.seven_day.used_percentage
if ($null -ne $f7) { $rate += ("7j [{0}] {1}%" -f (Bar $f7), [math]::Round($f7)) }
if ($rate.Count -gt 0) { $parts += ($rate -join '  ') }

if ($parts.Count -eq 0) { $parts += 'CTX [░░░░░░░░░░] -' }

# --- Caveman mode (empty if not installed); hardened read ---
$cfg = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$cmFile = Join-Path $cfg '.caveman-active'
$item = Get-Item $cmFile -Force -ErrorAction SilentlyContinue
if ($item -and -not $item.LinkType) {
  $mode = (Get-Content $cmFile -Raw -ErrorAction SilentlyContinue)
  if ($mode) {
    $mode = ($mode.Substring(0, [math]::Min(64, $mode.Length))).Trim().ToLower()
    $mode = ($mode -replace '[^a-z0-9-]', '')
    $valid = @('lite','full','ultra','wenyan','wenyan-lite','wenyan-full','wenyan-ultra','commit','review','compress')
    if ($valid -contains $mode) { $parts += ("🗿 CAVEMAN:{0}" -f $mode.ToUpper()) }
  }
}

# --- Active skills (cumulative per-session list, dedup) ---
$sid = $j.session_id
$skill = $null
if ($sid) {
  $listFile = Join-Path $env:TEMP ("claude_skills_{0}" -f $sid)
  if (Test-Path $listFile) {
    $names = Get-Content $listFile -ErrorAction SilentlyContinue | Where-Object { $_ } | Select-Object -Unique
    if ($names) { $skill = ($names -join ', ') }
  }
}
if (-not $skill) {
  $single = Join-Path $cfg '.active_skill'
  if (Test-Path $single) { $skill = (Get-Content $single -Raw -ErrorAction SilentlyContinue).Trim() }
}
if ($skill) { $parts += ("🛠 {0}" -f $skill) }

[Console]::Out.Write(($parts -join '  |  '))
