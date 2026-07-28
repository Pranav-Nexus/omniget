use std::process::Command;

pub fn execute_elevated_command(command: &str, args: &[&str]) -> Result<String, String> {
    let arg_str = args.join(" ");
    let ps_script = format!(
        "Start-Process -FilePath '{}' -ArgumentList '{}' -Verb RunAs -Wait",
        command, arg_str
    );

    let output = Command::new("powershell")
        .args(&["-NoProfile", "-NonInteractive", "-Command", &ps_script])
        .output()
        .map_err(|e| format!("Elevated execution failed: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

pub fn execute_silent_command(command: &str, args: &[&str]) -> Result<String, String> {
    let output = Command::new(command)
        .args(args)
        .output()
        .map_err(|e| format!("Command execution failed: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}
