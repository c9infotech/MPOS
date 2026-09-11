# Re-signs release APKs with v1+v2+v3 (needed by some industrial Android 13 devices).
# Usage: powershell -ExecutionPolicy Bypass -File tool\resign_apk_v1.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$propsFile = Join-Path $root "android\key.properties"
if (-not (Test-Path $propsFile)) { throw "Missing android\key.properties" }

$props = @{}
Get-Content $propsFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') { $props[$Matches[1].Trim()] = $Matches[2].Trim() }
}

$storeFile = Join-Path (Join-Path $root "android") ($props["storeFile"] -replace '^\.\./','')
if (-not (Test-Path $storeFile)) {
    $storeFile = Join-Path $root "android\keystore\mpos-release.jks"
}
if (-not (Test-Path $storeFile)) { throw "Keystore not found" }

$sdkRoot = $env:ANDROID_HOME
if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$apksigner = Get-ChildItem "$sdkRoot\build-tools" -Recurse -Filter apksigner.bat |
    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $apksigner) { throw "apksigner not found" }

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

function Sign-Apk($inPath, $outPath) {
    Write-Host "Signing $inPath -> $outPath"
    # --min-sdk-version 21 forces inclusion of v1 signatures even when the
    # app manifest minSdk is 24+ (needed by some industrial package installers).
    & $apksigner sign `
        --ks $storeFile `
        --ks-key-alias $props["keyAlias"] `
        --ks-pass ("pass:" + $props["storePassword"]) `
        --key-pass ("pass:" + $props["keyPassword"]) `
        --min-sdk-version 21 `
        --v1-signing-enabled true `
        --v2-signing-enabled true `
        --v3-signing-enabled true `
        --out $outPath `
        $inPath
    if ($LASTEXITCODE -ne 0) { throw "apksigner failed for $inPath" }
    & $apksigner verify --verbose $outPath
}

$universal = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $universal) {
    Sign-Apk $universal (Join-Path $dist "MPOS-1.4.0-signed-v1.apk")
}

foreach ($split in @(
    "app-armeabi-v7a-release.apk",
    "app-arm64-v8a-release.apk"
)) {
    $in = Join-Path $root "build\app\outputs\flutter-apk\$split"
    if (-not (Test-Path $in)) { continue }
    $name = $split -replace '^app-','MPOS-1.4.0-' -replace '-release\.apk$','.apk'
    Sign-Apk $in (Join-Path $dist $name)
}

Write-Host ""
Write-Host "Done. APKs in $dist"
Get-ChildItem $dist -Filter "MPOS*.apk" | Format-Table Name, Length -AutoSize
