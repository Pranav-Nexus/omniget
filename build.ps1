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
    
    Write-Host "Bundling into OmniGetSetup.exe..." -ForegroundColor Cyan
    $exeContent = Get-Content -Path "omniget.exe" -Encoding Byte -Raw
    $base64Exe = [Convert]::ToBase64String($exeContent)
    
    $setupCsCode = @"
using System;
using System.IO;
using System.Windows.Forms;
using Microsoft.Win32;

namespace OmniGetInstaller {
    public class Program {
        [STAThread]
        public static void Main() {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            
            DialogResult result = MessageBox.Show(
                "Do you want to install OmniGet to your system?",
                "OmniGet Setup",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question
            );
            
            if (result == DialogResult.Yes) {
                try {
                    Install();
                    MessageBox.Show(
                        "OmniGet installed successfully!\n\nPlease restart your terminal to use the 'omniget' command.",
                        "Success",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information
                    );
                } catch (Exception ex) {
                    MessageBox.Show("Installation failed:\n" + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }
        
        static void Install() {
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string installDir = Path.Combine(localAppData, "OmniGet");
            if (!Directory.Exists(installDir)) {
                Directory.CreateDirectory(installDir);
            }
            
            string exePath = Path.Combine(installDir, "omniget.exe");
            string b64 = "$base64Exe";
            byte[] exeBytes = Convert.FromBase64String(b64);
            File.WriteAllBytes(exePath, exeBytes);
            
            // Add to User PATH
            using (var key = Registry.CurrentUser.OpenSubKey(@"Environment", true)) {
                if (key != null) {
                    string path = key.GetValue("PATH") as string;
                    if (path == null) path = "";
                    
                    if (!path.Contains(installDir)) {
                        if (!path.EndsWith(";") && path.Length > 0) path += ";";
                        path += installDir;
                        key.SetValue("PATH", path, RegistryValueKind.ExpandString);
                    }
                }
            }
        }
    }
}
"@
    $setupCsPath = Join-Path $PSScriptRoot "setup.cs"
    Set-Content -Path $setupCsPath -Value $setupCsCode -Encoding UTF8
    
    & $cscPath /nologo /target:winexe /out:OmniGetSetup.exe /reference:System.Windows.Forms.dll /reference:System.Drawing.dll $setupCsPath
    $exitCodeSetup = $LASTEXITCODE
    if ($exitCodeSetup -eq 0) {
        Write-Host "Success! OmniGetSetup.exe generated." -ForegroundColor Green
        Remove-Item $setupCsPath -ErrorAction SilentlyContinue
    } else {
        Write-Error "Setup compilation failed."
        exit $exitCodeSetup
    }
} else {
    Write-Error "Compilation failed."
}
exit $exitCode
