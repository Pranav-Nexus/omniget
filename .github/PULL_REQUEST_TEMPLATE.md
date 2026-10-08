## 📦 OmniGet Pull Request

### Summary of Changes
<!-- Describe the bug fix, package manager adapter, or CLI enhancement introduced in this PR. -->

### Type of Change
- [ ] 🚀 New package manager integration (WinGet, Chocolatey, Scoop, etc.)
- [ ] 🩺 Health & Doctor enhancement (`omniget doctor`, PATH cleaning)
- [ ] 🌐 Environment variable / alias manager improvement
- [ ] 🐛 Bug fix & edge-case handling
- [ ] 📝 Documentation & setup wizard

---

## 🔍 Verification & Test Steps
- [ ] Tested on PowerShell 5.1 / PowerShell 7+ on Windows
- [ ] Verified non-elevated User-Scope vs Elevated System actions
- [ ] Verified `--dry-run` output behaves deterministically

---

## ✅ Quality Checklist
- [ ] No regressions in parallel Runspace execution.
- [ ] Documentation updated in `DOCS.md` or `README.md`.
