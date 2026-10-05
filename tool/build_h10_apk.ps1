# Build the H10 / industrial handheld APKs (Android 13 H10).
#
# Package: com.argit.mpos.handheld
# Outputs:
#   dist\MPOS-H10-universal-<ver>.apk
#   dist\MPOS-H10-32bit-<ver>.apk   (armeabi-v7a — preferred on many H10 devices)
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

function Get-PubspecVersion {
    $pubspec = Get-Content (Join-Path $root "pubspec.yaml") -Raw
    if ($pubspec -match '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
        return $Matches[1]
    }
    return "0.0.0"
}

$version = Get-PubspecVersion
Write-Host "MPOS version: $version"

Write-Host "Building handheld universal release APK..."
flutter build apk --release --flavor handheld
if ($LASTEXITCODE -ne 0) { throw "flutter build apk (universal) failed" }

$universalBuilt = Join-Path $root "build\app\outputs\flutter-apk\app-handheld-release.apk"
if (-not (Test-Path $universalBuilt)) {
    throw "Expected APK not found: $universalBuilt"
}

$universalOut = Join-Path $dist "MPOS-H10-universal-$version.apk"
Copy-Item $universalBuilt $universalOut -Force
# Keep unversioned alias for docs/scripts that expect the old name.
Copy-Item $universalBuilt (Join-Path $dist "MPOS-H10-universal.apk") -Force

Write-Host "Building handheld 32-bit (armeabi-v7a) APK..."
flutter build apk --release --flavor handheld --split-per-abi --target-platform android-arm
if ($LASTEXITCODE -ne 0) { throw "flutter build apk (32-bit) failed" }

$bit32Built = Join-Path $root "build\app\outputs\flutter-apk\app-armeabi-v7a-handheld-release.apk"
if (-not (Test-Path $bit32Built)) {
    # Older Flutter naming without flavor in the middle.
    $alt = Join-Path $root "build\app\outputs\flutter-apk\app-handheld-armeabi-v7a-release.apk"
    if (Test-Path $alt) { $bit32Built = $alt }
}
if (-not (Test-Path $bit32Built)) {
    Write-Warning "32-bit APK not found under flutter-apk. Listing outputs:"
    Get-ChildItem (Join-Path $root "build\app\outputs\flutter-apk") -ErrorAction SilentlyContinue |
        Format-Table Name, Length -AutoSize
    throw "Expected 32-bit APK not found"
}

$bit32Out = Join-Path $dist "MPOS-H10-32bit-$version.apk"
Copy-Item $bit32Built $bit32Out -Force

# H10 package installers reject APKs that only have v2/v3 ("App not installed").
# Re-sign with v1 as well. minSdk 21 forces the JAR signature even when the
# manifest minSdk is 24+.
$propsFile = Join-Path $root "android\key.properties"
if (-not (Test-Path $propsFile)) { throw "Missing android\key.properties" }
$props = @{}
Get-Content $propsFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') { $props[$Matches[1].Trim()] = $Matches[2].Trim() }
}
$storeFile = Join-Path (Join-Path $root "android") ($props["storeFile"] -replace '^\.\./','')
if (-not (Test-Path $storeFile)) { throw "Keystore not found: $storeFile" }
$sdkRoot = $env:ANDROID_HOME
if (-not $sdkRoot) { $sdkRoot = "D:\Android\Sdk" }
if (-not (Test-Path $sdkRoot)) { $sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$apksigner = Get-ChildItem "$sdkRoot\build-tools" -Recurse -Filter apksigner.bat |
    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $apksigner) { throw "apksigner not found" }

function Sign-H10Apk([string]$apkPath) {
    $signed = "$apkPath.signed"
    if (Test-Path $signed) { Remove-Item $signed -Force }
    Write-Host "Adding v1 signature: $apkPath"
    & $apksigner sign `
        --ks $storeFile `
        --ks-key-alias $props["keyAlias"] `
        --ks-pass ("pass:" + $props["storePassword"]) `
        --key-pass ("pass:" + $props["keyPassword"]) `
        --min-sdk-version 21 `
        "--v1-signing-enabled=true" `
        "--v2-signing-enabled=true" `
        "--v3-signing-enabled=true" `
        --out $signed `
        $apkPath
    if ($LASTEXITCODE -ne 0) { throw "apksigner failed for $apkPath" }
    Move-Item $signed $apkPath -Force
    & $apksigner verify --verbose $apkPath
    if ($LASTEXITCODE -ne 0) { throw "verify failed for $apkPath" }
}

Sign-H10Apk $universalOut
Sign-H10Apk (Join-Path $dist "MPOS-H10-universal.apk")
Sign-H10Apk $bit32Out

Write-Host ""
Write-Host "Done. APKs in $dist"
Get-ChildItem $dist -Filter "MPOS-H10*$version.apk" |
    Format-Table FullName, @{N = 'MB'; E = { [math]::Round($_.Length / 1MB, 2) } }, LastWriteTime -AutoSize
