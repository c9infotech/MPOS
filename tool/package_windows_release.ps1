# Builds, optionally self-signs, and zips the Windows release for sharing.
# Self-signed cert reduces SmartScreen friction on PCs that trust the cert.
# It does NOT fully clear Chrome "Virus detected" — that needs a paid OV/EV cert.

param(
    [switch]$SkipBuild,
    [switch]$SkipSign,
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$releaseDir = Join-Path $root "build\windows\x64\runner\Release"
if (-not $OutDir) {
    $OutDir = Join-Path $root "dist"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (-not $SkipBuild) {
    Write-Host "Building Windows release..."
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }
}

if (-not (Test-Path (Join-Path $releaseDir "mpos.exe"))) {
    throw "Release binary not found at $releaseDir\mpos.exe"
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
        # Timestamp optional; self-signed often fails timestamp chain checks.
        $result = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $cert -HashAlgorithm SHA256
        $signed = $null -ne $result.SignerCertificate
        Write-Host ("  {0}: signed={1} status={2}" -f $file.Name, $signed, $result.Status)
    }

    # Best-effort: trust on this machine so local Status becomes Valid.
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
    Write-Host "Exported public cert for internal trust install: $certExport"
    Write-Host "Note: self-signed Signature Status may show UnknownError until the .cer is trusted."
}

$readme = @"
MPOS Windows Release (Argit)
============================

Install
-------
1. Extract this entire folder (keep all files next to mpos.exe).
2. Run mpos.exe.

If Windows SmartScreen / "Unknown publisher" appears
----------------------------------------------------
1. Click More info -> Run anyway (only if you received this from Argit).
2. Or (internal PCs): install Argit-MPOS-CodeSigning.cer into
   Trusted Root Certification Authorities / Trusted Publishers,
   then re-open mpos.exe.

If Chrome says "Virus detected" on download
-------------------------------------------
This is a common false positive for unsigned/self-signed desktop apps.
Prefer sharing via Google Drive / OneDrive company link, or ask IT to
allowlist the file. A commercial code-signing certificate (OV/EV) is
required to clear browser Safe Browsing fully.
"@

$stage = Join-Path $OutDir "mpos-windows-stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -Path (Join-Path $releaseDir "*") -Destination $stage -Recurse -Force
Set-Content -Path (Join-Path $stage "README.txt") -Value $readme -Encoding UTF8
if ((-not $SkipSign) -and (Test-Path (Join-Path $OutDir "Argit-MPOS-CodeSigning.cer"))) {
    Copy-Item (Join-Path $OutDir "Argit-MPOS-CodeSigning.cer") -Destination $stage -Force
}

$zipPath = Join-Path $OutDir "mpos-windows.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -Force
Remove-Item $stage -Recurse -Force

Write-Host ""
Write-Host "Done: $zipPath"
Write-Host "Share via Drive/OneDrive when possible (less Chrome false positives than direct zip links)."
