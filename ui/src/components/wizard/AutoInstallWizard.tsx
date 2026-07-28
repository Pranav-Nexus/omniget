import React, { useState } from 'react';
import { Download, ShieldCheck, CheckCircle2, RefreshCw, Terminal, ArrowRight, AlertTriangle, Layers } from 'lucide-react';
import { AutoInstallerService, SetupProgressState } from '../../services/autoInstaller';
import { TerminalLog } from '../../types/omniget';

interface AutoInstallWizardProps {
  onComplete: () => void;
  onLog: (log: TerminalLog) => void;
}

export const AutoInstallWizard: React.FC<AutoInstallWizardProps> = ({ onComplete, onLog }) => {
  const [progress, setProgress] = useState<SetupProgressState>({
    step: 'detecting',
    message: 'OmniGet engine & WinGet bootstrapper audit. Ready to initiate setup.',
    progressPercent: 0
  });

  const [isRunning, setIsRunning] = useState(false);

  const startAutoSetup = async () => {
    setIsRunning(true);
    const success = await AutoInstallerService.runAutoInstallation(
      (state) => setProgress(state),
      onLog
    );
    setIsRunning(false);
    if (success) {
      setTimeout(() => {
        onComplete();
      }, 1000);
    }
  };

  return (
    <div className="fixed inset-0 bg-fluent-bg-dark text-white flex items-center justify-center p-6 z-50 select-none">
      <div className="max-w-xl w-full bg-fluent-bg-cardDark border border-fluent-border-dark rounded-3xl p-8 shadow-mica space-y-8 text-center relative overflow-hidden">
        {/* Background Accent Glow */}
        <div className="absolute -top-20 -left-20 w-72 h-72 bg-blue-500/20 rounded-full blur-3xl pointer-events-none" />

        <div className="space-y-3 relative z-10">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-blue-600 to-indigo-500 mx-auto flex items-center justify-center font-bold text-xl text-white shadow-xl">
            OG
          </div>

          <h1 className="text-2xl font-bold tracking-tight text-white">
            OmniGet & WinGet Automatic Setup
          </h1>
          <p className="text-xs text-gray-400 max-w-md mx-auto leading-relaxed">
            Sets up the OmniGet engine and automatically bootstraps WinGet (Microsoft DesktopAppInstaller) if missing on this Windows system.
          </p>
        </div>

        {/* Feature Highlights */}
        <div className="grid grid-cols-2 gap-3 text-left relative z-10">
          <div className="p-3 rounded-xl bg-white/5 border border-white/10 flex items-center space-x-2 text-xs text-gray-300">
            <ShieldCheck className="w-4 h-4 text-emerald-400" />
            <span>Auto-Bootstraps WinGet</span>
          </div>
          <div className="p-3 rounded-xl bg-white/5 border border-white/10 flex items-center space-x-2 text-xs text-gray-300">
            <Layers className="w-4 h-4 text-blue-400" />
            <span>Configures System PATH</span>
          </div>
        </div>

        {/* Progress Bar & Status */}
        <div className="space-y-4 relative z-10 bg-white/5 p-6 rounded-2xl border border-white/10">
          <div className="flex justify-between items-center text-xs font-semibold">
            <span className="text-blue-400 flex items-center space-x-2">
              <RefreshCw className={`w-3.5 h-3.5 ${isRunning ? 'animate-spin' : ''}`} />
              <span>Installation Progress</span>
            </span>
            <span className="font-mono text-gray-300">{progress.progressPercent}%</span>
          </div>

          {/* Progress Bar */}
          <div className="w-full h-2.5 rounded-full bg-black/50 overflow-hidden p-0.5 border border-white/10">
            <div
              className="h-full bg-gradient-to-r from-blue-500 to-indigo-500 rounded-full transition-all duration-300"
              style={{ width: `${progress.progressPercent}%` }}
            />
          </div>

          <div className="text-xs text-gray-300 font-mono text-left bg-black/40 p-3 rounded-xl border border-white/5">
            {progress.message}
          </div>
        </div>

        {/* Action Button */}
        <div className="relative z-10 pt-2">
          {progress.step === 'completed' ? (
            <button
              onClick={onComplete}
              className="w-full py-3 rounded-2xl bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-xs flex items-center justify-center space-x-2 shadow-lg shadow-emerald-600/30 transition-all"
            >
              <CheckCircle2 className="w-4 h-4" />
              <span>Launch Storefront</span>
            </button>
          ) : (
            <button
              disabled={isRunning}
              onClick={startAutoSetup}
              className="w-full py-3.5 rounded-2xl bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-semibold text-xs flex items-center justify-center space-x-2 shadow-lg shadow-blue-600/30 transition-all hover:scale-[1.02] active:scale-[0.98]"
            >
              <Download className="w-4 h-4" />
              <span>{isRunning ? 'Installing OmniGet & WinGet...' : '1-Click Install Engine & WinGet'}</span>
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
