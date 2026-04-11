$ps1Path = Join-Path $PSScriptRoot "OmniGet.ps1"
if (-not (Test-Path $ps1Path)) {
    Write-Error "Could not find OmniGet.ps1"
    exit 1
}

# --- STAGE 1: Build omniget.exe ---
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
Write-Host "Compiling omniget.exe..." -ForegroundColor Cyan
& $cscPath /nologo /target:exe /out:omniget.exe $csPath
if ($LASTEXITCODE -ne 0) { Write-Error "Failed building omniget.exe"; exit 1 }
Remove-Item $csPath -ErrorAction SilentlyContinue


# --- STAGE 2: Build Uninstaller ---
$uninstCsCode = @"
using System;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using Microsoft.Win32;
using System.Runtime.InteropServices;

namespace OmniGetUninstaller {
    public class Program {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr windowHandle, uint Msg, IntPtr wParam, string lParam, uint flags, uint timeout, out IntPtr result);
        
        [STAThread]
        public static void Main() {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            
            DialogResult result = MessageBox.Show(
                "Are you sure you want to completely remove OmniGet and all of its components?",
                "OmniGet Uninstall",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning
            );
            
            if (result == DialogResult.Yes) {
                try {
                    Uninstall();
                    MessageBox.Show("OmniGet was successfully removed from your computer.", "Uninstall Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
                } catch (Exception ex) {
                    MessageBox.Show("Uninstallation encountered an error:\n" + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }

        static void Uninstall() {
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string installDir = Path.Combine(localAppData, "OmniGet");
            
            using (var key = Registry.CurrentUser.OpenSubKey(@"Environment", true)) {
                if (key != null) {
                    string path = key.GetValue("PATH") as string;
                    if (path != null && path.IndexOf(installDir, StringComparison.OrdinalIgnoreCase) >= 0) {
                        string[] parts = path.Split(new char[]{';'}, StringSplitOptions.RemoveEmptyEntries);
                        string newPath = string.Join(";", parts.Where(p => !p.Equals(installDir, StringComparison.OrdinalIgnoreCase)));
                        key.SetValue("PATH", newPath, RegistryValueKind.ExpandString);
                    }
                }
            }
            IntPtr res;
            SendMessageTimeout(new IntPtr(0xffff), 0x001A, IntPtr.Zero, "Environment", 2, 5000, out res);

            string exe = "omniget.exe";
            string fullExe = Path.Combine(installDir, exe);
            if (File.Exists(fullExe)) File.Delete(fullExe);
            
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo() {
                Arguments = "/C choice /C Y /N /D Y /T 3 & Rmdir /S /Q \"" + installDir + "\"",
                WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden, CreateNoWindow = true, FileName = "cmd.exe"
            });
        }
    }
}
"@
$uninstCsPath = Join-Path $PSScriptRoot "uninst.cs"
Set-Content -Path $uninstCsPath -Value $uninstCsCode -Encoding UTF8

Write-Host "Compiling OmniGetUninstall.exe..." -ForegroundColor Cyan
& $cscPath /nologo /target:winexe /out:OmniGetUninstall.exe /reference:System.Windows.Forms.dll /reference:System.Drawing.dll $uninstCsPath
if ($LASTEXITCODE -ne 0) { Write-Error "Failed building OmniGetUninstall.exe"; exit 1 }
Remove-Item $uninstCsPath -ErrorAction SilentlyContinue


# --- STAGE 3: Build Installer GUI ---
Write-Host "Bundling into OmniGetSetup.exe..." -ForegroundColor Cyan
$exeContent = Get-Content -Path "omniget.exe" -Encoding Byte -Raw
$base64Exe = [Convert]::ToBase64String($exeContent)
$uninstContent = Get-Content -Path "OmniGetUninstall.exe" -Encoding Byte -Raw
$base64Uninst = [Convert]::ToBase64String($uninstContent)

$setupCsCode = @"
using System;
using System.IO;
using System.Windows.Forms;
using System.Drawing;
using Microsoft.Win32;
using System.Runtime.InteropServices;

namespace OmniGetInstaller {
    public class SetupWizard : Form {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr windowHandle, uint Msg, IntPtr wParam, string lParam, uint flags, uint timeout, out IntPtr result);

        private Panel panelWelcome, panelInfo, panelInstall;
        private Button btnNext, btnBack, btnCancel;
        private int currentStep = 0;

        public SetupWizard() {
            this.Text = "OmniGet Setup";
            this.Size = new Size(500, 360);
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.StartPosition = FormStartPosition.CenterScreen;

            btnCancel = new Button() { Text = "Cancel", Location = new Point(400, 290), Size = new Size(75, 25) };
            btnNext = new Button() { Text = "Next >", Location = new Point(315, 290), Size = new Size(75, 25) };
            btnBack = new Button() { Text = "< Back", Location = new Point(230, 290), Size = new Size(75, 25), Enabled = false };
            
            btnCancel.Click += (s, e) => { this.Close(); };
            btnNext.Click += BtnNext_Click;
            btnBack.Click += BtnBack_Click;

            this.Controls.Add(btnCancel);
            this.Controls.Add(btnNext);
            this.Controls.Add(btnBack);

            Label sep = new Label() { BorderStyle = BorderStyle.Fixed3D, AutoSize = false, Location = new Point(0, 275), Size = new Size(500, 2) };
            this.Controls.Add(sep);

            panelWelcome = new Panel() { Size = new Size(480, 270), Location = new Point(10, 5) };
            panelWelcome.Controls.Add(new Label() { Text = "Welcome to the OmniGet Setup Wizard", Font = new Font("Segoe UI", 14, FontStyle.Bold), Location = new Point(20, 20), Size = new Size(450, 40) });
            panelWelcome.Controls.Add(new Label() { Text = "This wizard will gracefully install OmniGet on your computer natively.\n\nClick Next to continue, or Cancel to exit Setup.", Font = new Font("Segoe UI", 10), Location = new Point(20, 70), Size = new Size(450, 60) });
            
            panelInfo = new Panel() { Size = new Size(480, 270), Location = new Point(10, 5), Visible = false };
            panelInfo.Controls.Add(new Label() { Text = "What is OmniGet?", Font = new Font("Segoe UI", 12, FontStyle.Bold), Location = new Point(20, 20), Size = new Size(450, 30) });
            panelInfo.Controls.Add(new Label() { Text = "OmniGet is a universal command-line package manager wrapper for Windows.\n\nIt seamlessly combines the power of WinGet, Chocolatey, and Scoop into a single, elegant `omniget` command.\n\nFeatures:\n- Install packages seamlessly across all ecosystems\n- Intelligent conflict detection avoiding duplicate installations\n- WSL native interactive fallback natively generated", Font = new Font("Segoe UI", 10), Location = new Point(20, 60), Size = new Size(450, 150) });

            panelInstall = new Panel() { Size = new Size(480, 270), Location = new Point(10, 5), Visible = false };
            panelInstall.Controls.Add(new Label() { Text = "Ready to Install", Font = new Font("Segoe UI", 12, FontStyle.Bold), Location = new Point(20, 20), Size = new Size(450, 30) });
            panelInstall.Controls.Add(new Label() { Text = "OmniGet will be installed to your local application data and automatically added to your System PATH natively, skipping the need for manual setup!\n\nClick Install to continue.", Font = new Font("Segoe UI", 10), Location = new Point(20, 60), Size = new Size(450, 80) });

            this.Controls.Add(panelWelcome);
            this.Controls.Add(panelInfo);
            this.Controls.Add(panelInstall);
        }

        private void BtnNext_Click(object sender, EventArgs e) {
            if (currentStep == 0) {
                currentStep = 1;
                panelWelcome.Visible = false;
                panelInfo.Visible = true;
                btnBack.Enabled = true;
            } else if (currentStep == 1) {
                currentStep = 2;
                panelInfo.Visible = false;
                panelInstall.Visible = true;
                btnNext.Text = "Install";
            } else if (currentStep == 2) {
                btnNext.Enabled = false;
                btnBack.Enabled = false;
                PerformInstall();
            } else if (currentStep == 3) {
                this.Close();
            }
        }

        private void BtnBack_Click(object sender, EventArgs e) {
            if (currentStep == 1) {
                currentStep = 0;
                panelInfo.Visible = false;
                panelWelcome.Visible = true;
                btnBack.Enabled = false;
            } else if (currentStep == 2) {
                currentStep = 1;
                panelInstall.Visible = false;
                panelInfo.Visible = true;
                btnNext.Text = "Next >";
            }
        }

        private void PerformInstall() {
            try {
                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string installDir = Path.Combine(localAppData, "OmniGet");
                if (!Directory.Exists(installDir)) Directory.CreateDirectory(installDir);

                string b64Exe = "$base64Exe";
                File.WriteAllBytes(Path.Combine(installDir, "omniget.exe"), Convert.FromBase64String(b64Exe));
                
                string b64Uninst = "$base64Uninst";
                File.WriteAllBytes(Path.Combine(installDir, "OmniGetUninstall.exe"), Convert.FromBase64String(b64Uninst));

                using (var key = Registry.CurrentUser.OpenSubKey(@"Environment", true)) {
                    if (key != null) {
                        string path = key.GetValue("PATH") as string ?? "";
                        if (!path.Contains(installDir)) {
                            if (!path.EndsWith(";") && path.Length > 0) path += ";";
                            path += installDir;
                            key.SetValue("PATH", path, RegistryValueKind.ExpandString);
                        }
                    }
                }

                IntPtr res;
                SendMessageTimeout(new IntPtr(0xffff), 0x001A, IntPtr.Zero, "Environment", 2, 5000, out res);

                panelInstall.Controls.Clear();
                panelInstall.Controls.Add(new Label() { Text = "Installation Complete!", Font = new Font("Segoe UI", 14, FontStyle.Bold), Location = new Point(20, 20), Size = new Size(450, 40) });
                panelInstall.Controls.Add(new Label() { Text = "OmniGet was successfully installed on your computer.\n\nIMPORTANT: Please restart any open PowerShell or Command Prompt windows for the new `omniget` command to be fully recognized by the console.", Font = new Font("Segoe UI", 10), Location = new Point(20, 70), Size = new Size(450, 80) });
                currentStep = 3;
                btnNext.Text = "Finish";
                btnNext.Enabled = true;
                btnCancel.Enabled = false;

            } catch (Exception ex) {
                MessageBox.Show("Installation failed:\n" + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                btnNext.Enabled = true;
                btnBack.Enabled = true;
            }
        }

        [STAThread]
        public static void Main() {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SetupWizard());
        }
    }
}
"@
$setupCsPath = Join-Path $PSScriptRoot "setup.cs"
Set-Content -Path $setupCsPath -Value $setupCsCode -Encoding UTF8

& $cscPath /nologo /target:winexe /out:OmniGetSetup.exe /reference:System.Windows.Forms.dll /reference:System.Drawing.dll $setupCsPath
if ($LASTEXITCODE -eq 0) {
    Write-Host "Success! OmniGetSetup.exe generated." -ForegroundColor Green
    Remove-Item $setupCsPath -ErrorAction SilentlyContinue
} else {
    Write-Error "Setup compilation failed."
    exit 1
}

Remove-Item "OmniGetUninstall.exe" -ErrorAction SilentlyContinue
exit 0
