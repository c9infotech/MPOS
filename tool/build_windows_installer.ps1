# Builds Flutter Windows release and compiles an Inno Setup installer into dist\.
#
# Prerequisites:
#   - Flutter (with Windows desktop enabled)
#   - Inno Setup 6 (ISCC.exe) - winget install JRSoftware.InnoSetup
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tool\build_windows_installer.ps1
#   powershell -File tool\build_windows_installer.ps1 -SkipBuild
#   powershell -File tool\build_windows_installer.ps1 -SkipSign

param(
    [switch]$SkipBuild,
    [switch]$SkipSign,
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$releaseDir = Join-Path $root "build\windows\x64\runner\Release"
$issPath = Join-Path $root "installer\mpos.iss"
if (-not $OutDir) {
    $OutDir = Join-Path $root "dist"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Get-PubspecVersion {
    $pubspec = Get-Content (Join-Path $root "pubspec.yaml") -Raw
    if ($pubspec -match '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
        return $Matches[1]
    }
    return "0.0.0"
}

function Find-Iscc {
    $candidates = @(
        "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )
    $cmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($cmd) {
        $candidates += $cmd.Source
    }
    return $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

$version = Get-PubspecVersion
Write-Host "MPOS version: $version"

if (-not $SkipBuild) {
    Write-Host "Building Windows release..."
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }
}

$exe = Join-Path $releaseDir "mpos.exe"
if (-not (Test-Path $exe)) {
    throw "Release binary not found at $exe. Run without -SkipBuild first."
}

if (-not $SkipSign) {
    Write-Host "Creating/using self-signed code-signing certificate (Argit MPOS)..."
    $certSubject = "CN=Argit MPOS Code Signing"
    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -eq $certSubject -and $_.NotAfter -gt (Get-Date) } |
        Select-Object -First 1

    if (-not $cert) {
        $cert = New-SelfSignedCertificate `
            -Type CodeSigningCert `
            -Subject $certSubject `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -KeyExportPolicy Exportable `
            -KeySpec Signature `
            -NotAfter (Get-Date).AddYears(2)
        Write-Host "Created new self-signed cert: $($cert.Thumbprint)"
    } else {
        Write-Host "Using existing cert: $($cert.Thumbprint)"
    }

    $filesToSign = Get-ChildItem $releaseDir -Include *.exe,*.dll -Recurse -File
    foreach ($file in $filesToSign) {
        $result = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $cert -HashAlgorithm SHA256
        Write-Host ("  {0}: status={1}" -f $file.Name, $result.Status)
    }

    try {
        $pub = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPublisher", "CurrentUser")
        $pub.Open("ReadWrite")
        $pub.Add($cert)
        $pub.Close()
    } catch {
        Write-Warning "Could not add cert to TrustedPublisher: $_"
    }

    $certExport = Join-Path $OutDir "Argit-MPOS-CodeSigning.cer"
    Export-Certificate -Cert $cert -FilePath $certExport -Force | Out-Null
    Write-Host "Exported public cert: $certExport"
}

$iscc = Find-Iscc
if (-not $iscc) {
    Write-Host ""
    Write-Host "Inno Setup 6 not found. Install it, then re-run this script:"
    Write-Host "  winget install --id JRSoftware.InnoSetup -e"
    Write-Host "Or download: https://jrsoftware.org/isdl.php"
    Write-Host ""
    $hint = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"
    Write-Host "After install, compile manually:"
    Write-Host ("  & '{0}' /DMyAppVersion={1} '{2}'" -f $hint, $version, $issPath)
    throw "ISCC.exe not found"
}

if (-not (Test-Path $issPath)) {
    throw "Inno script not found: $issPath"
}

Write-Host "Compiling installer with: $iscc"
& $iscc "/DMyAppVersion=$version" $issPath
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compile failed" }

$setup = Join-Path $OutDir "MPOS-Setup-$version.exe"
if (-not (Test-Path $setup)) {
    throw "Expected installer not found: $setup"
}

if (-not $SkipSign) {
    $certSubject = "CN=Argit MPOS Code Signing"
    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -eq $certSubject -and $_.NotAfter -gt (Get-Date) } |
        Select-Object -First 1
    if ($cert) {
        $result = Set-AuthenticodeSignature -FilePath $setup -Certificate $cert -HashAlgorithm SHA256
        Write-Host ("Signed installer: status={0}" -f $result.Status)
    }
}

Write-Host ""
Write-Host "Done: $setup"
Write-Host "Install on target PCs by running this Setup exe (admin recommended)."
