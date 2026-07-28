import React, { useState, useEffect } from 'react';
import { Download, Star, Settings, ShieldCheck, AlertCircle } from 'lucide-react';
import { Package, CliFlags, PackageSource, SystemInfo } from '../../types/omniget';
import { CliBridge } from '../../services/cliBridge';

interface AppCardProps {
  app: Package;
  onInstall: (pkg: Package, flags?: CliFlags) => void;
  onSelectApp: (pkg: Package) => void;
}

export const AppCard: React.FC<AppCardProps> = ({ app, onInstall, onSelectApp }) => {
  const [selectedSource, setSelectedSource] = useState<PackageSource>(app.source);
  const [showFlags, setShowFlags] = useState(false);
  const [systemArch, setSystemArch] = useState<string>('x64');
  const [flags, setFlags] = useState<CliFlags>({
    silent: true,
    force: false,
    userScope: false
  });

  useEffect(() => {
    CliBridge.fetchSystemInfo().then(info => {
      if (info?.arch) setSystemArch(info.arch);
    });
  }, []);

  const availArchs = app.architectureAvailable || ['x64'];
  const isHostX64 = systemArch.toLowerCase() === 'x64';
  const isHostArm64 = systemArch.toLowerCase() === 'arm64';

  const supportsNative = (isHostX64 && availArchs.includes('x64')) || (isHostArm64 && availArchs.includes('arm64')) || availArchs.includes('universal');
  const isEmulated = isHostArm64 && !availArchs.includes('arm64') && availArchs.includes('x64');
  const isIncompatible = isHostX64 && availArchs.length === 1 && availArchs.includes('arm64');

  const handleInstallClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (isIncompatible) return;
    onInstall({ ...app, source: selectedSource }, flags);
  };

  return (
    <div
      onClick={() => onSelectApp(app)}
      className="p-5 rounded-2xl bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark hover:border-blue-500/50 dark:hover:border-blue-500/50 shadow-sm hover:shadow-md transition-all duration-200 cursor-pointer flex flex-col justify-between group relative"
    >
      <div>
        {/* Header Icon + Source & Arch Badges */}
        <div className="flex items-start justify-between gap-2 mb-3">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center font-bold text-sm text-blue-600 dark:text-blue-400 group-hover:scale-105 transition-transform">
              {app.name.charAt(0)}
            </div>
            <div>
              <div className="text-xs font-semibold text-slate-500 dark:text-gray-400 line-clamp-1">
                {app.publisher}
              </div>
            </div>
          </div>

          <div className="flex items-center space-x-1.5">
            {/* Architecture Compatibility Badge */}
            <span className={`px-2 py-0.5 rounded text-[10px] font-mono font-bold border ${
              isIncompatible
                ? 'bg-red-50 dark:bg-red-500/10 text-red-700 dark:text-red-400 border-red-200 dark:border-red-500/20'
                : isEmulated
                ? 'bg-amber-50 dark:bg-amber-500/10 text-amber-700 dark:text-amber-400 border-amber-200 dark:border-amber-500/20'
                : 'bg-emerald-50 dark:bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border-emerald-200 dark:border-emerald-500/20'
            }`}>
              {isIncompatible ? 'ARM64 Only' : isEmulated ? 'x64 Emulated' : `Native ${systemArch}`}
            </span>

            {/* PM Source Badge */}
            <span className={`px-2 py-0.5 rounded text-[10px] font-mono uppercase font-bold border ${
              selectedSource === 'winget' ? 'bg-blue-50 dark:bg-blue-500/10 text-blue-700 dark:text-blue-400 border-blue-200 dark:border-blue-500/20' :
              selectedSource === 'choco' ? 'bg-amber-50 dark:bg-amber-700/10 text-amber-700 dark:text-amber-500 border-amber-200 dark:border-amber-700/20' :
              'bg-emerald-50 dark:bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border-emerald-200 dark:border-emerald-500/20'
            }`}>
              {selectedSource}
            </span>
          </div>
        </div>

        {/* App Title */}
        <h3 className="text-sm font-bold text-slate-900 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors line-clamp-1 mb-1">
          {app.name}
        </h3>

        {/* Description */}
        <p className="text-xs text-slate-600 dark:text-gray-300 leading-relaxed line-clamp-2 mb-4">
          {app.description}
        </p>
      </div>

      {/* Footer Controls & Install */}
      <div className="pt-3 border-t border-slate-100 dark:border-white/5 flex items-center justify-between gap-2">
        <div className="flex items-center space-x-2 text-xs">
          {app.rating && (
            <span className="flex items-center text-amber-500 font-semibold space-x-1">
              <Star className="w-3.5 h-3.5 fill-amber-500" />
              <span>{app.rating}</span>
            </span>
          )}
          <span className="text-slate-500 dark:text-gray-400 font-mono text-[11px]">({app.version})</span>
        </div>

        <div className="flex items-center space-x-1.5" onClick={(e) => e.stopPropagation()}>
          <button
            onClick={() => setShowFlags(!showFlags)}
            title="Configure CLI Installation Flags"
            className="p-2 rounded-lg bg-slate-100 dark:bg-white/5 hover:bg-slate-200 dark:hover:bg-white/10 text-slate-600 dark:text-gray-400 hover:text-slate-900 dark:hover:text-white border border-slate-200 dark:border-white/10 transition-colors"
          >
            <Settings className="w-3.5 h-3.5" />
          </button>

          <button
            onClick={handleInstallClick}
            disabled={isIncompatible}
            className={`px-3.5 py-1.5 rounded-lg text-white font-semibold text-xs flex items-center space-x-1.5 shadow-sm transition-all active:scale-95 ${
              isIncompatible
                ? 'bg-slate-400 dark:bg-gray-700 cursor-not-allowed opacity-60'
                : isEmulated
                ? 'bg-amber-600 hover:bg-amber-500'
                : 'bg-blue-600 hover:bg-blue-500'
            }`}
          >
            <Download className="w-3.5 h-3.5" />
            <span>{isIncompatible ? 'Incompatible' : isEmulated ? 'Install (Emulated)' : 'Install'}</span>
          </button>
        </div>
      </div>

      {/* Flags Dropdown */}
      {showFlags && (
        <div
          onClick={(e) => e.stopPropagation()}
          className="absolute bottom-14 right-4 bg-white dark:bg-fluent-bg-dark border border-slate-200 dark:border-fluent-border-dark rounded-xl shadow-lg p-3 z-30 space-y-2 text-xs w-52 animate-in fade-in"
        >
          <div className="font-semibold text-slate-900 dark:text-white border-b border-slate-100 dark:border-white/5 pb-1">
            CLI Flags (`--flag`)
          </div>

          <label className="flex items-center space-x-2 text-slate-700 dark:text-gray-300 cursor-pointer">
            <input
              type="checkbox"
              checked={flags.silent}
              onChange={(e) => setFlags({ ...flags, silent: e.target.checked })}
              className="rounded text-blue-600 focus:ring-blue-500"
            />
            <span>--silent (Quiet Install)</span>
          </label>

          <label className="flex items-center space-x-2 text-slate-700 dark:text-gray-300 cursor-pointer">
            <input
              type="checkbox"
              checked={flags.force}
              onChange={(e) => setFlags({ ...flags, force: e.target.checked })}
              className="rounded text-blue-600 focus:ring-blue-500"
            />
            <span>--force (Override Checksum)</span>
          </label>
        </div>
      )}
    </div>
  );
};
