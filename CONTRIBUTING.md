# Contributing to OmniGet 📦

Thank you for contributing to **OmniGet**! OmniGet unifies Windows package management, environment variables, and toolchains into a clean CLI and TUI experience.

---

## 🛠️ Local Development & Testing

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/Pranav-Nexus/omniget.git
   cd omniget
   ```

2. **Execute directly via PowerShell:**
   ```powershell
   pwsh -ExecutionPolicy Bypass -File .\OmniGet.ps1 --version
   ```

3. **Test with safe dry-run mode:**
   ```powershell
   pwsh -File .\OmniGet.ps1 doctor --dry-run
   ```

---

## 📌 PR Standards

- Test changes across standard PowerShell 5.1 and modern PowerShell 7+.
- Follow Conventional Commits (`feat:`, `fix:`, `docs:`, `perf:`).
- Document new switches and parameters in `DOCS.md`.
