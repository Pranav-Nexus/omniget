import React, { useState } from 'react';
import { X, Download, ShieldCheck, Star, ExternalLink, Globe, HardDrive } from 'lucide-react';
import { Package, PackageManagerSource, CliFlags } from '../../types/omniget';

interface AppDetailsModalProps {
  app: Package | null;
  onClose: () => void;
  onInstall: (pkg: Package, flags?: CliFlags) => void;
}

export const AppDetailsModal: React.FC<AppDetailsModalProps> = ({ app, onClose, onInstall }) => {
  if (!app) return null;

  const [selectedSource, setSelectedSource] = useState<PackageManagerSource>(app.source);
  const [flags, setFlags] = useState<CliFlags>({ force: false, dryRun: false, silent: true });

  const handleInstallClick = () => {
    onInstall({ ...app, source: selectedSource }, flags);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-md flex items-center justify-center p-4 z-50 animate-in fade-in duration-150">
      <div className="bg-fluent-bg-dark dark:bg-fluent-bg-dark light:bg-white border border-fluent-border-dark dark:border-fluent-border-dark light:border-gray-300 w-full max-w-2xl rounded-2xl p-6 shadow-mica relative space-y-6">
        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-2 rounded-full hover:bg-white/10 text-gray-400 hover:text-white transition-colors"
        >
          <X className="w-5 h-5" />
        </button>

        {/* Modal Header */}
        <div className="flex items-start space-x-5">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-blue-600 to-indigo-600 flex items-center justify-center font-bold text-2xl text-white shadow-lg">
            {app.name.charAt(0)}
          </div>

          <div className="space-y-1">
            <h2 className="text-xl font-bold text-white dark:text-white light:text-gray-900">
              {app.name}
            </h2>
            <div className="text-xs text-gray-400 flex items-center space-x-2">
              <span>{app.publisher}</span>
              <span>•</span>
              <span className="flex items-center text-amber-400 font-semibold">
                <Star className="w-3.5 h-3.5 fill-amber-400 mr-1" />
                {app.rating || '4.8'}
              </span>
            </div>
            <div className="text-[11px] text-emerald-400 flex items-center space-x-1 pt-1">
              <ShieldCheck className="w-3.5 h-3.5" />
              <span>Verified Package ({app.id})</span>
            </div>
          </div>
        </div>

        {/* Multi-Source Selector & Install Action */}
        <div className="p-4 rounded-xl bg-white/5 border border-white/10 flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
          <div>
            <label className="text-[11px] font-semibold text-gray-400 block mb-1">
              Select Package Manager Source:
            </label>
            <div className="flex items-center space-x-2">
              {(app.sourcesAvailable || [app.source]).map((src) => (
                <button
                  key={src}
                  onClick={() => setSelectedSource(src)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-mono font-bold uppercase transition-all border ${
                    selectedSource === src
                      ? 'bg-blue-600 text-white border-blue-400 shadow-md'
                      : 'bg-white/5 text-gray-400 border-white/10 hover:text-white'
                  }`}
                >
                  {src}
                </button>
              ))}
            </div>
          </div>

          <button
            onClick={handleInstallClick}
            className="px-6 py-3 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs flex items-center justify-center space-x-2 shadow-lg shadow-blue-600/30 transition-all hover:scale-105"
          >
            <Download className="w-4 h-4" />
            <span>Install via {selectedSource.toUpperCase()}</span>
          </button>
        </div>

        {/* Description & Overview */}
        <div className="space-y-2">
          <h3 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">
            About this Application
          </h3>
          <p className="text-xs text-gray-300 leading-relaxed bg-white/5 p-4 rounded-xl border border-white/5">
            {app.description}
          </p>
        </div>

        {/* Package Specifications Grid */}
        <div className="grid grid-cols-2 md:grid-cols-3 gap-3 text-xs">
          <div className="p-3 rounded-xl bg-white/5 border border-white/5">
            <span className="text-[10px] text-gray-400 block">Version</span>
            <span className="font-mono text-white font-semibold">{app.version}</span>
          </div>

          <div className="p-3 rounded-xl bg-white/5 border border-white/5">
            <span className="text-[10px] text-gray-400 block">Category</span>
            <span className="text-white font-semibold">{app.category}</span>
          </div>

          <div className="p-3 rounded-xl bg-white/5 border border-white/5">
            <span className="text-[10px] text-gray-400 block">UAC Scope</span>
            <span className="text-emerald-400 font-semibold">User Scope (Non-Admin)</span>
          </div>
        </div>

        {/* CLI Command Preview */}
        <div className="p-3 rounded-xl bg-black/50 border border-white/10 font-mono text-[11px] flex items-center justify-between text-gray-300">
          <span>omniget install {app.id} --pm {selectedSource}</span>
          <span className="text-[9px] text-blue-400">PowerShell</span>
        </div>
      </div>
    </div>
  );
};
