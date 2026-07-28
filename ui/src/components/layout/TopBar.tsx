import React, { useState, useEffect, useRef } from 'react';
import { Search, Command, Laptop, Minus, Square, X, Download, RefreshCw, Cpu, HardDrive, Monitor, Microchip, Activity, Maximize2, Zap } from 'lucide-react';
import { CATALOG_APPS, CliBridge } from '../../services/cliBridge';
import { Package, SystemInfo } from '../../types/omniget';

interface TopBarProps {
  onSelectPackage: (pkg: Package) => void;
  onNavigate: (tab: any) => void;
}

export const TopBar: React.FC<TopBarProps> = ({ onSelectPackage, onNavigate }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<Package[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [isFlyoutOpen, setIsFlyoutOpen] = useState(false);
  const [isSysSpecsOpen, setIsSysSpecsOpen] = useState(false);
  const [systemInfo, setSystemInfo] = useState<SystemInfo | null>(null);

  const searchInputRef = useRef<HTMLInputElement>(null);
  const flyoutRef = useRef<HTMLDivElement>(null);
  const sysFlyoutRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    CliBridge.fetchSystemInfo().then(info => {
      if (info) setSystemInfo(info);
    });
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        searchInputRef.current?.focus();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (flyoutRef.current && !flyoutRef.current.contains(e.target as Node) && !searchInputRef.current?.contains(e.target as Node)) {
        setIsFlyoutOpen(false);
      }
      if (sysFlyoutRef.current && !sysFlyoutRef.current.contains(e.target as Node)) {
        setIsSysSpecsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  useEffect(() => {
    const q = searchQuery.trim();
    if (!q) {
      setSearchResults([]);
      setIsFlyoutOpen(false);
      return;
    }

    setIsFlyoutOpen(true);
    setIsSearching(true);

    const timer = setTimeout(async () => {
      const liveResults = await CliBridge.fetchSearchPackages(q);
      if (liveResults && liveResults.length > 0) {
        setSearchResults(liveResults.slice(0, 8));
      } else {
        const catResults = CATALOG_APPS.filter(app => 
          app.name.toLowerCase().includes(q.toLowerCase()) || 
          app.publisher.toLowerCase().includes(q.toLowerCase()) ||
          app.id.toLowerCase().includes(q.toLowerCase())
        ).slice(0, 5);
        setSearchResults(catResults);
      }
      setIsSearching(false);
    }, 400);

    return () => clearTimeout(timer);
  }, [searchQuery]);

  return (
    <div className="h-12 border-b border-slate-200 dark:border-fluent-border-dark flex items-center justify-between px-4 bg-white/90 dark:bg-fluent-bg-dark/90 text-slate-900 dark:text-white backdrop-blur-mica z-30 select-none transition-colors duration-200">
      {/* App Branding: OmniGet */}
      <div className="flex items-center space-x-3 w-56">
        <div className="w-7 h-7 rounded-lg bg-gradient-to-tr from-blue-600 to-indigo-500 flex items-center justify-center shadow-md font-bold text-xs text-white">
          OG
        </div>
        <span className="font-bold text-sm tracking-wide text-slate-900 dark:text-white">
          OmniGet
        </span>
      </div>

      {/* Global Search Bar */}
      <div className="relative flex-1 max-w-xl mx-4">
        <div className="relative flex items-center">
          <Search className="w-4 h-4 absolute left-3 text-slate-400 dark:text-gray-400" />
          <input
            ref={searchInputRef}
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            onFocus={() => setIsFlyoutOpen(searchQuery.trim().length > 0)}
            placeholder="Search WinGet, Chocolatey & Scoop packages... (Ctrl+K)"
            className="w-full pl-9 pr-12 py-1.5 text-xs rounded-md bg-slate-100 dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark text-slate-900 dark:text-white focus:outline-none focus:ring-1 focus:ring-fluent-accent transition-all placeholder:text-slate-400 dark:placeholder:text-gray-400"
          />
          <kbd className="absolute right-3 px-1.5 py-0.5 text-[10px] font-mono text-slate-500 dark:text-gray-400 bg-slate-200 dark:bg-gray-800 rounded border border-slate-300 dark:border-gray-700 flex items-center gap-0.5">
            <Command className="w-2.5 h-2.5" /> K
          </kbd>
        </div>

        {/* Instant Search Flyout */}
        {isFlyoutOpen && (
          <div
            ref={flyoutRef}
            className="absolute top-full left-0 right-0 mt-2 bg-white/95 dark:bg-fluent-bg-dark/95 backdrop-blur-xl border border-slate-200 dark:border-fluent-border-dark rounded-xl shadow-lg overflow-hidden z-50 animate-in fade-in duration-150"
          >
            <div className="p-2 border-b border-slate-200 dark:border-fluent-border-dark text-[11px] font-medium text-slate-500 dark:text-gray-400 flex justify-between items-center">
              <span className="flex items-center space-x-1">
                {isSearching && <RefreshCw className="w-3 h-3 animate-spin text-blue-500 dark:text-blue-400 mr-1" />}
                <span>Live Repository Search Results ({searchResults.length})</span>
              </span>
              <span className="text-[10px] text-slate-400 dark:text-gray-500">Press ESC to dismiss</span>
            </div>

            {isSearching ? (
              <div className="p-6 text-center text-xs text-slate-500 dark:text-gray-400 font-mono">
                Searching active repositories (`omniget search {searchQuery}`)...
              </div>
            ) : searchResults.length > 0 ? (
              <div className="divide-y divide-slate-100 dark:divide-fluent-border-dark max-h-80 overflow-y-auto">
                {searchResults.map((pkg) => (
                  <div
                    key={pkg.id}
                    onClick={() => {
                      onSelectPackage(pkg);
                      setIsFlyoutOpen(false);
                      setSearchQuery('');
                    }}
                    className="p-3 hover:bg-slate-50 dark:hover:bg-fluent-bg-hoverDark cursor-pointer flex items-center justify-between group transition-colors"
                  >
                    <div className="flex items-center space-x-3">
                      <div className="w-8 h-8 rounded-lg bg-blue-500/10 border border-blue-500/20 flex items-center justify-center font-bold text-xs text-blue-600 dark:text-blue-400">
                        {pkg.name.charAt(0)}
                      </div>
                      <div>
                        <div className="text-xs font-semibold text-slate-900 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors">
                          {pkg.name}
                        </div>
                        <div className="text-[11px] font-mono text-slate-500 dark:text-gray-400">{pkg.id} • {pkg.version}</div>
                      </div>
                    </div>

                    <div className="flex items-center space-x-2">
                      <span className={`text-[10px] px-2 py-0.5 rounded-full font-mono uppercase font-semibold border ${
                        pkg.source === 'winget' ? 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-500/20' :
                        pkg.source === 'choco' ? 'bg-amber-700/10 text-amber-600 dark:text-amber-500 border-amber-700/20' :
                        'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20'
                      }`}>
                        {pkg.source}
                      </span>
                      <button className="p-1.5 rounded-md bg-blue-600 hover:bg-blue-500 text-white text-xs flex items-center space-x-1">
                        <Download className="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="p-6 text-center text-xs text-slate-500 dark:text-gray-400">
                No packages matching "{searchQuery}" found in active repositories.
              </div>
            )}
          </div>
        )}
      </div>

      {/* Right Tools & Subtle Single System Button */}
      <div className="flex items-center space-x-3">
        <div className="relative" ref={sysFlyoutRef}>
          <button
            onClick={() => setIsSysSpecsOpen(!isSysSpecsOpen)}
            className={`px-2.5 py-1 rounded-md border text-[11px] font-medium flex items-center space-x-1.5 transition-all ${
              isSysSpecsOpen
                ? 'bg-blue-600 text-white border-blue-500 shadow-sm'
                : 'bg-slate-100 dark:bg-white/5 hover:bg-slate-200 dark:hover:bg-white/10 border-slate-200 dark:border-white/10 text-slate-700 dark:text-gray-300'
            }`}
          >
            <Laptop className="w-3.5 h-3.5 text-blue-500 dark:text-blue-400" />
            <span className="font-mono text-[11px]">System</span>
          </button>

          {/* System Specs Flyout Card */}
          {isSysSpecsOpen && (
            <div className="absolute right-0 top-full mt-2 w-80 bg-white dark:bg-fluent-bg-dark border border-slate-200 dark:border-fluent-border-dark rounded-2xl shadow-2xl p-4 z-50 animate-in fade-in slide-in-from-top-2 duration-150 space-y-3">
              <div className="flex items-center justify-between border-b border-slate-100 dark:border-white/5 pb-2">
                <div className="flex items-center space-x-2 text-xs font-bold text-slate-900 dark:text-white">
                  <Activity className="w-4 h-4 text-blue-500 dark:text-blue-400" />
                  <span>Hardware Specifications</span>
                </div>
                <span className="px-2 py-0.5 rounded text-[10px] font-mono font-bold bg-blue-500/20 text-blue-600 dark:text-blue-300 uppercase">
                  {systemInfo?.arch || 'x64'}
                </span>
              </div>

              {systemInfo ? (
                <div className="space-y-2 text-xs">
                  {/* OS */}
                  <div className="p-2 rounded-xl bg-slate-50 dark:bg-white/5 border border-slate-100 dark:border-white/5 flex items-start space-x-2.5">
                    <Monitor className="w-4 h-4 text-indigo-500 shrink-0 mt-0.5" />
                    <div>
                      <div className="text-[10px] uppercase font-bold text-slate-400 dark:text-gray-500">Operating System</div>
                      <div className="font-semibold text-slate-800 dark:text-gray-200">{systemInfo.osName}</div>
                      <div className="text-[10px] font-mono text-slate-500 dark:text-gray-400">Build {systemInfo.osBuild}</div>
                    </div>
                  </div>

                  {/* CPU */}
                  <div className="p-2 rounded-xl bg-slate-50 dark:bg-white/5 border border-slate-100 dark:border-white/5 flex items-start space-x-2.5">
                    <Cpu className="w-4 h-4 text-blue-500 shrink-0 mt-0.5" />
                    <div>
                      <div className="text-[10px] uppercase font-bold text-slate-400 dark:text-gray-500">Processor (CPU)</div>
                      <div className="font-semibold text-slate-800 dark:text-gray-200 line-clamp-1">{systemInfo.cpu}</div>
                      <div className="text-[10px] font-mono text-slate-500 dark:text-gray-400">Architecture: {systemInfo.arch}</div>
                    </div>
                  </div>

                  {/* GPU Card */}
                  <div className="p-2 rounded-xl bg-slate-50 dark:bg-white/5 border border-slate-100 dark:border-white/5 flex items-start space-x-2.5">
                    <Zap className="w-4 h-4 text-emerald-500 shrink-0 mt-0.5" />
                    <div>
                      <div className="text-[10px] uppercase font-bold text-slate-400 dark:text-gray-500">Graphics (GPU)</div>
                      <div className="font-semibold text-slate-800 dark:text-gray-200 line-clamp-2">{systemInfo.gpu}</div>
                    </div>
                  </div>

                  {/* RAM */}
                  <div className="p-2 rounded-xl bg-slate-50 dark:bg-white/5 border border-slate-100 dark:border-white/5 flex items-start space-x-2.5">
                    <Microchip className="w-4 h-4 text-purple-500 shrink-0 mt-0.5" />
                    <div>
                      <div className="text-[10px] uppercase font-bold text-slate-400 dark:text-gray-500">Memory (RAM)</div>
                      <div className="font-semibold text-slate-800 dark:text-gray-200">{systemInfo.ramTotal} Total</div>
                      <div className="text-[10px] font-mono text-emerald-600 dark:text-emerald-400">{systemInfo.ramFree} Available</div>
                    </div>
                  </div>

                  {/* Storage */}
                  <div className="p-2 rounded-xl bg-slate-50 dark:bg-white/5 border border-slate-100 dark:border-white/5 flex items-start space-x-2.5">
                    <HardDrive className="w-4 h-4 text-indigo-500 shrink-0 mt-0.5" />
                    <div>
                      <div className="text-[10px] uppercase font-bold text-slate-400 dark:text-gray-500">System Storage (C:)</div>
                      <div className="font-semibold text-slate-800 dark:text-gray-200">{systemInfo.storageTotal} Capacity</div>
                      <div className="text-[10px] font-mono text-emerald-600 dark:text-emerald-400">{systemInfo.storageFree} Free Space</div>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="p-4 text-center text-xs text-slate-400 dark:text-gray-500 font-mono">
                  Loading system hardware specifications...
                </div>
              )}

              {/* Small Subtle Action Button */}
              <button
                onClick={() => {
                  onNavigate('system-monitor');
                  setIsSysSpecsOpen(false);
                }}
                className="w-full mt-2 py-1.5 px-3 rounded-lg bg-slate-100 dark:bg-white/5 hover:bg-slate-200 dark:hover:bg-white/10 text-slate-700 dark:text-gray-300 font-semibold text-[11px] border border-slate-200 dark:border-white/10 flex items-center justify-center space-x-1.5 transition-colors"
              >
                <span>Full System Monitor & App Control</span>
                <Maximize2 className="w-3 h-3 text-slate-400" />
              </button>
            </div>
          )}
        </div>

        {/* Windows Window Controls */}
        <div className="flex items-center pl-2 border-l border-slate-200 dark:border-fluent-border-dark">
          <button className="p-2 hover:bg-slate-200 dark:hover:bg-white/10 text-slate-500 dark:text-gray-400 hover:text-slate-900 dark:hover:text-white transition-colors">
            <Minus className="w-3 h-3" />
          </button>
          <button className="p-2 hover:bg-slate-200 dark:hover:bg-white/10 text-slate-500 dark:text-gray-400 hover:text-slate-900 dark:hover:text-white transition-colors">
            <Square className="w-2.5 h-2.5" />
          </button>
          <button className="p-2 hover:bg-red-600 text-slate-500 dark:text-gray-400 hover:text-white transition-colors">
            <X className="w-3 h-3" />
          </button>
        </div>
      </div>
    </div>
  );
};
