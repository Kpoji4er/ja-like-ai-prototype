$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
foreach ($folder in @('.runtime\Temp', '.runtime\AppData', '.runtime\LocalAppData', 'build')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot $folder) | Out-Null
}
$env:TEMP = Join-Path $projectRoot '.runtime\Temp'
$env:TMP = $env:TEMP
$env:APPDATA = Join-Path $projectRoot '.runtime\AppData'
$env:LOCALAPPDATA = Join-Path $projectRoot '.runtime\LocalAppData'
$engine = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tools\godot') -Filter '*win64_console.exe' | Select-Object -First 1
& $engine.FullName --path (Join-Path $projectRoot 'game') --log-file (Join-Path $projectRoot 'build\game.log') @args
exit $LASTEXITCODE
