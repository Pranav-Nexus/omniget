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
        string script = "Write-Host 'Starting process...' -ForegroundColor Cyan; ping -n 3 127.0.0.1 | Out-Host; Write-Host 'Done!'";
        string base64 = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(script));
        
        // Output building logic
        p.StandardInput.WriteLine("$scriptBase64 = '" + base64 + "'");
        p.StandardInput.WriteLine("$decodedScript = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($scriptBase64))");
        p.StandardInput.WriteLine("Invoke-Command -ScriptBlock ([scriptblock]::Create($decodedScript))");
        p.StandardInput.Close();
        p.WaitForExit();
        return p.ExitCode;
    }
}
