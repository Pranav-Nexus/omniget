$ps1Path = Join-Path $PSScriptRoot "OmniGet.ps1"
if (-not (Test-Path $ps1Path)) {
    Write-Error "Could not find OmniGet.ps1"
    exit 1
}

$cscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $cscPath)) {
    Write-Error "csc.exe not found at `$cscPath"
    exit 1
}

# Cleanup old legacy executable files if present
$legacyFiles = @("OmniGetSetup.exe", "OmniGetSetup-x86.exe", "OmniGetUninstall.exe", "omniget.exe", "OmniGetUI.exe")
foreach ($legacy in $legacyFiles) {
    $p = Join-Path $PSScriptRoot $legacy
    if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
}

# --- STAGE 1: Build OmniGetCLI.exe ---
$manifestContent = @"
<?xml version="1.0" encoding="utf-8"?>
<assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1">
  <assemblyIdentity version="1.0.0.0" name="OmniGetCLI"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
        <requestedExecutionLevel level="asInvoker" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
"@
$manifestPath = Join-Path $PSScriptRoot "app.manifest"
Set-Content -Path $manifestPath -Value $manifestContent -Encoding UTF8

$ps1Content = Get-Content -Path $ps1Path -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($ps1Content)
$base64Script = [Convert]::ToBase64String($bytes)

$cliCsCode = @"
using System;
using System.Diagnostics;

namespace OmniGetCLI {
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
            string base64Script = "$base64Script";
            p.StandardInput.WriteLine("`$argsParams = @(" + argList + ")");
            p.StandardInput.WriteLine("`$scriptBase64 = '" + base64Script + "'");
            p.StandardInput.WriteLine("`$decodedScript = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$scriptBase64))");
            p.StandardInput.WriteLine("Invoke-Command -ScriptBlock ([scriptblock]::Create(`$decodedScript)) -ArgumentList `$argsParams");
            p.StandardInput.Close();
            p.WaitForExit();
            return p.ExitCode;
        }
    }
}
"@
$cliCsPath = Join-Path $PSScriptRoot "clicompile.cs"
Set-Content -Path $cliCsPath -Value $cliCsCode -Encoding UTF8

Write-Host "Compiling OmniGetCLI.exe..." -ForegroundColor Cyan
& $cscPath /nologo /target:exe /win32manifest:$manifestPath /out:OmniGetCLI.exe $cliCsPath
if ($LASTEXITCODE -ne 0) { Write-Error "Failed building OmniGetCLI.exe"; Remove-Item $manifestPath -ErrorAction SilentlyContinue; exit 1 }
Remove-Item $cliCsPath -ErrorAction SilentlyContinue


# --- STAGE 2: Package UI Payload Zip ---
Write-Host "Packaging UI payload zip..." -ForegroundColor Cyan
$uiZipTemp = Join-Path $env:TEMP "omniget_ui_payload.zip"
if (Test-Path $uiZipTemp) { Remove-Item $uiZipTemp -Force }

$uiDist = Join-Path $PSScriptRoot "ui\dist"
$uiServer = Join-Path $PSScriptRoot "ui\server.cjs"
$uiBridge = Join-Path $PSScriptRoot "ui\bridge.ps1"
$uiMcp = Join-Path $PSScriptRoot "ui\mcp-server.cjs"

Compress-Archive -Path $uiDist, $uiServer, $uiBridge, $uiMcp -DestinationPath $uiZipTemp -Force
$uiPayloadBytes = [System.IO.File]::ReadAllBytes($uiZipTemp)
$base64UIPayload = [Convert]::ToBase64String($uiPayloadBytes)
Remove-Item $uiZipTemp -Force

$cliBytes = [System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot "OmniGetCLI.exe"))
$base64CLI = [Convert]::ToBase64String($cliBytes)


# --- STAGE 3: Build OmniGet.exe (Main App & Universal Setup) ---
Write-Host "Compiling OmniGet.exe (Main GUI App & Setup)..." -ForegroundColor Cyan
$guiCsCode = @"
using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
using System.Windows.Forms;
using System.Drawing;
using Microsoft.Win32;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Threading;

namespace OmniGet {
    public class Program {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr windowHandle, uint Msg, IntPtr wParam, string lParam, uint flags, uint timeout, out IntPtr result);

        [STAThread]
        public static void Main(string[] args) {
            bool runSetup = false;
            bool runUninstall = false;

            foreach (var a in args) {
                if (a.Equals("/install", StringComparison.OrdinalIgnoreCase) || a.Equals("--install", StringComparison.OrdinalIgnoreCase)) {
                    runSetup = true;
                } else if (a.Equals("/uninstall", StringComparison.OrdinalIgnoreCase) || a.Equals("--uninstall", StringComparison.OrdinalIgnoreCase)) {
                    runUninstall = true;
                }
            }

            if (runUninstall) {
                Uninstall();
                return;
            }

            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string installDir = Path.Combine(localAppData, "OmniGet");
            string serverPath = Path.Combine(installDir, "ui", "server.cjs");

            if (runSetup || !File.Exists(serverPath)) {
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new SetupWizard());
            } else {
                LaunchGUI(installDir, serverPath);
            }
        }

        public static void LaunchGUI(string installDir, string serverPath) {
            var psi = new ProcessStartInfo {
                FileName = "cmd.exe",
                Arguments = "/c node \"" + serverPath + "\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = Path.GetDirectoryName(serverPath)
            };
            try {
                Process.Start(psi);
                Thread.Sleep(800);
                Process.Start(new ProcessStartInfo("http://localhost:3001") { UseShellExecute = true });
            } catch (Exception ex) {
                MessageBox.Show("Unable to launch OmniGet UI: " + ex.Message + "\n\nPlease ensure Node.js is installed.", "OmniGet Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        static void Uninstall() {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            
            DialogResult result = MessageBox.Show(
                "Are you sure you want to completely uninstall OmniGet and all of its components?",
                "OmniGet Uninstall",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning
            );
            
            if (result == DialogResult.Yes) {
                try {
                    string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                    string installDir = Path.Combine(localAppData, "OmniGet");
                    
                    using (var key = Registry.CurrentUser.OpenSubKey(@"Environment", true)) {
                        if (key != null) {
                            string path = key.GetValue("PATH") as string ?? "";
                            if (path.Contains(installDir)) {
                                var parts = System.Linq.Enumerable.Where(path.Split(';'), p => !p.Equals(installDir, StringComparison.OrdinalIgnoreCase) && !string.IsNullOrEmpty(p));
                                string newPath = string.Join(";", parts);
                                key.SetValue("PATH", newPath, RegistryValueKind.ExpandString);
                            }
                        }
                    }
                    
                    IntPtr res;
                    SendMessageTimeout(new IntPtr(0xffff), 0x001A, IntPtr.Zero, "Environment", 2, 5000, out res);

                    string startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "OmniGet");
                    if (Directory.Exists(startMenuDir)) Directory.Delete(startMenuDir, true);

                    string desktopShortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "OmniGet.lnk");
                    if (File.Exists(desktopShortcut)) File.Delete(desktopShortcut);

                    if (Directory.Exists(installDir)) {
                        var batPath = Path.Combine(Path.GetTempPath(), "omniget_cleanup.bat");
                        string batContent = "@echo off\r\ntimeout /t 1 /nobreak > NUL\r\nrmdir /s /q \"" + installDir + "\"\r\ndel \"%~f0\"";
                        File.WriteAllText(batPath, batContent);
                        var psi = new ProcessStartInfo {
                            FileName = batPath,
                            CreateNoWindow = true,
                            UseShellExecute = false
                        };
                        Process.Start(psi);
                    }
                    MessageBox.Show("OmniGet was successfully removed from your computer.", "Uninstall Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
                } catch (Exception ex) {
                    MessageBox.Show("Uninstallation encountered an error:\n" + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }
    }

    public class SetupWizard : Form {
        private Panel panelWelcome, panelInfo, panelBoot, panelPriority, panelInstall;
        private ListBox lbPriority;
        private Button btnNext, btnBack, btnCancel;
        private CheckBox chkUserScope, chkChocoBoot, chkScoopBoot;
        private bool showBootPage = false;
        private List<Panel> steps = new List<Panel>();
        private int currentStep = 0;

        private static bool CommandExists(string command) {
            string pathEnv = Environment.GetEnvironmentVariable("PATH");
            if (string.IsNullOrEmpty(pathEnv)) return false;
            foreach (var dir in pathEnv.Split(';')) {
                try {
                    string fullPath = Path.Combine(dir.Trim(), command + ".exe");
                    if (File.Exists(fullPath)) return true;
                } catch { }
            }
            return false;
        }

        private static void RunPowerShellScript(string script) {
            var psi = new ProcessStartInfo {
                FileName = "powershell.exe",
                Arguments = "-NoProfile -ExecutionPolicy Bypass -Command \"" + script.Replace("\"", "\\\"") + "\"",
                UseShellExecute = false,
                CreateNoWindow = true
            };
            try {
                var p = Process.Start(psi);
                p.WaitForExit();
            } catch { }
        }

        public SetupWizard() {
            this.Text = "OmniGet Installer & Setup";
            this.Size = new Size(520, 380);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;

            btnBack = new Button() { Text = "< Back", Location = new Point(230, 300), Size = new Size(80, 28), Enabled = false };
            btnNext = new Button() { Text = "Next >", Location = new Point(320, 300), Size = new Size(80, 28) };
            btnCancel = new Button() { Text = "Cancel", Location = new Point(410, 300), Size = new Size(80, 28) };

            btnBack.Click += (s, e) => {
                if (currentStep > 0) {
                    steps[currentStep].Visible = false;
                    currentStep--;
                    steps[currentStep].Visible = true;
                    btnNext.Text = "Next >";
                    if (currentStep == 0) btnBack.Enabled = false;
                }
            };
            btnNext.Click += BtnNext_Click;
            btnCancel.Click += (s, e) => this.Close();

            this.Controls.Add(btnBack);
            this.Controls.Add(btnNext);
            this.Controls.Add(btnCancel);

            InitializeSteps();
        }

        private void InitializeSteps() {
            panelWelcome = new Panel() { Size = new Size(480, 270), Location = new Point(10, 5), Visible = true };
            panelWelcome.Controls.Add(new Label() { Text = "Welcome to OmniGet Setup", Font = new Font("Segoe UI", 14, FontStyle.Bold), AutoSize = false, Location = new Point(20, 20), Size = new Size(450, 40) });
            panelWelcome.Controls.Add(new Label() { Text = "This wizard will install OmniGet CLI (`OmniGetCLI.exe`) & OmniGet Desktop Store (`OmniGet.exe`) on your computer.\n\nOmniGet unifies WinGet, Chocolatey, and Scoop into a single, lightning-fast package manager and hardware telemetry hub.", Font = new Font("Segoe UI", 10), Location = new Point(20, 70), Size = new Size(450, 160) });

            panelInfo = new Panel() { Size = new Size(480, 270), Location = new Point(10, 5), Visible = false };
            panelInfo.Controls.Add(new Label() { Text = "Component Detection", Font = new Font("Segoe UI", 12, FontStyle.Bold), AutoSize = false, Location = new Point(20, 20), Size = new Size(450, 30) });

            bool hasWinget = CommandExists("winget");
            bool hasChoco = CommandExists("choco");
            bool hasScoop = CommandExists("scoop");

            string infoText = "OmniGet detected the following package managers on your system:\n\n";
            infoText += " • WinGet: " + (hasWinget ? "Found" : "Not Found") + "\n";
            infoText += " • Chocolatey: " + (hasChoco ? "Found" : "Not Found") + "\n";
            infoText += " • Scoop: " + (hasScoop ? "Found" : "Not Found") + "\n\n";

            if (!hasChoco || !hasScoop) {
                showBootPage = true;
                infoText += "Recommended missing package managers can be automatically bootstrapped during setup.";
            } else {
                infoText += "All primary package managers are available!";
            }

            panelInfo.Controls.Add(new Label() { Text = infoText, Font = new Font("Segoe UI", 9.5f), Location = new Point(20, 60), Size = new Size(450, 180) });

            if (showBootPage) {
                panelBoot = new Panel() { Size = new Size(480, 270), Location = new Point(10, 5), Visible = false };
                panelBoot.Controls.Add(new Label() { Text = "Automatic Bootstrap Options", Font = new Font("Segoe UI", 12, FontStyle.Bold), AutoSize = false, Location = new Point(20, 20), Size = new Size(450, 30) });
                panelBoot.Controls.Add(new Label() { Text = "Select missing package managers to automatically download and configure during installation:", Font = new Font("Segoe UI", 9.5f), Location = new Point(20, 55), Size = new Size(450, 40) });

                int topPos = 105;
                if (!hasScoop) {
                    chkScoopBoot = new CheckBox() { Text = "Bootstrap Scoop Package Manager (User Scope)", Checked = true, AutoSize = true, Location = new Point(25, topPos), Font = new Font("Segoe UI", 9.5f) };
                    panelBoot.Controls.Add(chkScoopBoot);
                    topPos += 35;
                }
                if (!hasChoco) {
                    chkChocoBoot = new CheckBox() { Text = "Bootstrap Chocolatey Package Manager (System Scope)", Checked = true, AutoSize = true, Location = new Point(25, topPos), Font = new Font("Segoe UI", 9.5f) };
                    panelBoot.Controls.Add(chkChocoBoot);
                }
            }

            panelPriority = new Panel() { Size = new Size(480, 270), Location = new Point(10, 5), Visible = false };
            panelPriority.Controls.Add(new Label() { Text = "Package Manager Priority Order", Font = new Font("Segoe UI", 12, FontStyle.Bold), AutoSize = false, Location = new Point(20, 10), Size = new Size(450, 30) });
            panelPriority.Controls.Add(new Label() { Text = "Arrange package managers in order of preference when searching and installing software:", Font = new Font("Segoe UI", 9), Location = new Point(20, 40), Size = new Size(450, 30) });

            lbPriority = new ListBox() { Location = new Point(20, 75), Size = new Size(260, 110), Font = new Font("Segoe UI", 10) };
            if (hasWinget) lbPriority.Items.Add("winget");
            if (hasChoco) lbPriority.Items.Add("choco");
            if (hasScoop) lbPriority.Items.Add("scoop");
            if (lbPriority.Items.Count == 0) lbPriority.Items.Add("winget");

            Button btnUp = new Button() { Text = "Move Up", Location = new Point(290, 75), Size = new Size(90, 30) };
            Button btnDown = new Button() { Text = "Move Down", Location = new Point(290, 115), Size = new Size(90, 30) };

            btnUp.Click += (s, e) => {
                int idx = lbPriority.SelectedIndex;
                if (idx > 0) {
                    var item = lbPriority.Items[idx];
                    lbPriority.Items.RemoveAt(idx);
                    lbPriority.Items.Insert(idx - 1, item);
                    lbPriority.SelectedIndex = idx - 1;
                }
            };
            btnDown.Click += (s, e) => {
                int idx = lbPriority.SelectedIndex;
                if (idx >= 0 && idx < lbPriority.Items.Count - 1) {
                    var item = lbPriority.Items[idx];
                    lbPriority.Items.RemoveAt(idx);
                    lbPriority.Items.Insert(idx + 1, item);
                    lbPriority.SelectedIndex = idx + 1;
                }
            };

            chkUserScope = new CheckBox() { Text = "Default to User-Scope installations where available", Checked = true, AutoSize = true, Location = new Point(20, 200), Font = new Font("Segoe UI", 9) };
            panelPriority.Controls.Add(lbPriority);
            panelPriority.Controls.Add(btnUp);
            panelPriority.Controls.Add(btnDown);
            panelPriority.Controls.Add(chkUserScope);

            panelInstall = new Panel() { Size = new Size(480, 270), Location = new Point(10, 5), Visible = false };
            panelInstall.Controls.Add(new Label() { Text = "Ready to Install", Font = new Font("Segoe UI", 12, FontStyle.Bold), AutoSize = false, Location = new Point(20, 20), Size = new Size(450, 30) });
            panelInstall.Controls.Add(new Label() { Text = "OmniGet (`OmniGet.exe` & `OmniGetCLI.exe`) will be installed to your local application data and automatically added to your System PATH and Start Menu!\n\nClick Install to continue.", Font = new Font("Segoe UI", 10), Location = new Point(20, 60), Size = new Size(450, 80) });

            this.Controls.Add(panelWelcome);
            this.Controls.Add(panelInfo);
            if (showBootPage) this.Controls.Add(panelBoot);
            this.Controls.Add(panelPriority);
            this.Controls.Add(panelInstall);

            steps.Add(panelWelcome);
            steps.Add(panelInfo);
            if (showBootPage) steps.Add(panelBoot);
            steps.Add(panelPriority);
            steps.Add(panelInstall);
        }

        private void BtnNext_Click(object sender, EventArgs e) {
            if (currentStep < steps.Count) {
                if (showBootPage && steps[currentStep] == panelBoot) {
                    if (chkScoopBoot != null && chkScoopBoot.Checked && !lbPriority.Items.Contains("scoop")) lbPriority.Items.Add("scoop");
                    if (chkChocoBoot != null && chkChocoBoot.Checked && !lbPriority.Items.Contains("choco")) lbPriority.Items.Add("choco");
                }
            }

            if (currentStep < steps.Count - 1) {
                steps[currentStep].Visible = false;
                currentStep++;
                steps[currentStep].Visible = true;
                btnBack.Enabled = true;
                if (currentStep == steps.Count - 1) {
                    btnNext.Text = "Install";
                }
            } else if (currentStep == steps.Count - 1) {
                btnNext.Enabled = false;
                btnBack.Enabled = false;
                PerformInstall();
            } else {
                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string installDir = Path.Combine(localAppData, "OmniGet");
                string serverPath = Path.Combine(installDir, "ui", "server.cjs");
                this.Hide();
                Program.LaunchGUI(installDir, serverPath);
                this.Close();
            }
        }

        private void PerformInstall() {
            try {
                this.Cursor = Cursors.WaitCursor;
                panelInstall.Controls.Clear();
                var lblStatus = new Label() { Text = "Installing OmniGet...", Font = new Font("Segoe UI", 12, FontStyle.Bold), AutoSize = false, Location = new Point(20, 20), Size = new Size(450, 40) };
                panelInstall.Controls.Add(lblStatus);
                panelInstall.Refresh();

                if (chkScoopBoot != null && chkScoopBoot.Checked) {
                    lblStatus.Text = "Bootstrapping Scoop Package Manager...";
                    panelInstall.Refresh();
                    RunPowerShellScript("Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression");
                }
                if (chkChocoBoot != null && chkChocoBoot.Checked) {
                    lblStatus.Text = "Bootstrapping Chocolatey Package Manager...";
                    panelInstall.Refresh();
                    RunPowerShellScript("Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))");
                }

                lblStatus.Text = "Writing OmniGet settings...";
                panelInstall.Refresh();

                string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                string configPath = Path.Combine(userProfile, ".omniget_config.json");
                string json = "{ \"Priority\": [";
                for(int i=0; i<lbPriority.Items.Count; i++) {
                    json += "\"" + lbPriority.Items[i].ToString() + "\"";
                    if (i < lbPriority.Items.Count - 1) json += ", ";
                }
                json += "], \"UserScopeInstall\": " + chkUserScope.Checked.ToString().ToLower() + " }";
                File.WriteAllText(configPath, json);

                lblStatus.Text = "Deploying OmniGet CLI & Desktop UI...";
                panelInstall.Refresh();

                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string installDir = Path.Combine(localAppData, "OmniGet");
                if (!Directory.Exists(installDir)) Directory.CreateDirectory(installDir);

                // Write OmniGet.exe copy
                string selfExe = Process.GetCurrentProcess().MainModule.FileName;
                File.Copy(selfExe, Path.Combine(installDir, "OmniGet.exe"), true);

                // Write OmniGetCLI.exe
                string b64CLI = "$base64CLI";
                File.WriteAllBytes(Path.Combine(installDir, "OmniGetCLI.exe"), Convert.FromBase64String(b64CLI));
                File.WriteAllBytes(Path.Combine(installDir, "omniget.exe"), Convert.FromBase64String(b64CLI));

                // Unpack UI Payload Zip
                string b64UIPayload = "$base64UIPayload";
                string uiZipPath = Path.Combine(installDir, "ui.zip");
                File.WriteAllBytes(uiZipPath, Convert.FromBase64String(b64UIPayload));

                string uiInstallDir = Path.Combine(installDir, "ui");
                if (Directory.Exists(uiInstallDir)) Directory.Delete(uiInstallDir, true);
                Directory.CreateDirectory(uiInstallDir);
                ZipFile.ExtractToDirectory(uiZipPath, uiInstallDir);
                File.Delete(uiZipPath);

                // Configure System PATH
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

                // Create Start Menu & Desktop Shortcuts
                string startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "OmniGet");
                if (!Directory.Exists(startMenuDir)) Directory.CreateDirectory(startMenuDir);

                string desktopShortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "OmniGet.lnk");
                string startMenuShortcut = Path.Combine(startMenuDir, "OmniGet.lnk");
                string guiExePath = Path.Combine(installDir, "OmniGet.exe");

                string vbsScript = "Set WshShell = CreateObject(\"WScript.Shell\")\r\n" +
                                   "Set shortcut = WshShell.CreateShortcut(\"" + desktopShortcut.Replace("\\", "\\\\") + "\")\r\n" +
                                   "shortcut.TargetPath = \"" + guiExePath.Replace("\\", "\\\\") + "\"\r\n" +
                                   "shortcut.WorkingDirectory = \"" + installDir.Replace("\\", "\\\\") + "\"\r\n" +
                                   "shortcut.Description = \"OmniGet Desktop UI & Telemetry Hub\"\r\n" +
                                   "shortcut.Save\r\n" +
                                   "Set shortcut2 = WshShell.CreateShortcut(\"" + startMenuShortcut.Replace("\\", "\\\\") + "\")\r\n" +
                                   "shortcut2.TargetPath = \"" + guiExePath.Replace("\\", "\\\\") + "\"\r\n" +
                                   "shortcut2.WorkingDirectory = \"" + installDir.Replace("\\", "\\\\") + "\"\r\n" +
                                   "shortcut2.Description = \"OmniGet Desktop UI & Telemetry Hub\"\r\n" +
                                   "shortcut2.Save";
                string vbsPath = Path.Combine(Path.GetTempPath(), "omniget_shortcut.vbs");
                File.WriteAllText(vbsPath, vbsScript);
                Process.Start("wscript.exe", "\"" + vbsPath + "\"").WaitForExit();
                File.Delete(vbsPath);

                IntPtr res;
                Program.SendMessageTimeout(new IntPtr(0xffff), 0x001A, IntPtr.Zero, "Environment", 2, 5000, out res);

                this.Cursor = Cursors.Default;
                panelInstall.Controls.Clear();
                panelInstall.Controls.Add(new Label() { Text = "Installation Complete!", Font = new Font("Segoe UI", 14, FontStyle.Bold), AutoSize = false, Location = new Point(20, 20), Size = new Size(450, 40) });
                panelInstall.Controls.Add(new Label() { Text = "OmniGet Desktop UI and CLI were successfully installed!\n\nShortcuts created on Desktop & Start Menu (`OmniGet`).\nCLI Commands: `OmniGetCLI` or `omniget`", Font = new Font("Segoe UI", 10), Location = new Point(20, 70), Size = new Size(450, 100) });
                currentStep = steps.Count;
                btnNext.Text = "Finish & Launch";
                btnNext.Enabled = true;
                btnCancel.Enabled = false;

            } catch (Exception ex) {
                this.Cursor = Cursors.Default;
                MessageBox.Show("Installation failed:\n" + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                btnNext.Enabled = true;
                btnBack.Enabled = true;
            }
        }
    }
}
"@
$guiCsPath = Join-Path $PSScriptRoot "guicompile.cs"
Set-Content -Path $guiCsPath -Value $guiCsCode -Encoding UTF8

& $cscPath /nologo /target:winexe /win32manifest:$manifestPath /out:OmniGet.exe /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll $guiCsPath
if ($LASTEXITCODE -eq 0) {
    Write-Host "Success! Clean industry standard executables generated:" -ForegroundColor Green
    Write-Host "  - OmniGet.exe (Main Desktop App & Setup)" -ForegroundColor Yellow
    Write-Host "  - OmniGetCLI.exe (Command Line Engine)" -ForegroundColor Yellow
    Remove-Item $guiCsPath -ErrorAction SilentlyContinue
    Remove-Item $manifestPath -ErrorAction SilentlyContinue
} else {
    Write-Error "OmniGet.exe compilation failed."
    Remove-Item $manifestPath -ErrorAction SilentlyContinue
    exit 1
}

exit 0
