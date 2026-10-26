param([Parameter(Mandatory)][string]$OutputDirectory,[int]$Seconds=245)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Diagnostics/Microsoft.PowerShell.Diagnostics.psd1')
$paths=@('\Processor Information(*)\% Processor Performance','\Processor Information(*)\% Processor Utility','\Processor Information(*)\% Performance Limit','\Processor Information(*)\Processor Frequency','\System\Processor Queue Length','\Process(*)\% Processor Time','\Process(*)\ID Process')
[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');seconds=$Seconds;powerScheme=(powercfg /getactivescheme)} | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'counters-session.json') -Encoding UTF8
Get-Counter -Counter $paths -SampleInterval 1 -MaxSamples $Seconds -ErrorAction SilentlyContinue -ErrorVariable counterErrors | Export-Counter -Path (Join-Path $OutputDirectory 'host.blg') -FileFormat BLG -Force

[ordered]@{counterErrorCount=@($counterErrors).Count;finishedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'counters-quality.json') -Encoding UTF8
