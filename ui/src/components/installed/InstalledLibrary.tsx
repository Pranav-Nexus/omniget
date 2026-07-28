import React, { useState, useEffect } from 'react';
import { PackageCheck, Search, Trash2, Shield, ToggleLeft, ToggleRight, ArrowUpDown, RefreshCw } from 'lucide-react';
import { CliBridge } from '../../services/cliBridge';
import { InstalledPackage, CliFlags } from '../../types/omniget';

interface InstalledLibraryProps {
  onUninstallPackage: (pkg: InstalledPackage, flags?: CliFlags) => void;
}

export const InstalledLibrary: React.FC<InstalledLibraryProps> = ({ onUninstallPackage }) => {
  const [installedList, setInstalledList] = useState<InstalledPackage[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [isSilentMode, setIsSilentMode] = useState(true);
  const [sortField, setSortField] = useState<'name' | 'source' | 'installDate'>('name');
  const [sortAsc, setSortAsc] = useState(true);

  const loadLivePackages = async () => {
    setLoading(true);
    const livePkgs = await CliBridge.fetchInstalledPackages();
    setInstalledList(livePkgs);
    setLoading(false);
  };

  useEffect(() => {
    loadLivePackages();
  }, []);

  const filteredList = installedList.filter(pkg =>
    pkg.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    pkg.publisher.toLowerCase().includes(searchQuery.toLowerCase()) ||
    pkg.id.toLowerCase().includes(searchQuery.toLowerCase())
  ).sort((a, b) => {
    const valA = a[sortField] || '';
    const valB = b[sortField] || '';
    return sortAsc ? valA.localeCompare(valB) : valB.localeCompare(valA);
  });

  const handleSort = (field: 'name' | 'source' | 'installDate') => {
    if (sortField === field) {
      setSortAsc(!sortAsc);
    } else {
      setSortField(field);
      setSortAsc(true);
    }
  };

  const handleUninstall = (pkg: InstalledPackage) => {
    onUninstallPackage(pkg, { silent: isSilentMode });
    setInstalledList(prev => prev.filter(p => p.id !== pkg.id));
  };

  return (
    <div className="p-6 md:p-8 space-y-6 overflow-y-auto h-full">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-fluent-border-dark dark:border-fluent-border-dark light:border-gray-200 pb-6">
        <div>
          <h1 className="text-xl font-bold text-white dark:text-white light:text-gray-900 flex items-center space-x-2">
            <PackageCheck className="w-6 h-6 text-blue-400" />
            <span>Installed Library (Live System Audit)</span>
          </h1>
          <p className="text-xs text-gray-400 mt-1">
            Real packages tracked on your system via WinGet, Chocolatey, and Scoop.
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <button
            onClick={loadLivePackages}
            className="px-3 py-2 rounded-xl bg-white/5 hover:bg-white/10 text-gray-300 text-xs font-medium border border-white/10 flex items-center space-x-1.5 transition-all"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh Library</span>
          </button>

          {/* Silent Uninstall Toggle Switch */}
          <div className="p-2.5 rounded-xl bg-white/5 border border-white/10 flex items-center space-x-3">
            <Shield className="w-4 h-4 text-emerald-400" />
            <div className="text-xs">
              <span className="font-semibold text-white block">Silent Uninstall Mode</span>
            </div>
            <button
              onClick={() => setIsSilentMode(!isSilentMode)}
              className="text-blue-400 focus:outline-none pl-2"
            >
              {isSilentMode ? (
                <ToggleRight className="w-7 h-7 text-blue-500" />
              ) : (
                <ToggleLeft className="w-7 h-7 text-gray-500" />
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Search Filter Bar */}
      <div className="relative">
        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Filter installed packages by name, publisher, or ID..."
          className="w-full pl-9 pr-4 py-2 text-xs rounded-xl bg-fluent-bg-cardDark border border-fluent-border-dark text-white focus:outline-none focus:ring-1 focus:ring-fluent-accent"
        />
      </div>

      {/* Table View */}
      <div className="rounded-2xl border border-fluent-border-dark bg-fluent-bg-dark/50 backdrop-blur-xl overflow-hidden shadow-mica">
        <table className="w-full text-left text-xs">
          <thead className="bg-white/5 border-b border-fluent-border-dark text-gray-400 font-semibold uppercase text-[10px] tracking-wider select-none">
            <tr>
              <th onClick={() => handleSort('name')} className="p-4 cursor-pointer hover:text-white">
                <div className="flex items-center space-x-1">
                  <span>App Name & ID</span>
                  <ArrowUpDown className="w-3 h-3" />
                </div>
              </th>
              <th className="p-4">Installed Version</th>
              <th onClick={() => handleSort('source')} className="p-4 cursor-pointer hover:text-white">
                <div className="flex items-center space-x-1">
                  <span>Source</span>
                  <ArrowUpDown className="w-3 h-3" />
                </div>
              </th>
              <th className="p-4 text-right">Actions</th>
            </tr>
          </thead>

          <tbody className="divide-y divide-fluent-border-dark text-gray-200">
            {loading ? (
              <tr>
                <td colSpan={4} className="p-8 text-center text-xs text-gray-400 font-mono">
                  <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-blue-400" />
                  Querying live package catalog via `omniget list`...
                </td>
              </tr>
            ) : filteredList.length === 0 ? (
              <tr>
                <td colSpan={4} className="p-8 text-center text-xs text-gray-400">
                  No installed packages matching filter.
                </td>
              </tr>
            ) : (
              filteredList.map((item) => (
                <tr key={item.id} className="hover:bg-white/5 transition-colors">
                  <td className="p-4">
                    <div className="font-semibold text-white">{item.name}</div>
                    <div className="text-[11px] font-mono text-gray-400">{item.id}</div>
                  </td>

                  <td className="p-4 font-mono text-gray-300">{item.version}</td>

                  <td className="p-4">
                    <span className={`px-2.5 py-1 rounded text-[10px] font-mono uppercase font-bold border ${
                      item.source === 'winget' ? 'bg-blue-500/10 text-blue-400 border-blue-500/20' :
                      item.source === 'choco' ? 'bg-amber-700/10 text-amber-500 border-amber-700/20' :
                      'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                    }`}>
                      {item.source}
                    </span>
                  </td>

                  <td className="p-4 text-right">
                    <button
                      onClick={() => handleUninstall(item)}
                      className="px-3 py-1.5 rounded-lg bg-red-600/20 hover:bg-red-600 text-red-300 hover:text-white font-medium text-xs border border-red-500/30 transition-all flex items-center space-x-1.5 ml-auto"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                      <span>Uninstall</span>
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
