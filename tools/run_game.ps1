# Chạy game Clashborn v2 (Windows). LUÔN dùng script này sau khi git pull:
# nó cho Godot import trước để cập nhật danh sách class_name (tránh lỗi
# "Identifier ... not declared" khi có file script mới — D-09).
#   powershell -ExecutionPolicy Bypass -File tools\run_game.ps1
param([string]$Godot = "")

$DefaultGodot = "C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if ($Godot -eq "") { $Godot = $env:GODOT }
if ([string]::IsNullOrEmpty($Godot)) { $Godot = $DefaultGodot }
if (-not (Test-Path $Godot)) {
    Write-Host "Không tìm thấy Godot: $Godot" -ForegroundColor Red
    exit 3
}
$ConsoleGodot = $Godot -replace '\.exe$', '_console.exe'
$Importer = if (Test-Path $ConsoleGodot) { $ConsoleGodot } else { $Godot }
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "Đang import dự án..."
Start-Process -FilePath $Importer -NoNewWindow -Wait `
    -ArgumentList @("--headless", "--path", "`"$Root`"", "--import") `
    -RedirectStandardOutput "$env:TEMP\clashborn_import.log" `
    -RedirectStandardError "$env:TEMP\clashborn_import_err.log" | Out-Null

Write-Host "Chạy game."
Start-Process -FilePath $Godot -ArgumentList @("--path", "`"$Root`"")
