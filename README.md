# OS Setup Scripts

A collection of comprehensive setup scripts for configuring modern development environments on different operating systems.

## Available Scripts

### 🐧 Linux Development Environment Setup

#### Fedora 42 KDE Plasma Wayland (`setup-fedora-42.sh`)

Complete installation and configuration script for a modern development environment on Fedora 42 KDE Plasma with Wayland.

**Features:**

- System update and NVIDIA driver installation
- ZSH with Oh My ZSH and essential plugins
- Starship terminal prompt with custom configuration
- Python development tools (pyenv, Poetry, uv)
- Rust development environment (rustup, cargo tools)
- Go development environment
- C++ build tools and development environment
- Modern CLI tools (ripgrep, bat, fd, eza, zoxide, etc.)
- Container tools (Docker, Podman)
- Nerd Fonts (FiraCode, JetBrains Mono)
- GitHub CLI
- Comprehensive aliases and configurations

**Prerequisites:**

- Fresh installation of Fedora 42 KDE Plasma (Wayland session)
- Active internet connection
- Sudo privileges
- At least 10GB of free disk space

#### Ubuntu 24.04 LTS GNOME Wayland (`setup-ubuntu-24.04.sh`)

Complete installation and configuration script for a modern development environment on Ubuntu 24.04 LTS GNOME with Wayland.

**Features:**

- System update and NVIDIA driver installation
- ZSH with Oh My ZSH and essential plugins
- Starship terminal prompt with custom configuration
- Python development tools (pyenv, Poetry, uv)
- Rust development environment (rustup, cargo tools)
- Go development environment
- C++ build tools and development environment
- Modern CLI tools (ripgrep, bat, fd, eza, zoxide, etc.)
- Container tools (Docker, Podman)
- Nerd Fonts (FiraCode, JetBrains Mono)
- GitHub CLI
- Comprehensive aliases and configurations

**Prerequisites:**

- Fresh installation of Ubuntu 24.04 LTS GNOME (Wayland session)
- Active internet connection
- Sudo privileges
- At least 10GB of free disk space

### 🪟 Windows Development Environment Setup

#### Windows PowerShell (`setup-windows.ps1`)

PowerShell script for setting up a development environment on Windows.

## Usage

### Linux Scripts (Fedora/Ubuntu)

1. Clone this repository:

   ```bash
   git clone https://github.com/yourusername/os-setup-scripts.git
   cd os-setup-scripts
   ```

2. Make the script executable:

   ```bash
   chmod +x setup-fedora-42.sh
   # or
   chmod +x setup-ubuntu-24.04.sh
   ```

3. Run the script:

   ```bash
   ./setup-fedora-42.sh
   # or
   ./setup-ubuntu-24.04.sh
   ```

### Windows Script

1. Open PowerShell as Administrator

2. Set execution policy (if needed):

   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. Run the script:

   ```powershell
   .\setup-windows.ps1
   ```

## What Gets Installed

### Development Tools

- **Languages**: Python (latest via pyenv), Rust (via rustup), Go
- **Package Managers**: Poetry (Python), Cargo (Rust), npm/yarn (Node.js)
- **Version Managers**: pyenv (Python), rustup (Rust)
- **Build Tools**: GCC, Clang, CMake, Make

### Modern CLI Tools

- **File Operations**: eza (better ls), fd (better find), ripgrep (better grep)
- **System Monitoring**: htop, bottom (btm), procs (better ps)
- **Text Processing**: bat (better cat), sd (better sed), jq (JSON processor)
- **Navigation**: zoxide (smarter cd), fzf (fuzzy finder)
- **Git**: git-delta (better git diff), GitHub CLI
- **Networking**: gping (better ping)
- **Performance**: hyperfine (benchmarking), du-dust (better du)

### Terminal & Shell

- **Shell**: ZSH with Oh My ZSH framework
- **Prompt**: Starship cross-shell prompt
- **Plugins**: autosuggestions, syntax highlighting, history search
- **Fonts**: Nerd Fonts (FiraCode, JetBrains Mono)

### Container & Virtualization

- **Docker**: Container platform with compose
- **Podman**: Daemonless container engine (Linux)

## Configuration Files

The scripts create and configure several dotfiles:

- `~/.zshrc` - ZSH configuration with plugins and settings
- `~/.config/starship.toml` - Starship prompt configuration
- `~/.aliases` - Comprehensive command aliases
- Backup directory: `~/.config_backup_YYYYMMDD_HHMMSS`

## Post-Installation

After running the script:

1. **Restart your system** to ensure all changes take effect
2. **Log out and log back in** for shell changes and group permissions
3. **Open a new terminal** and run `source ~/.zshrc`
4. **Configure your terminal font** to use a Nerd Font
5. **Authenticate with GitHub**: `gh auth login`

## Logging

Each script creates a detailed log file:

- Fedora: `fedora_setup_YYYYMMDD_HHMMSS.log`
- Ubuntu: `ubuntu_setup_YYYYMMDD_HHMMSS.log`
- Windows: `windows_setup_YYYYMMDD_HHMMSS.log`

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the script is executable (`chmod +x script.sh`)
2. **Network Issues**: Check internet connection for package downloads
3. **NVIDIA Drivers**: Reboot required after NVIDIA driver installation
4. **Shell Changes**: Log out/in required for ZSH to become default

### Getting Help

- Check the log file for detailed error messages
- Ensure all prerequisites are met
- Run with verbose output for debugging

## Contributing

Feel free to contribute improvements, bug fixes, or additional OS support:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.