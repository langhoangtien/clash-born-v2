# Chạy toàn bộ test Clashborn v2 (Windows).
#   powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
#   powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Filter CRP_05 -VerboseTests
# Đường dẫn Godot: tham số -Godot, hoặc biến môi trường GODOT, hoặc mặc định bên dưới.
# Mã thoát: 0 = xanh, 1 = có test đỏ, 2 = không có test nào chạy, 3 = không tìm thấy Godot.
param(
    [string]$Filter = "",
    [switch]$VerboseTests,
    [string]$Godot = ""
)

$DefaultGodot = "C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if ($Godot -eq "") { $Godot = $env:GODOT }
if ([string]::IsNullOrEmpty($Godot)) { $Godot = $DefaultGodot }

# Bản _console.exe in kết quả ra cửa sổ này và trả mã thoát đúng; ưu tiên nó nếu có.
$ConsoleGodot = $Godot -replace '\.exe$', '_console.exe'
if (Test-Path $ConsoleGodot) { $Godot = $ConsoleGodot }
if (-not (Test-Path $Godot)) {
    Write-Host "Không tìm thấy Godot: $Godot" -ForegroundColor Red
    Write-Host "Truyền -Godot <đường dẫn> hoặc đặt biến môi trường GODOT."
    exit 3
}

$Root = Split-Path -Parent $PSScriptRoot
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Bước 1: import để Godot cập nhật danh sách class_name (tránh lỗi
# "Identifier not declared" đã gặp ở v1 — D-09).
Start-Process -FilePath $Godot -NoNewWindow -Wait `
    -ArgumentList @("--headless", "--path", "`"$Root`"", "--import") `
    -RedirectStandardOutput "$env:TEMP\clashborn_import.log" `
    -RedirectStandardError "$env:TEMP\clashborn_import_err.log" | Out-Null

# Bước 2: chạy test.
$UserArgs = @()
if ($Filter -ne "") { $UserArgs += "--filter=$Filter" }
if ($VerboseTests) { $UserArgs += "--verbose" }
$Proc = Start-Process -FilePath $Godot -NoNewWindow -Wait -PassThru `
    -ArgumentList (@("--headless", "--path", "`"$Root`"", "-s", "res://tests/run_all.gd", "--") + $UserArgs)
$Code = $Proc.ExitCode
if ($Code -eq 0) { Write-Host "TEST XANH" -ForegroundColor Green }
elseif ($Code -eq 2) { Write-Host "KHÔNG CÓ TEST NÀO CHẠY" -ForegroundColor Yellow }
else { Write-Host "TEST ĐỎ (mã $Code)" -ForegroundColor Red }
exit $Code
