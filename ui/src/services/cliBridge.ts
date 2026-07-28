import { 
  Package, 
  PackageUpdate, 
  InstalledPackage, 
  CliFlags, 
  DoctorCheck, 
  EnvVariable, 
  PathEntry, 
  ShellAlias,
  TerminalLog,
  SystemInfo,
  PrivacyAuditEntry
} from '../types/omniget';

const API_BASE = 'http://localhost:3001/api';

type LogHandler = (log: TerminalLog) => void;
let globalLogHandler: LogHandler | null = null;

export const setLogHandler = (handler: LogHandler) => {
  globalLogHandler = handler;
};

const emitLog = (level: 'info' | 'warn' | 'error' | 'success', text: string) => {
  if (globalLogHandler) {
    globalLogHandler({
      id: Math.random().toString(),
      timestamp: new Date().toLocaleTimeString(),
      level,
      text
    });
  }
};

export const FEATURED_APPS: Package[] = [
  {
    id: 'Microsoft.VisualStudioCode',
    name: 'Visual Studio Code',
    publisher: 'Microsoft Corporation',
    description: 'Code editing. Redefined. Lightweight, powerful open-source code editor with built-in Git & extensions.',
    version: '1.96.2',
    source: 'winget',
    sourcesAvailable: ['winget', 'choco', 'scoop'],
    architectureAvailable: ['x64', 'arm64', 'x86'],
    category: 'Development',
    rating: 4.9,
    featured: true,
    downloads: '12M+'
  },
  {
    id: 'Mozilla.Firefox',
    name: 'Mozilla Firefox',
    publisher: 'Mozilla',
    description: 'Fast, private, and independent web browser built for freedom and customization.',
    version: '134.0.2',
    source: 'winget',
    sourcesAvailable: ['winget', 'choco'],
    architectureAvailable: ['x64', 'arm64', 'x86'],
    category: 'Browsers',
    rating: 4.7,
    featured: true,
    downloads: '8M+'
  },
  {
    id: 'Git.Git',
    name: 'Git for Windows',
    publisher: 'The Git Development Team',
    description: 'Distributed version control system designed to handle everything from small to very large projects.',
    version: '2.47.1',
    source: 'winget',
    sourcesAvailable: ['winget', 'choco', 'scoop'],
    architectureAvailable: ['x64', 'x86'],
    category: 'Development',
    rating: 4.8,
    featured: true,
    downloads: '15M+'
  },
  {
    id: 'Neovim.Neovim',
    name: 'Neovim',
    publisher: 'Neovim Team',
    description: 'Vim-fork focused on extensibility and usability, featuring built-in Lua scripting engine.',
    version: '0.10.3',
    source: 'scoop',
    sourcesAvailable: ['scoop', 'winget', 'choco'],
    architectureAvailable: ['x64'],
    category: 'Development',
    rating: 4.9,
    featured: true,
    downloads: '2M+'
  },
  {
    id: 'VideoLAN.VLC',
    name: 'VLC Media Player',
    publisher: 'VideoLAN',
    description: 'Free and open-source cross-platform multimedia player that plays most multimedia files.',
    version: '3.0.21',
    source: 'choco',
    sourcesAvailable: ['choco', 'winget'],
    architectureAvailable: ['x64', 'x86', 'arm64'],
    category: 'Media',
    rating: 4.6,
    featured: true,
    downloads: '9M+'
  }
];

export const CATALOG_APPS: Package[] = [
  ...FEATURED_APPS,
  {
    id: 'Nodejs.Nodejs',
    name: 'Node.js LTS',
    publisher: 'OpenJS Foundation',
    description: 'JavaScript runtime built on Chrome\'s V8 JavaScript engine for scalable network apps.',
    version: '22.13.0',
    source: 'winget',
    sourcesAvailable: ['winget', 'choco', 'scoop'],
    architectureAvailable: ['x64', 'arm64'],
    category: 'Development',
    rating: 4.8
  },
  {
    id: 'Python.Python.3.12',
    name: 'Python 3.12',
    publisher: 'Python Software Foundation',
    description: 'High-level programming language emphasizes code readability with simple syntax.',
    version: '3.12.8',
    source: 'winget',
    sourcesAvailable: ['winget', 'choco'],
    architectureAvailable: ['x64', 'arm64', 'x86'],
    category: 'Development',
    rating: 4.9
  },
  {
    id: 'Docker.DockerDesktop',
    name: 'Docker Desktop',
    publisher: 'Docker Inc.',
    description: 'Collaborative containerization app to build, share, and run containerized apps.',
    version: '4.37.1',
    source: 'winget',
    sourcesAvailable: ['winget', 'choco'],
    architectureAvailable: ['x64'],
    category: 'Development',
    rating: 4.7
  },
  {
    id: '7zip.7zip',
    name: '7-Zip File Archiver',
    publisher: 'Igor Pavlov',
    description: 'High compression ratio file archiver utility supporting 7z, ZIP, RAR formats.',
    version: '24.09',
    source: 'winget',
    sourcesAvailable: ['winget', 'choco', 'scoop'],
    architectureAvailable: ['x64', 'arm64', 'x86'],
    category: 'Utilities',
    rating: 4.9
  },
  {
    id: 'Zen-Browser.Zen',
    name: 'Zen Browser',
    publisher: 'Zen Team',
    description: 'Beautiful, fast, privacy-focused Firefox fork with side tabs and workspaces.',
    version: '1.7.2',
    source: 'scoop',
    sourcesAvailable: ['scoop', 'winget'],
    architectureAvailable: ['x64'],
    category: 'Browsers',
    rating: 4.9
  },
  {
    id: 'Obsidian.Obsidian',
    name: 'Obsidian',
    publisher: 'Dynalist Inc.',
    description: 'Powerful knowledge base and note-taking application that works on local Markdown files.',
    version: '1.7.7',
    source: 'winget',
    sourcesAvailable: ['winget', 'choco'],
    architectureAvailable: ['x64', 'arm64'],
    category: 'Productivity',
    rating: 4.9
  }
];

export class CliBridge {
  static async checkCliInstalled(): Promise<{ installed: boolean; path?: string; version?: string }> {
    return { installed: true, path: 'C:\\Users\\User\\AppData\\Local\\OmniGet\\omniget.exe', version: '1.0.6' };
  }

  static async fetchSystemInfo(): Promise<SystemInfo | null> {
    try {
      const res = await fetch(`${API_BASE}/system-info`);
      const data = await res.json();
      if (data.success && data.info) {
        return data.info;
      }
    } catch (e) {
      console.warn('Unable to fetch system hardware specifications');
    }
    return null;
  }

  static async fetchProcesses(): Promise<any[]> {
    try {
      const res = await fetch(`${API_BASE}/processes`);
      const data = await res.json();
      if (data.success && Array.isArray(data.processes)) {
        return data.processes;
      }
    } catch (e) {
      console.warn('Unable to fetch running processes');
    }
    return [];
  }

  static async killProcess(pid: number): Promise<boolean> {
    emitLog('info', `> Executing: Stop-Process -Id ${pid} -Force`);
    try {
      const res = await fetch(`${API_BASE}/processes/kill`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pid })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', `Process (PID: ${pid}) terminated successfully.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Failed to terminate process ${pid}: ${e}`);
      return false;
    }
  }

  static async fetchPrivacyLogs(): Promise<PrivacyAuditEntry[]> {
    try {
      const res = await fetch(`${API_BASE}/privacy/logs`);
      const data = await res.json();
      if (data.success && Array.isArray(data.logs)) {
        return data.logs;
      }
    } catch (e) {
      console.warn('Unable to fetch privacy audit logs');
    }
    return [];
  }

  static async fetchServices(): Promise<any[]> {
    try {
      const res = await fetch(`${API_BASE}/services`);
      const data = await res.json();
      if (data.success && Array.isArray(data.services)) {
        return data.services;
      }
    } catch (e) {
      console.warn('Unable to fetch Windows services');
    }
    return [];
  }

  static async fetchStartupPrograms(): Promise<any[]> {
    try {
      const res = await fetch(`${API_BASE}/startup`);
      const data = await res.json();
      if (data.success && Array.isArray(data.startup)) {
        return data.startup;
      }
    } catch (e) {
      console.warn('Unable to fetch startup applications');
    }
    return [];
  }

  static async fetchInstalledPackages(): Promise<InstalledPackage[]> {
    emitLog('info', '> Executing: omniget list');
    try {
      const res = await fetch(`${API_BASE}/installed`);
      const data = await res.json();
      if (data.success && Array.isArray(data.packages)) {
        emitLog('success', `[OmniGet] Executed 'omniget list': returned ${data.packages.length} installed packages.`);
        return data.packages;
      }
      emitLog('warn', `[OmniGet] Executed 'omniget list': raw output parsing returned 0 packages.`);
    } catch (e) {
      emitLog('error', `[OmniGet Bridge] Error fetching installed packages: ${e}`);
    }
    return [];
  }

  static async fetchOutdatedPackages(): Promise<PackageUpdate[]> {
    emitLog('info', '> Executing: omniget upgrade (outdated scan)');
    try {
      const res = await fetch(`${API_BASE}/outdated`);
      const data = await res.json();
      if (data.success && Array.isArray(data.updates)) {
        emitLog('success', `[OmniGet] Executed 'omniget upgrade': found ${data.updates.length} outdated packages.`);
        return data.updates;
      }
      emitLog('success', `[OmniGet] Executed 'omniget upgrade': all packages up to date.`);
    } catch (e) {
      emitLog('error', `[OmniGet Bridge] Error checking outdated packages: ${e}`);
    }
    return [];
  }

  static async fetchSearchPackages(query: string): Promise<Package[]> {
    emitLog('info', `> Executing: omniget search ${query}`);
    try {
      const res = await fetch(`${API_BASE}/search?q=${encodeURIComponent(query)}`);
      const data = await res.json();
      if (data.success && Array.isArray(data.results)) {
        emitLog('success', `[OmniGet] Executed 'omniget search ${query}': returned ${data.results.length} matching packages.`);
        return data.results;
      }
    } catch (e) {
      emitLog('error', `[OmniGet Bridge] Search query failed: ${e}`);
    }
    return [];
  }

  static async fetchDoctorChecks(): Promise<DoctorCheck[]> {
    emitLog('info', '> Executing: omniget doctor');
    try {
      const res = await fetch(`${API_BASE}/doctor`);
      const data = await res.json();
      if (data.success && Array.isArray(data.checks)) {
        const warnCount = data.checks.filter((c: any) => c.status === 'warning' && !c.isDismissed).length;
        const errCount = data.checks.filter((c: any) => c.status === 'error' && !c.isDismissed).length;
        emitLog(
          errCount > 0 ? 'error' : warnCount > 0 ? 'warn' : 'success',
          `[OmniGet] Executed 'omniget doctor': ${data.checks.length} checks performed (${warnCount} active warnings, ${errCount} critical errors).`
        );
        return data.checks;
      }
    } catch (e) {
      emitLog('error', `[OmniGet Bridge] Error running doctor audit: ${e}`);
    }
    return [];
  }

  static async dismissDoctorCheck(id: string): Promise<boolean> {
    emitLog('info', `> Executing: omniget doctor dismiss ${id}`);
    try {
      const res = await fetch(`${API_BASE}/doctor/dismiss`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', `Warning '${id}' permanently dismissed.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Error dismissing doctor check: ${e}`);
      return false;
    }
  }

  static async snoozeDoctorCheck(id: string, hours: number): Promise<boolean> {
    emitLog('info', `> Executing: omniget doctor snooze ${id} ${hours}`);
    try {
      const res = await fetch(`${API_BASE}/doctor/snooze`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, hours })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', `Warning '${id}' snoozed for ${hours} hours.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Error snoozing doctor check: ${e}`);
      return false;
    }
  }

  static async restoreDoctorCheck(id: string): Promise<boolean> {
    emitLog('info', `> Executing: omniget doctor restore ${id}`);
    try {
      const res = await fetch(`${API_BASE}/doctor/restore`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', `Warning '${id}' restored to active checklist.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Error restoring doctor check: ${e}`);
      return false;
    }
  }

  static async fetchEnvVariables(): Promise<EnvVariable[]> {
    emitLog('info', '> Executing: omniget env show');
    try {
      const res = await fetch(`${API_BASE}/env`);
      const data = await res.json();
      if (data.success && Array.isArray(data.vars)) {
        emitLog('success', `[OmniGet] Executed 'omniget env show': loaded ${data.vars.length} environment variables.`);
        return data.vars;
      }
    } catch (e) {
      emitLog('error', `[OmniGet Bridge] Error fetching environment variables: ${e}`);
    }
    return [];
  }

  static async setEnvVariable(name: string, value: string, scope: 'user' | 'system'): Promise<boolean> {
    emitLog('info', `> Executing: omniget env set "${name}" "${value}" ${scope === 'system' ? '--system' : ''}`);
    try {
      const res = await fetch(`${API_BASE}/env/set`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, value, scope })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', data.output || `Environment variable '${name}' set successfully.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Error setting environment variable: ${e}`);
      return false;
    }
  }

  static async removeEnvVariable(name: string, scope: 'user' | 'system'): Promise<boolean> {
    emitLog('info', `> Executing: omniget env remove "${name}" ${scope === 'system' ? '--system' : ''}`);
    try {
      const res = await fetch(`${API_BASE}/env/remove`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, scope })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', data.output || `Environment variable '${name}' removed successfully.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Error removing environment variable: ${e}`);
      return false;
    }
  }

  static async fetchPathEntries(): Promise<PathEntry[]> {
    emitLog('info', '> Executing: omniget path show');
    try {
      const res = await fetch(`${API_BASE}/path`);
      const data = await res.json();
      if (data.success && Array.isArray(data.entries)) {
        emitLog('success', `[OmniGet] Executed 'omniget path show': ${data.entries.length} PATH directories audited.`);
        return data.entries;
      }
    } catch (e) {
      emitLog('error', `[OmniGet Bridge] Error auditing PATH entries: ${e}`);
    }
    return [];
  }

  static async addPathEntry(folder: string, scope: 'user' | 'system'): Promise<boolean> {
    emitLog('info', `> Executing: omniget path add "${folder}" ${scope === 'system' ? '--system' : ''}`);
    try {
      const res = await fetch(`${API_BASE}/path/add`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ folder, scope })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', data.output || `PATH folder added successfully.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Error adding path entry: ${e}`);
      return false;
    }
  }

  static async removePathEntry(folder: string, scope: 'user' | 'system'): Promise<boolean> {
    emitLog('info', `> Executing: omniget path remove "${folder}" ${scope === 'system' ? '--system' : ''}`);
    try {
      const res = await fetch(`${API_BASE}/path/remove`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ folder, scope })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', data.output || `PATH folder removed successfully.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Error removing path entry: ${e}`);
      return false;
    }
  }

  static async pruneDeadPaths(): Promise<boolean> {
    emitLog('info', '> Executing: omniget doctor (pruning dead PATH entries)');
    try {
      const res = await fetch(`${API_BASE}/path/prune`, { method: 'POST' });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', data.output || `Dead paths pruned successfully.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Error pruning dead paths: ${e}`);
      return false;
    }
  }

  static async fetchShellAliases(): Promise<ShellAlias[]> {
    emitLog('info', '> Executing: omniget alias list');
    try {
      const res = await fetch(`${API_BASE}/alias`);
      const data = await res.json();
      if (data.success && Array.isArray(data.aliases)) {
        emitLog('success', `[OmniGet] Executed 'omniget alias list': ${data.aliases.length} shortcuts registered in $PROFILE.`);
        return data.aliases;
      }
    } catch (e) {
      emitLog('error', `[OmniGet Bridge] Error fetching shell aliases: ${e}`);
    }
    return [];
  }

  static async addShellAlias(name: string, command: string): Promise<boolean> {
    emitLog('info', `> Executing: omniget alias add "${name}" "${command}"`);
    try {
      const res = await fetch(`${API_BASE}/alias/add`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, command })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', data.output || `Registered shortcut '${name}' in $PROFILE.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Error adding alias: ${e}`);
      return false;
    }
  }

  static async removeShellAlias(name: string): Promise<boolean> {
    emitLog('info', `> Executing: omniget alias remove "${name}"`);
    try {
      const res = await fetch(`${API_BASE}/alias/remove`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', data.output || `Removed shortcut '${name}' from $PROFILE.`);
      return data.success;
    } catch (e) {
      emitLog('error', `Error removing alias: ${e}`);
      return false;
    }
  }

  static async exportCatalog(format: 'json' | 'txt'): Promise<{ success: boolean; file?: string }> {
    emitLog('info', `> Executing: omniget export (format: ${format})`);
    try {
      const res = await fetch(`${API_BASE}/export`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ format })
      });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', data.output || `Exported manifest to ${data.file}`);
      return data;
    } catch (e) {
      emitLog('error', `Error exporting catalog: ${e}`);
      return { success: false };
    }
  }

  static async syncCatalog(): Promise<{ success: boolean; output?: string }> {
    emitLog('info', '> Executing: omniget sync (declarative system alignment)');
    try {
      const res = await fetch(`${API_BASE}/sync`, { method: 'POST' });
      const data = await res.json();
      emitLog(data.success ? 'success' : 'error', data.output || `System state synchronized successfully.`);
      return data;
    } catch (e) {
      emitLog('error', `Error syncing catalog: ${e}`);
      return { success: false };
    }
  }

  static async executeCommand(
    command: string, 
    args: string[], 
    onLog?: (log: TerminalLog) => void
  ): Promise<{ success: boolean; output: string }> {
    const fullCmd = `omniget ${command} ${args.join(' ')}`;
    emitLog('info', `> Executing: ${fullCmd}`);

    try {
      const res = await fetch(`${API_BASE}/action`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: command, id: args[0], flags: { silent: true } })
      });
      const data = await res.json();

      emitLog(
        data.success ? 'success' : 'error',
        data.output || `[OmniGet] Operation '${command}' completed.`
      );

      return { success: data.success, output: data.output };
    } catch (e) {
      emitLog('error', `Execution error for ${fullCmd}: ${e}`);
      return { success: false, output: `Execution failed ${fullCmd}` };
    }
  }
}
