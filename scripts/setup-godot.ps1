$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsRoot = Join-Path $projectRoot 'tools'
$engineRoot = Join-Path $toolsRoot 'godot'
New-Item -ItemType Directory -Force -Path $engineRoot | Out-Null
$archivePath = Join-Path $toolsRoot 'godot.zip'
$version = '4.7.2-stable'
$url = "https://github.com/godotengine/godot/releases/download/$version/Godot_v${version}_win64.exe.zip"
if (-not (Test-Path -LiteralPath (Join-Path $engineRoot "Godot_v${version}_win64_console.exe"))) {
    Invoke-WebRequest -Uri $url -OutFile $archivePath
    Expand-Archive -LiteralPath $archivePath -DestinationPath $engineRoot -Force
}
Write-Output "Godot is ready in $engineRoot. Run START.cmd."
