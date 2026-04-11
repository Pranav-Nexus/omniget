using System;
using System.Diagnostics;
class Program {
    static void Main(string[] args) {
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
        p.StandardInput.WriteLine("$argsParams = @(" + argList + ")");
        p.StandardInput.WriteLine("Invoke-Command -ScriptBlock { Write-Host 'Args:' $args } -ArgumentList $argsParams");
        p.StandardInput.Close();
        p.WaitForExit();
    }
}
