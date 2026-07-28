#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod config;
mod elevation;
mod models;
mod parser;

use commands::*;

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            check_cli_installed,
            get_app_config,
            save_app_config,
            run_auto_install,
            search_packages,
            get_outdated_packages,
            get_installed_packages,
            execute_package_action
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
