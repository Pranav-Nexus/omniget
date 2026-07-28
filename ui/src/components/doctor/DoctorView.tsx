import React, { useState, useEffect } from 'react';
import { 
  Stethoscope, 
  CheckCircle2, 
  AlertTriangle, 
  XCircle, 
  RefreshCw, 
  Wrench, 
  ShieldAlert, 
  BellOff, 
  Clock, 
  RotateCcw, 
  PlusCircle, 
  Download,
  PackageCheck
} from 'lucide-react';
import { CliBridge } from '../../services/cliBridge';
import { DoctorCheck } from '../../types/omniget';

interface DoctorViewProps {
  initialChecks?: DoctorCheck[];
}

export const DoctorView: React.FC<DoctorViewProps> = ({ initialChecks }) => {
  const [checks, setChecks] = useState<DoctorCheck[]>(initialChecks || []);
  const [isScanning, setIsScanning] = useState(!initialChecks || initialChecks.length === 0);
  const [snoozeOpenId, setSnoozeOpenId] = useState<string | null>(null);

  const runDoctorScan = async () => {
    setIsScanning(true);
    const liveChecks = await CliBridge.fetchDoctorChecks();
    setChecks(liveChecks);
    setIsScanning(false);
  };

  useEffect(() => {
    if (!initialChecks || initialChecks.length === 0) {
      runDoctorScan();
    }
  }, []);

  const handleFix = async (id: string) => {
    setIsScanning(true);
    if (id === 'user-path-dead') {
      await CliBridge.pruneDeadPaths();
    }
    await runDoctorScan();
  };

  const handleDismiss = async (id: string) => {
    setIsScanning(true);
    await CliBridge.dismissDoctorCheck(id);
    await runDoctorScan();
  };

  const handleSnooze = async (id: string, hours: number) => {
    setIsScanning(true);
    setSnoozeOpenId(null);
    await CliBridge.snoozeDoctorCheck(id, hours);
    await runDoctorScan();
  };

  const handleRestore = async (id: string) => {
    setIsScanning(true);
    await CliBridge.restoreDoctorCheck(id);
    await runDoctorScan();
  };

  // Group checks into 4 clear categories:
  const installedPms = checks.filter(c => c.category === 'Installed Package Manager' || (c.category === 'Package Manager' && c.status === 'healthy'));
  const availablePms = checks.filter(c => c.category === 'Available Package Manager' || (c.category === 'Package Manager' && c.status === 'available'));
  const activeDiagnostics = checks.filter(c => 
    c.category !== 'Installed Package Manager' && 
    c.category !== 'Available Package Manager' &&
    !c.isDismissed
  );
  const dismissedChecks = checks.filter(c => c.isDismissed);

  const healthyCount = installedPms.length + activeDiagnostics.filter(c => c.status === 'healthy').length;
  const warningCount = activeDiagnostics.filter(c => c.status === 'warning').length;
  const errorCount = activeDiagnostics.filter(c => c.status === 'error').length;

  return (
    <div className="p-6 md:p-8 space-y-8 overflow-y-auto h-full">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-200 dark:border-fluent-border-dark pb-6">
        <div>
          <h1 className="text-xl font-bold text-slate-900 dark:text-white flex items-center space-x-2">
            <Stethoscope className="w-6 h-6 text-blue-500 dark:text-blue-400" />
            <span>OmniGet Doctor (Live System Audit)</span>
          </h1>
          <p className="text-xs text-slate-600 dark:text-gray-400 mt-1">
            Audits installed package managers, PATH hygiene, UAC privileges, and warning dismissals.
          </p>
        </div>

        <button
          onClick={runDoctorScan}
          disabled={isScanning}
          className="px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-semibold text-xs flex items-center space-x-2 shadow-lg shadow-blue-600/30 transition-all"
        >
          <RefreshCw className={`w-4 h-4 ${isScanning ? 'animate-spin' : ''}`} />
          <span>{isScanning ? 'Auditing System...' : 'Run Full Audit'}</span>
        </button>
      </div>

      {/* Health Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center space-x-3">
          <CheckCircle2 className="w-8 h-8 text-emerald-500 dark:text-emerald-400" />
          <div>
            <div className="text-2xl font-bold text-emerald-600 dark:text-emerald-400">{healthyCount}</div>
            <div className="text-xs text-slate-700 dark:text-gray-300 font-medium">Healthy Audits</div>
          </div>
        </div>

        <div className="p-4 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center space-x-3">
          <AlertTriangle className="w-8 h-8 text-amber-500 dark:text-amber-400" />
          <div>
            <div className="text-2xl font-bold text-amber-600 dark:text-amber-400">{warningCount}</div>
            <div className="text-xs text-slate-700 dark:text-gray-300 font-medium">Active Warnings</div>
          </div>
        </div>

        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 flex items-center space-x-3">
          <ShieldAlert className="w-8 h-8 text-red-500 dark:text-red-400" />
          <div>
            <div className="text-2xl font-bold text-red-600 dark:text-red-400">{errorCount}</div>
            <div className="text-xs text-slate-700 dark:text-gray-300 font-medium">Critical Errors</div>
          </div>
        </div>
      </div>

      {/* Section 1: Installed Package Managers */}
      <div className="space-y-3">
        <h2 className="text-xs font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider flex items-center space-x-2">
          <PackageCheck className="w-4 h-4 text-emerald-500 dark:text-emerald-400" />
          <span>Installed Package Managers ({installedPms.length})</span>
        </h2>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {installedPms.map((pm) => (
            <div
              key={pm.id}
              className="p-4 rounded-xl bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark flex items-center justify-between gap-3 shadow-sm dark:shadow-mica overflow-hidden"
            >
              <div className="flex items-center space-x-3 min-w-0 flex-1">
                <CheckCircle2 className="w-5 h-5 text-emerald-500 dark:text-emerald-400 shrink-0" />
                <div className="min-w-0 flex-1">
                  <div className="text-xs font-bold text-slate-900 dark:text-white truncate">{pm.name}</div>
                  <div className="text-[11px] font-mono text-slate-500 dark:text-gray-400 truncate" title={pm.details}>
                    {pm.details}
                  </div>
                </div>
              </div>
              <span className="text-[10px] px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20 font-bold uppercase shrink-0">
                Active
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Section 2: Available Package Managers (Option to Add More) */}
      <div className="space-y-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-1">
          <h2 className="text-xs font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider flex items-center space-x-2">
            <PlusCircle className="w-4 h-4 text-blue-500 dark:text-blue-400" />
            <span>Available Package Managers (Option to Add More)</span>
          </h2>
          <span className="text-[11px] text-slate-500 dark:text-gray-400">
            Missing package managers are optional and not treated as system warnings.
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {availablePms.map((pm) => (
            <div
              key={pm.id}
              className="p-4 rounded-xl bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark flex items-center justify-between gap-3 shadow-sm dark:shadow-mica overflow-hidden"
            >
              <div className="min-w-0 flex-1">
                <div className="text-xs font-bold text-slate-900 dark:text-white truncate">{pm.name}</div>
                <div className="text-[11px] font-mono text-slate-500 dark:text-gray-400 truncate mt-0.5">{pm.details}</div>
              </div>

              <button
                onClick={() => CliBridge.executeCommand('bootstrap', [pm.id])}
                className="px-3 py-1.5 rounded-lg bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold flex items-center space-x-1.5 shadow-sm transition-all shrink-0"
              >
                <Download className="w-3.5 h-3.5" />
                <span>{pm.fixAction || `Bootstrap ${pm.name.split(' ')[0]}`}</span>
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Section 3: Active System Diagnostics Checklist */}
      <div className="space-y-3">
        <h2 className="text-xs font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider">
          Active Diagnostics Checklist
        </h2>

        {isScanning ? (
          <div className="p-8 text-center text-xs text-slate-500 dark:text-gray-400 font-mono bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark rounded-xl">
            <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-blue-500 dark:text-blue-400" />
            Executing live system health check (`omniget doctor`)...
          </div>
        ) : activeDiagnostics.length === 0 ? (
          <div className="p-8 text-center text-xs text-slate-600 dark:text-gray-300 bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark rounded-xl space-y-2">
            <CheckCircle2 className="w-6 h-6 text-emerald-500 dark:text-emerald-400 mx-auto" />
            <div className="font-bold text-sm text-slate-900 dark:text-white">System is 100% Healthy!</div>
            <div className="text-slate-500 dark:text-gray-400 text-[11px]">No active warnings or errors detected.</div>
          </div>
        ) : (
          <div className="space-y-3">
            {activeDiagnostics.map((check) => (
              <div
                key={check.id}
                className="p-4 rounded-xl bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark flex flex-col md:flex-row md:items-center justify-between gap-4 transition-all shadow-sm dark:shadow-mica"
              >
                <div className="flex items-start space-x-3 min-w-0 flex-1">
                  {check.status === 'healthy' ? (
                    <CheckCircle2 className="w-5 h-5 text-emerald-500 dark:text-emerald-400 mt-0.5 shrink-0" />
                  ) : check.status === 'warning' ? (
                    <AlertTriangle className="w-5 h-5 text-amber-500 dark:text-amber-400 mt-0.5 shrink-0" />
                  ) : (
                    <XCircle className="w-5 h-5 text-red-500 dark:text-red-400 mt-0.5 shrink-0" />
                  )}

                  <div className="min-w-0 flex-1">
                    <div className="flex items-center space-x-2">
                      <span className="text-xs font-bold text-slate-900 dark:text-white">{check.name}</span>
                      <span className="text-[10px] px-2 py-0.5 rounded bg-slate-100 dark:bg-white/10 text-slate-700 dark:text-gray-300 font-mono">
                        {check.category}
                      </span>
                    </div>
                    <p className="text-xs text-slate-600 dark:text-gray-400 mt-0.5">{check.description}</p>
                    <div className="text-[11px] font-mono text-slate-800 dark:text-gray-300 mt-2 bg-slate-50 dark:bg-black/40 p-2 rounded-lg border border-slate-200 dark:border-white/5 break-all">
                      {check.details}
                    </div>
                  </div>
                </div>

                <div className="flex items-center space-x-2 self-end md:self-center shrink-0">
                  {check.fixable && (
                    <button
                      onClick={() => handleFix(check.id)}
                      className="px-3 py-1.5 rounded-lg bg-amber-500/20 hover:bg-amber-500 text-amber-700 dark:text-amber-300 hover:text-white text-xs font-semibold border border-amber-500/30 flex items-center space-x-1 transition-all"
                    >
                      <Wrench className="w-3.5 h-3.5" />
                      <span>{check.fixAction || 'Fix Issue'}</span>
                    </button>
                  )}

                  {/* Snooze Dropdown */}
                  <div className="relative">
                    <button
                      onClick={() => setSnoozeOpenId(snoozeOpenId === check.id ? null : check.id)}
                      className="px-3 py-1.5 rounded-lg bg-slate-100 dark:bg-white/5 hover:bg-slate-200 dark:hover:bg-white/10 text-slate-700 dark:text-gray-300 text-xs font-semibold border border-slate-200 dark:border-white/10 flex items-center space-x-1"
                    >
                      <Clock className="w-3.5 h-3.5" />
                      <span>Snooze</span>
                    </button>

                    {snoozeOpenId === check.id && (
                      <div className="absolute right-0 top-full mt-1 bg-white dark:bg-fluent-bg-dark border border-slate-200 dark:border-fluent-border-dark rounded-xl shadow-lg p-1 z-30 w-36 text-xs divide-y divide-slate-100 dark:divide-white/5">
                        <button onClick={() => handleSnooze(check.id, 1)} className="w-full text-left px-3 py-1.5 hover:bg-slate-100 dark:hover:bg-white/10 text-slate-800 dark:text-gray-200">Snooze 1 Hour</button>
                        <button onClick={() => handleSnooze(check.id, 24)} className="w-full text-left px-3 py-1.5 hover:bg-slate-100 dark:hover:bg-white/10 text-slate-800 dark:text-gray-200">Snooze 24 Hours</button>
                        <button onClick={() => handleSnooze(check.id, 168)} className="w-full text-left px-3 py-1.5 hover:bg-slate-100 dark:hover:bg-white/10 text-slate-800 dark:text-gray-200">Snooze 7 Days</button>
                      </div>
                    )}
                  </div>

                  {/* Dismiss Button */}
                  <button
                    onClick={() => handleDismiss(check.id)}
                    className="px-3 py-1.5 rounded-lg bg-red-500/10 hover:bg-red-500 text-red-600 dark:text-red-400 hover:text-white text-xs font-semibold border border-red-500/20 flex items-center space-x-1 transition-all"
                  >
                    <BellOff className="w-3.5 h-3.5" />
                    <span>Dismiss</span>
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Section 4: Dismissed & Snoozed Warnings (Stored Separately) */}
      <div className="space-y-3 pt-6 border-t border-slate-200 dark:border-fluent-border-dark pb-8">
        <h2 className="text-xs font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider flex items-center space-x-2">
          <BellOff className="w-4 h-4 text-purple-500 dark:text-purple-400" />
          <span>Dismissed & Snoozed Warnings (Stored Separately)</span>
        </h2>

        {dismissedChecks.length === 0 ? (
          <div className="p-4 text-center text-xs text-slate-500 dark:text-gray-400 bg-slate-100/60 dark:bg-white/5 border border-slate-200 dark:border-white/5 rounded-xl w-full font-medium">
            No warnings are currently dismissed or snoozed.
          </div>
        ) : (
          <div className="space-y-2">
            {dismissedChecks.map((dc) => (
              <div
                key={dc.id}
                className="p-3.5 rounded-xl bg-slate-50 dark:bg-white/5 border border-slate-200 dark:border-white/10 flex items-center justify-between gap-3 text-xs opacity-80 hover:opacity-100 transition-opacity"
              >
                <div className="flex items-center space-x-3 min-w-0 flex-1">
                  <BellOff className="w-4 h-4 text-purple-500 dark:text-purple-400 shrink-0" />
                  <div className="min-w-0 flex-1">
                    <span className="font-bold text-slate-900 dark:text-white">{dc.name}</span>
                    <span className="ml-2 text-[11px] font-mono text-slate-500 dark:text-gray-400 block sm:inline">
                      {dc.isSnoozed ? `Snoozed until ${new Date(dc.snoozedUntil!).toLocaleString()}` : 'Permanently Dismissed'}
                    </span>
                  </div>
                </div>

                <button
                  onClick={() => handleRestore(dc.id)}
                  className="px-3 py-1.5 rounded-lg bg-blue-600/20 hover:bg-blue-600 text-blue-700 dark:text-blue-300 hover:text-white text-xs font-medium border border-blue-500/30 flex items-center space-x-1 shrink-0 transition-all"
                >
                  <RotateCcw className="w-3.5 h-3.5" />
                  <span>Restore Warning</span>
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
