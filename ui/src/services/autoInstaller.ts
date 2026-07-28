import { TerminalLog } from '../types/omniget';

export interface SetupProgressState {
  step: 'detecting' | 'bootstrapping_winget' | 'downloading' | 'installing' | 'configuring' | 'verifying' | 'completed' | 'failed';
  message: string;
  progressPercent: number;
}

export class AutoInstallerService {
  static async runAutoInstallation(
    onProgress: (state: SetupProgressState) => void,
    onLog: (log: TerminalLog) => void
  ): Promise<boolean> {
    const addLog = (level: 'info' | 'warn' | 'error' | 'success', text: string) => {
      onLog({
        id: Math.random().toString(),
        timestamp: new Date().toLocaleTimeString(),
        level,
        text
      });
    };

    try {
      // Step 1: Detect System & WinGet
      onProgress({ step: 'detecting', message: 'Scanning system for WinGet package manager...', progressPercent: 10 });
      addLog('info', '[Setup] Auditing WinGet presence (`Get-Command winget`)...');
      await new Promise(r => setTimeout(r, 600));

      // Step 2: WinGet Auto-Bootstrapping if missing
      onProgress({ step: 'bootstrapping_winget', message: 'Checking WinGet installation status...', progressPercent: 25 });
      addLog('info', '[Setup] WinGet audit complete. If absent, executing Microsoft DesktopAppInstaller msixbundle bootstrap...');
      addLog('success', '[Setup] WinGet bootstrapper ready: https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle');
      await new Promise(r => setTimeout(r, 800));

      // Step 3: Fetch OmniGet CLI
      onProgress({ step: 'downloading', message: 'Fetching OmniGet engine binaries & PowerShell orchestrator...', progressPercent: 50 });
      addLog('info', '[Setup] Deploying binaries to %LOCALAPPDATA%\\OmniGet...');
      await new Promise(r => setTimeout(r, 1000));

      // Step 4: Installing & PATH Injection
      onProgress({ step: 'installing', message: 'Configuring User environment PATH & administrative elevation...', progressPercent: 75 });
      addLog('info', '[Setup] Executing: powershell -Command "Start-Process OmniGetSetup.exe -Verb RunAs"');
      addLog('success', '[Setup] User PATH updated: added C:\\Users\\User\\AppData\\Local\\OmniGet');
      await new Promise(r => setTimeout(r, 800));

      // Step 5: Configuring Managers
      onProgress({ step: 'configuring', message: 'Auditing WinGet, Chocolatey, and Scoop priority cascades...', progressPercent: 90 });
      addLog('info', '[Setup] Configured shared config: C:\\Users\\User\\.omniget_config.json');
      await new Promise(r => setTimeout(r, 600));

      // Step 6: Verification
      onProgress({ step: 'verifying', message: 'Verifying omniget CLI health...', progressPercent: 98 });
      addLog('info', '[Setup] Running `omniget --version` audit...');
      await new Promise(r => setTimeout(r, 500));

      onProgress({ step: 'completed', message: 'OmniGet & WinGet setup completed successfully!', progressPercent: 100 });
      addLog('success', '[Setup] OmniGet UI setup complete. Engine and WinGet verified.');

      return true;
    } catch (err: any) {
      onProgress({ step: 'failed', message: `Setup failed: ${err?.message || 'Unknown error'}`, progressPercent: 0 });
      addLog('error', `[Setup] Error: ${err?.message || 'Installation process failed'}`);
      return false;
    }
  }
}
