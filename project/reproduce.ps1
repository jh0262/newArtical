param([string]$RunName = ('Retzler_History_Replay_' + (Get-Date -Format 'yyyyMMdd_HHmmss')))
$ErrorActionPreference = 'Stop'
if ($RunName -notmatch '^[A-Za-z0-9_-]+$') { throw 'RunName must contain only letters, digits, underscore or hyphen.' }
$sourceDir = Split-Path -Parent $PSCommandPath
$workspaceDir = (Resolve-Path (Join-Path $sourceDir '../..')).Path
$projectParent = (Resolve-Path (Join-Path $workspaceDir '06_projects')).Path
$newRunDir = [IO.Path]::GetFullPath((Join-Path $projectParent $RunName))
if (-not $newRunDir.StartsWith($projectParent + [IO.Path]::DirectorySeparatorChar)) { throw 'Invalid destination boundary.' }
if (Test-Path -LiteralPath $newRunDir) { throw 'Output already exists; refusing to overwrite.' }
New-Item -ItemType Directory -Path $newRunDir | Out-Null
Get-ChildItem -LiteralPath $sourceDir -File | Where-Object { $_.Extension -in '.py','.md','.json' -or $_.Name -like 'requirements-*.txt' -or $_.Name -eq 'SOURCE_LICENSE' } | Where-Object { $_.Name -notin 'suite_status.json','delivery_check.json' } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $newRunDir }
$pythonExe = Join-Path $workspaceDir '.venv-v3/Scripts/python.exe'
$env:STEP4_PLOT_DEPS = Join-Path $sourceDir 'plot_deps'
$env:PYTHONHASHSEED = '101'
Push-Location -LiteralPath $newRunDir
try {
    & $pythonExe -X utf8 preflight.py
    if ($LASTEXITCODE -ne 0) { throw 'Preflight failed.' }
    & $pythonExe -X utf8 -m unittest test_contracts test_networks test_export -v 2>&1 | Tee-Object -FilePath tests_pass.log
    if ($LASTEXITCODE -ne 0) { throw 'Contract checks failed.' }
    & $pythonExe -u -X utf8 run_physics.py 2>&1 | Tee-Object -FilePath physics_console.log
    if ($LASTEXITCODE -ne 0) { throw 'Physics fitting failed.' }
    & $pythonExe -u -X utf8 run_suite.py 2>&1 | Tee-Object -FilePath suite_console.log
    if ($LASTEXITCODE -ne 0) { throw 'Suite launcher failed.' }
    & $pythonExe -X utf8 analyze.py
    if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
    & $pythonExe -X utf8 render_results.py
    if ($LASTEXITCODE -ne 0) { throw 'Rendering failed.' }
    & $pythonExe -X utf8 write_report.py
    if ($LASTEXITCODE -ne 0) { throw 'Report failed.' }
    & $pythonExe -X utf8 delivery_check.py --from-replay
    if ($LASTEXITCODE -ne 0) { throw 'Delivery check failed.' }
    Write-Output ('Results: ' + (Join-Path $newRunDir 'results/第4步_重跑分析报告.md'))
} finally { Pop-Location }
