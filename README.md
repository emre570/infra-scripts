# infra-scripts

Minimal, selectable, and repeatable **instance bootstrap scripts**.

This repository exists to bring up a clean and reliable development
environment on fresh machines such as GPU rental instances
(RentGPU, RunPod, Vast, bare-metal servers, VMs) with **a single command**.

The scripts are designed to:
- detect the active shell (bash / zsh)
- modify only the correct rc file
- handle PATH, NVM, tmux, and common CLI tooling correctly
- be safely re-run multiple times

---

## 🚀 Quick Start (One-liner)

After logging into a new instance, run:

```bash
curl -fsSL https://raw.githubusercontent.com/emre570/infra-scripts/main/instance-boot.sh | bash
```
