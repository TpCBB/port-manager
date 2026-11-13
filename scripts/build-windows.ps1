param(
    [switch]$Test
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $root 'dist\windows'
$source = Join-Path $root 'Windows\PortManager.cs'
$icon = Join-Path $root 'Windows\app.ico'
$executable = Join-Path $outputDirectory 'PortManager.exe'
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'VERSION must contain X.Y.Z.' }
$versionSource = Join-Path $outputDirectory 'VersionInfo.cs'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    throw '.NET Framework 4.x C# compiler was not found. Build on 64-bit Windows with .NET Framework installed.'
}
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
@"
using System.Reflection;
[assembly: AssemblyTitle("Port Manager")]
[assembly: AssemblyProduct("Port Manager")]
[assembly: AssemblyVersion("$version.0")]
[assembly: AssemblyFileVersion("$version.0")]
[assembly: AssemblyInformationalVersion("$version")]
"@ | Set-Content -LiteralPath $versionSource -Encoding UTF8
& $compiler /nologo /target:winexe /platform:x64 /optimize+ "/win32icon:$icon" "/out:$executable" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Management.dll $source $versionSource
if ($LASTEXITCODE -ne 0) { throw "Windows build failed with exit code $LASTEXITCODE" }
if ((Get-Item -LiteralPath $executable).VersionInfo.FileVersion -ne "$version.0") {
    throw 'The executable version does not match VERSION.'
}
Write-Host "Built $executable"
if ($Test) {
    $report = Join-Path ([System.IO.Path]::GetTempPath()) ("port-manager-test-" + [Guid]::NewGuid().ToString('N') + '.txt')
    try {
        $process = Start-Process -FilePath $executable -ArgumentList @('--self-test', ('"' + $report + '"')) -PassThru -Wait
        if (Test-Path -LiteralPath $report) { Get-Content -LiteralPath $report -Encoding UTF8 }
        if ($process.ExitCode -ne 0) { throw "Windows self-test failed with exit code $($process.ExitCode)" }
        if (-not (Test-Path -LiteralPath $report)) { throw 'Windows self-test did not produce a report.' }
    } finally {
        Remove-Item -LiteralPath $report -Force -ErrorAction SilentlyContinue
    }
}
