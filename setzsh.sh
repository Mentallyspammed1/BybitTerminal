#!/bin/bash

# Termux Enhanced ZSH Setup Script - Pyrmethus Edition (Ultra-Enhanced)
# Description: Comprehensive setup for an optimized Termux ZSH environment with AI, usability, and robust features.

# --- Configuration (No changes needed here in setup script) ---
ZSHRC_CONTENT=$(cat <<'END_ZSHRC'
# --- Powerlevel10k Instant Prompt ---
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- Last Updated: 2024-08-03 ---
# Enhanced ZSH Configuration - Gemini AI & Usability Focused (Termux Compatible)
# By Pyrmethus, the Termux Coding Wizard

# --- 0.  Initialization and Local Config ---
if [[ -f ~/.zshrc.local ]]; then
    source ~/.zshrc.local
fi

# --- 1. Core Environment Variables ---
export TERM="xterm-256color"
export LANG="en_US.UTF-8"
export SHELL="/data/data/com.termux/files/usr/bin/zsh"
export ZSH="$HOME/.oh-my-zsh"
export ZSHRC="$HOME/.zshrc"
export ZDOTDIR="$HOME"

# --- 2. General Shell Improvements ---
setopt auto_cd correct numeric_glob_sort no_flow_control extended_glob interactive_comments glob_dots append_history hist_reduce_blanks cdable_vars list_types

# --- 3. History Configuration ---
export HISTFILE="$HOME/.zsh_history_encrypted"
export HISTSIZE=20000
export SAVEHIST="$HISTSIZE"
export HIST_IGNORE_SPACE="true"
export HIST_IGNORE_DUPS="true"
export HIST_NO_STORE="ls:cd:pwd:exit:history:bg:fg:jobs:clear"
setopt hist_verify share_history inc_append_history hist_no_functions HIST_EXPIRE_DUPS_FIRST

# --- 4. Theme and Prompt Customization (Powerlevel10k) ---
THEME_DIR="$ZSH/custom/themes/powerlevel10k"
THEME_FILE="$THEME_DIR/powerlevel10k.zsh-theme"
if [[ -f "$THEME_FILE" ]]; then
    ZSH_THEME="powerlevel10k/powerlevel10k"
    POWERLEVEL10K_MODE='nerdfont-complete'
    POWERLEVEL10K_INSTALLATION_PATH="$THEME_DIR"
    POWERLEVEL10K_CONFIG_FILE="$HOME/.p10k.zsh"
    POWERLEVEL10K_LEFT_PROMPT_ELEMENTS=(context dir vcs newline prompt_separator)
    POWERLEVEL10K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time ram root_indicator battery time)
    POWERLEVEL10K_PROMPT_ON_NEWLINE=true POWERLEVEL10K_MULTILINE_NEWLINE=true POWERLEVEL10K_RPROMPT_SEGMENT_SEPARATOR="" POWERLEVEL10K_RPROMPT_ELEMENTS_BEFORE_COMMAND=0 POWERLEVEL10K_LEFT_SUBSEGMENT_SEPARATOR=""
    source "$THEME_FILE" || echo "Failed to source Powerlevel10k theme."
else
    ZSH_THEME="agnoster"
    echo "Powerlevel10k theme not found. Using 'agnoster' fallback."
    echo "Install Powerlevel10k for an enhanced prompt: git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $THEME_DIR"
    [[ -x "$(command -v termux-toast)" ]] && termux-toast "Powerlevel10k theme not installed. Using Agnoster."
fi

# --- 5. Plugin Management (Oh My Zsh) ---
plugins=(git zsh-z zsh-autosuggestions command-not-found zsh-completions extract aichat history copycat urltools safe-paste sudo colorize dirhistory vi-mode systemd docker tmux fzf)
source "$ZSH/oh-my-zsh.sh" 2>/dev/null || { echo "Oh My Zsh installation failed. Please check internet and try again."; [[ -x "$(command -v termux-toast)" ]] && termux-toast "Oh My Zsh install failed!"; }

# --- 6. Optional Plugins ---
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
optional_plugins=(
    "fast-syntax-highlighting https://github.com/zdharma-continuum/fast-syntax-highlighting"
    "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting"
    "zsh-completions https://github.com/zsh-users/zsh-completions" # For ensuring latest completions - often redundant as OMZ includes them.
)

install_optional_plugin() {
    local plugin="$1" plugin_name=$(echo "$plugin" | awk '{print $1}') plugin_url=$(echo "$plugin" | awk '{$1=""; print $0}' | xargs) plugin_path="$ZSH_CUSTOM/plugins/$plugin_name"
    if [[ ! -d "$plugin_path" ]]; then echo "Installing optional plugin '$plugin_name' from $plugin_url..."; git clone --depth=1 "$plugin_url" "$plugin_path" || echo "  Error: Failed to clone plugin '$plugin_name'."; else echo "Optional plugin '$plugin_name' already exists."; fi
}
source_optional_plugin() {
    local plugin="$1" plugin_name=$(echo "$plugin" | awk '{print $1}') plugin_path="$ZSH_CUSTOM/plugins/$plugin_name"
    [[ "$plugin_name" == "powerlevel10k" || "$plugin_name" == "spaceship-prompt" ]] && return 0 # Skip themes - handled separately
    if [[ -r "$plugin_path/$plugin_name.plugin.zsh" ]]; then source "$plugin_path/$plugin_name.plugin.zsh" 2>/dev/null; elif [[ -r "$plugin_path/$plugin_name.zsh" ]]; then source "$plugin_path/$plugin_name.zsh" 2>/dev/null; fi
}
for plugin in "${optional_plugins[@]}"; do install_optional_plugin "$plugin"; source_optional_plugin "$plugin"; done

# --- 7. Custom Configuration Files ---
ZSH_CUSTOM_CONFIG="$HOME/.config/zsh"
[[ -d "$ZSH_CUSTOM_CONFIG" ]] && for config_file in "$ZSH_CUSTOM_CONFIG"/*.zsh; do source "$config_file" 2>/dev/null; done

# --- 8. Performance Optimizations and Completions ---
setopt promptsubst; zstyle ':completion:*' menu select=1 _complete '' _ignored '*'; zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'; zstyle ':completion:*' use-cache on; zstyle ':completion:*' cache-path "$HOME/.zsh_cache"
if (( $+commands[compinit] )); then autoload -Uz compinit && compinit -i 2>/dev/null; fi

# --- 9. Development Tools and Paths ---
export EDITOR="nano" VISUAL="$EDITOR" PYTHONPATH="/data/data/com.termux/files/usr/bin/python"
export PATH="$HOME/bin:/data/data/com.termux/files/usr/bin:\$PATH"
export PATH="$HOME/.cargo/bin:\$PATH" export PATH="$HOME/.local/bin:\$PATH"

# --- 10. Enhanced Aliases ---
alias c="clear"
[[ -x "$(command -v bat)" ]] && alias cat="bat --theme=Dracula --paging=auto" || alias cat="cat"
[[ -x "$(command -v eza)" ]] && { alias ls="eza --group-directories-first --icons" alias ll="eza -lh --git" alias la="eza -lah --icons" alias lt="eza -T --level=2" alias llt="eza -lhaT --level=2 --icons --git"; } || alias ls="ls --color=auto"
[[ -x "$(command -v fd)" ]] && alias find="fd" || alias find="find"
alias grep="grep --color=auto" df="df -h" du="du -h --max-depth=1" mkdir="mkdir -p" vim="vim" gs="git status" ga="git add" gc="git commit -m" gcm="git commit" gp="git push" gpl="git pull" gco="git checkout" gb="git branch" gst="git stash" gsta="git stash apply" gstp="git stash pop" pkg="pkg" sudo="tsudo " rustup="rustup" python="$PYTHONPATH" python3="$PYTHONPATH" pip="pip3"

# --- 11. Custom Functions ---
man-search() { man -k "$@" | less 2>/dev/null || echo "No man pages found"; }
list_processes_by_memory() { ps -eo pid,user,%mem,%cpu,start,command | sort -nrk 3 2>/dev/null || ps aux; }
update_all() { pkg update && pkg upgrade -y; }
sync_dotfiles() { cd "$HOME" && git pull && source "$ZSHRC"; }
manage_ssh_keys() { ssh-keygen -t ed25519 -C "$1"; }
ssh_work() { ssh user@work_server; }
gen_password() { tr -dc A-Za-z0-9_ < /dev/urandom | head -c 12; echo; }
open_dir() { termux-open . 2>/dev/null || echo "termux-open not available"; }
run_in_dirs() { for dir in */; do (cd "$dir" && "$@"); done; }
find_large_files() { find . -type f -size +100M -exec ls -lh {} \; 2>/dev/null; }
shorten_url() { curl -s "https://bit.ly/?url=$1" | grep -o 'https://bit.ly/[a-zA-Z0-9]*' 2>/dev/null; }
clean_temp_files() { find ~ -type f -name "*.tmp" -delete; }
encrypt_history() { [[ -f "$HISTFILE" ]] && if command -v gpg >/dev/null; then gpg -c --batch --yes -o "$HISTFILE.gpg" "$HISTFILE" && rm "$HISTFILE"; else echo "gpg not found, history encryption skipped."; fi }
decrypt_history() { [[ -f "$HISTFILE.gpg" ]] && if command -v gpg >/dev/null; then gpg -d --batch --yes "$HISTFILE.gpg" > "$HISTFILE" 2>/dev/null; else echo "gpg not found, history decryption skipped."; fi }
system_info() { termux-info 2>/dev/null || uname -a; }
update_shell() { source "$ZSHRC"; }
welcome_message() { echo "Welcome to your ZSH environment! [$(date '+%Y-%m-%d %H:%M:%S')]"; }
list_aliases() { alias; }
list_functions() { typeset -f | grep -v '^#' | sed -n '/^ *[a-zA-Z]/s/^\( *\)\([a-zA-Z_]*\).*/\2/p'; }
history_search() { history | grep "$@"; }
backup_dotfiles() { tar -czf "$HOME/dotfiles_$(date +%Y%m%d).tar.gz" "$ZSHRC" "$ZSH_CUSTOM" 2>/dev/null; }
run_python() { if [[ -f "$1" ]]; then if [[ -x "$1" ]]; then "$1" || echo "Error running $1"; elif [[ -x "$PYTHONPATH" ]]; then "$PYTHONPATH" "$1" || echo "Error running $1"; else echo "Python not found or script not executable"; fi; else echo "Script $1 doesn’t exist"; fi }
mkcd() { mkdir -p "$1"; cd "$1"; }
take() { mkdir -p "$1"; cd "$1"; }
extract() { if [ -f "$1" ]; then case "$1" in *.tar.bz2) tar xjf "$1" ;; *.tar.gz) tar xzf "$1" ;; *.tar.xz) tar xf "$1" ;; *.zip) unzip "$1" ;; *.rar) unrar x "$1" ;; *.7z) 7z x "$1" ;; *.tar) tar xf "$1" ;; *.tgz) tar xzf "$1" ;; *.tbz2) tar xjf "$1" ;; *.txz) tar xf "$1" ;; *.gz) gzip -d "$1" ;; *.bz2) bzip2 -d "$1" ;; *.xz) xz -d "$1" ;; *.Z) uncompress "$1" ;; *.lzh) lha e "$1" ;; *.lha) lha e "$1" ;; *.rpm) rpm2cpio "$1" | cpio -idmv ;; *.deb) ar vx "$1" ;; *) echo "unknown archive type: $1" ;; esac else echo "file not found: $1" fi }

# --- 12. AI Integration with Gemini (AIChat) ---
# --- 12.1. Configuration ---
export AICHA_CONFIG="$ZDOTDIR/.config/aichat"
export AICHA_HISTORY="$ZDOTDIR/.local/share/aichat/history"
export AICHA_CACHE_DIR="$ZDOTDIR/.cache/aichat"
export AICHA_MODEL="${AICHA_MODEL:-gemini}"
export AICHA_TIMEOUT="${AICHA_TIMEOUT:-10}"

# --- 12.2. AIChat Functions ---
get_api_key() {
    local config_file="${AICHA_CONFIG}/config.yaml" api_key
    if [[ ! -f "$config_file" ]]; then echo "Error: AIChat config file not found at $config_file."; echo "  Run 'Setup AIChat AI Features' from Termux Setup Wizard."; return 1; fi
    api_key=$(yq e '.api_key' "$config_file" 2>/dev/null)
    if [[ -z "$api_key" ]]; then echo "Error: Gemini API key is not set in $config_file."; echo "  Edit $config_file and set API key in 'api_key: \"\"'."; return 1; fi; echo "$api_key"
}

_aichat_suggest() {
    local current_buffer="$BUFFER"
    [[ -z "$current_buffer" ]] && { echo "AI Suggest: Type a command first (Alt+E)"; zle accept-line; return; }
    local suggestion api_key; api_key=$(get_api_key) || { zle accept-line; return; };
    echo -n "Generating suggestion... "
    suggestion=$(timeout "$AICHA_TIMEOUT" aichat suggest "$current_buffer" --model "$AICHA_MODEL" --api-key "$api_key" --max-length 200 2>/dev/null)
    local aichat_status=$?
    if [[ $aichat_status -ne 0 || -z "$suggestion" ]]; then echo -e "\rError: AI Suggestion failed (aichat error: $aichat_status). Check install, API key, model."; zle accept-line; return; fi
    if command -v lolcat >/dev/null 2>&1; then echo -n "AI Suggestion: $(echo "$suggestion" | lolcat)"; else echo -n "AI Suggestion: $suggestion"; fi
    echo -n " [Enter=Accept, Ctrl+C=Cancel, Type to Edit]: "
    local history_file="${AICHA_HISTORY}" user_input; read -r user_input
    if [[ $? -eq 1 ]]; then BUFFER="$current_buffer"; echo "$(date '+%Y-%m-%d %H:%M:%S') - Suggestion Cancelled" >> "$history_file"; elif [[ -z "$user_input" ]]; then BUFFER="$suggestion"; echo "$(date '+%Y-%m-%d %H:%M:%S') - Suggestion Accepted: $suggestion" >> "$history_file"; else BUFFER="$user_input"; echo "$(date '+%Y-%m-%d %H:%M:%S') - Suggestion Edited: $suggestion -> $user_input" >> "$history_file"; fi; zle accept-line
}
zle -N _aichat_suggest

_aichat_command() {
    local current_buffer="$BUFFER"
    [[ -z "$current_buffer" ]] && { echo "AI Command: Type instruction (Alt+C)"; zle accept-line; return; }
    local generated_command api_key; api_key=$(get_api_key) || { zle accept-line; return; };
    echo -n "Generating command... "
    generated_command=$(timeout "$AICHA_TIMEOUT" aichat --prompt "$current_buffer" --model "$AICHA_MODEL" --api-key "$api_key" --max-length 200 2>/dev/null)
    local aichat_status=$?
    if [[ $aichat_status -ne 0 || -z "$generated_command" ]]; then echo -e "\rError: AI Command Generation failed (aichat error: $aichat_status). Check install, API key, model."; zle accept-line; return; fi
    if command -v lolcat >/dev/null 2>&1; then echo -n "AI Generated Command: $(echo "$generated_command" | lolcat)"; else echo -n "AI Generated Command: $generated_command"; fi
    echo -n " [Enter=Execute, Ctrl+C=Cancel, Type to Edit]: "
    local history_file="${AICHA_HISTORY}" user_input; echo "$(date '+%Y-%m-%d %H:%M:%S') - Command Generated: $generated_command" >> "$history_file"
    read -r user_input
    if [[ $? -eq 1 ]]; then BUFFER="$current_buffer"; echo "$(date '+%Y-%m-%d %H:%M:%S') - Command Generation Cancelled" >> "$history_file"; elif [[ -z "$user_input" ]]; then BUFFER="$generated_command"; echo "$(date '+%Y-%m-%d %H:%M:%S') - Command Executed: $generated_command" >> "$history_file"; else BUFFER="$user_input"; echo "$(date '+%Y-%m-%d %H:%M:%S') - Command Edited: $generated_command -> $user_input" >> "$history_file"; fi; zle accept-line
}
zle -N _aichat_command

summarize_output() {
    local output="$1" max_length="${2:-500}" api_key; api_key=$(get_api_key) || return;
    if ! command -v aichat >/dev/null 2>&1; then echo "Install aichat for full summarization"; echo "$output" | head -n 1; return; fi
    local summary
    summary=$(echo "$output" | timeout "$AICHA_TIMEOUT" aichat summarize --model "$AICHA_MODEL" --api-key "$api_key" --max-length "$max_length" 2>/dev/null)
    if [[ $? -ne 0 || -z "$summary" ]]; then echo "Error summarizing output - showing first line instead."; echo "$output" | head -n 1; else
        if command -v lolcat >/dev/null 2>&1; then echo "Summary: $(echo "$summary" | lolcat)"; else echo "Summary: $summary"; fi; fi
}

view_aichat_history() {
    local history_file="${AICHA_HISTORY}"
    if [[ -f "$history_file" ]]; then
        echo "AI Chat History (last 20 entries):"
        if command -v bat >/dev/null 2>&1; then bat --style=plain --color=always "$history_file" | tail -n 20; else cat "$history_file" | tail -n 20; fi
    else
        echo "No AI history found."
    fi
}

edit_aichat_config() {
    local config_file="${AICHA_CONFIG}/config.yaml"
    [[ ! -d "$AICHA_CONFIG" ]] && mkdir -p "$AICHA_CONFIG"
    [[ ! -f "$config_file" ]] && { echo "Creating default aichat config at $config_file"; mkdir -p "$(dirname "$config_file")"; cat <<EOF > "$config_file"
model: gemini
api_key: "" # <-- Set your API Key HERE!
EOF
}
    if command -v nano >/dev/null 2>&1; then nano "$config_file"; elif command -v vim >/dev/null 2>&1; then vim "$config_file"; else echo "No text editor (nano or vim) found. Please install one to edit config."; fi
}

# --- 12.3. Keybindings and Actions ---
bindkey '^[e' _aichat_suggest
bindkey '^[c' _aichat_command
alias ais='_aichat_suggest'
alias aic='_aichat_command'
alias aih='view_aichat_history'
alias aiconf='edit_aichat_config'

# --- 13. Other Keybindings ---
bindkey '^[[H' beginning-of-line bindkey '^[[F' end-of-line bindkey '^?' backward-delete-char bindkey '^W' backward-kill-word bindkey '^R' history-incremental-search-backward bindkey '^[[3~' delete-char bindkey '^K' kill-whole-line bindkey '^A' beginning-of-line bindkey '^E' end-of-line bindkey '^L' clear-screen bindkey '^U' update_all bindkey '^S' sync_dotfiles bindkey '^T' mkcd bindkey '^[^T' take

# --- Post Configuration ---
[[ -f "$HISTFILE.gpg" ]] && decrypt_history
trap 'encrypt_history' EXIT
if (( $+commands[compinit] )); then autoload -Uz compinit && compinit -i 2>/dev/null; fi
welcome_message

if [[ -r "$ZSH_CUSTOM/plugins/aichat/aichat.plugin.zsh" ]]; then source "$ZSH_CUSTOM/plugins/aichat/aichat.plugin.zsh"; elif [[ -r "$ZSH_CUSTOM/plugins/aichat/aichat.sh" ]]; then source "$ZSH_CUSTOM/plugins/aichat/aichat.sh"; elif [[ -r "/data/data/com.termux/files/usr/share/zsh/site-functions/_aichat" ]]; then fpath+=(/data/data/com.termux/files/usr/share/zsh/site-functions) && autoload -Uz _aichat && compinit; fi
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

echo "Enhanced ZSH configuration loaded. Welcome, Termux Wizard! ✨"
END_ZSHRC
)

# --- Helper Functions ---
check_command_exists() { command -v "$1" &> /dev/null; }
install_package() { if ! pkg info "$1" &> /dev/null; then echo "Installing $1..."; pkg install -y "$1"; else echo "$1 is already installed."; fi }
install_packages_list() { local category_name="$1"; shift; echo "Installing $category_name..."; for package in "$@"; do install_package "$package"; done; echo "$category_name installation complete."; }
setup_storage_access() { if ! [ -d ~/storage ]; then echo "Requesting storage access..."; termux-setup-storage; if [ -d ~/storage ]; then echo "Storage access granted."; else echo "Failed to grant storage access. Some features may not work."; fi; else echo "Storage access already configured."; fi }
create_backup_dir() { if ! [ -d "$BACKUP_DIR" ]; then mkdir -p "$BACKUP_DIR"; if [ $? -eq 0 ]; then echo "Backup directory created at $BACKUP_DIR"; else echo "Error creating backup directory at $BACKUP_DIR"; fi; else echo "Backup directory already exists at $BACKUP_DIR"; fi }
backup_termux() { create_backup_dir || return 1; echo "Creating Termux backup to $BACKUP_FILE..."; tar -czvf "$BACKUP_FILE" "$HOME" "$PREFIX"; if [ $? -eq 0 ]; then echo "Termux backup complete! File saved at $BACKUP_FILE"; else echo "Backup failed!"; return 1; fi }
restore_termux_backup() { setup_storage_access || return 1; if [ ! -f "$SDCARD/termux-backup.tar.gz" ]; then echo "Backup file not found at $SDCARD/termux-backup.tar.gz. Please place your backup there."; return 1; fi; echo "Restoring Termux from $SDCARD/termux-backup.tar.gz..."; tar -zxf "$SDCARD/termux-backup.tar.gz" -C "$PREFIX" --recursive-unlink --preserve-permissions; if [ $? -eq 0 ]; then echo "Termux restore complete!"; echo "Please restart Termux for changes to take full effect."; else echo "Restore failed!"; return 1; fi }
install_essential_tools() { local essential_packages=("git" "curl" "wget" "nano" "vim" "python" "clang" "nodejs" "ruby" "perl" "php" "openssh" "proot" "tmux" "screen" "tar" "gzip" "bzip2" "unzip" "zip" "ca-certificates" "less" "more" "diffutils" "patch" "coreutils" "findutils" "grep" "sed" "awk" "bc" "dc" "units" "man" "info" "termux-exec"); install_packages_list "Essential Tools" "${essential_packages[@]}"; }
install_networking_tools() { local networking_packages=("nmap" "net-tools" "dnsutils" "netcat" "tcpdump" "openssl" "sshpass" "httpie" "w3m" "lynx" "links" "elinks" "whois" "traceroute" "mtr" "arping" "host" "dig" "curlftpfs" "rsync" "socat" "ngrep" "tcpflow" "iperf3" "vnstat" "ethtool" "iftop"); install_packages_list "Networking Tools" "${networking_packages[@]}"; }
install_system_monitoring_tools() { local monitoring_packages=("neofetch" "htop" "man" "tree" "ncdu" "lsof" "strace" "termux-api" "df" "du" "free" "uptime" "top" "ps" "pgrep" "pkill" "iotop" "glances" "sar" "vmstat" "mpstat" "pidstat" "iostat" "dstat" "screenfetch"); install_packages_list "System Monitoring Tools" "${monitoring_packages[@]}"; }
install_development_tools() { echo "Installing Development Tools..."; echo "  Setting up Python environment..."; install_package python-pip; pip install --upgrade pip; pip install numpy flask requests beautifulsoup4 pandas scipy matplotlib jupyter || echo "  Warning: Some Python packages may have failed to install."; echo "  Setting up Node.js environment..."; install_package yarn; npm install -g yarn npm nodemon pm2 browser-sync gulp grunt bower webpack parcel || echo "  Warning: Some Node.js packages may have failed to install."; echo "  Setting up Ruby environment..."; install_package ruby; gem install rails bundler jekyll rspec rubocop || echo "  Warning: Some Ruby gems may have failed to install."; local core_dev_packages=("code-server" "make" "cmake" "gcc" "g++" "clang" "rust" "cargo" "go" "golang" "rustc" "php-cli" "lua" "luajit" "valgrind" "gdb" "shellcheck"); install_packages_list "Core Development Tools" "${core_dev_packages[@]}"; echo "Development Tools installation (core + Python/Node.js/Ruby stacks) complete."; }
install_file_management_tools() { local file_mgmt_packages=("zip" "unzip" "tar" "rclone" "rsync" "p7zip" "unrar" "lzop" "xz-utils" "gzip" "bzip2" "pbzip2" "pigz" "plzip" "pxz" "atool" "rpm2cpio" "cpio" "ar" "pax" "sharutils" "uudeview" "uudecode" "uuencode" "base32" "base64" "mmv" "rename" "fd-find" "ripgrep" "fzf" "ranger" "mc" "vifm" "lf" "broot" "yazi"); install_packages_list "File Management Tools" "${file_mgmt_packages[@]}"; }
install_fun_tools() { local fun_packages=("cmatrix" "cowsay" "figlet" "fortune" "sl" "lolcat" "toilet" "boxes" "banner" "pv" "progress" "watch"); install_packages_list "Fun Tools" "${fun_packages[@]}"; }
install_security_tools() { echo "Installing Security Tools (Use Responsibly and Ethically!)..."; read -p "  Are you sure you want to install security tools? [y/N]: " -n 1 -r; echo; if [[ ! $REPLY =~ ^[Yy]$ ]]; then echo "  Security tools installation skipped."; return 0; fi; local security_packages=("hydra" "sqlmap" "aircrack-ng" "john" "wireshark"); install_packages_list "Security Tools" "${security_packages[@]}"; echo "  IMPORTANT: Security tools are powerful and can be used for illegal activities."; echo "  Use them responsibly and ethically, only on systems you own or have explicit permission to test."; }
customize_termux() { echo "Customizing Termux..."; install_package zsh; if ! grep -q "zsh" /etc/passwd; then chsh -s zsh; echo "  Default shell changed to zsh."; else echo "  Default shell is already zsh."; fi; if ! check_command_exists oh-my-zsh; then echo "  Installing Oh-My-Zsh..."; sh -c "$(curl -fsSL $OH_MY_ZSH_INSTALL_URL)"; else echo "  Oh-My-Zsh is already installed."; fi; install_package powerline; if ! grep -q "alias ll='ls -lha'" "$HOME/.zshrc"; then echo "  Adding alias ll='ls -lha' to $HOME/.zshrc"; echo "alias ll='ls -lha'" >> "$HOME/.zshrc"; else echo "  Alias ll='ls -lha' already in $HOME/.zshrc"; fi; source "$HOME/.zshrc"; setup_storage_access; if [ -f "$DEFAULT_WALLPAPER" ]; then echo "  Setting wallpaper to $DEFAULT_WALLPAPER"; termux-wallpaper -f "$DEFAULT_WALLPAPER"; else echo "  Default wallpaper image not found at $DEFAULT_WALLPAPER. Skipping wallpaper setup."; fi; install_package termux-styling; echo "Termux Customization (Zsh, Oh-My-Zsh, Powerline, Wallpaper, Aliases) complete."; }
setup_termux_services() { local services_packages=("termux-services"); install_packages_list "Termux Services" "${services_packages[@]}" || return 1; if ! sv status sshd | grep -q "enabled"; then sv-enable sshd; echo "  sshd service enabled."; else echo "  sshd service already enabled."; fi; if ! sv status ftpd | grep -q "enabled"; then sv-enable ftpd; echo "  ftpd service enabled."; else echo "  ftpd service already enabled."; fi; if ! sv status sshd | grep -q "up"; then sv up sshd; echo "  sshd service started."; else echo "  sshd service already running."; fi; if ! sv status ftpd | grep -q "up"; then sv up ftpd; echo "  ftpd service started."; else echo "  ftpd service already running."; fi; echo "Termux Services (sshd, ftpd) setup complete."; }
setup_aichat_ai_features() { echo "Setting up AIChat AI Features (Gemini Integration)..."; echo "  Step 1: Checking for Rust..."; if check_command_exists rustc && check_command_exists cargo; then echo "  Rust and Cargo are already installed."; else echo "  Rust and Cargo not found. Installing Rust..."; if install_package rust; then echo "  Rust and Cargo installed successfully."; else echo "  Error: Failed to install Rust. AIChat setup cannot continue."; echo "  Please check your internet connection and package availability."; return 1; fi; fi; echo "  Step 2: Installing AIChat..."; if check_command_exists aichat; then echo "  AIChat is already installed."; else echo "  AIChat not found. Installing AIChat using Cargo..."; if ! cargo install aichat; then echo "  Error: Failed to install AIChat using Cargo."; echo "  Please ensure Rust is correctly installed and Cargo is in your PATH."; echo "  Also check your internet connection as Cargo downloads crates from the internet."; return 1; fi; echo "  AIChat installed successfully via Cargo."; fi; echo "  Step 3: Setting up AIChat configuration..."; AICHA_CONFIG="$ZDOTDIR/.config/aichat"; CONFIG_FILE="$AICHA_CONFIG/config.yaml"; if [[ ! -d "$AICHA_CONFIG" ]]; then echo "  Creating AIChat configuration directory: $AICHA_CONFIG"; mkdir -p "$AICHA_CONFIG" || return 1; else echo "  AIChat configuration directory already exists: $AICHA_CONFIG"; fi; if [[ ! -f "$CONFIG_FILE" ]]; then echo "  Creating default AIChat config file: $CONFIG_FILE"; cat <<EOF > "$CONFIG_FILE" model: gemini api_key: "" # <-- IMPORTANT: Set your Gemini API Key in ~/.config/aichat/config.yaml EOF; if [ $? -ne 0 ]; then echo "  Error: Failed to create default AIChat config file."; return 1; fi; else echo "  AIChat config file already exists: $CONFIG_FILE"; fi; echo "  Step 4: API Key Setup Instructions..."; echo "  -------------------------------------------------------------------"; echo "  IMPORTANT: Gemini API Key Setup Required!"; echo "  -------------------------------------------------------------------"; echo "  AIChat is configured to use the Gemini AI model, but requires an API key."; echo "  To enable AI features, you MUST set your Gemini API Key."; echo "  Follow these steps:"; echo "    1. Obtain a Gemini API key from Google AI Studio (or a suitable service)."; echo "    2. Edit the AIChat config file at ~/.config/aichat/config.yaml"; echo "    3. Locate the line 'api_key: \"\"' and replace '\"\"' with your Gemini API key, e.g., 'api_key: \"YOUR_GEMINI_API_KEY\"'"; echo "    4. Save and close ~/.config/aichat/config.yaml."; echo "  -------------------------------------------------------------------"; echo "  * DO NOT put your API key directly in ~/.zshrc or any public file!"; echo "  * ~/.config/aichat/config.yaml is designed for local, private configurations like API keys."; echo "  -------------------------------------------------------------------"; echo "  Step 5: Completion Setup (Automatic in .zshrc)"; echo "  AIChat command completions should be automatically enabled by your .zshrc"; echo "  configuration (if you have correctly set up your .zshrc)."; echo "AIChat AI Features setup complete."; echo "  Please remember to set your Gemini API Key in ~/.config/aichat/config.yaml to use AI features."; }
install_advanced_tools() { local advanced_packages=("unstable-repo" "root-repo" "x11-repo" "qemu-system-x86_64" "ffmpeg" "imagemagick"); install_packages_list "Advanced Tools (and Repositories)" "${advanced_packages[@]}"; echo "  Note: Advanced tools like Qemu and X11-repo are large and may take significant time/space."; }
setup_termux_api_features() { local api_packages=("termux-api"); install_packages_list "Termux-API Features" "${api_packages[@]}" || return 1; echo "Termux-API installed. You can test API features manually now:"; echo "  termux-location"; echo "  termux-battery-status"; echo "  termux-toast \"Hello from Termux Setup Script!\""; echo "  termux-vibrate -d 100"; echo "  termux-notification -t \"Alert\" -c \"Example Notification\""; echo "  termux-telephony-call 123456789"; echo "  termux-sms-send -n 12345 \"Hi from Termux Setup Script!\""; }
install_miscellaneous_tools() { local misc_packages=("man" "info" "termux-exec"); install_packages_list "Miscellaneous Tools" "${misc_packages[@]}"; }
perform_updates() { echo "Updating and upgrading packages..."; pkg update; pkg upgrade; echo "Update and upgrade complete."; }

# --- Main Menu ---
main_menu() {
    while true; do
        clear
        echo "╔══════════════════════════════════╗"
        echo "║        Termux Setup Wizard         ║"
        echo "╚══════════════════════════════════╝"
        echo "Choose options to setup Termux:"
        echo "1) Perform Update & Upgrade"
        echo "2) Grant Storage Access"
        echo "3) Backup Termux"
        echo "4) Restore Termux Backup"
        echo "--------------------------------------"
        echo "5) Install Essential Tools (Recommended)"
        echo "6) Install Networking Tools"
        echo "7) Install System Monitoring Tools"
        echo "8) Install Development Tools"
        echo "9) Install File Management Tools"
        echo "10) Install Fun Tools"
        echo "11) Install Security Tools (慎重に / Careful!)"
        echo "--------------------------------------"
        echo "12) Customize Termux (Zsh, Oh My Zsh, etc.) (Recommended)"
        echo "13) Setup Termux Services (sshd, ftpd)"
        echo "14) Install Advanced Tools (and Repositories - Large Download)"
        echo "15) Setup Termux-API Features"
        echo "16) Install Miscellaneous Tools"
        echo "--------------------------------------"
        echo "19) Setup AIChat AI Features (Gemini)"
        echo "--------------------------------------"
        echo "20) Exit"
        read -p "Enter your choice (1-20): " choice

        case "$choice" in
            1) perform_updates ;;
            2) setup_storage_access ;;
            3) backup_termux ;;
            4) restore_termux_backup ;;
            5) install_essential_tools ;;
            6) install_networking_tools ;;
            7) install_system_monitoring_tools ;;
            8) install_development_tools ;;
            9) install_file_management_tools ;;
            10) install_fun_tools ;;
            11) install_security_tools ;;
            12) customize_termux ;;
            13) setup_termux_services ;;
            14) install_advanced_tools ;;
            15) setup_termux_api_features ;;
            16) install_miscellaneous_tools ;;
            19) setup_aichat_ai_features ;;
            20) echo "Exiting Termux Setup Wizard. Goodbye!"; exit 0 ;;
            *) echo "Invalid choice. Please enter a number between 1 and 20." ;;
        esac
        echo -e "\nPress Enter to return to the main menu..."
        read
    done
}

# --- Script Execution ---
set -e
echo "Starting Termux Enhanced ZSH Setup Wizard..."

# --- Write ZSHRC Content to File ---
echo -e "$ZSHRC_CONTENT" > "$HOME/.zshrc"
echo "Writing enhanced ZSH configuration to ~/.zshrc..."

# --- Run Main Menu ---
main_menu

echo "Termux setup wizard finished. Enjoy your enhanced Termux environment! 🚀"
