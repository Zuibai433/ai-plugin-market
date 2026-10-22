param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$WorkDir = (Join-Path $env:TEMP ('dsh-publish-' + [guid]::NewGuid().ToString('N')))
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Remove-ScratchDir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.LinkType) { $item.Delete(); return }
  if ($Path -notmatch 'dsh-publish-[0-9a-f]{32}') { throw "refuse to delete a non-scratch path: $Path" }
  Remove-Item -LiteralPath $Path -Recurse -Force
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$indexPath = Join-Path $here 'index.json'
$patchPath = Join-Path $env:USERPROFILE '.dsh\profiles\desktop\cordis.patch.yml'

if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "Repo must be owner/name: $Repo" }

Write-Host '== 0/4 validate index.json ==' -ForegroundColor Cyan
$doc = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
if ($doc.format -ne 1) { throw 'format must be 1' }
if (-not $doc.plugins -or $doc.plugins.Count -eq 0) { throw 'plugins must not be empty' }
Write-Host ('   ok: {0} plugins' -f $doc.plugins.Count) -ForegroundColor Green

Write-Host '== 1/4 clone existing repo ==' -ForegroundColor Cyan
Remove-ScratchDir $WorkDir
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$cloneDir = Join-Path $WorkDir $Repo.Split('/')[1]
git clone "https://github.com/$Repo.git" $cloneDir
if ($LASTEXITCODE -ne 0) { throw 'clone failed: check network/credentials; the repo must exist and be PUBLIC for jsDelivr' }
$branch = (git -C $cloneDir rev-parse --abbrev-ref HEAD).Trim()
Write-Host "   branch: $branch" -ForegroundColor Green

Write-Host '== 2/4 copy index.json and push ==' -ForegroundColor Cyan
Copy-Item $indexPath (Join-Path $cloneDir 'index.json') -Force
git -C $cloneDir add index.json
git -C $cloneDir -c user.name='dsh-agent' -c user.email='dsh-agent@localhost' commit -m 'add DSH plugin market index'
if ($LASTEXITCODE -ne 0) { Write-Host '   nothing to commit (identical file already present)' -ForegroundColor Yellow }
git -C $cloneDir push origin $branch
if ($LASTEXITCODE -ne 0) { throw 'push failed' }

Write-Host '== 3/4 point DSH at the GitHub copy ==' -ForegroundColor Cyan
$url = "https://cdn.jsdelivr.net/gh/$Repo@$branch/index.json"
if (-not (Test-Path $patchPath)) { throw "profile patch not found: $patchPath" }
Copy-Item $patchPath "$patchPath.bak-$(Get-Date -Format yyyyMMddHHmmss)" -Force
$yaml = [System.IO.File]::ReadAllText($patchPath, [System.Text.Encoding]::UTF8)
$pattern = 'https://cdn\.jsdelivr\.net/gh/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+/index\.json'
if ($yaml -notmatch $pattern) { throw "no jsdelivr index URL in $patchPath; set plugin-market.indexes to $url manually" }
$yaml = [regex]::Replace($yaml, $pattern, $url)
[System.IO.File]::WriteAllText($patchPath, $yaml, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "   $url" -ForegroundColor Green

Write-Host '== 4/4 next ==' -ForegroundColor Cyan
Write-Host '   1) open the jsDelivr URL in a browser; it must return JSON (first hit can take a few seconds)'
Write-Host '   2) restart the DSH desktop app, then Plugins -> Discover'
Remove-ScratchDir $WorkDir
