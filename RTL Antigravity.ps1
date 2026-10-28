<#
.SYNOPSIS
  Re-applies the Persian RTL chat patch to Antigravity after an update.
  One-click: closes Antigravity, backs up app.asar, injects the RTL
  stylesheet loader into dist/utils.js, repacks the asar, replaces it,
  relaunches the app. Safe to re-run: exits early if already patched.
#>
$ErrorActionPreference = 'Stop'

$ResDir   = Join-Path $env:LOCALAPPDATA 'Programs\antigravity\resources'
$Asar     = Join-Path $ResDir 'app.asar'
$Exe      = Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe'
$Marker   = 'RTL_FARSI_CSS'
$UnpackD  = 'node_modules/chrome-devtools-mcp'
$Stamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
$WorkRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'agy-rtl-repatch'
$SrcDir   = Join-Path $WorkRoot 'src'
$OutDir   = Join-Path $WorkRoot 'out'

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

if (-not (Test-Path -LiteralPath $Asar)) { Fail "app.asar not found: $Asar" }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail "node is not on PATH" }

# 0. Idempotency: already patched -> nothing to do.
# NOTE: asar extract-file writes the file into the CURRENT directory
# named after its basename; run it from $WorkRoot and read it there.
New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null
Push-Location $WorkRoot
& npx --yes @electron/asar@3.4.1 extract-file "$Asar" "dist/utils.js" | Out-Null
Pop-Location
$content = Get-Content (Join-Path $WorkRoot 'utils.js') -Raw -ErrorAction SilentlyContinue
Remove-Item (Join-Path $WorkRoot 'utils.js') -Force -ErrorAction SilentlyContinue
if (-not $content) { Fail 'could not read dist/utils.js from app.asar' }
if ($content.Contains($Marker)) {
  Write-Host 'Already patched (RTL marker present). Nothing to do.'
  exit 0
}

# 1. Close the app (file lock) and back up.
Get-Process -Name 'Antigravity' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
$backup = Join-Path $ResDir 'app.asar.pre-rtl'
Copy-Item -LiteralPath $Asar -Destination $backup -Force
Write-Host "Backup written: $backup"

# 2. Full extract.
Remove-Item -Recurse -Force $SrcDir -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $OutDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
& npx --yes @electron/asar@3.4.1 extract "$Asar" "$SrcDir"
if ($LASTEXITCODE -ne 0) { Fail 'asar extract failed' }

# 3. Patch dist/utils.js (anchor must occur exactly once).
$utils = Join-Path $SrcDir 'dist\utils.js'
$anchor = "    void win.loadURL(url);`r?`n    return win;`r?`n}"
$text = Get-Content -LiteralPath $utils -Raw
$hits = ([regex]::Matches($text, 'void win\.loadURL\(url\);\s*\r?\n\s*return win;\s*\r?\n\}')).Count
if ($hits -ne 1) { Fail "anchor not unique (hits=$hits); utils.js structure changed, aborting" }

$css = @(
  '[data-testid="conversation-view"] .md-divider-spacing,',
  '[data-testid="conversation-view"] [data-testid="pending-user-messages"]',
  '{direction:rtl!important;text-align:right!important}',
  '[data-testid="conversation-view"] .md-divider-spacing p,',
  '[data-testid="conversation-view"] .md-divider-spacing li,',
  '[data-testid="conversation-view"] .md-divider-spacing blockquote,',
  '[data-testid="conversation-view"] .md-divider-spacing h1,',
  '[data-testid="conversation-view"] .md-divider-spacing h2,',
  '[data-testid="conversation-view"] .md-divider-spacing h3,',
  '[data-testid="conversation-view"] .md-divider-spacing h4,',
  '[data-testid="conversation-view"] [data-testid="pending-user-messages"] p,',
  '[data-testid="conversation-view"] [data-testid="pending-user-messages"] li',
  '{unicode-bidi:plaintext!important}',
  '[data-testid="conversation-view"] .md-divider-spacing pre,',
  '[data-testid="conversation-view"] .md-divider-spacing code,',
  '[data-testid="conversation-view"] .md-divider-spacing table,',
  '[data-testid="conversation-view"] .md-divider-spacing .katex,',
  '[data-testid="conversation-view"] [data-testid="pending-user-messages"] pre,',
  '[data-testid="conversation-view"] [data-testid="pending-user-messages"] code',
  '{direction:ltr!important;text-align:left!important;unicode-bidi:normal!important}',
  '[data-testid="conversation-view"] .md-divider-spacing ul,',
  '[data-testid="conversation-view"] .md-divider-spacing ol',
  '{padding-left:0!important;padding-right:18px!important}',
  '[data-testid="conversation-view"] [contenteditable="true"]',
  '{direction:rtl!important;text-align:right!important;unicode-bidi:plaintext!important}'
) -join "`n"

$patch = @'
// Right-to-left support for Persian (Farsi) chat text. Jetski Web is
// served by the language server binary, so its own assets cannot be
// patched — instead the shell injects this stylesheet into every window
// on each full page load (SPA route changes keep injected CSS).
// Conversation text (assistant + user markdown) is right-aligned and
// uses per-paragraph auto direction so mixed Persian/English no longer
// interleaves; code, tables and math stay left-to-right.
const RTL_FARSI_CSS = [
__CSS_LINES__
].join('\n');
win.webContents.on('did-finish-load', () => {
    win.webContents.insertCSS(RTL_FARSI_CSS).catch(() => { });
});
__ANCHOR__
'@
$cssLines = ($css -split "`n" | ForEach-Object { "        '$_'," }) -join "`r`n"
$cssLines = $cssLines.TrimEnd(',')
$patch = $patch.Replace('__CSS_LINES__', $cssLines)
$anchorText = "    void win.loadURL(url);`r`n    return win;`r`n}"
$patch = $patch.Replace('__ANCHOR__', $anchorText)
$text = [regex]::Replace($text, '    void win\.loadURL\(url\);\s*\r?\n\s*return win;\s*\r?\n\}', $patch, 1)
[System.IO.File]::WriteAllText($utils, $text, (New-Object System.Text.UTF8Encoding $false))

& node --check "$utils"
if ($LASTEXITCODE -ne 0) { Fail 'patched utils.js failed node --check' }
Write-Host 'Patched dist/utils.js (syntax OK)'

# 4. Repack with the same unpack layout.
$outAsar = Join-Path $OutDir 'app.asar'
& npx --yes @electron/asar@3.4.1 pack "$SrcDir" "$outAsar" --unpack-dir "$UnpackD"
if ($LASTEXITCODE -ne 0) { Fail 'asar pack failed' }

# 5. Verify: same entry count + marker present + unpacked count matches.
$oldList = & npx --yes @electron/asar@3.4.1 list "$Asar"
$newList = & npx --yes @electron/asar@3.4.1 list "$outAsar"
if ($oldList.Count -ne $newList.Count) { Fail ("entry count changed: {0} -> {1}" -f $oldList.Count, $newList.Count) }
$oldU = (Get-ChildItem (Join-Path $ResDir 'app.asar.unpacked') -Recurse -File).Count
$newU = (Get-ChildItem (Join-Path $OutDir 'app.asar.unpacked') -Recurse -File).Count
if ($oldU -ne $newU) { Fail ("unpacked file count changed: {0} -> {1}" -f $oldU, $newU) }
Push-Location $OutDir
& npx --yes @electron/asar@3.4.1 extract-file "$outAsar" "dist/utils.js" | Out-Null
Pop-Location
$verify = Get-Content (Join-Path $OutDir 'utils.js') -Raw
Remove-Item (Join-Path $OutDir 'utils.js') -Force -ErrorAction SilentlyContinue
if (-not $verify.Contains($Marker)) { Fail 'marker missing from repacked utils.js' }
Write-Host ("Verified: {0} entries, unpacked {1} files, marker present" -f $newList.Count, $newU)

# 6. Replace (app.asar + unpacked tree) and relaunch.
$unpackedLive = Join-Path $ResDir 'app.asar.unpacked'
$unpackedBak = Join-Path $ResDir ("app.asar.unpacked.bak-" + $Stamp)
Move-Item -LiteralPath $unpackedLive -Destination $unpackedBak
try {
  Copy-Item -LiteralPath $outAsar -Destination $Asar -Force
  Copy-Item -Recurse -Path (Join-Path $OutDir 'app.asar.unpacked') -Destination $unpackedLive
} catch {
  Copy-Item -LiteralPath $backup -Destination $Asar -Force
  if (Test-Path -LiteralPath $unpackedLive) { Remove-Item -Recurse -Force -LiteralPath $unpackedLive }
  Move-Item -LiteralPath $unpackedBak -Destination $unpackedLive
  Fail ("replace failed, rolled back: {0}" -f $_)
}
Remove-Item -Recurse -Force -LiteralPath $unpackedBak
Write-Host 'Installed patched app.asar'

if ($args -notcontains '-NoLaunch') {
  Start-Process -FilePath $Exe
  Write-Host 'Antigravity relaunched'
}
Write-Host 'DONE'
