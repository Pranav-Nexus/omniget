use std::fs;
use std::path::PathBuf;
use crate::models::OmniGetConfig;

pub fn get_config_path() -> PathBuf {
    if let Some(home) = dirs::home_dir() {
        home.join(".omniget_config.json")
    } else {
        PathBuf::from(".omniget_config.json")
    }
}

pub fn load_config() -> OmniGetConfig {
    let path = get_config_path();
    if path.exists() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(config) = serde_json::from_str::<OmniGetConfig>(&content) {
                return config;
            }
        }
    }
    let default_cfg = OmniGetConfig::default();
    let _ = save_config(&default_cfg);
    default_cfg
}

pub fn save_config(config: &OmniGetConfig) -> Result<(), String> {
    let path = get_config_path();
    let json_str = serde_json::to_string_pretty(config)
        .map_err(|e| format!("Serialization error: {}", e))?;
    fs::write(path, json_str)
        .map_err(|e| format!("Failed to write config file: {}", e))
}
