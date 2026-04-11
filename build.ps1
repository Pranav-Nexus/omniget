$ps1Path = Join-Path $PSScriptRoot "OmniGet.ps1"
if (-not (Test-Path $ps1Path)) {
    Write-Error "Could not find OmniGet.ps1"
    exit 1
}

$ps1Content = Get-Content -Path $ps1Path -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($ps1Content)
$base64 = [Convert]::ToBase64String($bytes)

$csCode = @"
using System;
using System.Diagnostics;

class Program {
    static int Main(string[] args) {
        var psi = new ProcessStartInfo {
            FileName = "powershell.exe",
            Arguments = "-NoProfile -ExecutionPolicy Bypass -Command -",
            UseShellExecute = false,
            RedirectStandardInput = true
        };
        var p = Process.Start(psi);
        string argList = "";
        foreach (var arg in args) {
            argList += "'" + arg.Replace("'", "''") + "',";
        }
        argList = argList.TrimEnd(',');
        
        // Using literal string format for large base64 literal correctly
        string base64Script = "$base64";
        
        p.StandardInput.WriteLine("`$argsParams = @(" + argList + ")");
        p.StandardInput.WriteLine("`$scriptBase64 = '" + base64Script + "'");
        p.StandardInput.WriteLine("`$decodedScript = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$scriptBase64))");
        p.StandardInput.WriteLine("Invoke-Command -ScriptBlock ([scriptblock]::Create(`$decodedScript)) -ArgumentList `$argsParams");
        
        p.StandardInput.Close();
        p.WaitForExit();
        return p.ExitCode;
    }
}
"@

$csPath = Join-Path $PSScriptRoot "wrapper.cs"
Set-Content -Path $csPath -Value $csCode -Encoding UTF8

$cscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $cscPath)) {
    Write-Error "csc.exe not found at `$cscPath"
    exit 1
}

Write-Host "Compiling omniget.exe..." -ForegroundColor Cyan
& $cscPath /nologo /target:exe /out:omniget.exe $csPath
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "Success! omniget.exe generated." -ForegroundColor Green
    Remove-Item $csPath -ErrorAction SilentlyContinue
} else {
    Write-Error "Compilation failed."
}
exit $exitCode
