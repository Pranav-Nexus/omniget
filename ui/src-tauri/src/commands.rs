use crate::config::{load_config, save_config};
use crate::elevation::{execute_elevated_command, execute_silent_command};
use crate::models::{CliFlags, InstalledPackage, OmniGetConfig, Package, PackageUpdate};
use crate::parser::{parse_installed_packages, parse_outdated_packages};
use std::path::PathBuf;

#[tauri::command]
pub fn check_cli_installed() -> Result<bool, String> {
    if let Ok(path) = std::env::var("LOCALAPPDATA") {
        let omniget_exe = PathBuf::from(path).join("OmniGet").join("omniget.exe");
        if omniget_exe.exists() {
            return Ok(true);
        }
    }
    match execute_silent_command("omniget", &["--version"]) {
        Ok(_) => Ok(true),
        Err(_) => Ok(false),
    }
}

#[tauri::command]
pub fn get_app_config() -> Result<OmniGetConfig, String> {
    Ok(load_config())
}

#[tauri::command]
pub fn save_app_config(config: OmniGetConfig) -> Result<(), String> {
    save_config(&config)
}

#[tauri::command]
pub fn run_auto_install() -> Result<bool, String> {
    let script = "powershell -Command \"Start-Process OmniGetSetup.exe -Verb RunAs -Wait\"";
    match execute_elevated_command("powershell", &["-Command", script]) {
        Ok(_) => Ok(true),
        Err(e) => Err(e),
    }
}

#[tauri::command]
pub fn search_packages(query: String) -> Result<Vec<Package>, String> {
    let output = execute_silent_command("omniget", &["search", &query])?;
    Ok(vec![])
}

#[tauri::command]
pub fn get_outdated_packages() -> Result<Vec<PackageUpdate>, String> {
    let output = execute_silent_command("omniget", &["upgrade"])?;
    Ok(parse_outdated_packages(&output))
}

#[tauri::command]
pub fn get_installed_packages() -> Result<Vec<InstalledPackage>, String> {
    let output = execute_silent_command("omniget", &["list"])?;
    Ok(parse_installed_packages(&output))
}

#[tauri::command]
pub fn execute_package_action(
    action: String,
    package_id: String,
    source: Option<String>,
    flags: Option<CliFlags>,
) -> Result<String, String> {
    let mut args = vec![action.as_str(), package_id.as_str()];
    let pm_flag;
    if let Some(src) = source {
        pm_flag = format!("--pm {}", src);
        args.push(&pm_flag);
    }
    if let Some(f) = flags {
        if f.silent.unwrap_or(false) {
            args.push("--silent");
        }
        if f.force.unwrap_or(false) {
            args.push("--force");
        }
    }

    if action == "install" || action == "upgrade" || action == "uninstall" {
        execute_elevated_command("omniget", &args)
    } else {
        execute_silent_command("omniget", &args)
    }
}
