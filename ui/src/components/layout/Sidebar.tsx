import React from 'react';
import { 
  ShoppingBag, 
  RefreshCw, 
  FolderCheck, 
  Stethoscope, 
  Variable, 
  Sliders,
  Terminal,
  Activity,
  HardDrive
} from 'lucide-react';
import { NavigationTab } from '../../types/omniget';

interface SidebarProps {
  currentTab: NavigationTab;
  onNavigate: (tab: NavigationTab) => void;
  outdatedCount?: number;
  doctorWarningCount?: number;
}

export const Sidebar: React.FC<SidebarProps> = ({ 
  currentTab, 
  onNavigate,
  outdatedCount = 0,
  doctorWarningCount = 0
}) => {
  const navItems = [
    { id: 'store' as NavigationTab, label: 'OmniGet', icon: ShoppingBag },
    { id: 'updates' as NavigationTab, label: 'Updates', icon: RefreshCw, badge: outdatedCount > 0 ? outdatedCount : null },
    { id: 'installed' as NavigationTab, label: 'Installed Library', icon: FolderCheck },
    { id: 'doctor' as NavigationTab, label: 'OmniGet Doctor', icon: Stethoscope, tag: doctorWarningCount > 0 ? `${doctorWarningCount} Warn` : 'Health' },
    { id: 'system-monitor' as NavigationTab, label: 'System Monitor', icon: Activity, betaTag: 'BETA' },
    { id: 'env' as NavigationTab, label: 'Env & PATH Manager', icon: Variable },
    { id: 'sync' as NavigationTab, label: 'Backup & Sync', icon: HardDrive },
    { id: 'alias' as NavigationTab, label: 'Shell Aliases', icon: Terminal },
    { id: 'settings' as NavigationTab, label: 'Settings', icon: Sliders },
  ];

  return (
    <aside className="w-56 bg-slate-50/90 dark:bg-fluent-bg-dark/90 border-r border-slate-200 dark:border-fluent-border-dark flex flex-col justify-between p-3 select-none backdrop-blur-mica transition-colors duration-200">
      <div>
        <div className="px-3 py-2 text-[10px] font-semibold tracking-wider text-slate-400 dark:text-gray-500 uppercase font-mono">
          Core Hub
        </div>
        <nav className="space-y-1 mt-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = currentTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => onNavigate(item.id)}
                className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs font-medium transition-all duration-150 ${
                  isActive
                    ? 'bg-blue-600/10 dark:bg-fluent-accent/15 text-blue-600 dark:text-fluent-accent font-semibold border border-blue-500/20 shadow-sm'
                    : 'text-slate-600 dark:text-gray-300 hover:bg-slate-200/60 dark:hover:bg-fluent-bg-hoverDark hover:text-slate-900 dark:hover:text-white'
                }`}
              >
                <div className="flex items-center space-x-2.5">
                  <Icon className={`w-4 h-4 ${isActive ? 'text-blue-600 dark:text-fluent-accent' : 'text-slate-400 dark:text-gray-400'}`} />
                  <span>{item.label}</span>
                </div>

                {item.badge && (
                  <span className="px-1.5 py-0.2 rounded-full text-[10px] font-mono font-bold bg-blue-600 text-white">
                    {item.badge}
                  </span>
                )}

                {item.tag && (
                  <span className={`px-1.5 py-0.2 rounded text-[10px] font-mono font-semibold ${
                    doctorWarningCount > 0 
                      ? 'bg-amber-500/20 text-amber-600 dark:text-amber-400' 
                      : 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400'
                  }`}>
                    {item.tag}
                  </span>
                )}

                {item.betaTag && (
                  <span className="px-1.5 py-0.2 rounded text-[10px] font-mono font-bold uppercase bg-purple-500/15 text-purple-600 dark:text-purple-400 border border-purple-500/30">
                    {item.betaTag}
                  </span>
                )}
              </button>
            );
          })}
        </nav>
      </div>

      {/* Subtle Bottom Status Indicator */}
      <div className="p-2.5 rounded-xl bg-slate-200/50 dark:bg-white/5 border border-slate-200 dark:border-white/5 space-y-1">
        <div className="flex items-center space-x-2 text-[11px] font-medium text-slate-700 dark:text-gray-300">
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
          <span className="font-semibold text-xs">Omniget Engine Active</span>
        </div>
      </div>
    </aside>
  );
};
