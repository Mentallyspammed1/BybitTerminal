#!/bin/bash

# ████████ ███████ ███████ ███    ███ ███████ ████████ ██     ██ ███████  ██████
#    ██    ██      ██      ████  ████ ██         ██    ██     ██ ██      ██  ████
#    ██    █████   ███████ ██ ████ ██ ███████    ██    ██  █  ██ ███████ ██ ██ ██
#    ██    ██           ██ ██  ██  ██      ██    ██    ██ ███ ██      ██ ████  ██
#    ██    ███████ ███████ ██      ██ ███████    ██     ███ ███  ███████  ██████
#
# Termux Setup Spellbook - v3.0
# Author: Pyrmethus the Termux Coding Wizard
# Description: A comprehensive and modular setup script for Termux with user choices,
#              error handling, configuration setup, and mystical colorization.

# --- Arcane Constants (Configuration) ---
export TERMUX_SETUP_SPELLBOOK_VERSION="3.0"
CONFIG_DIR="$HOME/.config/termux-setup-spellbook"
BACKUP_DIR="$HOME/termux-backups"
ZSHRC="$HOME/.zshrc"
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
OH_MY_ZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$OH_MY_ZSH_DIR/custom}"
TMUX_CONFIG_DIR="$HOME/.config/tmux" # Using .config/tmux instead of ~/.tmux
TMUX_CONFIG_FILE="$TMUX_CONFIG_DIR/tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm" # Standard TPM location
VIMRC="$HOME/.vimrc"
GITCONFIG="$HOME/.gitconfig"

# --- Color Incantations (ANSI Escape Codes) ---
# Example usage: print_color "$GREEN" "Success!"
RESET='\033[0m'
# Regular
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
# Bright/Bold
B_BLACK='\033[1;30m'
B_RED='\033[1;31m'
B_GREEN='\033[1;32m'
B_YELLOW='\033[1;33m'
B_BLUE='\033[1;34m'
B_MAGENTA='\033[1;35m'
B_CYAN='\033[1;36m'
B_WHITE='\033[1;37m'
# Backgrounds (add 10 to foreground code)
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'

# --- Utility Glyphs (Helper Functions) ---

# Usage: print_color COLOR "Message string" [NO_NEWLINE]
print_color() {
    local color="$1"
    local message="$2"
    local no_newline="$3"
    if [[ -n "$no_newline" ]]; then
        echo -ne "${color}${message}${RESET}"
    else
        echo -e "${color}${message}${RESET}"
    fi
}

# Checks if a command exists and is executable
check_command_exists() {
    command -v "$1" &>/dev/null
}

# Installs a package using pkg if not already installed
install_pkg_if_missing() {
    local package="$1"
    local description="${2:-$package}" # Optional description
    print_color "$CYAN" "Checking for ${description}..." "NO_NEWLINE"
    if ! pkg info "$package" &>/dev/null; then
        echo # Newline after check
        print_color "$YELLOW" "  -> Casting installation spell for $package..."
        if pkg install -y "$package"; then
            print_color "$GREEN" "  -> $package summoned successfully."
            return 0
        else
            print_color "$RED" "  -> Error! Failed to summon $package. Check your connection and sources."
            return 1
        fi
    else
        print_color "$GREEN" " Already exists."
        return 0
    fi
}

# Installs pip packages
install_pip_packages() {
    if ! check_command_exists pip; then
        print_color "$RED" "Error: pip command not found. Please install Python/pip first."
        return 1
    fi
    print_color "$MAGENTA" "Conjuring Python packages: $*"
    if pip install --upgrade pip && pip install "$@"; then
        print_color "$GREEN" "Python packages summoned successfully."
    else
        print_color "$RED" "Error summoning Python packages."
        return 1
    fi
}

# Installs global npm packages
install_npm_packages() {
    if ! check_command_exists npm; then
        print_color "$RED" "Error: npm command not found. Please install Node.js/npm first."
        return 1
    fi
    print_color "$MAGENTA" "Weaving Node.js incantations: $*"
    if npm install -g "$@"; then
        print_color "$GREEN" "Global Node.js packages woven successfully."
    else
        print_color "$RED" "Error weaving Node.js packages."
        return 1
    fi
}

# Installs ruby gems
install_gem_packages() {
    if ! check_command_exists gem; then
        print_color "$RED" "Error: gem command not found. Please install Ruby/gem first."
        return 1
    fi
    print_color "$MAGENTA" "Polishing Ruby gems: $*"
    if gem install "$@"; then
        print_color "$GREEN" "Ruby gems polished successfully."
    else
        print_color "$RED" "Error polishing Ruby gems."
        return 1
    fi
}


# Ensures storage access is set up
setup_storage_access() {
    print_color "$CYAN" "Verifying storage realm access..."
    if [[ ! -d "$HOME/storage" ]]; then
        print_color "$YELLOW" "Storage link appears broken or uninitialized. Requesting access..."
        termux-setup-storage
        sleep 3 # Give Android time to process
        if [[ -d "$HOME/storage" ]]; then
            print_color "$GREEN" "Storage realm access granted and linked."
            # Attempt to create common dirs if they don't exist
            mkdir -p "$HOME/storage/shared" "$HOME/storage/dcim" "$HOME/storage/downloads" "$HOME/storage/music" "$HOME/storage/pictures" "$HOME/storage/movies"
        else
            print_color "$RED" "Failed to establish link to storage realm. Some spells may fail."
            return 1
        fi
    else
        print_color "$GREEN" "Storage realm link confirmed."
    fi
    # Define SDCARD based on standard link, needed for backup/restore suggestions
    SDCARD="$HOME/storage/shared"
    return 0
}

# Creates the backup directory
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_color "$YELLOW" "Creating backup sanctuary at $BACKUP_DIR..."
        if mkdir -p "$BACKUP_DIR"; then
            print_color "$GREEN" "Sanctuary established."
        else
            print_color "$RED" "Error establishing backup sanctuary at $BACKUP_DIR!"
            return 1
        fi
    else
         print_color "$GREEN" "Backup sanctuary already exists at $BACKUP_DIR."
    fi
     # Ensure storage is accessible if we plan to suggest moving backup
    setup_storage_access
    return 0
}

# Backs up user configuration ($HOME dotfiles and .config)
backup_termux_config() {
    create_backup_dir || return 1
    local backup_file="$BACKUP_DIR/termux-config-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    print_color "$YELLOW" "Preparing configuration backup ritual..."
    print_color "$CYAN" "This will archive important files/folders in your home directory:"
    print_color "$CYAN" "  -> Dotfiles (.zshrc, .bashrc, .vimrc, .gitconfig, etc.)"
    print_color "$CYAN" "  -> .config, .ssh, .termux, .local/bin (if exists)"
    print_color "$WHITE" "------------------------------------------------------------"
    read -p "$(print_color "$B_YELLOW" "Proceed with backup to $backup_file? (y/N): ")" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_color "$YELLOW" "Backup ritual aborted by user."
        return 1
    fi

    print_color "$CYAN" "Gathering configuration essences..."
    # List of essential files/dirs to back up from HOME
    local files_to_backup=()
    # Find common dotfiles directly under HOME
    shopt -s dotglob # Include dotfiles in globbing
    for file in "$HOME"/.*; do
        # Exclude ., .., directories we handle separately, and potentially large cache/history files
        base_name=$(basename "$file")
        if [[ -f "$file" && "$base_name" != "." && "$base_name" != ".." && "$base_name" != ".bash_history" && "$base_name" != ".zsh_history" && "$base_name" != ".lesshst" ]]; then
            files_to_backup+=("$file")
        fi
    done
    shopt -u dotglob # Turn off dotglob

    # Add essential directories
    [[ -d "$HOME/.config" ]] && files_to_backup+=("$HOME/.config")
    [[ -d "$HOME/.ssh" ]] && files_to_backup+=("$HOME/.ssh") # Important!
    [[ -d "$HOME/.termux" ]] && files_to_backup+=("$HOME/.termux") # Termux-specific config
    [[ -d "$HOME/.local/bin" ]] && files_to_backup+=("$HOME/.local/bin") # User scripts
    [[ -d "$HOME/.tmux" ]] && files_to_backup+=("$HOME/.tmux") # User tmux config/plugins
    # Add any other specific files/dirs you need here, e.g., specific project configs if desired
    # files_to_backup+=("$HOME/my_project_config")

    if [[ ${#files_to_backup[@]} -eq 0 ]]; then
        print_color "$RED" "No configuration files or directories found to back up."
        return 1
    fi

    # Use tar with absolute paths relative to root to preserve structure under HOME
    # Use --transform to remove the leading /data/data/com.termux/files/ path prefix
    local home_strip_prefix=$(echo $HOME | sed 's|^/||') # Remove leading /
    if tar -czvf "$backup_file" --transform="s|^${home_strip_prefix}/||S" -C / "${files_to_backup[@]/#/\/}"; then
    # The "${files_to_backup[@]/#/\/}" adds a leading '/' to each element for the -C / context
        print_color "$GREEN" "Configuration backup complete! Archive preserved at:"
        print_color "$B_GREEN" "  $backup_file"
        if [[ -n "$SDCARD" && -d "$SDCARD" ]]; then
             print_color "$YELLOW" "Consider copying this file to your shared storage for safety:"
             print_color "$B_YELLOW" "  cp \"$backup_file\" \"$SDCARD/\""
        fi
    else
        print_color "$RED" "Backup ritual failed!"
        rm -f "$backup_file" # Clean up failed attempt
        return 1
    fi
    return 0
}


# Restores user configuration from a backup
restore_termux_config_backup() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_color "$RED" "Backup sanctuary ($BACKUP_DIR) not found. Nothing to restore."
        return 1
    fi

    print_color "$CYAN" "Available configuration backup archives in $BACKUP_DIR:"
    local backups=("$BACKUP_DIR"/termux-config-backup-*.tar.gz)
    if [[ ! -e "${backups[0]}" ]]; then # Check if the first potential match actually exists
        print_color "$RED" "No configuration backup archives (*.tar.gz) found in $BACKUP_DIR."
        return 1
    fi

    select backup_choice in "${backups[@]}"; do
        if [[ -n "$backup_choice" ]]; then
            break
        else
            print_color "$RED" "Invalid selection. Please choose a number from the list."
        fi
    done

    print_color "$YELLOW" "WARNING: This will overwrite existing configuration files in your home directory"
    print_color "$YELLOW" "         with the contents of $backup_choice."
    print_color "$WHITE" "------------------------------------------------------------------"
    read -p "$(print_color "$B_RED" "Proceed with restoring '$backup_choice'? (y/N): ")" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_color "$YELLOW" "Restoration ritual aborted by user."
        return 1
    fi

    print_color "$CYAN" "Initiating restoration ritual from $backup_choice..."
    # Extract directly into HOME, tar should handle paths relative to HOME because of --transform during backup
    if tar -xzvf "$backup_choice" -C "$HOME"; then
        print_color "$GREEN" "Restoration complete!"
        print_color "$YELLOW" "Please restart Termux or source your shell configuration (e.g., 'source ~/.zshrc')"
        print_color "$YELLOW" "for all changes to take effect."
    else
        print_color "$RED" "Restoration ritual failed! Your home directory might be in an inconsistent state."
        return 1
    fi
    return 0
}

# --- Installation Grimoires (Categorized Functions) ---

update_package_sources() {
    print_color "$B_CYAN" "=== Updating Package Source Lists ==="
    pkg update -y && pkg upgrade -y
    if [[ $? -ne 0 ]]; then
         print_color "$RED" "Failed to update package lists or upgrade packages. Check sources and connection."
         return 1
    fi
    print_color "$GREEN" "Package sources updated and packages upgraded."
    return 0
}

install_essential_tools() {
    print_color "$B_CYAN" "=== Summoning Essential Tools ==="
    local failed=0
    install_pkg_if_missing coreutils || failed=1
    install_pkg_if_missing findutils || failed=1
    install_pkg_if_missing grep || failed=1
    install_pkg_if_missing sed || failed=1
    install_pkg_if_missing gawk "awk" || failed=1 # gawk provides awk
    install_pkg_if_missing tar || failed=1
    install_pkg_if_missing gzip || failed=1
    install_pkg_if_missing curl || failed=1
    install_pkg_if_missing wget || failed=1
    install_pkg_if_missing git || failed=1
    install_pkg_if_missing openssh || failed=1
    install_pkg_if_missing nano "Nano Editor" || failed=1
    install_pkg_if_missing vim "Vim Editor" || failed=1
    install_pkg_if_missing less || failed=1
    install_pkg_if_missing man || failed=1
    install_pkg_if_missing termux-exec || failed=1
    install_pkg_if_missing ca-certificates || failed=1
    install_pkg_if_missing diffutils || failed=1
    install_pkg_if_missing patch || failed=1
    install_pkg_if_missing procps "ps, top, etc." || failed=1 # provides ps, top, free
    return $failed
}

install_shell_enhancements() {
    print_color "$B_CYAN" "=== Enhancing the Shell Interface ==="
    local failed=0
    install_pkg_if_missing zsh "Zsh Shell" || failed=1
    install_pkg_if_missing fzf "Fuzzy Finder" || failed=1
    install_pkg_if_missing fd "fd (find alternative)" || failed=1
    install_pkg_if_missing ripgrep "ripgrep (grep alternative)" || failed=1
    install_pkg_if_missing bat "bat (cat alternative)" || failed=1
    # Zsh/Oh My Zsh setup is separate, called from menu
    return $failed
}

install_multiplexer_tools() {
   print_color "$B_CYAN" "=== Preparing Session Multiplexers ==="
   local failed=0
   install_pkg_if_missing tmux || failed=1
   install_pkg_if_missing screen || failed=1 # Less common now, but some prefer it
   # Tmux Plugin Manager (TPM) setup is separate, called from menu
   return $failed
}


install_networking_tools() {
    print_color "$B_CYAN" "=== Unveiling Networking Tools ==="
    local failed=0
    install_pkg_if_missing nmap || failed=1
    install_pkg_if_missing net-tools "netstat, ifconfig" || failed=1
    install_pkg_if_missing dnsutils "dig, nslookup" || failed=1
    install_pkg_if_missing netcat "nc" || failed=1
    install_pkg_if_missing tcpdump || failed=1
    install_pkg_if_missing openssl || failed=1
    install_pkg_if_missing httpie || failed=1
    install_pkg_if_missing w3m "Text Browser" || failed=1 # Often useful
    install_pkg_if_missing whois || failed=1
    install_pkg_if_missing traceroute || failed=1
    install_pkg_if_missing mtr || failed=1
    install_pkg_if_missing socat || failed=1
    install_pkg_if_missing iperf3 || failed=1
    install_pkg_if_missing vnstat || failed=1
    install_pkg_if_missing termux-api "Termux API (for network info)" || failed=1
    return $failed
}

install_system_monitoring_tools() {
    print_color "$B_CYAN" "=== Illuminating System Monitoring Tools ==="
    local failed=0
    install_pkg_if_missing neofetch || failed=1
    install_pkg_if_missing htop || failed=1
    install_pkg_if_missing tree || failed=1
    install_pkg_if_missing ncdu "Disk Usage Analyzer"|| failed=1
    install_pkg_if_missing lsof "List Open Files" || failed=1
    install_pkg_if_missing strace || failed=1
    install_pkg_if_missing sysstat "sar, iostat, mpstat" || failed=1
    install_pkg_if_missing glances "Glances Monitor" || failed=1
    install_pkg_if_missing dstat || failed=1
    install_pkg_if_missing termux-api "Termux API (for battery, etc)" || failed=1
    return $failed
}

install_development_tools() {
    print_color "$B_CYAN" "=== Forging Development Tools ==="
    local failed=0
    # Base Build Tools
    install_pkg_if_missing build-essential "Essential Build Tools (make, clang, etc)" || failed=1
    # install_pkg_if_missing clang || failed=1 # Usually included in build-essential
    install_pkg_if_missing cmake || failed=1
    install_pkg_if_missing pkg-config || failed=1
    install_pkg_if_missing binutils || failed=1
    install_pkg_if_missing gdb "GNU Debugger" || failed=1
    install_pkg_if_missing shellcheck || failed=1

    # Languages & Runtimes
    install_pkg_if_missing python "Python" || failed=1
    # pip comes with python package in Termux
    if [[ $? -eq 0 ]]; then
      print_color "$MAGENTA" "Upgrading pip..."
      pip install --upgrade pip || print_color "$RED" "pip upgrade failed"
      # Install common Python libs (optional, add more/remove as needed)
      # install_pip_packages numpy pandas requests beautifulsoup4 flask matplotlib jupyter || failed=1
    fi

    install_pkg_if_missing nodejs "Node.js" || failed=1
    if [[ $? -eq 0 ]]; then
      # Install common global NPM packages (optional)
      # install_npm_packages yarn nodemon pm2 || failed=1
       print_color "$YELLOW" "Skipping optional global NPM packages (yarn, nodemon, pm2). Install manually if needed."
    fi

    install_pkg_if_missing ruby "Ruby" || failed=1
    if [[ $? -eq 0 ]]; then
      # Install common gems (optional)
      # install_gem_packages rails bundler jekyll || failed=1
      print_color "$YELLOW" "Skipping optional Ruby Gems (rails, bundler, jekyll). Install manually if needed."
    fi

    install_pkg_if_missing golang "Go Language" || failed=1
    install_pkg_if_missing rust "Rust Language" || failed=1
    install_pkg_if_missing php || failed=1
    install_pkg_if_missing lua || failed=1

    # install_pkg_if_missing code-server "Code Server (VSCode in browser - resource intensive!)" || failed=1

    return $failed
}

install_file_management_tools() {
    print_color "$B_CYAN" "=== Organizing File Management Tools ==="
    local failed=0
    # Archive Tools
    install_pkg_if_missing zip || failed=1
    install_pkg_if_missing unzip || failed=1
    install_pkg_if_missing p7zip "7zip" || failed=1
    install_pkg_if_missing unrar || failed=1
    install_pkg_if_missing bzip2 || failed=1
    install_pkg_if_missing xz-utils "xz" || failed=1
    # Parallel Utils (can be useful on multi-core)
    # install_pkg_if_missing pigz || failed=1
    # install_pkg_if_missing pbzip2 || failed=1
    # install_pkg_if_missing pxz || failed=1

    # TUI File Managers
    install_pkg_if_missing ranger || failed=1
    install_pkg_if_missing mc "Midnight Commander" || failed=1
    install_pkg_if_missing lf || failed=1
    # install_pkg_if_missing yazi # Check if available in pkg

    # Cloud/Sync
    install_pkg_if_missing rclone || failed=1
    install_pkg_if_missing rsync || failed=1

    # Utilities
    install_pkg_if_missing jq "JSON processor" || failed=1
    install_pkg_if_missing xmlstarlet "XML processor" || failed=1
    # install_pkg_if_missing imagemagick # Can be large

    return $failed
}

install_fun_tools() {
    print_color "$B_CYAN" "=== Adding Whimsical Tools ==="
    local failed=0
    install_pkg_if_missing cmatrix || failed=1
    install_pkg_if_missing cowsay || failed=1
    install_pkg_if_missing figlet || failed=1
    install_pkg_if_missing fortune || failed=1
    install_pkg_if_missing sl "Steam Locomotive" || failed=1
    install_pkg_if_missing lolcat "Rainbow Text" || failed=1
    install_pkg_if_missing toilet "ASCII Art Fonts" || failed=1
    install_pkg_if_missing pv "Pipe Viewer" || failed=1 # Also useful utility
    install_pkg_if_missing progress "Progress Monitor" || failed=1 # Also useful utility
    install_pkg_if_missing watch || failed=1 # Also useful utility
    return $failed
}

# --- Configuration Runes (Setup Functions) ---

setup_zsh_ohmyzsh() {
    print_color "$B_MAGENTA" "=== Configuring Zsh & Oh My Zsh ==="
    if ! check_command_exists zsh; then
        print_color "$YELLOW" "Zsh not found. Installing..."
        install_pkg_if_missing zsh || return 1
    fi

    # Set Zsh as default shell if not already
    if [[ "$SHELL" != *"zsh"* ]]; then
        print_color "$YELLOW" "Attempting to set Zsh as default shell..."
        if chsh -s zsh; then
            print_color "$GREEN" "Zsh set as default shell. Restart Termux for change to take effect."
        else
            print_color "$RED" "Failed to set Zsh as default shell via chsh. Do it manually if needed."
        fi
    else
        print_color "$GREEN" "Zsh is already the default shell."
    fi

    # Install Oh My Zsh if not installed
    if [[ ! -d "$OH_MY_ZSH_DIR" ]]; then
        print_color "$YELLOW" "Oh My Zsh not found. Installing..."
        if ! check_command_exists curl && ! check_command_exists wget ; then
             install_pkg_if_missing curl || install_pkg_if_missing wget || { print_color "$RED" "Need curl or wget to install Oh My Zsh."; return 1; }
        fi
        # OMZ installer runs zsh at the end, temporarily exit script to allow it, then user restarts manually
        print_color "$CYAN" "Launching Oh My Zsh installer... Follow its prompts."
        print_color "$YELLOW" "The script will exit after OMZ setup. Re-run script for further steps if needed."
        sh -c "$(curl -fsSL $OH_MY_ZSH_INSTALL_URL)" "" --unattended || sh -c "$(wget -O- $OH_MY_ZSH_INSTALL_URL)" "" --unattended
        local omz_install_status=$?
        if [[ $omz_install_status -ne 0 ]]; then
             print_color "$RED" "Oh My Zsh installation failed."
             return 1
        fi
         print_color "$B_GREEN" "Oh My Zsh installation successful!"
         print_color "$B_YELLOW" "IMPORTANT: Please exit and restart Termux now, then re-run this script to continue setup (e.g., plugins)."
         exit 0 # Exit cleanly to let user restart for OMZ to take effect properly
    else
        print_color "$GREEN" "Oh My Zsh already installed."
    fi

    # Install common plugins (if OMZ exists)
     if [[ -d "$OH_MY_ZSH_DIR" ]]; then
        if ! check_command_exists git; then
            install_pkg_if_missing git || { print_color "$RED" "Git is required to install plugins."; return 1; }
        fi
        # zsh-autosuggestions
        local autosuggest_dir="${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
        if [[ ! -d "$autosuggest_dir" ]]; then
            print_color "$YELLOW" "Installing zsh-autosuggestions plugin..."
            git clone https://github.com/zsh-users/zsh-autosuggestions "$autosuggest_dir" || print_color "$RED" "Failed to clone zsh-autosuggestions"
        else
            print_color "$GREEN" "zsh-autosuggestions already cloned."
        fi

        # zsh-syntax-highlighting
        local highlight_dir="${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
        if [[ ! -d "$highlight_dir" ]]; then
            print_color "$YELLOW" "Installing zsh-syntax-highlighting plugin..."
            git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$highlight_dir" || print_color "$RED" "Failed to clone zsh-syntax-highlighting"
        else
            print_color "$GREEN" "zsh-syntax-highlighting already cloned."
        fi

        # Modify .zshrc to enable plugins
        print_color "$CYAN" "Ensuring plugins are enabled in $ZSHRC..."
        if grep -q "plugins=(git)" "$ZSHRC"; then
             # Check if plugins already exist
            if ! grep -q "zsh-autosuggestions" "$ZSHRC" || ! grep -q "zsh-syntax-highlighting" "$ZSHRC"; then
                print_color "$YELLOW" "Adding plugins to $ZSHRC..."
                # Use sed - careful with syntax for different OS (using simple works for Termux's sed)
                sed -i '/^plugins=(git/s/git/git zsh-autosuggestions zsh-syntax-highlighting/' "$ZSHRC"
                print_color "$GREEN" "Plugins added. Source ~/.zshrc or restart Termux."
            else
                 print_color "$GREEN" "Plugins already seem to be enabled in $ZSHRC."
            fi
        else
            print_color "$YELLOW" "Could not find default 'plugins=(git)' line in $ZSHRC. Add manually if needed:"
            print_color "$YELLOW" "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)"
        fi
     else
         print_color "$RED" "Cannot configure plugins as Oh My Zsh directory not found."
         return 1
     fi

    print_color "$GREEN" "Zsh & Oh My Zsh configuration spells complete."
    return 0
}

setup_tmux_tpm() {
    print_color "$B_MAGENTA" "=== Configuring Tmux & TPM ==="
    if ! check_command_exists tmux; then
        print_color "$YELLOW" "Tmux not found. Installing..."
        install_pkg_if_missing tmux || return 1
    fi
    if ! check_command_exists git; then
        install_pkg_if_missing git || { print_color "$RED" "Git is required to install TPM."; return 1; }
    fi

    # Install Tmux Plugin Manager (TPM) if not installed
    if [[ ! -d "$TPM_DIR" ]]; then
        print_color "$YELLOW" "Tmux Plugin Manager (TPM) not found. Installing..."
        mkdir -p "$(dirname "$TPM_DIR")" # Ensure parent dir exists
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
        if [[ $? -ne 0 ]]; then
            print_color "$RED" "Failed to clone TPM."
            return 1
        fi
        print_color "$GREEN" "TPM installed successfully."
    else
        print_color "$GREEN" "TPM already installed."
    fi

    # Create a basic tmux config file if it doesn't exist
     mkdir -p "$TMUX_CONFIG_DIR" # Ensure config dir exists
    if [[ ! -f "$TMUX_CONFIG_FILE" ]]; then
        print_color "$YELLOW" "Creating basic Tmux configuration at $TMUX_CONFIG_FILE..."
        cat > "$TMUX_CONFIG_FILE" << EOF
# Pyrmethus's Basic Tmux Config

# Set prefix to Ctrl-a (screen default) - Change if desired
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Improve colors
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",*256col*:Tc" # True Color support if terminal supports it

# UTF8 support
# set -g utf8 on # Usually default now
# set -g status-utf8 on # Usually default now

# Mouse mode
set -g mouse on

# Better splitting
bind | split-window -h -c "#{pane_current_path}" # Horizontal split, same dir
bind - split-window -v -c "#{pane_current_path}" # Vertical split, same dir
unbind '"'
unbind %

# Pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Pane resizing
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# List of plugins (using TPM)
# Add or remove plugins here
set -g @plugin 'tmux-plugins/tpm'          # TPM itself
set -g @plugin 'tmux-plugins/tmux-sensible' # Sensible defaults
set -g @plugin 'tmux-plugins/tmux-resurrect' # Persist sessions across restarts
set -g @plugin 'tmux-plugins/tmux-continuum' # Auto-save/restore sessions
set -g @plugin 'tmux-plugins/tmux-yank'      # Better copy-paste
# set -g @plugin 'tmux-plugins/tmux-open'     # Open highlighted text in browser/editor
# set -g @plugin 'dracula/tmux'              # Dracula theme (or other theme)
# set -g @plugin 'tmux-plugins/tmux-battery' # Battery status (requires termux-api)
# set -g @plugin 'tmux-plugins/tmux-cpu'     # CPU usage

# Configure plugins (examples)
set -g @continuum-restore 'on' # Enable auto-restore
# set -g @dracula-show-powerline true # Dracula theme options

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '$TPM_DIR/tpm'

EOF
        print_color "$GREEN" "Basic $TMUX_CONFIG_FILE created."
        print_color "$YELLOW" "Start tmux, then press 'Prefix + I' (e.g., Ctrl+a then I) to install listed plugins."
    else
        print_color "$GREEN" "$TMUX_CONFIG_FILE already exists."
         # Ensure TPM run command is present and at the end
        if ! grep -q "run '$TPM_DIR/tpm'" "$TMUX_CONFIG_FILE"; then
            print_color "$YELLOW" "Adding TPM initialization to $TMUX_CONFIG_FILE..."
            echo "" >> "$TMUX_CONFIG_FILE"
            echo "# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)" >> "$TMUX_CONFIG_FILE"
            echo "run '$TPM_DIR/tpm'" >> "$TMUX_CONFIG_FILE"
        fi
         print_color "$YELLOW" "Remember to press 'Prefix + I' inside tmux to install new plugins if you edited the list."
    fi

    print_color "$GREEN" "Tmux & TPM configuration spells complete."
    return 0
}

setup_vim() {
    print_color "$B_MAGENTA" "=== Setting up Basic Vim Configuration ==="
    if ! check_command_exists vim; then
        print_color "$YELLOW" "Vim not found. Installing..."
        install_pkg_if_missing vim || return 1
    fi

    if [[ ! -f "$VIMRC" ]]; then
        print_color "$YELLOW" "Creating basic Vim configuration at $VIMRC..."
        cat > "$VIMRC" << EOF
" Pyrmethus's Basic Vim Config

syntax on            " Enable syntax highlighting
filetype plugin indent on " Enable filetype detection, plugins, and indentation

set number           " Show line numbers
set relativenumber   " Show relative line numbers (hybrid mode)
set cursorline       " Highlight the current line
set showcmd          " Show command in bottom bar
set wildmenu         " Enhanced command-line completion
set showmatch        " Highlight matching brackets
set incsearch        " Incremental search
set hlsearch         " Highlight search results
set ignorecase       " Ignore case in search by default
set smartcase        " Override ignorecase if search pattern contains uppercase letters

set tabstop=4        " Number of spaces that a <Tab> in the file counts for
set shiftwidth=4     " Number of spaces to use for each step of (auto)indent
set expandtab        " Use spaces instead of tabs
set autoindent       " Copy indent from current line when starting a new line
set smartindent      " Be smart about indentation

set scrolloff=5      " Keep 5 lines visible above/below cursor
set sidescrolloff=10 " Keep 10 columns visible left/right of cursor

set encoding=utf-8   " Use UTF-8 encoding

" Enable mouse support in all modes
set mouse=a

" Better buffer splitting
set splitright       " Open vertical splits to the right
set splitbelow       " Open horizontal splits below

" Basic backup/swap file settings (consider disabling if using VCS heavily)
" set backupdir=~/.vim/backup//
" set directory=~/.vim/swap//
" set undodir=~/.vim/undo//
" set undofile " Persistent undo

" Create directories if they don't exist
" if !isdirectory(&backupdir) | call mkdir(&backupdir, "p") | endif
" if !isdirectory(&directory) | call mkdir(&directory, "p") | endif
" if !isdirectory(&undodir) | call mkdir(&undodir, "p") | endif


" Add more customizations below

EOF
        print_color "$GREEN" "Basic $VIMRC created."
    else
        print_color "$GREEN" "$VIMRC already exists. No changes made."
    fi
    print_color "$GREEN" "Vim configuration spell complete."
    return 0
}

setup_git() {
    print_color "$B_MAGENTA" "=== Configuring Git User Information ==="
     if ! check_command_exists git; then
        print_color "$YELLOW" "Git not found. Installing..."
        install_pkg_if_missing git || return 1
    fi

    local current_name=$(git config --global --get user.name)
    local current_email=$(git config --global --get user.email)

    print_color "$CYAN" "Checking current Git global configuration..."
    if [[ -n "$current_name" ]]; then
        print_color "$GREEN" "Current git user.name: $current_name"
    else
        print_color "$YELLOW" "Git user.name is not set."
    fi
     if [[ -n "$current_email" ]]; then
        print_color "$GREEN" "Current git user.email: $current_email"
    else
        print_color "$YELLOW" "Git user.email is not set."
    fi

    read -p "$(print_color "$B_YELLOW" "Enter your Git user name [${current_name:-Your Name}]: ")" git_name
    read -p "$(print_color "$B_YELLOW" "Enter your Git user email [${current_email:-you@example.com}]: ")" git_email

    # Use defaults if user just presses Enter
    git_name="${git_name:-$current_name}"
    git_email="${git_email:-$current_email}"

    if [[ -z "$git_name" || -z "$git_email" ]]; then
         print_color "$RED" "Both name and email are required for Git configuration. Aborting."
         return 1
    fi

    print_color "$CYAN" "Setting global Git configuration:"
    print_color "$WHITE" "  user.name = $git_name"
    print_color "$WHITE" "  user.email = $git_email"
    read -p "$(print_color "$B_YELLOW" "Confirm these settings? (y/N): ")" confirm
     if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        print_color "$GREEN" "Git global configuration updated."

        # Optional: Set default branch name (main is common now)
        git config --global init.defaultBranch main
        print_color "$CYAN" "Set default branch name to 'main'."

        # Optional: Set editor
        git config --global core.editor vim # or nano, etc.
        print_color "$CYAN" "Set default Git editor to 'vim'."

    else
        print_color "$YELLOW" "Git configuration not changed."
        return 1
    fi
    print_color "$GREEN" "Git configuration spell complete."
    return 0
}


# --- The Grand Grimoire (Main Menu) ---

display_main_menu() {
    print_color "$B_MAGENTA" "\n📜 Pyrmethus's Termux Setup Spellbook (v$TERMUX_SETUP_SPELLBOOK_VERSION) 📜"
    print_color "$CYAN" "================================================="
    print_color "$WHITE" " [ 1] Grant Storage Access"
    print_color "$WHITE" " [ 2] Update Package Sources & Upgrade All"
    print_color "$CYAN" "\n--- Installation Spells ---"
    print_color "$WHITE" " [ 3] Install Essential Tools"
    print_color "$WHITE" " [ 4] Install Shell Enhancements (Zsh, fzf, etc.)"
    print_color "$WHITE" " [ 5] Install Multiplexers (Tmux, Screen)"
    print_color "$WHITE" " [ 6] Install Networking Tools"
    print_color "$WHITE" " [ 7] Install System Monitoring Tools"
    print_color "$WHITE" " [ 8] Install Development Tools (Python, Node, Go, Rust, etc.)"
    print_color "$WHITE" " [ 9] Install File Management Tools (Ranger, mc, rclone, etc.)"
    print_color "$WHITE" " [10] Install Fun Tools (cmatrix, cowsay, etc.)"
    print_color "$WHITE" " [11] Cast ALL Installation Spells (3-10)"
    print_color "$CYAN" "\n--- Configuration Runes ---"
    print_color "$WHITE" " [12] Configure Zsh + Oh My Zsh + Plugins"
    print_color "$WHITE" " [13] Configure Tmux + TPM + Basic Plugins"
    print_color "$WHITE" " [14] Configure Basic Vim (~/.vimrc)"
    print_color "$WHITE" " [15] Configure Git User Info"
    print_color "$WHITE" " [16] Apply ALL Configuration Runes (12-15)"
    print_color "$CYAN" "\n--- Backup & Restore Rituals ---"
    print_color "$WHITE" " [17] Backup Termux Configuration ($HOME dotfiles)"
    print_color "$WHITE" " [18] Restore Termux Configuration"
    print_color "$CYAN" "================================================="
    print_color "$B_RED"   " [ q ] Quit Spellbook"
    print_color "$CYAN" "================================================="
    print_color "$B_YELLOW" "Enter your choice: " "NO_NEWLINE"
}

main() {
    # Create base config dir if needed
     mkdir -p "$CONFIG_DIR"

    while true; do
        display_main_menu
        read choice

        case "$choice" in
            1) setup_storage_access ;;
            2) update_package_sources ;;
            3) install_essential_tools ;;
            4) install_shell_enhancements ;;
            5) install_multiplexer_tools ;;
            6) install_networking_tools ;;
            7) install_system_monitoring_tools ;;
            8) install_development_tools ;;
            9) install_file_management_tools ;;
            10) install_fun_tools ;;
            11)
                print_color "$B_BLUE" "Casting ALL Installation Spells..."
                install_essential_tools && \
                install_shell_enhancements && \
                install_multiplexer_tools && \
                install_networking_tools && \
                install_system_monitoring_tools && \
                install_development_tools && \
                install_file_management_tools && \
                install_fun_tools
                print_color "$B_GREEN" "All installation spells cast (check output for errors)."
                ;;
            12) setup_zsh_ohmyzsh ;;
            13) setup_tmux_tpm ;;
            14) setup_vim ;;
            15) setup_git ;;
            16)
                print_color "$B_BLUE" "Applying ALL Configuration Runes..."
                # Note: Zsh setup might exit the script, run it last or inform user
                setup_tmux_tpm && \
                setup_vim && \
                setup_git && \
                setup_zsh_ohmyzsh # Run Zsh setup last due to potential exit
                print_color "$B_GREEN" "All configuration runes applied (check output)."
                ;;
            17) backup_termux_config ;;
            18) restore_termux_config_backup ;;
            q|Q)
                print_color "$B_MAGENTA" "Leaving the Spellbook. May your commands be swift and true!"
                break
                ;;
            *)
                print_color "$RED" "Invalid choice '$choice'. Please select a valid option."
                ;;
        esac
        print_color "$CYAN" "\nPress Enter to return to the Spellbook..."
        read -r
    done
}

# --- Begin the Incantation ---
main

exit 0

