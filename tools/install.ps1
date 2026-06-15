#!/usr/bin/env pwsh
#Requires -Version 5.1
<#
Polaris installer -- Windows / PowerShell port of tools/install.

Renders the Polaris core into a single inlined "managed block" and writes it into
the entrypoint files AI CLIs auto-load at startup. It is a faithful port of the
bash installer and produces BYTE-IDENTICAL output (same bundle sha256, LF line
endings), so a repo can be installed/checked from either Windows or POSIX and the
adapter drift check stays green on both. CI proves this on windows-latest and via
a cross-render test on Linux.

Targets (repo-local, default):
  AGENTS.md, CLAUDE.md, .github/copilot-instructions.md
Targets (-Global): $env:CODEX_HOME\AGENTS.md (default ~/.codex), ~/.claude/CLAUDE.md,
  $env:XDG_CONFIG_HOME\opencode\AGENTS.md (default ~/.config), $env:PI_CODING_AGENT_DIR\AGENTS.md
  (default ~/.pi/agent). Copilot global is UI-only (reported as a manual step).

Usage:
  pwsh tools/install.ps1                 write/update THIS repo's entrypoints
  pwsh tools/install.ps1 -Target DIR     write/update ANOTHER repo's entrypoints
  pwsh tools/install.ps1 -Global         write/update global (per-user) entrypoints
  pwsh tools/install.ps1 -Check          verify the blocks are up to date (CI gate)
  pwsh tools/install.ps1 -Remove         remove Polaris blocks (keeps your text)
  pwsh tools/install.ps1 -DryRun         preview without writing
#>
[CmdletBinding()]
param(
  [string]$Target,
  [switch]$Global,
  [switch]$Check,
  [switch]$Remove,
  [switch]$DryRun,
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  $inDoc = $false
  foreach ($line in (Get-Content -LiteralPath $PSCommandPath)) {
    if ($line -eq '<#') { $inDoc = $true; continue }
    if ($line -eq '#>') { break }
    if ($inDoc) { Write-Output $line }
  }
  exit 0
}

$LF        = "`n"
$BEGIN     = '<!-- AGENT-RULES:BEGIN do-not-edit-inside-this-block -->'
$END       = '<!-- AGENT-RULES:END -->'
$BEGIN_PFX = '<!-- AGENT-RULES:BEGIN'
$END_PFX   = '<!-- AGENT-RULES:END -->'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Manifest = Join-Path $RepoRoot 'MANIFEST.json'

function Read-TextRaw([string]$path) {
  # RAW bytes as UTF-8, NO line-ending normalization. The bash installer reads
  # raw (cat/awk) and compares with `cmp`; normalizing here would make `-Check`
  # accept a CRLF target that `tools/install --check` rejects -- breaking the
  # cross-platform byte-identity guarantee. .gitattributes forces LF on the
  # committed tree, so a normal checkout is already LF on both platforms.
  return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function Write-TextLF([string]$path, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)  # UTF-8, no BOM
  [System.IO.File]::WriteAllText($path, $content, $enc)
}

function Get-Sha256Hex([string]$content) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $hash = $sha.ComputeHash($bytes) } finally { $sha.Dispose() }
  return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

# Faithful port of polaris_render_bundle: for each required core file, demote
# every heading one level (outside ``` fences) and concatenate, each file
# followed by one blank line. LF throughout. Refuses to emit an empty bundle.
function Get-RenderedBundle {
  $manifestObj = Get-Content -Raw -LiteralPath $Manifest | ConvertFrom-Json
  $order = @($manifestObj.required_core_read_order)
  $out = [System.Text.StringBuilder]::new()
  $emitted = 0
  foreach ($rel in $order) {
    if ([string]::IsNullOrEmpty($rel)) { continue }
    $p = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $p)) { throw "polaris: missing core file: $rel" }
    $raw = Read-TextRaw $p
    if ($raw.Length -eq 0) {
      # awk emits ZERO records for an empty file -- only the separator follows.
      [void]$out.Append($LF); $emitted = 1; continue
    }
    # awk record model: a trailing newline does not create an empty final record.
    if ($raw.EndsWith($LF)) { $raw = $raw.Substring(0, $raw.Length - 1) }
    $lines = $raw.Split([char]10)
    $fence = $false
    foreach ($line in $lines) {
      if ($line -match '^```') { $fence = -not $fence }
      if ((-not $fence) -and ($line -match '^#{1,6} ')) {
        [void]$out.Append('#'); [void]$out.Append($line); [void]$out.Append($LF)
      } else {
        [void]$out.Append($line); [void]$out.Append($LF)
      }
    }
    [void]$out.Append($LF)   # blank-line separator (matches printf '\n')
    $emitted = 1
  }
  if ($emitted -eq 0) {
    throw "polaris: empty required_core_read_order (manifest unreadable or empty); refusing empty bundle"
  }
  return $out.ToString()
}

# Faithful port of render_block (markers + provenance header + inlined contract).
function Get-RenderedBlock {
  $ver = 'dev'
  $vfile = Join-Path $RepoRoot 'VERSION'
  if (Test-Path -LiteralPath $vfile) {
    $v = (Read-TextRaw $vfile) -replace '[ \r\n]', ''
    if (-not [string]::IsNullOrEmpty($v)) { $ver = $v }
  }
  $bundle = Get-RenderedBundle
  $sha = Get-Sha256Hex $bundle
  # bash assigns the bundle via $(...) which strips trailing newlines, then
  # printf '%s\n' re-adds exactly one.
  $embedded = $bundle.TrimEnd([char]10) + $LF

  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.Append($BEGIN + $LF)
  [void]$sb.Append("<!-- version: $ver  sha256: $sha -->" + $LF)
  [void]$sb.Append($LF + '# Operating Contract' + $LF + $LF)
  [void]$sb.Append('Baseline engineering rules for this project, loaded automatically. Treat them as' + $LF)
  [void]$sb.Append("the floor, not the ceiling: the active task and this repository's own conventions" + $LF)
  [void]$sb.Append('may tighten them freely, and may relax one only with an explicit, documented justification.' + $LF + $LF)
  [void]$sb.Append('Precedence, highest first: runtime/platform safety; the active task; this' + $LF)
  [void]$sb.Append("repository's conventions; the rules below; then personal global defaults." + $LF + $LF)
  [void]$sb.Append($embedded)
  [void]$sb.Append($END + $LF)
  return $sb.ToString()
}

function Test-HasBeginMarker([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $false }
  foreach ($line in (Read-TextRaw $path).Split([char]10)) {
    if ($line.StartsWith($BEGIN_PFX)) { return $true }
  }
  return $false
}

# Port of compose_into. Returns composed content; throws 'UNTERMINATED' on a
# BEGIN with no matching END.
function Get-ComposedContent([string]$target, [string]$block) {
  if ((Test-Path -LiteralPath $target) -and (Test-HasBeginMarker $target)) {
    $raw = Read-TextRaw $target
    if ($raw.EndsWith($LF)) { $raw = $raw.Substring(0, $raw.Length - 1) }
    $lines = $raw.Split([char]10)
    $result = [System.Text.StringBuilder]::new()
    $done = $false; $skip = $false
    foreach ($line in $lines) {
      if ($line.StartsWith($BEGIN_PFX)) {
        if (-not $done) { [void]$result.Append($block); $done = $true }
        $skip = $true; continue
      }
      if ($line.StartsWith($END_PFX) -and $skip) { $skip = $false; continue }
      if ($skip) { continue }
      [void]$result.Append($line); [void]$result.Append($LF)
    }
    if ($skip) { throw 'UNTERMINATED' }
    return $result.ToString()
  } else {
    if (Test-Path -LiteralPath $target) { return (Read-TextRaw $target) + $LF + $block }
    return $block
  }
}

# Port of remove_block. Throws 'UNTERMINATED' on a BEGIN with no matching END.
function Get-RemovedContent([string]$target) {
  $raw = Read-TextRaw $target
  if ($raw.EndsWith($LF)) { $raw = $raw.Substring(0, $raw.Length - 1) }
  $lines = $raw.Split([char]10)
  $result = [System.Text.StringBuilder]::new()
  $skip = $false
  foreach ($line in $lines) {
    if ($line.StartsWith($BEGIN_PFX)) { $skip = $true; continue }
    if ($line.StartsWith($END_PFX) -and $skip) { $skip = $false; continue }
    if ($skip) { continue }
    [void]$result.Append($line); [void]$result.Append($LF)
  }
  if ($skip) { throw 'UNTERMINATED' }
  return $result.ToString()
}

function Get-HomeDir {
  if ($env:HOME) { return $env:HOME }
  if ($env:USERPROFILE) { return $env:USERPROFILE }
  return [Environment]::GetFolderPath('UserProfile')
}

function Get-Targets([string]$scope, [string]$targetDir) {
  if ($scope -eq 'repo') {
    return @(
      (Join-Path $targetDir 'AGENTS.md'),
      (Join-Path $targetDir 'CLAUDE.md'),
      (Join-Path (Join-Path $targetDir '.github') 'copilot-instructions.md')
    )
  }
  $home = Get-HomeDir
  $codex = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $home '.codex' }
  $xdg   = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $home '.config' }
  $pi    = if ($env:PI_CODING_AGENT_DIR) { $env:PI_CODING_AGENT_DIR } else { Join-Path (Join-Path $home '.pi') 'agent' }
  return @(
    (Join-Path $codex 'AGENTS.md'),
    (Join-Path (Join-Path $home '.claude') 'CLAUDE.md'),
    (Join-Path (Join-Path $xdg 'opencode') 'AGENTS.md'),
    (Join-Path $pi 'AGENTS.md')
  )
}

# --- resolve scope/action/target ---
$scope = if ($Global) { 'global' } else { 'repo' }
# Named switches lose command-line order, so a conflict cannot resolve to bash's
# "last flag wins". Refuse rather than silently pick one -- especially since one
# of them (-Remove) is destructive.
$actionSwitches = @($Check, $Remove, $DryRun | Where-Object { $_ }).Count
if ($actionSwitches -gt 1) {
  [Console]::Error.WriteLine('install: choose at most one of -Check, -Remove, -DryRun.'); exit 2
}
$action = 'write'
if ($Check)  { $action = 'check' }
if ($DryRun) { $action = 'dry' }
if ($Remove) { $action = 'remove' }

$targetDir = $RepoRoot
if ($Target) {
  if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    [Console]::Error.WriteLine("install: -Target directory not found: $Target"); exit 2
  }
  $targetDir = (Resolve-Path -LiteralPath $Target).Path
}

$block = Get-RenderedBlock
$status = 0
$changed = 0

foreach ($t in (Get-Targets $scope $targetDir)) {
  switch ($action) {
    'check' {
      if (Test-HasBeginMarker $t) {
        try {
          $composed = Get-ComposedContent $t $block
          if ((Read-TextRaw $t) -eq $composed) { Write-Output "ok:      $t" }
          else { Write-Output "DRIFT:   $t"; $status = 1 }
        } catch {
          Write-Output "MALFORMED: $t (AGENT-RULES:BEGIN without AGENT-RULES:END)"; $status = 1
        }
      } else {
        if ($scope -eq 'repo') { Write-Output "MISSING: $t (no managed block; run tools/install.ps1)"; $status = 1 }
        else { Write-Output "absent:  $t (advisory; run tools/install.ps1 -Global)" }
      }
    }
    'remove' {
      if (Test-HasBeginMarker $t) {
        try {
          $out = Get-RemovedContent $t
          if ($out -match '[^\s]') { Write-TextLF $t $out; Write-Output "removed block: $t (kept surrounding content)"; $changed = 1 }
          else { Remove-Item -LiteralPath $t; Write-Output "removed file:  $t (was Polaris-only)"; $changed = 1 }
        } catch {
          [Console]::Error.WriteLine("install: $t has AGENT-RULES:BEGIN without AGENT-RULES:END; refusing to edit."); $status = 1
        }
      } else { Write-Output "absent:  $t (no managed block to remove)" }
    }
    'dry' {
      try {
        $composed = Get-ComposedContent $t $block
        if ((-not (Test-Path -LiteralPath $t)) -or ((Read-TextRaw $t) -ne $composed)) { Write-Output "would write: $t" }
        else { Write-Output "unchanged:   $t" }
      } catch {
        Write-Output "would REFUSE: $t (AGENT-RULES:BEGIN without AGENT-RULES:END -- fix markers)"; $status = 1
      }
    }
    'write' {
      $dir = Split-Path -Parent $t
      if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      try {
        $composed = Get-ComposedContent $t $block
        if ((Test-Path -LiteralPath $t) -and ((Read-TextRaw $t) -eq $composed)) { Write-Output "unchanged: $t" }
        else { Write-TextLF $t $composed; Write-Output "wrote:     $t"; $changed = 1 }
      } catch {
        [Console]::Error.WriteLine("install: $t has AGENT-RULES:BEGIN without AGENT-RULES:END; refusing to write (would drop your trailing content). Fix the markers.")
        $status = 1
      }
    }
  }
}

if ($scope -eq 'global') {
  Write-Output ''
  Write-Output 'note: GitHub Copilot has no global file entrypoint. Set user-wide rules'
  Write-Output "      manually: VS Code 'Chat: New Instructions File -> New (User)' with"
  Write-Output "      applyTo: '**', and/or github.com Copilot personal instructions."
}

switch ($action) {
  'check'  { if ($status -eq 0) { Write-Output 'polaris install: blocks up to date.' } else { Write-Output 'polaris install: out of date (drift or missing); run tools/install.ps1.' } }
  'write'  { if ($changed -eq 1) { Write-Output "polaris install: done ($scope)." } else { Write-Output "polaris install: already up to date ($scope)." } }
  'remove' { if ($changed -eq 1) { Write-Output "polaris install: removed ($scope)." } else { Write-Output "polaris install: nothing to remove ($scope)." } }
}

exit $status
