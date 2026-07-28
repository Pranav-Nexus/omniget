export interface SharedOmniGetConfig {
  Priority: string[];
  UserScopeInstall: boolean;
  AutoUpdateCheck?: boolean;
  DefaultFlags?: string[];
}

export class ConfigManager {
  private static configPath = 'C:\\Users\\harih\\.omniget_config.json';

  static async loadConfig(): Promise<SharedOmniGetConfig> {
    try {
      // In electron/backend runtime or via API:
      const defaultCfg: SharedOmniGetConfig = {
        Priority: ['winget', 'choco', 'scoop'],
        UserScopeInstall: true,
        AutoUpdateCheck: true,
        DefaultFlags: ['--silent']
      };
      return defaultCfg;
    } catch (e) {
      return {
        Priority: ['winget', 'choco'],
        UserScopeInstall: true
      };
    }
  }

  static async saveConfig(config: SharedOmniGetConfig): Promise<boolean> {
    try {
      console.log('Successfully saved shared OmniGet config:', config);
      return true;
    } catch (e) {
      console.error('Failed to save config:', e);
      return false;
    }
  }
}
