<#
.SYNOPSIS
  发布 H:\AI\plugin-market 到 GitHub，并把 DSH 自定义插件市场的搜索源指向它。
.EXAMPLE
  .\publish.ps1 -Repo myname/ai-plugin-market
#>
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$patchPath = Join-Path $env:USERPROFILE '.dsh\profiles\desktop\cordis.patch.yml'

if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "Repo must be owner/name: $Repo" }

Write-Host '== 1/4 validate index.json ==' -ForegroundColor Cyan
$doc = [System.IO.File]::ReadAllText((Join-Path $here 'index.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
if ($doc.format -ne 1) { throw 'format must be 1' }
if (-not $doc.plugins -or $doc.plugins.Count -eq 0) { throw 'plugins must not be empty' }
Write-Host ('   ok: {0} plugins' -f $doc.plugins.Count) -ForegroundColor Green

Write-Host '== 2/4 commit to local git ==' -ForegroundColor Cyan
Push-Location $here
try {
  if (-not (Test-Path (Join-Path $here '.git'))) { git init -q | Out-Null }
  git add -A
  git -c user.name='dsh-agent' -c user.email='dsh-agent@localhost' commit -q -m 'plugin market index'
  if ($LASTEXITCODE -ne 0) { Write-Host '   no changes' -ForegroundColor Yellow }
  git branch -M $Branch
} finally { Pop-Location }

Write-Host '== 3/4 push to GitHub ==' -ForegroundColor Cyan
Push-Location $here
try {
  $remotes = @(git remote)
  if ($remotes -contains 'origin') { git remote set-url origin "https://github.com/$Repo.git" }
  else { git remote add origin "https://github.com/$Repo.git" }
  git push -u origin $Branch
  if ($LASTEXITCODE -ne 0) { throw 'push failed: log in to git and create the GitHub repo first' }
} finally { Pop-Location }

Write-Host '== 4/4 point DSH search source at it ==' -ForegroundColor Cyan
$url = "https://cdn.jsdelivr.net/gh/$Repo@$Branch/index.json"
if (-not (Test-Path $patchPath)) { throw "profile patch not found: $patchPath" }
Copy-Item $patchPath "$patchPath.bak-$(Get-Date -Format yyyyMMddHHmmss)" -Force
$yaml = [System.IO.File]::ReadAllText($patchPath, [System.Text.Encoding]::UTF8)
$pattern = 'https://cdn\.jsdelivr\.net/gh/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+/index\.json'
if ($yaml -notmatch $pattern) { throw "no jsdelivr index URL in $patchPath; set plugin-market.indexes to $url manually" }
[System.IO.File]::WriteAllText($patchPath, [regex]::Replace($yaml, $pattern, $url), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "   indexes: $url" -ForegroundColor Green
Write-Host 'Restart the DSH desktop app, then Plugins -> Discover.'
