# Fixes Flutter Chrome/web builds when Puro recreates flutter_web_sdk as a symlink.
# Prefer the global auto-fix in %USERPROFILE%\bin\flutter.bat (runs on every flutter call).
#
# Manual:
#   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\bin\fix_flutter_web_sdk.ps1"
#   powershell -ExecutionPolicy Bypass -File tool\fix_flutter_web_sdk.ps1

$global = Join-Path $env:USERPROFILE "bin\fix_flutter_web_sdk.ps1"
if (Test-Path $global) {
    & $global @args
    exit $LASTEXITCODE
}

$ErrorActionPreference = "Stop"
$link = Join-Path $env:USERPROFILE ".puro\envs\stable\flutter\bin\cache\flutter_web_sdk"
if (-not (Test-Path $link)) {
    throw "flutter_web_sdk not found at $link. Run: flutter precache --web"
}

$item = Get-Item $link -Force
$isReparse = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
if (-not $isReparse) {
    Write-Host "OK: flutter_web_sdk is already a real directory."
    exit 0
}

$src = @($item.Target)[0]
if (-not $src -or -not (Test-Path $src)) {
    $src = Get-ChildItem (Join-Path $env:USERPROFILE ".puro\shared\caches") -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName "flutter_web_sdk" } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1
}
if (-not $src -or -not (Test-Path $src)) {
    throw "Could not resolve shared-cache flutter_web_sdk source."
}

Write-Host "Replacing symlink with real copy..."
cmd /c "rmdir `"$link`"" | Out-Null
if (Test-Path $link) { throw "Failed to remove symlink: $link" }
New-Item -ItemType Directory -Path $link -Force | Out-Null
robocopy $src $link /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit $LASTEXITCODE" }
Write-Host "Done. Try: flutter run -d chrome"
