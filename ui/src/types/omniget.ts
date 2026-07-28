export type PackageSource = 'winget' | 'choco' | 'scoop' | 'pip' | 'npm' | 'cargo';
export type PackageManagerSource = PackageSource;

export type NavigationTab = 
  | 'store' 
  | 'updates' 
  | 'installed' 
  | 'doctor' 
  | 'env' 
  | 'sync' 
  | 'alias' 
  | 'settings'
  | 'system-monitor';

export interface DiskInfo {
  deviceId: string;
  totalGB: string;
  freeGB: string;
  usedGB: string;
  usedPercent: number;
  mediaType?: string;
}

export interface GpuCardInfo {
  name: string;
  vram: string;
  driverVersion: string;
  videoProcessor: string;
  resolution: string;
  isDiscrete?: boolean;
}

export interface RamModuleDetail {
  bank: string;
  capacity: string;
  manufacturer: string;
  partNumber: string;
  speedMHz: string;
  formFactor: string;
}

export interface NetworkAdapterInfo {
  name: string;
  mac: string;
  speed: string;
  status: string;
  type: string;
}

export interface DisplayMonitorInfo {
  name: string;
  resolution: string;
  status: string;
}

export interface UsbDeviceInfo {
  name: string;
  status: string;
  deviceClass: string;
}

export interface AudioDeviceInfo {
  name: string;
  status: string;
  manufacturer: string;
}

export interface PrivacyAuditEntry {
  id: string;
  timestamp: string;
  processName: string;
  deviceType: 'Webcam' | 'Microphone' | 'Location API';
  status: 'Active' | 'Closed';
  appPath: string;
}

export interface SystemInfo {
  cpu: string;
  cores?: number;
  threads?: number;
  maxClock?: string;
  socket?: string;
  l3Cache?: string;
  cpuDriver?: string;
  arch: string;
  osName: string;
  osBuild: string;
  uptimeHours?: string;
  ramTotal: string;
  ramFree: string;
  ramUsedPercent?: number;
  ramSpeed?: string;
  ramModules?: RamModuleDetail[];
  gpus?: GpuCardInfo[];
  gpu: string;
  gpuDriver?: string;
  cpuLoadPercent?: number;
  cpuTempC?: number;
  gpuTempC?: number;
  storageTotal: string;
  storageFree: string;
  networkAdapter?: string;
  netAdapters?: NetworkAdapterInfo[];
  displays?: DisplayMonitorInfo[];
  usbDevices?: UsbDeviceInfo[];
  audioDevices?: AudioDeviceInfo[];
  motherboard?: string;
  biosVersion?: string;
  disks?: DiskInfo[];
}

export interface Package {
  id: string;
  name: string;
  publisher: string;
  description: string;
  version: string;
  source: PackageSource;
  sourcesAvailable: PackageSource[];
  architecture?: 'x64' | 'x86' | 'arm64' | 'universal';
  architectureAvailable?: string[];
  category: string;
  icon?: string;
  screenshots?: string[];
  rating?: number;
  featured?: boolean;
  downloads?: string;
}

export interface InstalledPackage {
  id: string;
  name: string;
  publisher: string;
  version: string;
  source: PackageSource;
  installDate?: string;
  size?: string;
}

export interface PackageUpdate {
  id: string;
  name: string;
  publisher: string;
  currentVersion: string;
  newVersion: string;
  source: PackageSource;
  isPinned?: boolean;
  isSelected?: boolean;
}

export interface DoctorCheck {
  id: string;
  name: string;
  category: string;
  description: string;
  status: 'healthy' | 'warning' | 'error' | 'available';
  details: string;
  fixable: boolean;
  fixAction?: string;
  isDismissed?: boolean;
  isSnoozed?: boolean;
  snoozedUntil?: string | null;
}

export interface EnvVariable {
  name: string;
  value: string;
  scope: 'user' | 'system';
}

export interface PathEntry {
  id: string;
  path: string;
  scope: 'user' | 'system';
  exists: boolean;
  isDuplicate: boolean;
}

export interface ShellAlias {
  id: string;
  name: string;
  command: string;
  profilePath: string;
}

export interface CliFlags {
  silent?: boolean;
  force?: boolean;
  userScope?: boolean;
  dryRun?: boolean;
  ignoreChecksum?: boolean;
  customLocation?: string;
}

export interface TerminalLog {
  id: string;
  timestamp: string;
  level: 'info' | 'warn' | 'error' | 'success';
  text: string;
}
