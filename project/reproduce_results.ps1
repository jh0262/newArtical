$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    python scripts\audit_results.py
    if ($LASTEXITCODE -ne 0) { throw 'Independent numerical audit failed.' }
    & 'C:\Program Files\MATLAB\R2025b\bin\matlab.exe' -singleCompThread -batch "ec_setup; addpath('analysis'); ec_analyze;"
    if ($LASTEXITCODE -ne 0) { throw 'MATLAB analysis failed.' }
    python scripts\crosscheck_statistics.py
    if ($LASTEXITCODE -ne 0) { throw 'Independent statistical crosscheck failed.' }
    python scripts\build_report.py
    if ($LASTEXITCODE -ne 0) { throw 'Report generation failed.' }
} finally {
    Pop-Location
}
