import React from 'react';
import { Terminal, Activity } from 'lucide-react';

interface FooterProps {
  doctorStatus: 'healthy' | 'warning' | 'error';
  isTerminalOpen: boolean;
  onToggleTerminal: () => void;
  onOpenDoctor: () => void;
  logCount: number;
}

export const Footer: React.FC<FooterProps> = ({
  doctorStatus,
  isTerminalOpen,
  onToggleTerminal,
  onOpenDoctor,
  logCount
}) => {
  return (
    <div className="h-9 border-t border-gray-200 dark:border-fluent-border-dark bg-white/90 dark:bg-fluent-bg-dark/95 backdrop-blur-md px-4 flex items-center justify-between text-xs text-gray-600 dark:text-gray-400 select-none z-20 transition-colors duration-200">
      {/* OmniGet Doctor Status */}
      <button
        onClick={onOpenDoctor}
        className="flex items-center space-x-2 hover:text-gray-900 dark:hover:text-white transition-colors py-1 px-2 rounded-md hover:bg-gray-100 dark:hover:bg-white/5"
      >
        <span className="relative flex h-2.5 w-2.5">
          <span className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${
            doctorStatus === 'healthy' ? 'bg-emerald-400' : doctorStatus === 'warning' ? 'bg-amber-400' : 'bg-red-400'
          }`}></span>
          <span className={`relative inline-flex rounded-full h-2.5 w-2.5 ${
            doctorStatus === 'healthy' ? 'bg-emerald-500' : doctorStatus === 'warning' ? 'bg-amber-500' : 'bg-red-500'
          }`}></span>
        </span>

        <span className="text-[11px] font-medium flex items-center space-x-1">
          <Activity className="w-3 h-3 text-gray-400" />
          <span>Doctor Status:</span>
          <span className={`font-semibold ${
            doctorStatus === 'healthy' ? 'text-emerald-600 dark:text-emerald-400' : doctorStatus === 'warning' ? 'text-amber-600 dark:text-amber-400' : 'text-red-600 dark:text-red-400'
          }`}>
            {doctorStatus === 'healthy' ? 'System Healthy' : doctorStatus === 'warning' ? 'Warnings Found' : 'Issues Detected'}
          </span>
        </span>
      </button>

      {/* Terminal Drawer Toggle */}
      <button
        onClick={onToggleTerminal}
        className={`flex items-center space-x-2 py-1 px-2.5 rounded-md text-[11px] font-mono transition-all ${
          isTerminalOpen
            ? 'bg-blue-600/10 dark:bg-blue-600/20 text-blue-600 dark:text-blue-400 border border-blue-500/30 font-semibold'
            : 'hover:bg-gray-100 dark:hover:bg-white/10 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'
        }`}
      >
        <Terminal className="w-3.5 h-3.5" />
        <span>Terminal Log</span>
        {logCount > 0 && (
          <span className="ml-1.5 px-1.5 py-0.2 bg-blue-500/20 text-blue-600 dark:text-blue-300 rounded text-[10px] border border-blue-500/30">
            {logCount}
          </span>
        )}
      </button>
    </div>
  );
};
