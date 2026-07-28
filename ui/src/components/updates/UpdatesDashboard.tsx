import React, { useState, useEffect } from 'react';
import { RefreshCw, Lock, CheckSquare, Square, ArrowUpRight, CheckCircle2, Filter } from 'lucide-react';
import { CliBridge } from '../../services/cliBridge';
import { PackageUpdate, CliFlags } from '../../types/omniget';

interface UpdatesDashboardProps {
  onUpdatePackages: (updates: PackageUpdate[], flags?: CliFlags) => void;
  onOutdatedCountChange?: (count: number) => void;
}

export const UpdatesDashboard: React.FC<UpdatesDashboardProps> = ({ 
  onUpdatePackages,
  onOutdatedCountChange 
}) => {
  const [updates, setUpdates] = useState<PackageUpdate[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [filterSource, setFilterSource] = useState<string>('All');

  const fetchLiveOutdated = async () => {
    setLoading(true);
    const liveUpdates = await CliBridge.fetchOutdatedPackages();
    setUpdates(liveUpdates);
    if (onOutdatedCountChange) {
      onOutdatedCountChange(liveUpdates.length);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchLiveOutdated();
  }, []);

  const toggleSelect = (id: string) => {
    setUpdates(prev => prev.map(up => {
      if (up.id === id && !up.isPinned) {
        return { ...up, isSelected: !up.isSelected };
      }
      return up;
    }));
  };

  const toggleSelectAll = () => {
    const selectable = updates.filter(u => !u.isPinned);
    const allSelected = selectable.every(u => u.isSelected);
    setUpdates(prev => prev.map(up => up.isPinned ? up : { ...up, isSelected: !allSelected }));
  };

  const togglePin = (id: string) => {
    setUpdates(prev => prev.map(up => {
      if (up.id === id) {
        const nextPin = !up.isPinned;
        return { ...up, isPinned: nextPin, isSelected: nextPin ? false : up.isSelected };
      }
      return up;
    }));
  };

  const selectedUpdates = updates.filter(u => u.isSelected && !u.isPinned);
  const unpinnedCount = updates.filter(u => !u.isPinned).length;

  let buttonLabel = 'Update All';
  if (selectedUpdates.length === 1) {
    buttonLabel = `Update ${selectedUpdates[0].name}`;
  } else if (selectedUpdates.length > 1 && selectedUpdates.length < unpinnedCount) {
    buttonLabel = `Update Selected (${selectedUpdates.length})`;
  } else if (selectedUpdates.length === unpinnedCount && unpinnedCount > 0) {
    buttonLabel = 'Update All';
  }

  const filteredUpdates = filterSource === 'All' 
    ? updates 
    : updates.filter(u => u.source === filterSource);

  return (
    <div className="p-6 md:p-8 space-y-6 overflow-y-auto h-full">
      {/* Header & Dynamic Action Button */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-gray-200 dark:border-fluent-border-dark pb-6">
        <div>
          <h1 className="text-xl font-bold text-gray-900 dark:text-white flex items-center space-x-2">
            <RefreshCw className="w-6 h-6 text-blue-500 dark:text-blue-400" />
            <span>Updates Dashboard (Live System Check)</span>
          </h1>
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
            Scans system for outdated software across WinGet, Chocolatey, and Scoop.
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <button
            onClick={fetchLiveOutdated}
            disabled={loading}
            className="px-3 py-2 rounded-xl bg-gray-100 dark:bg-white/5 hover:bg-gray-200 dark:hover:bg-white/10 text-gray-700 dark:text-gray-300 text-xs font-medium border border-gray-200 dark:border-white/10 flex items-center space-x-1.5 transition-all"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span>{loading ? 'Scanning Outdated...' : 'Check Outdated'}</span>
          </button>

          <button
            disabled={selectedUpdates.length === 0 || loading}
            onClick={() => onUpdatePackages(selectedUpdates)}
            className="px-6 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 disabled:opacity-40 disabled:hover:bg-blue-600 text-white font-semibold text-xs flex items-center space-x-2 shadow-lg shadow-blue-600/30 transition-all active:scale-95"
          >
            <ArrowUpRight className="w-4 h-4" />
            <span>{buttonLabel}</span>
          </button>
        </div>
      </div>

      {/* Filter Bar & Select All Header */}
      <div className="flex items-center justify-between text-xs text-gray-500 dark:text-gray-400">
        <div className="flex items-center space-x-2">
          <button
            onClick={toggleSelectAll}
            disabled={loading || updates.length === 0}
            className="flex items-center space-x-2 text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white transition-colors"
          >
            {selectedUpdates.length === unpinnedCount && unpinnedCount > 0 ? (
              <CheckSquare className="w-4 h-4 text-blue-500 dark:text-blue-400" />
            ) : (
              <Square className="w-4 h-4 text-gray-400 dark:text-gray-500" />
            )}
            <span className="font-medium">Select All</span>
          </button>
          <span>•</span>
          <span>{selectedUpdates.length} of {updates.length} selected</span>
        </div>

        <div className="flex items-center space-x-2">
          <Filter className="w-3.5 h-3.5 text-gray-400" />
          <span className="text-gray-500 dark:text-gray-400">Filter Source:</span>
          {['All', 'winget', 'choco', 'scoop'].map((src) => (
            <button
              key={src}
              onClick={() => setFilterSource(src)}
              className={`px-2.5 py-1 rounded-lg text-[11px] font-mono uppercase font-bold transition-all ${
                filterSource === src
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 dark:bg-white/5 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'
              }`}
            >
              {src}
            </button>
          ))}
        </div>
      </div>

      {/* Updates Table Layout */}
      <div className="rounded-2xl border border-gray-200 dark:border-fluent-border-dark bg-white dark:bg-fluent-bg-dark/50 backdrop-blur-xl overflow-hidden shadow-sm dark:shadow-mica">
        <table className="w-full text-left text-xs">
          <thead className="bg-gray-50 dark:bg-white/5 border-b border-gray-200 dark:border-fluent-border-dark text-gray-500 dark:text-gray-400 font-semibold uppercase text-[10px] tracking-wider">
            <tr>
              <th className="p-4 w-12 text-center">Select</th>
              <th className="p-4">App Name & ID</th>
              <th className="p-4">Current Version</th>
              <th className="p-4">New Version</th>
              <th className="p-4">Source</th>
              <th className="p-4 text-right">Actions</th>
            </tr>
          </thead>

          <tbody className="divide-y divide-gray-200 dark:divide-fluent-border-dark text-gray-800 dark:text-gray-200">
            {loading ? (
              <tr>
                <td colSpan={6} className="p-8 text-center text-xs text-gray-500 dark:text-gray-400 font-mono">
                  <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-blue-500 dark:text-blue-400" />
                  Running system outdated scan (`winget upgrade` / `choco outdated`)...
                </td>
              </tr>
            ) : filteredUpdates.length === 0 ? (
              <tr>
                <td colSpan={6} className="p-8 text-center text-xs text-gray-600 dark:text-gray-300 space-y-2">
                  <CheckCircle2 className="w-6 h-6 text-emerald-500 dark:text-emerald-400 mx-auto" />
                  <div className="font-semibold text-sm text-gray-900 dark:text-white">All Packages Up to Date!</div>
                  <div className="text-gray-500 dark:text-gray-400 text-[11px]">No outdated software detected on this system.</div>
                </td>
              </tr>
            ) : (
              filteredUpdates.map((item) => (
                <tr 
                  key={item.id}
                  className={`hover:bg-gray-50 dark:hover:bg-white/5 transition-colors ${
                    item.isPinned ? 'opacity-60 bg-red-500/5' : item.isSelected ? 'bg-blue-500/5' : ''
                  }`}
                >
                  <td className="p-4 text-center">
                    {item.isPinned ? (
                      <div title="Version locked - Pinned to prevent accidental updates">
                        <Lock className="w-4 h-4 text-amber-500 mx-auto" />
                      </div>
                    ) : (
                      <button onClick={() => toggleSelect(item.id)} className="focus:outline-none">
                        {item.isSelected ? (
                          <CheckSquare className="w-4 h-4 text-blue-500 dark:text-blue-400 mx-auto" />
                        ) : (
                          <Square className="w-4 h-4 text-gray-400 dark:text-gray-500 mx-auto" />
                        )}
                      </button>
                    )}
                  </td>

                  <td className="p-4">
                    <div className="font-semibold text-gray-900 dark:text-white">{item.name}</div>
                    <div className="text-[11px] font-mono text-gray-500 dark:text-gray-400">{item.id}</div>
                  </td>

                  <td className="p-4 font-mono text-gray-500 dark:text-gray-400">{item.currentVersion}</td>

                  <td className="p-4 font-mono text-emerald-600 dark:text-emerald-400 font-semibold flex items-center space-x-1">
                    <span>{item.newVersion}</span>
                    <span className="text-[10px] px-1.5 py-0.2 rounded bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 font-sans">
                      NEW
                    </span>
                  </td>

                  <td className="p-4">
                    <span className={`px-2.5 py-1 rounded text-[10px] font-mono uppercase font-bold border ${
                      item.source === 'winget' ? 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-500/20' :
                      item.source === 'choco' ? 'bg-amber-700/10 text-amber-600 dark:text-amber-500 border-amber-700/20' :
                      'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20'
                    }`}>
                      {item.source}
                    </span>
                  </td>

                  <td className="p-4 text-right space-x-2">
                    <button
                      onClick={() => togglePin(item.id)}
                      title={item.isPinned ? 'Unlock Version' : 'Lock Version'}
                      className={`p-1.5 rounded-lg border transition-colors ${
                        item.isPinned 
                          ? 'bg-amber-500/20 text-amber-600 dark:text-amber-400 border-amber-500/40' 
                          : 'bg-gray-100 dark:bg-white/5 text-gray-500 dark:text-gray-400 border-gray-200 dark:border-white/10 hover:text-gray-900 dark:hover:text-white'
                      }`}
                    >
                      <Lock className="w-3.5 h-3.5" />
                    </button>

                    <button
                      disabled={item.isPinned}
                      onClick={() => onUpdatePackages([item])}
                      className="px-3 py-1.5 rounded-lg bg-blue-600/20 hover:bg-blue-600 disabled:opacity-30 text-blue-700 dark:text-blue-300 hover:text-white font-medium text-xs border border-blue-500/30 transition-all"
                    >
                      Update
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
