<#
.SYNOPSIS
  FORGELOOP-01 read-only inventory of Roblox / Blender / Codex work on this Windows PC (task FL-0034).

.DESCRIPTION
  Finds Roblox place and model files, Rojo/Script Sync style source folders, Blender files and exports,
  and the tools installed (Studio, Blender incl. portable copies, git, rojo/rokit/aftman, python, codex, claude).
  It only READS the disk. The single file it writes is the report (default: forgeloop-inventory-<date>.md
  in the current folder). Nothing is uploaded.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\find-roblox-projects.ps1
  powershell -ExecutionPolicy Bypass -File .\find-roblox-projects.ps1 -ExtraRoots D:\Projects,E:\
#>
param(
    [string[]]$ExtraRoots = @(),
    [string]$Out = (Join-Path (Get-Location) ("forgeloop-inventory-{0}.md" -f (Get-Date -Format 'yyyy-MM-dd'))),
    [int]$MaxResultsPerType = 200
)

$ErrorActionPreference = 'SilentlyContinue'
$started = Get-Date
$userHome = $env:USERPROFILE
$roots = @(
    (Join-Path $userHome 'Documents'), (Join-Path $userHome 'Desktop'), (Join-Path $userHome 'Downloads'),
    (Join-Path $userHome 'OneDrive'), (Join-Path $userHome 'source'), (Join-Path $userHome 'Projects'),
    (Join-Path $userHome 'Roblox'), (Join-Path $userHome 'Codex'), (Join-Path $userHome '.codex'),
    (Join-Path $env:LOCALAPPDATA 'Roblox'), 'C:\Projects', 'C:\Dev', 'C:\src'
) + $ExtraRoots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$skip = '\\node_modules\\|\\\.git\\|\\AppData\\Local\\Temp\\|\\Roblox\\Versions\\|\\Roblox\\logs\\|\\\$Recycle\.Bin\\'

function Find-Files([string[]]$patterns) {
    $found = foreach ($r in $roots) {
        Get-ChildItem -Path $r -Recurse -File -Include $patterns -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch $skip }
    }
    $found | Sort-Object LastWriteTime -Descending | Select-Object -First $MaxResultsPerType
}

function Table($items, [scriptblock[]]$cols, [string[]]$headers) {
    if (-not $items) { return "_None found._`n" }
    $lines = @('| ' + ($headers -join ' | ') + ' |', '|' + ('---|' * $headers.Count))
    foreach ($i in $items) { $lines += '| ' + (($cols | ForEach-Object { (& $_ $i) -replace '\|', '/' }) -join ' | ') + ' |' }
    ($lines -join "`n") + "`n"
}

function Size($b) { if ($b -ge 1MB) { '{0:N1} MB' -f ($b / 1MB) } else { '{0:N0} KB' -f ($b / 1KB) } }

$report = New-Object System.Collections.Generic.List[string]
$report.Add("# FORGELOOP inventory — $env:COMPUTERNAME — $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$report.Add("")
$report.Add("Read-only scan. Roots searched: " + (($roots | ForEach-Object { "``$_``" }) -join ', '))
$report.Add("")

# --- Tools
$report.Add("## Tools")
$tools = @()
$studio = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox\Versions') -Recurse -Filter 'RobloxStudioBeta.exe' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$tools += [pscustomobject]@{ Name = 'Roblox Studio'; Where = $(if ($studio) { $studio.FullName } else { 'not found' }); Version = $(if ($studio) { $studio.VersionInfo.FileVersion } else { '' }) }
$blenders = @()
$blenders += Get-ChildItem 'C:\Program Files\Blender Foundation' -Recurse -Filter 'blender.exe' -ErrorAction SilentlyContinue
$blenders += foreach ($r in $roots) { Get-ChildItem $r -Recurse -Filter 'blender.exe' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $skip } }
foreach ($b in ($blenders | Sort-Object FullName -Unique)) { $tools += [pscustomobject]@{ Name = 'Blender'; Where = $b.FullName; Version = $b.VersionInfo.ProductVersion } }
if (-not $blenders) { $tools += [pscustomobject]@{ Name = 'Blender'; Where = 'not found'; Version = '' } }
foreach ($cmd in 'git', 'git-lfs', 'rojo', 'rokit', 'aftman', 'foreman', 'selene', 'stylua', 'lune', 'wally', 'python', 'py', 'node', 'codex', 'claude', 'gh') {
    $c = Get-Command $cmd -ErrorAction SilentlyContinue | Select-Object -First 1
    $v = ''
    if ($c) { try { $v = (& $c.Source --version 2>&1 | Select-Object -First 1) -as [string] } catch { $v = '' } }
    $tools += [pscustomobject]@{ Name = $cmd; Where = $(if ($c) { $c.Source } else { 'not on PATH' }); Version = $v }
}
$report.Add((Table $tools @({ param($t) $t.Name }, { param($t) $t.Where }, { param($t) $t.Version }) @('Tool', 'Location', 'Version')))

# --- Rojo plugin / Studio plugins
$plugins = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox\Plugins') -File -ErrorAction SilentlyContinue
$report.Add("## Studio local plugins")
$report.Add((Table $plugins @({ param($f) $f.Name }, { param($f) $f.LastWriteTime.ToString('yyyy-MM-dd') }) @('File', 'Modified')))

# --- Places and models
$report.Add("## Roblox place files (.rbxl / .rbxlx) — newest first")
$places = Find-Files @('*.rbxl', '*.rbxlx')
$report.Add((Table $places @({ param($f) $f.Name }, { param($f) $f.DirectoryName }, { param($f) Size $f.Length }, { param($f) $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm') }) @('File', 'Folder', 'Size', 'Modified')))
$report.Add("## Roblox model files (.rbxm / .rbxmx)")
$models = Find-Files @('*.rbxm', '*.rbxmx')
$report.Add((Table $models @({ param($f) $f.Name }, { param($f) $f.DirectoryName }, { param($f) Size $f.Length }, { param($f) $f.LastWriteTime.ToString('yyyy-MM-dd') }) @('File', 'Folder', 'Size', 'Modified')))

# --- Studio autosaves
$auto = @()
foreach ($p in @((Join-Path $userHome 'Documents\ROBLOX\AutoSaves'), (Join-Path $env:LOCALAPPDATA 'Roblox\AutoSaves'))) {
    if (Test-Path $p) { $auto += Get-ChildItem $p -File -ErrorAction SilentlyContinue }
}
$report.Add("## Studio autosaves")
$report.Add((Table ($auto | Sort-Object LastWriteTime -Descending | Select-Object -First 50) @({ param($f) $f.Name }, { param($f) $f.DirectoryName }, { param($f) $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm') }) @('File', 'Folder', 'Modified')))

# --- Source projects (Rojo / toolchain manifests)
$report.Add("## Source projects (Rojo / Rokit / Aftman / Wally manifests)")
$manifests = Find-Files @('*.project.json', 'rokit.toml', 'aftman.toml', 'foreman.toml', 'wally.toml', 'selene.toml')
$report.Add((Table $manifests @({ param($f) $f.Name }, { param($f) $f.DirectoryName }, { param($f) $f.LastWriteTime.ToString('yyyy-MM-dd') }) @('File', 'Folder', 'Modified')))

# --- Luau/Lua script folders (Script Sync, Codex output, loose scripts)
$report.Add("## Folders containing Luau/Lua scripts (possible Script Sync / Codex output)")
$scripts = foreach ($r in $roots) { Get-ChildItem $r -Recurse -File -Include '*.luau', '*.lua' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $skip } }
$folders = $scripts | Group-Object DirectoryName | Sort-Object Count -Descending | Select-Object -First 60
$report.Add((Table $folders @({ param($g) $g.Name }, { param($g) $g.Count }, { param($g) ($g.Group | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.ToString('yyyy-MM-dd') }) @('Folder', 'Scripts', 'Newest')))
$keywords = 'flood', 'lagoon', 'arena', 'disaster', 'jungle', 'spectat', 'lobby', 'hunger', 'survival'
$hits = $scripts | Where-Object { $n = $_.Name.ToLower(); $keywords | Where-Object { $n -like "*$_*" } } | Select-Object -First 50
$report.Add("### Script names matching survival-arena keywords")
$report.Add((Table $hits @({ param($f) $f.Name }, { param($f) $f.DirectoryName }, { param($f) $f.LastWriteTime.ToString('yyyy-MM-dd') }) @('File', 'Folder', 'Modified')))

# --- Blender
$report.Add("## Blender files and exports")
$blend = Find-Files @('*.blend', '*.fbx', '*.obj', '*.glb', '*.gltf')
$report.Add((Table $blend @({ param($f) $f.Name }, { param($f) $f.DirectoryName }, { param($f) Size $f.Length }, { param($f) $f.LastWriteTime.ToString('yyyy-MM-dd') }) @('File', 'Folder', 'Size', 'Modified')))

# --- Git repos
$report.Add("## Git repositories under the searched roots")
$repos = foreach ($r in $roots) { Get-ChildItem $r -Recurse -Directory -Filter '.git' -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\node_modules\\' } }
$repoRows = foreach ($g in ($repos | Select-Object -First 60)) {
    $dir = $g.Parent.FullName
    $remote = ''
    if (Get-Command git -ErrorAction SilentlyContinue) { $remote = (git -C $dir remote get-url origin 2>$null) -as [string] }
    [pscustomobject]@{ Dir = $dir; Remote = $remote }
}
$report.Add((Table $repoRows @({ param($x) $x.Dir }, { param($x) $x.Remote }) @('Repository', 'origin')))

$report.Add("---")
$report.Add("Scan took $([int]((Get-Date) - $started).TotalSeconds) s. Results per type capped at $MaxResultsPerType. Add more places with -ExtraRoots.")
$report -join "`n" | Out-File -FilePath $Out -Encoding utf8
Write-Host "Report written to $Out"
Write-Host "Next: commit it to forgeloop/production/handoffs/ or paste it into the FORGE-00 chat."
