#!/bin/bash

# Termux Setup Script - Optimized & User-Friendly Edition
# Author: Pyrmethus the Termux Coding Wizard
# Description: A comprehensive and modular setup script for Termux, focusing on usability, clarity, and essential tools.

# --- Configuration ---
BACKUP_DIR="$HOME/termux-backups"
BACKUP_FILE="$BACKUP_DIR/termux-backup-$(date +%Y%m%d%H%M%S).tar.gz"
ZSHRC="$HOME/.zshrc"
OH_MY_ZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
WALLPAPER_DIR="$SDCARD/Pictures" # Assuming $SDCARD is set by termux-setup-storage
DEFAULT_WALLPAPER="$WALLPAPER_DIR/your_image.jpg" # Replace with your default image path
TMUX_CONFIG_DIR="$HOME/.tmux"
TMUX_CONFIG_FILE="$TMUX_CONFIG_DIR/tmux.conf"
VIMRC="$HOME/.vimrc"
GITCONFIG="$HOME/.gitconfig"
SCREENRC="$HOME/.screenrc"
INPUTRC="$HOME/.inputrc"
BASHRC="$HOME/.bashrc"

# --- Helper Functions ---

check_command_exists() {
  if ! command -v "$1" &> /dev/null; then
    return 1 # Command does NOT exist
  else
    return 0 # Command exists
  fi
}

install_package() {
  local package="$1"
  if ! pkg info "$package" &> /dev/null; then
    echo "Installing $package..."
    if ! pkg install -y "$package"; then
      echo "  Error installing $package. Please check your internet connection and package availability."
      return 1 # Indicate installation failure
    else
      echo "  $package installed successfully."
      return 0 # Indicate installation success
    fi
  else
    echo "  $package is already installed."
    return 0 # Indicate already installed
  fi
}

install_packages_list() {
  local category_name="$1"
  shift
  local packages=("$@")

  echo "Installing $category_name..."
  for package in "${packages[@]}"; do
    install_package "$package" || return 1 # Exit function if any package fails
  done
  echo "$category_name installation complete."
  return 0
}


setup_storage_access() {
  if ! [ -d ~/storage ]; then
    echo "Requesting storage access..."
    termux-setup-storage
    if [ -d ~/storage ]; then
      echo "Storage access granted."
    else
      echo "Failed to grant storage access. Some features may not work."
      return 1
    fi
  else
    echo "Storage access already configured."
  fi
  return 0
}

create_backup_dir() {
  if ! [ -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    if [ $? -eq 0 ]; then
      echo "Backup directory created at $BACKUP_DIR"
    else
      echo "Error creating backup directory at $BACKUP_DIR"
      return 1
    fi
  else
    echo "Backup directory already exists at $BACKUP_DIR"
  fi
  return 0
}

backup_termux() {
  create_backup_dir || return 1
  echo "Creating Termux backup to $BACKUP_FILE..."
  tar -czvf "$BACKUP_FILE" "$HOME" "$PREFIX"
  if [ $? -eq 0 ]; then
    echo "Termux backup complete! File saved at $BACKUP_FILE"
  else
    echo "Backup failed!"
    return 1
  fi
  return 0
}

restore_termux_backup() {
  setup_storage_access || return 1
  if [ ! -f "$SDCARD/termux-backup.tar.gz" ]; then
    echo "Backup file not found at $SDCARD/termux-backup.tar.gz. Please place your backup there."
    return 1
  fi
  echo "Restoring Termux from $SDCARD/termux-backup.tar.gz..."
  tar -zxf "$SDCARD/termux-backup.tar.gz" -C "$PREFIX" --recursive-unlink --preserve-permissions
  if [ $? -eq 0 ]; then
    echo "Termux restore complete!"
    echo "Please restart Termux for changes to take full effect."
  else
    echo "Restore failed!"
    return 1
  fi
  return 0
}


install_essential_tools() {
  local essential_packages=(
    git curl wget nano vim python clang nodejs ruby perl php openssh proot tmux screen
    tar gzip bzip2 unzip zip ca-certificates less more diffutils patch coreutils findutils
    grep sed awk bc dc units man info termux-exec
  )
  install_packages_list "Essential Tools" "${essential_packages[@]}"
  return 0
}

install_networking_tools() {
  local networking_packages=(
    nmap net-tools dnsutils netcat tcpdump openssl sshpass httpie w3m lynx links elinks
    whois traceroute mtr arping host dig curlftpfs rsync socat ngrep tcpflow iperf3 vnstat
    ethtool iftop
  )
  install_packages_list "Networking Tools" "${networking_packages[@]}"
  return 0
}

install_system_monitoring_tools() {
  local monitoring_packages=(
    neofetch htop man tree ncdu lsof strace termux-api df du free uptime top ps pgrep pkill
    iotop glances sar vmstat mpstat pidstat iostat dstat screenfetch
  )
  install_packages_list "System Monitoring Tools" "${monitoring_packages[@]}"
  return 0
}

install_development_tools() {
  echo "Installing Development Tools..."

  # Python Stack
  echo "  Setting up Python environment..."
  install_package python-pip || return 1
  pip install --upgrade pip
  pip install numpy flask requests beautifulsoup4 pandas scipy matplotlib jupyter || echo "  Warning: Some Python packages may have failed to install."

  # Node.js Stack
  echo "  Setting up Node.js environment..."
  install_package yarn || return 1 # installs nodejs if not present
  npm install -g yarn npm nodemon pm2 browser-sync gulp grunt bower webpack parcel || echo "  Warning: Some Node.js packages may have failed to install."

  # Ruby Stack
  echo "  Setting up Ruby environment..."
  install_package ruby || return 1 # installs ruby if not present
  gem install rails bundler jekyll rspec rubocop || echo "  Warning: Some Ruby gems may have failed to install."

  # Core Development Tools
  local core_dev_packages=(
    code-server make cmake gcc g++ clang rust cargo go golang rustc php-cli lua luajit
    valgrind gdb shellcheck
  )
  install_packages_list "Core Development Tools" "${core_dev_packages[@]}"

  echo "Development Tools installation (core + Python/Node.js/Ruby stacks) complete."
  return 0
}


install_file_management_tools() {
  local file_mgmt_packages=(
    zip unzip tar rclone rsync p7zip unrar lzop xz-utils gzip bzip2 pbzip2 pigz plzip pxz
    atool rpm2cpio cpio ar pax sharutils uudeview uudecode uuencode base32 base64 mmv rename
    fd-find ripgrep fzf ranger mc vifm lf broot yazi
  )
  install_packages_list "File Management Tools" "${file_mgmt_packages[@]}"
  return 0
}


install_fun_tools() {
  local fun_packages=(
    cmatrix cowsay figlet fortune sl lolcat toilet boxes banner pv progress watch
  )
  install_packages_list "Fun Tools" "${fun_packages[@]}"
  return 0
}


install_security_tools() {
  echo "Installing Security Tools (Use Responsibly and Ethically!)..."
  read -p "  Are you sure you want to install security tools? [y/N]: " -n 1 -r
  echo    # (optional) move to a new line after answer
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "  Security tools installation skipped."
    return 0
  fi

  local security_packages=(
    hydra sqlmap aircrack-ng john wireshark
  )
  install_packages_list "Security Tools" "${security_packages[@]}"
  echo "  IMPORTANT: Security tools are powerful and can be used for illegal activities."
  echo "  Use them responsibly and ethically, only on systems you own or have explicit permission to test."
  return 0
}


customize_termux() {
  echo "Customizing Termux..."

  # Zsh Setup
  install_package zsh || return 1
  if ! grep -q "zsh" /etc/passwd; then # Check if zsh is already default shell
    chsh -s zsh
    echo "  Default shell changed to zsh."
  else
    echo "  Default shell is already zsh."
  fi

  if ! check_command_exists oh-my-zsh; then
    echo "  Installing Oh-My-Zsh..."
    sh -c "$(curl -fsSL $OH_MY_ZSH_INSTALL_URL)"
  else
    echo "  Oh-My-Zsh is already installed."
  fi

  install_package powerline || return 1

  if ! grep -q "alias ll='ls -lha'" "$ZSHRC"; then # Check if alias already exists
    echo "  Adding alias ll='ls -lha' to $ZSHRC"
    echo "alias ll='ls -lha'" >> "$ZSHRC"
  else
    echo "  Alias ll='ls -lha' already in $ZSHRC"
  fi
  source "$ZSHRC" # Reload zshrc to apply changes

  # Wallpaper Setup
  setup_storage_access # Ensure storage access for wallpaper
  if [ -f "$DEFAULT_WALLPAPER" ]; then
    echo "  Setting wallpaper to $DEFAULT_WALLPAPER"
    termux-wallpaper -f "$DEFAULT_WALLPAPER"
  else
    echo "  Default wallpaper image not found at $DEFAULT_WALLPAPER. Skipping wallpaper setup."
  fi
  install_package termux-styling || return 1 # Install styling if not present
  echo "Termux Customization (Zsh, Oh-My-Zsh, Powerline, Wallpaper, Aliases) complete."
  return 0
}


setup_termux_services() {
  local services_packages=(termux-services)
  install_packages_list "Termux Services" "${services_packages[@]}" || return 1

  if ! sv status sshd | grep -q "enabled"; then
    sv-enable sshd
    echo "  sshd service enabled."
  else
    echo "  sshd service already enabled."
  fi
  if ! sv status ftpd | grep -q "enabled"; then
    sv-enable ftpd
    echo "  ftpd service enabled."
  else
    echo "  ftpd service already enabled."
  fi

  if ! sv status sshd | grep -q "up"; then
    sv up sshd
    echo "  sshd service started."
  else
    echo "  sshd service already running."
  fi
  if ! sv status ftpd | grep -q "up"; then
    sv up ftpd
    echo "  ftpd service started."
  else
    echo "  ftpd service already running."
  fi
  echo "Termux Services (sshd, ftpd) setup complete."
  return 0
}


install_advanced_tools() {
  local advanced_packages=(
    unstable-repo root-repo x11-repo qemu-system-x86_64 ffmpeg imagemagick
  )
  install_packages_list "Advanced Tools (and Repositories)" "${advanced_packages[@]}"
  echo "  Note: Advanced tools like Qemu and X11-repo are large and may take significant time/space."
  return 0
}


setup_termux_api_features() {
  local api_packages=(termux-api)
  install_packages_list "Termux-API Features" "${api_packages[@]}" || return 1
  echo "Termux-API installed. You can test API features manually now:"
  echo "  termux-location"
  echo "  termux-battery-status"
  echo "  termux-toast \"Hello from Termux Setup Script!\""
  echo "  termux-vibrate -d 100"
  echo "  termux-notification -t \"Alert\" -c \"Example Notification\""
  echo "  termux-telephony-call 123456789"
  echo "  termux-sms-send -n 12345 \"Hi from Termux Setup Script!\""
  return 0
}


install_miscellaneous_tools() {
  local misc_packages=(man info termux-exec) # Keeping man and info for category clarity
  install_packages_list "Miscellaneous Tools" "${misc_packages[@]}"
  return 0
}


perform_updates() {
  echo "Updating and upgrading packages..."
  pkg update
  pkg upgrade
  echo "Update and upgrade complete."
  return 0
}


# --- Main Script ---

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
    echo "8) Install Development Tools (inc. Python, Node.js, Ruby stacks)"
    echo "9) Install File Management Tools"
    echo "10) Install Fun Tools"
    echo "11) Install Security Tools (慎重に / Careful!)"
    echo "--------------------------------------"
    echo "12) Customize Termux (Zsh, Oh-My-Zsh, etc.) (Recommended)"
    echo "13) Setup Termux Services (sshd, ftpd)"
    echo "14) Install Advanced Tools (and Repositories - Large Download)"
    echo "15) Setup Termux-API Features"
    echo "16) Install Miscellaneous Tools"
    echo "--------------------------------------"
    echo "17) Run Recommended Basic Setup (1-2, 5, 8-9, 12)"
    echo "18) Exit"
    read -p "Enter your choice (1-18): " choice

    case $choice in
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
      17) # Run recommended basic setups
          perform_updates
          setup_storage_access
          install_essential_tools
          install_development_tools
          install_file_management_tools
          customize_termux
          ;;
      18) echo "Exiting Termux Setup Wizard. Goodbye!"; exit 0 ;;
      *) echo "Invalid choice. Please enter a number between 1 and 18." ;;
    esac
    echo -e "\nPress Enter to return to the main menu..."
    read
  done
}

# --- Script Execution ---
set -e # Exit immediately if a command exits with a non-zero status

echo "Starting Termux Setup Wizard..."
main_menu

echo "Termux setup wizard finished. Enjoy your enhanced Termux environment! 🚀"
