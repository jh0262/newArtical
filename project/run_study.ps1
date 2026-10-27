param([int]$Workers=8)
$ErrorActionPreference='Stop'
$taskRoot=$PSScriptRoot
$taskMatlab='C:\Program Files\MATLAB\R2025b\bin\matlab.exe'
if ($Workers -lt 1 -or $Workers -gt 8) { throw 'Workers must be 1..8' }
if (-not (Test-Path -LiteralPath (Join-Path $taskRoot 'provenance\code_manifest.json'))) { throw 'Run preflight and freeze_study.py first.' }
$taskLogRoot=Join-Path $taskRoot 'logs'
New-Item -ItemType Directory -Path $taskLogRoot -Force | Out-Null
$taskStamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$taskProcesses=@()
for($taskWorker=1;$taskWorker -le $Workers;$taskWorker++) {
    $taskExpr="cd('"+$taskRoot.Replace("'","''")+"'); ec_worker("+$taskWorker+","+$Workers+");"
    $taskOut=Join-Path $taskLogRoot ("batch_"+$taskStamp+"_worker_"+$taskWorker+".stdout.log")
    $taskErr=Join-Path $taskLogRoot ("batch_"+$taskStamp+"_worker_"+$taskWorker+".stderr.log")
    $taskProcess=Start-Process -FilePath $taskMatlab -ArgumentList @('-singleCompThread','-batch',('"'+$taskExpr+'"')) -WorkingDirectory $taskRoot -WindowStyle Hidden -RedirectStandardOutput $taskOut -RedirectStandardError $taskErr -PassThru
    $taskProcesses+= [PSCustomObject]@{worker=$taskWorker;pid=$taskProcess.Id;startedAt=(Get-Date).ToUniversalTime().ToString('o');stdout=$taskOut;stderr=$taskErr}
}
$taskLaunch=Join-Path $taskLogRoot ('launch_'+$taskStamp+'.json')
$taskProcesses | ConvertTo-Json | Set-Content -LiteralPath $taskLaunch -Encoding utf8
$taskProcesses | Format-Table worker,pid,stdout -AutoSize
