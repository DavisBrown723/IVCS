param(
    [string]$ArmaDirectory = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 3',
    [string]$FileBank = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 3 Tools\FileBank\FileBank.exe',
    [int]$TimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'
$repositoryPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$serverExecutable = Join-Path $ArmaDirectory 'arma3server_x64.exe'
if (!(Test-Path -LiteralPath $serverExecutable) -or !(Test-Path -LiteralPath $FileBank)) {
    throw 'Arma dedicated server and FileBank are required.'
}
$runPath = Join-Path ([IO.Path]::GetTempPath()) ('ivcs-tasks-' + [guid]::NewGuid().ToString('N'))
$missionPath = Join-Path $runPath 'ivcs_task_tests.Altis'
$missionsPath = Join-Path $runPath 'mpmissions'
$profilePath = Join-Path $runPath 'profile'
$sourcePath = Join-Path $missionPath 'IVCS'
New-Item -ItemType Directory -Path $sourcePath, $missionsPath, $profilePath | Out-Null
foreach ($entry in Get-ChildItem -LiteralPath $repositoryPath -Force) {
    if ($entry.Name -in @('.git', 'tests', '.vscode')) { continue }
    Copy-Item -LiteralPath $entry.FullName -Destination $sourcePath -Recurse
}
foreach ($name in @('mission.sqm', 'init.sqf', 'description.ext')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $missionPath
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'run.sqf') -Destination (Join-Path $missionPath 'test.sqf')
& $FileBank -dst $missionsPath $missionPath | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not pack test mission.' }
$missionName = 'ivcs_task_tests_' + [guid]::NewGuid().ToString('N') + '.Altis'
$installedMissionPath = Join-Path $ArmaDirectory ('MPMissions\' + $missionName + '.pbo')
if (Test-Path -LiteralPath $installedMissionPath) { throw 'Test mission path already exists.' }
$configPath = Join-Path $runPath 'server.cfg'
@'
hostname="IVCS Tasks local tests";
password="ivcs-local-test";
maxPlayers=1;
persistent=1;
BattlEye=0;
verifySignatures=0;
upnp=0;
class Missions {
    class IVCSTasks { template="ivcs_task_tests.Altis"; difficulty="Regular"; };
};
'@ | ForEach-Object { $_.Replace('ivcs_task_tests.Altis', $missionName) } | Set-Content -LiteralPath $configPath -Encoding ascii
Write-Output ('Test artifacts: ' + $runPath)
$arguments = @(
    '-ip=127.0.0.1', '-port=2492', '-world=empty', '-autoInit', '-noSound',
    ('"-config=' + $configPath + '"'), ('"-profiles=' + $profilePath + '"'),
    '-name=IVCSTasks'
)
$serverProcess = $null
try {
    Copy-Item -LiteralPath (Join-Path $missionsPath 'ivcs_task_tests.Altis.pbo') -Destination $installedMissionPath
    $serverProcess = Start-Process -FilePath $serverExecutable -ArgumentList $arguments -WorkingDirectory $ArmaDirectory -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $result = ''
    $logText = ''
    while ([DateTime]::UtcNow -lt $deadline -and !$serverProcess.HasExited) {
        Start-Sleep -Seconds 1
        $logFile = Get-ChildItem -LiteralPath $profilePath -Filter '*.rpt' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($null -ne $logFile) {
            $logText = Get-Content -LiteralPath $logFile.FullName -Raw
            $result = [regex]::Match($logText, '\[IVCS TASK TEST\] DONE passed=\d+ failed=\d+').Value
            if ($result) { break }
        }
    }
    [regex]::Split($logText, '\r?\n') | Where-Object { $_ -match '\[IVCS TASK TEST\]|Error in expression|Error position|Error Undefined variable|Error Missing|Error Type' } | Write-Output
    if (!$result) { throw 'Test mission did not complete; inspect the retained RPT.' }
    if ($result -notmatch 'failed=0$' -or $logText -match 'Error in expression|Error Undefined variable|Error Missing|Error Type') {
        throw 'Engine tests failed; inspect the retained RPT.'
    }
} finally {
    if ($null -ne $serverProcess) {
        if (!$serverProcess.HasExited) { Stop-Process -Id $serverProcess.Id }
        if (!$serverProcess.WaitForExit(10000)) { throw 'Test server did not exit.' }
    }
    if (Test-Path -LiteralPath $installedMissionPath) {
        Remove-Item -LiteralPath $installedMissionPath
    }
}
