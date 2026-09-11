# Build the H10 / industrial handheld universal APK (what worked on Android 13 H10).
#
# Package: com.argit.mpos.handheld
# Output:  dist\MPOS-H10-universal.apk
#
# Prerequisites:
#   - Android SDK + JAVA_HOME set
#   - android\key.properties + android\keystore\mpos-release.jks (release signing)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tool\build_h10_apk.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

Write-Host "Building handheld release APK..."
flutter build apk --release --flavor handheld
if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed" }

$built = Join-Path $root "build\app\outputs\flutter-apk\app-handheld-release.apk"
if (-not (Test-Path $built)) {
    throw "Expected APK not found: $built"
}

$out = Join-Path $dist "MPOS-H10-universal.apk"
Copy-Item $built $out -Force

Write-Host ""
Write-Host "Done: $out"
Get-Item $out | Format-Table FullName, @{N = 'MB'; E = { [math]::Round($_.Length / 1MB, 2) } }, LastWriteTime -AutoSize
