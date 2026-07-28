use crate::models::{InstalledPackage, PackageUpdate, DoctorCheck};
use regex::Regex;

pub fn parse_installed_packages(stdout: &str) -> Vec<InstalledPackage> {
    let mut packages = Vec::new();
    let re = Regex::new(r"(?m)^(?P<name>.+?)\s{2,}(?P<id>[^\s]+)\s{2,}(?P<version>[^\s]+)\s{2,}(?P<source>winget|choco|scoop)").unwrap();

    for cap in re.captures_iter(stdout) {
        packages.push(InstalledPackage {
            id: cap["id"].to_string(),
            name: cap["name"].trim().to_string(),
            publisher: "Unknown".to_string(),
            version: cap["version"].to_string(),
            source: cap["source"].to_string(),
            install_date: "2026-07-01".to_string(),
        });
    }

    packages
}

pub fn parse_outdated_packages(stdout: &str) -> Vec<PackageUpdate> {
    let mut updates = Vec::new();
    let re = Regex::new(r"(?m)^(?P<name>.+?)\s{2,}(?P<id>[^\s]+)\s{2,}(?P<curr>[^\s]+)\s{2,}(?P<new>[^\s]+)\s{2,}(?P<source>winget|choco|scoop)").unwrap();

    for cap in re.captures_iter(stdout) {
        updates.push(PackageUpdate {
            id: cap["id"].to_string(),
            name: cap["name"].trim().to_string(),
            publisher: "Unknown".to_string(),
            current_version: cap["curr"].to_string(),
            new_version: cap["new"].to_string(),
            source: cap["source"].to_string(),
            is_pinned: false,
        });
    }

    updates
}
