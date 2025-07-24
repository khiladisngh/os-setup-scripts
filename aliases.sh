# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
#                    ★  ALIASES ★
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# --------------------------------------------------------------
# ► Shell & Convenience
# --------------------------------------------------------------
alias c='clear'                               # Clear the screen
alias q='exit'                                # Quick exit
alias ..='cd ..'                              # Go up one directory
alias ...='cd ../..'                          # Go up two directories
alias ....='cd ../../..'                      # Go up three directories
alias aliases='nano ~/.aliases_combined'      # Quickly edit this file
alias reload='source ~/.bashrc'               # Reload shell configuration
alias h='history'                             # Shorthand for history
alias hg='history | grep'                     # Grep through history
alias cd='z'                                  # Use zoxide for smarter cd


# --------------------------------------------------------------
# ► File & Directory Management (Modern Replacements)
# --------------------------------------------------------------
# eza (replaces ls) - https://github.com/eza-community/eza
alias ls='eza --icons --color=always --group-directories-first' # ls replacement with icons
alias l='eza -l -h --git --icons --group-directories-first'     # Long format, human-readable sizes, git status
alias la='eza -la --icons --group-directories-first'            # Long format, all files (including hidden)
alias ll='la'                                                   # Common alias for `la`
alias lt='la --sort=modified'                                   # Sort by modification time, newest first
alias llt='eza -l --icons --sort=modified'                      # Long format sorted by time
alias lS='la --sort=size'                                       # Sort by size, largest first
alias tree='eza --tree --level=3 --long --icons --git'          # Tree view with details, up to 3 levels deep

# bat (replaces cat) - https://github.com/sharkdp/bat
alias cat='bat --theme="Dracula"'                               # Use bat instead of cat
alias catp='bat'                                                # bat with paging

# fd (replaces find) - https://github.com/sharkdp/fd
alias find='fd'

# ripgrep (replaces grep) - https://github.com/BurntSushi/ripgrep
alias grep='rg'

# dust (replaces du) & duf (replaces df)
alias du='dust'                                                 # Show disk usage of directories
alias df='duf'                                                  # Show disk free space

# procs (replaces ps)
alias ps='procs'

# gping (replaces ping)
alias ping='gping'                                              # Use gping for a graphical ping

# tealdeer (replaces man)
alias man='tldr'                                                # Quick help with tealdeer


# --------------------------------------------------------------
# ► System & Package Management
# --------------------------------------------------------------
# System Monitoring
alias top='btm'                                                 # Use bottom for system monitoring
alias htop='btm'                                                # Also alias htop to bottom
alias procs='procs --tree'                                      # Use procs with tree view

# Package Management (Debian/Ubuntu)
alias apti='sudo apt install'
alias apts='apt search'
alias aptu='sudo apt update && sudo apt upgrade'
alias aptr='sudo apt remove'
alias aptc='sudo apt autoremove && sudo apt autoclean'

# Package Management (Fedora/RHEL)
alias dnfi='sudo dnf install'
alias dnfs='sudo dnf search'
alias dnfu='sudo dnf upgrade --refresh'
alias dnfr='sudo dnf remove'
alias dnfc='sudo dnf autoremove'
alias update='sudo dnf upgrade --refresh -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'
alias search='dnf search'


# --------------------------------------------------------------
# ► Git Aliases (Productivity Boost)
# --------------------------------------------------------------
alias g='git'
alias ga='git add'
alias gaa='git add -A'                                          # Add all changes
alias gc='git commit -v'
alias gcm='git commit -m'
alias gca='git commit --amend'                                  # Amend the last commit
alias gcaa='git commit --amend --no-edit'                       # Amend without editing
alias gp='git push'
alias gpf='git push --force-with-lease'                         # Safer force push
alias gpl='git pull'
alias gco='git checkout'
alias gcb='git checkout -b'                                     # Create and checkout a new branch
alias gsw='git switch'                                          # Switch branches (modern)
alias gsc='git switch -c'                                       # Create and switch to a new branch
alias gb='git branch'
alias gbr='git branch'
alias gba='git branch -a'                                       # List all local and remote branches
alias gs='git status -sb'                                       # Short branch-aware status
alias gss='git status -s'                                       # Short status
alias gcl='git clone'
alias gsta='git stash'
alias gstp='git stash pop'
alias gd='git-delta'                                            # Use delta for diffs
alias gdiff='git diff | delta'                                  # Git diff with delta
alias glog="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gld="git log --pretty=format:'%C(yellow)%h\\ %ad%d\\ %Creset%s%C(blue)\\ [%cn]' --decorate --date=short"
alias gl='git log --oneline --graph --decorate'                 # Short git log
alias glogd='git log --oneline | delta'                         # Git log with delta
alias lazygit='lazygit'                                         # Launch the lazygit TUI
alias lg='lazygit'                                              # Short alias for lazygit


# --------------------------------------------------------------
# ► Networking
# --------------------------------------------------------------
alias myip="curl -s ifconfig.me && echo"                        # Get public IP address


# --------------------------------------------------------------
# ► Docker & Containers
# --------------------------------------------------------------
alias d='docker'

# Containers
alias dps='docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}"'
alias dpsa='docker ps -a'
alias dstopall='docker stop $(docker ps -aq)'                   # Stop all running containers
alias drmall='docker rm $(docker ps -aq)'                       # Remove all containers (must be stopped first)

# Images
alias di='docker images'
alias dirmall='docker rmi $(docker images -q)'                  # Remove all images (will fail if in use)
alias diprune='docker image prune -a'                           # Remove all dangling and unused images

# Volumes
alias dvl='docker volume ls'                                    # List volumes
alias dvprune='docker volume prune -f'                          # Remove all unused local volumes

# Logs and Execution
alias dlogs='docker logs -f'
alias dexec='docker exec -it'

# TUI
alias lazydocker='lazydocker'                                   # Launch the lazydocker TUI

# Docker Compose
alias dc='docker compose'
alias dcup='docker compose up'
alias dcud='docker compose up -d'                               # Start services in detached mode
alias dcdown='docker compose down'                              # Stop and remove containers, networks
alias dcd='docker compose down'                                 # Alternative alias
alias dcps='docker compose ps'                                  # List containers
alias dcl='docker compose logs -f --tail=100'                   # Follow logs for all services
alias dclogs='docker compose logs -f'                           # Alternative alias
alias dcb='docker compose build'                                # Build or rebuild services
alias dce='docker compose exec'                                 # Execute a command in a running container


# --------------------------------------------------------------
# ► Podman (Alternative to Docker)
# --------------------------------------------------------------
alias p='podman'
alias pps='podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias ppsa='podman ps -a'
alias pi='podman images'


# --------------------------------------------------------------
# ► Python Development
# --------------------------------------------------------------
alias py='python'

# Poetry
alias po='poetry'
alias poa='poetry add'
alias por='poetry remove'
alias poi='poetry install'
alias pou='poetry update'
alias porun='poetry run'
alias poshell='poetry shell'

# uv (Fast Python package manager)
alias uv='uv'
alias uvi='uv pip install'
alias uvr='uv pip install -r requirements.txt'


# --------------------------------------------------------------
# ► Rust Development
# --------------------------------------------------------------
alias cc='cargo check'
alias cb='cargo build'
alias cbr='cargo build --release'
alias cr='cargo run'
alias ct='cargo test'
alias cl='cargo clippy'
alias cfmt='cargo fmt'


# --------------------------------------------------------------
# ► Go Development
# --------------------------------------------------------------
alias gr='go run'
alias gb='go build'
alias gt='go test ./...'
alias gti='go mod tidy'


# --------------------------------------------------------------
# ► FZF Integration
# --------------------------------------------------------------
alias fzf-preview='fzf --preview "bat --style=numbers --color=always {}"'
alias fzf-cd='cd $(fd --type d | fzf)'
alias fzf-edit='$EDITOR $(fd --type f | fzf)'


# --------------------------------------------------------------
# ► Atuin (Shell History)
# --------------------------------------------------------------
alias ha='atuin search'                                         # Atuin search
alias hai='atuin search -i'                                     # Atuin case-insensitive search


# --------------------------------------------------------------
# ► Utility Functions
# --------------------------------------------------------------
# Start a simple web server in the current directory
serve() {
    python3 -m http.server "${1:-8000}"
}

# Create a directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Backup a file
bak() {
    cp -a "$1" "$1.bak"
}

# Get public IP
myip_func() {
    curl ifconfig.me
}

# Quick file find and edit
fe() {
    local file
    file=$(fd --type f | fzf --preview "bat --style=numbers --color=always {}") && $EDITOR "$file"
}

# Quick directory navigation
fcd() {
    local dir
    dir=$(fd --type d | fzf) && cd "$dir"
}

# Git fuzzy checkout
fco() {
    git branch --all | grep -v HEAD | fzf | sed 's/^..//' | xargs git checkout
}

# Process fuzzy kill
fkill() {
    local pid
    pid=$(procs | fzf --header-lines=1 | awk '{print $1}')
    if [ -n "$pid" ]; then
        kill -9 "$pid"
    fi
}

# Docker fuzzy container management
fdc() {
    local container
    container=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | fzf --header-lines=1 | awk '{print $1}')
    if [ -n "$container" ]; then
        docker exec -it "$container" /bin/bash
    fi
}