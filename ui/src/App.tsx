import React, { useState, useEffect } from 'react';
import { TopBar } from './components/layout/TopBar';
import { Sidebar } from './components/layout/Sidebar';
import { TerminalDrawer } from './components/layout/TerminalDrawer';
import { StorefrontView } from './components/store/StorefrontView';
import { UpdatesDashboard } from './components/updates/UpdatesDashboard';
import { InstalledLibrary } from './components/installed/InstalledLibrary';
import { DoctorView } from './components/doctor/DoctorView';
import { EnvPathManager } from './components/env/EnvPathManager';
import { BackupSyncView } from './components/sync/BackupSyncView';
import { AliasManager } from './components/alias/AliasManager';
import { SettingsPage } from './components/settings/SettingsPage';
import { SystemMonitorView } from './components/system/SystemMonitorView';
import { ThemeProvider } from './context/ThemeContext';
import { NavigationTab, Package, InstalledPackage, CliFlags, TerminalLog, DoctorCheck } from './types/omniget';
import { CliBridge, setLogHandler } from './services/cliBridge';

export const AppContent: React.FC = () => {
  const [activeTab, setActiveTab] = useState<NavigationTab>('store');
  const [selectedPackage, setSelectedPackage] = useState<Package | null>(null);
  const [terminalLogs, setTerminalLogs] = useState<TerminalLog[]>([]);
  const [isTerminalOpen, setIsTerminalOpen] = useState(false);
  const [pendingUpdatesCount, setPendingUpdatesCount] = useState<number>(1);
  const [preloadedDoctor, setPreloadedDoctor] = useState<DoctorCheck[]>([]);

  useEffect(() => {
    setLogHandler((log) => {
      setTerminalLogs((prev) => [...prev.slice(-200), log]);
    });

    CliBridge.fetchDoctorChecks().then(checks => setPreloadedDoctor(checks));
    CliBridge.fetchOutdatedPackages().then(updates => setPendingUpdatesCount(updates.length));
  }, []);

  const handleInstallPackage = async (pkg: Package, flags?: CliFlags) => {
    setIsTerminalOpen(true);
    let pmArg = pkg.source || 'winget';
    const args = [pkg.id, '--pm', pmArg];
    if (flags?.silent !== false) args.push('--silent');
    if (flags?.force) args.push('--force');
    if (flags?.userScope) args.push('--scope', 'user');

    await CliBridge.executeCommand('install', args, (log) => {
      setTerminalLogs((prev) => [...prev, log]);
    });
  };

  const handleUninstallPackage = async (pkg: InstalledPackage, flags?: CliFlags) => {
    setIsTerminalOpen(true);
    await CliBridge.executeCommand('uninstall', [pkg.id], (log) => {
      setTerminalLogs((prev) => [...prev, log]);
    });
  };

  const handleUpdatePackages = async (packages: any[]) => {
    setIsTerminalOpen(true);
    for (const pkg of packages) {
      await CliBridge.executeCommand('upgrade', [pkg.id], (log) => {
        setTerminalLogs((prev) => [...prev, log]);
      });
    }
  };

  return (
    <div className="h-screen w-screen flex flex-col overflow-hidden bg-slate-900 font-sans text-slate-100 select-none">
      {/* Top Windows App Header */}
      <TopBar 
        onSelectPackage={(pkg) => setSelectedPackage(pkg)} 
        onNavigate={(tab) => setActiveTab(tab)}
      />

      {/* Main App Workspace */}
      <div className="flex-1 flex overflow-hidden">
        {/* Left Sidebar */}
        <Sidebar 
          currentTab={activeTab} 
          onNavigate={(tab) => setActiveTab(tab)} 
          outdatedCount={pendingUpdatesCount}
        />

        {/* Content View Container */}
        <main className="flex-1 overflow-hidden bg-slate-50 dark:bg-gradient-to-br dark:from-fluent-bg-dark dark:via-[#1e1e1e] dark:to-[#181818] relative transition-colors duration-200">
          {activeTab === 'store' && (
            <StorefrontView 
              onInstallPackage={handleInstallPackage} 
              onSelectPackage={(pkg) => setSelectedPackage(pkg)} 
            />
          )}
          {activeTab === 'updates' && (
            <UpdatesDashboard 
              onUpdatePackages={handleUpdatePackages} 
              onOutdatedCountChange={(count) => setPendingUpdatesCount(count)}
            />
          )}
          {activeTab === 'installed' && <InstalledLibrary onUninstallPackage={handleUninstallPackage} />}
          {activeTab === 'doctor' && <DoctorView initialChecks={preloadedDoctor} />}
          {activeTab === 'system-monitor' && <SystemMonitorView />}
          {activeTab === 'env' && <EnvPathManager />}
          {activeTab === 'sync' && <BackupSyncView />}
          {activeTab === 'alias' && <AliasManager />}
          {activeTab === 'settings' && <SettingsPage />}
        </main>
      </div>

      {/* Bottom Collapsible PowerShell Terminal Drawer */}
      <TerminalDrawer
        isOpen={isTerminalOpen}
        onClose={() => setIsTerminalOpen(false)}
        logs={terminalLogs}
        onClearLogs={() => setTerminalLogs([])}
      />
    </div>
  );
};

export const App: React.FC = () => {
  return (
    <ThemeProvider>
      <AppContent />
    </ThemeProvider>
  );
};

export default App;
