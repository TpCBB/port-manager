$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'VERSION must contain X.Y.Z.' }
& (Join-Path $PSScriptRoot 'build-windows.ps1') -Test
$outputDirectory = Join-Path $root 'dist\windows'
$releaseName = "PortManager-$version-win-x64"
$releaseExecutable = Join-Path $outputDirectory "$releaseName.exe"
$archive = Join-Path $outputDirectory "$releaseName.zip"
$stagingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("port-manager-package-" + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $stagingDirectory | Out-Null
    Copy-Item -LiteralPath (Join-Path $outputDirectory 'PortManager.exe') -Destination $releaseExecutable
    Copy-Item -LiteralPath $releaseExecutable -Destination (Join-Path $stagingDirectory 'PortManager.exe')
    Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination $stagingDirectory
    Copy-Item -LiteralPath (Join-Path $root 'Windows\README.md') -Destination (Join-Path $stagingDirectory 'README.md')
    Compress-Archive -Path (Join-Path $stagingDirectory '*') -DestinationPath $archive -Force
    foreach ($file in @($releaseExecutable, $archive)) {
        $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $([System.IO.Path]::GetFileName($file))" | Set-Content -LiteralPath "$file.sha256" -Encoding ASCII
    }
    Write-Host "Packaged $releaseExecutable and $archive"
} finally {
    Remove-Item -LiteralPath $stagingDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
