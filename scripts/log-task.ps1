param(
    [Parameter(Mandatory=$true)][ValidateSet('Start','Finish','Status')][string]$Action,
    [string]$Task,
    [string]$Result
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$statePath = Join-Path $projectRoot '.runtime\task-timer.json'
$readmePath = Join-Path $projectRoot 'README.md'
$nowUtc = [DateTimeOffset]::UtcNow
$moscowOffset = [TimeSpan]::FromHours(3)
$encoding = New-Object System.Text.UTF8Encoding($false)
if ($Action -eq 'Start') {
    if (Test-Path -LiteralPath $statePath) { throw 'An active task timer already exists. Finish it first.' }
    if ([string]::IsNullOrWhiteSpace($Task)) { throw 'Task is required.' }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $statePath) | Out-Null
    $state = @{ task=$Task; started_utc=$nowUtc.ToString('o') }
    [IO.File]::WriteAllText($statePath,($state | ConvertTo-Json),$encoding)
    $text = [IO.File]::ReadAllText($readmePath)
    $current = '**Текущий этап:** с ' + $nowUtc.ToOffset($moscowOffset).ToString('dd.MM.yyyy HH:mm:ss') + ' МСК — ' + $Task + '.'
    $text = [regex]::Replace($text,'(?m)^\*\*Текущий этап:\*\*.*$',{param($match) $current})
    [IO.File]::WriteAllText($readmePath,$text,$encoding)
    Write-Output $current
    exit 0
}
if (-not (Test-Path -LiteralPath $statePath)) { throw 'No active task timer.' }
$state = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json
$startUtc = [DateTimeOffset]$state.started_utc
$duration = $nowUtc - $startUtc
if ($Action -eq 'Status') {
    [PSCustomObject]@{ Task=$state.task; StartedMoscow=$startUtc.ToOffset($moscowOffset); ElapsedSeconds=[int]$duration.TotalSeconds }
    exit 0
}
$description = ($state.task + '. ' + $Result).Replace('|','/').Replace("`r",' ').Replace("`n",' ')
$elapsed = '{0} мин {1:00} с' -f [math]::Floor($duration.TotalMinutes),$duration.Seconds
$row = '| ' + $startUtc.ToOffset($moscowOffset).ToString('dd.MM HH:mm:ss') + ' | ' + $nowUtc.ToOffset($moscowOffset).ToString('dd.MM HH:mm:ss') + ' | ' + $elapsed + ' | ' + $description + ' |'
$text = [IO.File]::ReadAllText($readmePath)
$text = $text.Replace('<!-- WORKLOG_ROWS_END -->',($row + "`n<!-- WORKLOG_ROWS_END -->"))
$text = [regex]::Replace($text,'(?m)^\*\*Текущий этап:\*\*.*$','**Текущий этап:** нет активного таймера; завершённые этапы приведены выше.')
[IO.File]::WriteAllText($readmePath,$text,$encoding)
Remove-Item -LiteralPath $statePath
Write-Output $row
