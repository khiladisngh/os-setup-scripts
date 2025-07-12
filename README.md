# 🚀 OS Setup Scripts

![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Fedora](https://img.shields.io/badge/Fedora-294172?style=for-the-badge&logo=fedora&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white)](https://docs.microsoft.com/en-us/powershell/)

[![GitHub stars](https://img.shields.io/github/stars/khiladisngh/os-setup-scripts?style=for-the-badge)](https://github.com/khiladisngh/os-setup-scripts/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/khiladisngh/os-setup-scripts?style=for-the-badge)](https://github.com/khiladisngh/os-setup-scripts/network)
[![GitHub issues](https://img.shields.io/github/issues/khiladisngh/os-setup-scripts?style=for-the-badge)](https://github.com/khiladisngh/os-setup-scripts/issues)

> 🎯 **Automated development environment setup scripts for multiple operating systems**

A collection of comprehensive, production-ready setup scripts for configuring modern development environments across different operating systems. Each script is designed to transform a fresh OS installation into a fully configured development powerhouse.

## 📊 Platform Support

<table>
    <tr>
        <td align="center">
            <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/fedora/fedora-original.svg" width="60" height="60" alt="Fedora"/>
            <br><b>Fedora 42</b><br>
            KDE Plasma + Wayland<br>
            <em>+ WSL Support</em>
        </td>
        <td align="center">
            <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/ubuntu/ubuntu-plain.svg" width="60" height="60" alt="Ubuntu"/>
            <br><b>Ubuntu 24.04 LTS</b><br>
            GNOME + Wayland<br>
            <em>+ WSL Support</em>
        </td>
        <td align="center">
            <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/windows8/windows8-original.svg" width="60" height="60" alt="Windows"/>
            <br><b>Windows 11</b><br>
            PowerShell<br>
            <em>+ WSL2 Setup</em>
        </td>
        <td align="center">
            <img src="https://img.utdstc.com/icon/06f/a39/06fa39301c97531152761a4d780a1fedcdaec6b55ff08f5327eba2ff19cdd9bb:200" width="60" height="60" alt="WSL"/>
            <br><b>WSL Universal</b><br>
            Multi-Distro Support<br>
            <em>Ubuntu/Fedora/Debian</em>
        </td>
    </tr>
</table>

## ✨ Features

| 🛠️ **Development Tools** |   🚀 **Modern CLI**   | 🐚 **Shell & Terminal** | 📦 **Containers** | 🪟 **WSL Support**  |
| :----------------------: | :-------------------: | :---------------------: | :---------------: | :-----------------: |
|  Python, Rust, Go, C++   | ripgrep, bat, eza, fd |     ZSH + Oh My ZSH     |  Docker + Podman  |   Auto-Detection    |
|   Poetry, Cargo, pyenv   | bottom, delta, zoxide |     Starship Prompt     |  Compose Support  | Windows Integration |
| Build Tools & Debuggers  |  fzf, jq, hyperfine   |       Nerd Fonts        |  Registry Config  |   X11 Forwarding    |

## �️ Available Scripts

### 🐧 Fedora 42 KDE Plasma (`setup-fedora-42.sh`)

```bash
# Optimized for Fedora 42 KDE Plasma + Wayland
./setup-fedora-42.sh
```

**🎯 Target Environment:** Fresh Fedora 42 KDE Plasma (Wayland)  
**📦 Package Manager:** DNF  
**🔧 Desktop:** KDE Plasma with Wayland session

**📋 Installation Includes:**

- 🔄 System updates and NVIDIA drivers
- 🐚 ZSH + Oh My ZSH + premium plugins
- ⭐ Starship prompt with custom theme
- 🐍 Python ecosystem (pyenv, Poetry, uv)
- 🦀 Rust toolchain (rustup, cargo, clippy)
- 🐹 Go development environment
- 🔨 C++ build tools and debuggers
- 🚀 Modern CLI toolkit (50+ tools)
- 📦 Container platforms (Docker + Podman)
- 🔤 Nerd Fonts (FiraCode, JetBrains Mono)
- 🐙 GitHub CLI with auth setup

### 🟠 Ubuntu 24.04 LTS GNOME (`setup-ubuntu-24.04.sh`)

```bash
# Optimized for Ubuntu 24.04 LTS GNOME + Wayland
./setup-ubuntu-24.04.sh
```

**🎯 Target Environment:** Fresh Ubuntu 24.04 LTS GNOME (Wayland)  
**📦 Package Manager:** APT  
**🔧 Desktop:** GNOME with Wayland session

**📋 Installation Includes:**

- 🔄 System updates and NVIDIA drivers
- 🐚 ZSH + Oh My ZSH + premium plugins
- ⭐ Starship prompt with Ubuntu theme
- 🐍 Python ecosystem (pyenv, Poetry, uv)
- 🦀 Rust toolchain (rustup, cargo, clippy)
- 🐹 Go development environment
- 🔨 C++ build tools and debuggers
- 🚀 Modern CLI toolkit (50+ tools)
- 📦 Container platforms (Docker + Podman)
- 🔤 Nerd Fonts (FiraCode, JetBrains Mono)
- 🐙 GitHub CLI with auth setup

### 🪟 Windows 11 PowerShell (`setup-windows.ps1`)

```powershell
# Windows development environment setup
.\setup-windows.ps1
```

**🎯 Target Environment:** Windows 11  
**📦 Package Manager:** Chocolatey + Winget  
**🔧 Shell:** PowerShell 7+

**📋 Features:** _(Coming Soon)_

- Package management automation
- Development tools installation
- Windows Terminal configuration
- WSL2 setup and optimization

### 🐧 WSL Universal (`setup-wsl.sh`)

```bash
# Universal WSL development environment setup
./setup-wsl.sh
```

**🎯 Target Environment:** WSL (Windows Subsystem for Linux)  
**📦 Package Manager:** Auto-detected (APT/DNF)  
**🔧 Distributions:** Ubuntu, Fedora, Debian

**📋 Installation Includes:**

- 🔍 Automatic distribution detection
- 🔄 System updates for detected distro
- 🌐 X11 forwarding configuration
- 🐚 WSL-optimized shell configuration
- 🐙 Git configuration for Windows interop
- 📦 Container tools (WSL-compatible)
- 🚀 Programming languages (Node.js, Python, Go, Rust)
- 🔗 Windows integration (symlinks, aliases)
- 📂 Convenient Windows directory access

**🔧 WSL-Specific Features:**

- Automatic WSL environment detection
- Skip desktop environment configurations
- Windows PATH integration
- Docker Desktop compatibility
- Cross-platform file access

## 🚀 Quick Start

### 📋 Prerequisites

**All Platforms:**

- ✅ Active internet connection
- ✅ Administrator/sudo privileges
- ✅ 10GB+ free disk space
- ✅ Fresh OS installation (recommended)

### ⚡ Installation

**Linux (Fedora/Ubuntu):**

```bash
# 1️⃣ Clone the repository
git clone https://github.com/khiladisngh/os-setup-scripts.git
cd os-setup-scripts

# 2️⃣ Make executable
chmod +x setup-fedora-42.sh setup-ubuntu-24.04.sh setup-wsl.sh

# 3️⃣ Run your platform script
./setup-fedora-42.sh     # For Fedora 42
./setup-ubuntu-24.04.sh  # For Ubuntu 24.04
```

**WSL (Any Distribution):**

```bash
# 1️⃣ Clone the repository
git clone https://github.com/khiladisngh/os-setup-scripts.git
cd os-setup-scripts

# 2️⃣ Make executable and run universal WSL script
chmod +x setup-wsl.sh
./setup-wsl.sh  # Auto-detects Ubuntu/Fedora/Debian
```

**Windows:**

```powershell
# 1️⃣ Open PowerShell as Administrator
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 2️⃣ Clone and run
git clone https://github.com/khiladisngh/os-setup-scripts.git
cd os-setup-scripts
.\setup-windows.ps1
```

**WSL:**

```bash
# 1️⃣ Clone the repository (from Windows)
git clone https://github.com/khiladisngh/os-setup-scripts.git
cd os-setup-scripts

# 2️⃣ Make executable (if required)
chmod +x setup-wsl.sh

# 3️⃣ Run the WSL setup script
./setup-wsl.sh
```

## 🛠️ Development Stack

### 🌟 Programming Languages & Runtimes

|   Language    | Version Manager | Package Manager |             Tools              |
| :-----------: | :-------------: | :-------------: | :----------------------------: |
| **🐍 Python** |      pyenv      | Poetry, uv, pip |      Black, pytest, mypy       |
|  **🦀 Rust**  |     rustup      |      Cargo      | rustfmt, clippy, rust-analyzer |
|   **🐹 Go**   |  System/Manual  |     go mod      |      gofmt, golint, delve      |
|  **⚡ C++**   |     System      |   cmake, make   |   GCC, Clang, GDB, Valgrind    |

### 🚀 Modern CLI Toolkit

#### 📂 File & Navigation Tools

- **`eza`** → Enhanced `ls` with icons and git integration
- **`fd`** → Fast and user-friendly `find` replacement
- **`ripgrep`** → Ultra-fast text search tool
- **`bat`** → Cat with syntax highlighting and git integration
- **`zoxide`** → Smarter `cd` command with frecency algorithm
- **`fzf`** → Fuzzy finder for files, commands, and history

#### ⚡ System & Performance Tools

- **`bottom (btm)`** → Cross-platform system monitor
- **`procs`** → Modern `ps` replacement
- **`du-dust`** → Intuitive disk usage analyzer
- **`hyperfine`** → Command-line benchmarking tool
- **`gping`** → Ping with graph visualization
- **`duf`** → Better `df` with colored output

#### 🔧 Development Tools

- **`git-delta`** → Beautiful git diffs with syntax highlighting
- **`gh`** → Official GitHub CLI
- **`jq`** → JSON processor and formatter
- **`sd`** → Intuitive find & replace CLI
- **`hexyl`** → Command-line hex viewer
- **`tealdeer (tldr)`** → Simplified man pages

## 📁 Project Structure & Configuration

```text
os-setup-scripts/
├── 🐧 setup-fedora-42.sh      # Fedora 42 KDE setup script
├── 🟠 setup-ubuntu-24.04.sh   # Ubuntu 24.04 LTS setup script
├── 🪟 setup-windows.ps1       # Windows 11 setup script
├── 📖 README.md               # This file
├── 📋 SETUP_SUMMARY.md        # Installation summary
└── 📝 logs/                   # Generated log files
    ├── fedora_setup_YYYYMMDD_HHMMSS.log
    ├── ubuntu_setup_YYYYMMDD_HHMMSS.log
    └── windows_setup_YYYYMMDD_HHMMSS.log
```

### 🔧 Configuration Files Created

| File                      | Purpose                        | Backup Location       |
| :------------------------ | :----------------------------- | :-------------------- |
| `~/.zshrc`                | ZSH configuration with plugins | `~/.config_backup_*/` |
| `~/.config/starship.toml` | Starship prompt theme          | `~/.config_backup_*/` |
| `~/.aliases`              | 100+ useful command aliases    | `~/.config_backup_*/` |
| `~/.gitconfig`            | Git configuration with delta   | `~/.config_backup_*/` |

## 🎯 Post-Installation Checklist

### ✅ Essential Steps

1. **🔄 System Restart** - Required for kernel modules and drivers
2. **🚪 Re-login** - Activates shell changes and group permissions
3. **🔤 Font Configuration** - Set terminal to use Nerd Font
4. **🐙 GitHub Authentication** - Run `gh auth login`
5. **⚡ Source Configuration** - Run `source ~/.zshrc`

### 🛠️ Optional Configuration

- **Terminal Theme** - Configure your terminal colors
- **IDE Setup** - Install VS Code, JetBrains IDEs, or Neovim
- **SSH Keys** - Generate and add SSH keys to GitHub/GitLab
- **Custom Aliases** - Edit `~/.aliases` for personal shortcuts

## 📊 Logging & Debugging

Each script generates comprehensive logs with:

- ⏰ **Timestamps** for every operation
- 🎯 **Color-coded** messages (INFO, SUCCESS, WARNING, ERROR)
- 📈 **Progress tracking** with visual progress bars
- 🔄 **Error handling** with detailed error messages
- 📁 **Backup tracking** of modified configuration files

**Log Locations:**

```bash
# View recent logs
ls -la *_setup_*.log

# Follow installation in real-time
tail -f fedora_setup_$(date +%Y%m%d)*.log
```

## 🔧 Troubleshooting

### 🚨 Common Issues

| Issue                   | Solution                                          |
| :---------------------- | :------------------------------------------------ |
| **Permission Denied**   | Ensure script is executable: `chmod +x script.sh` |
| **Network Timeout**     | Check internet connection and retry               |
| **NVIDIA Installation** | Reboot required after driver installation         |
| **Docker Permission**   | Log out/in to apply group changes                 |
| **ZSH Not Default**     | Log out/in to activate shell change               |
| **Missing Fonts**       | Run `fc-cache -fv` to refresh font cache          |

### 🔍 Getting Support

1. **📝 Check logs** - Look for ERROR messages in log files
2. **🐛 Enable debug** - Run with `bash -x script.sh` for verbose output
3. **🌐 Search issues** - Check GitHub issues for similar problems
4. **📬 Report bugs** - Create detailed issue with log excerpts

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### 🛠️ Development Setup

```bash
# Fork and clone your fork
git clone https://github.com/YOUR_USERNAME/os-setup-scripts.git
cd os-setup-scripts

# Create feature branch
git checkout -b feature/amazing-improvement

# Make your changes and test thoroughly
./setup-ubuntu-24.04.sh  # Test your changes

# Commit and push
git commit -m "feat: add amazing improvement"
git push origin feature/amazing-improvement

# Create pull request
```

### 📋 Contribution Guidelines

- **🧪 Test thoroughly** on fresh OS installations
- **📝 Update documentation** for new features
- **🔍 Follow shell scripting best practices**
- **📊 Add appropriate logging and error handling**
- **🎨 Maintain consistent code style**

## 📜 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

**⭐ Star this repository if it helped you!**

[![GitHub stars](https://img.shields.io/github/stars/khiladisngh/os-setup-scripts?style=social)](https://github.com/khiladisngh/os-setup-scripts/stargazers)

Made with ❤️ by [Gishant](https://github.com/khiladisngh)
