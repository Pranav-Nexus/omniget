use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Package {
    pub id: String,
    pub name: String,
    pub publisher: String,
    pub description: String,
    pub version: String,
    pub source: String,
    pub sources_available: Option<Vec<String>>,
    pub category: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageUpdate {
    pub id: String,
    pub name: String,
    pub publisher: String,
    pub current_version: String,
    pub new_version: String,
    pub source: String,
    pub is_pinned: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstalledPackage {
    pub id: String,
    pub name: String,
    pub publisher: String,
    pub version: String,
    pub source: String,
    pub install_date: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CliFlags {
    pub force: Option<bool>,
    pub dry_run: Option<bool>,
    pub silent: Option<bool>,
    pub pm: Option<String>,
    pub ignore_checksum: Option<bool>,
    pub system: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DoctorCheck {
    pub id: String,
    pub name: String,
    pub category: String,
    pub description: String,
    pub status: String,
    pub details: String,
    pub fixable: bool,
    pub fix_action: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnvVariable {
    pub name: String,
    pub value: String,
    pub scope: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PathEntry {
    pub id: String,
    pub path: String,
    pub scope: String,
    pub exists: bool,
    pub is_duplicate: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShellAlias {
    pub id: String,
    pub name: String,
    pub command: String,
    pub profile_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OmniGetConfig {
    pub priority_cascade: Vec<String>,
    pub user_scope_bypass: bool,
    pub auto_update_check: bool,
    pub default_flags: Vec<String>,
}

impl Default for OmniGetConfig {
    fn default() -> Self {
        Self {
            priority_cascade: vec!["winget".to_string(), "choco".to_string(), "scoop".to_string()],
            user_scope_bypass: true,
            auto_update_check: true,
            default_flags: vec!["--silent".to_string()],
        }
    }
}
