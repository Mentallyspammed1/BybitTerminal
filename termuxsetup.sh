```bash                                                    #!/data/data/com.termux/files/usr/bin/env bash             
# Configuration files
ZSHRC=$HOME/.zshrc                                         VIMRC=$HOME/.vimrc                                         TMUX_CONFIG=$HOME/.tmux.conf                                                                                          # Colors for output                                        RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'                                        BLUE='\033[0;34m'                                          NC='\033[0m' # No Color                                                                                               # Function to install packages                             install_package() {
    echo -e "${BLUE}Installing $1...${NC}"
    if pkg install "$1" &> /dev/null; then                         echo -e "${GREEN}Successfully installed: $1${NC}"      else                                                           echo -e "${RED}Error installing $1${NC}"                   echo -e "${YELLOW}Continuing with the setup...${NC}"
        # Optionally exit here if critical                         # exit 1                                               fi                                                     }                                                                                                                     # Function to install packages and exit on critical failure
install_critical() {
    echo -e "${BLUE}Installing critical package: $1${NC}"      if pkg install "$1" &> /dev/null; then                         echo -e "${GREEN}Successfully installed: $1${NC}"      else                                                           echo -e "${RED}Failed to install critical package: $1${NC}"
        echo -e "${RED}Setup cannot proceed. Exiting...${NC}"                                                                 exit 1                                                 fi                                                     }

# Base tools installation                                  install_base() {                                               echo -e "${BLUE}Installing base tools...${NC}"             local -a packages=(git openssh wget curl unzip unrar)      for pkg in "${packages[@]}"; do
        install_package "$pkg"
    done                                                   }                                                                                                                     # Development tools installation                           install_dev() {
    echo -e "${BLUE}Installing development tools...${NC}"
    local -a packages=(python nodejs npm clang cmake gcc)      for pkg in "${packages[@]}"; do                                install_package "$pkg"                                 done                                                   }                                                                                                                     # Shell utilities installation
install_shell_utils() {
    echo -e "${BLUE}Installing shell utilities...${NC}"
    local -a packages=(neofetch htop tree ncdu lsof strace)
    for pkg in "${packages[@]}"; do                                install_package "$pkg"                                 done                                                   }                                                          
# Fun utilities installation
install_fun() {
    echo -e "${BLUE}Installing fun utilities...${NC}"
    local -a packages=(cmatrix cowsay figlet fortune sl)
    for pkg in "${packages[@]}"; do                                install_package "$pkg"                                 done                                                   }

# Configure shell environment
configure_shell() {                                            echo -e "${BLUE}Configuring shell environment...${NC}"

    # Backup existing configs
    if [ -f "$ZSHRC" ]; then
        cp "$ZSHRC" "${ZSHRC}.bak"
    fi
    if [ -f "$VIMRC" ]; then                                       cp "$VIMRC" "${VIMRC}.bak"
    fi
    if [ -f "$TMUX_CONFIG" ]; then
        cp "$TMUX_CONFIG" "${TMUX_CONFIG}.bak"
    fi

    # ZSH configuration
    echo "alias ls='ls -G'" >> "$ZSHRC"                        echo "alias ll='ls -l'" >> "$ZSHRC"

    # Vim configuration
    echo "syntax on" >> "$VIMRC"                               echo "set number" >> "$VIMRC"                              echo "set tabstop=4" >> "$VIMRC"
    echo "set shiftwidth=4" >> "$VIMRC"

    # Tmux configuration                                       echo "set -g default-terminal 'screen-256color'" >> "$TMUX_CONFIG"
    echo "bind-key -T copy-mode-vi 'v' send-keys -X begin-selection" >> "$TMUX_CONFIG"
    echo "bind-key -T copy-mode-vi 'y' send-keys -X copy-selection-and-cancel" >> "$TMUX_CONFIG"                      }

# Ensure storage access
request_storage_access() {
    echo -e "${BLUE}Requesting storage access...${NC}"
    echo -e "${YELLOW}Please grant storage access when prompted.${NC}"
    termux-setup-storage
                                                               # Check if storage was granted
    if [ ! -d ~/storage ]; then
        echo -e "${RED}Storage access not granted. Some functions may not work properly.${NC}"
        echo -e "${YELLOW}Continuing with the setup...${NC}"
    fi
}                                                                                                                     # Main execution                                           echo -e "${GREEN}Starting Termux setup...${NC}"

# Request storage access
request_storage_access
                                                           # Install all packages                                     install_critical git  # Ensure git is installed as it's critical                                                      install_base                                               install_dev
install_shell_utils
install_fun                                                                                                           # Apply configurations                                     configure_shell                                                                                                       # Source the new configurations
echo -e "${BLUE}Reloading shell configuration...${NC}"
source "$ZSHRC"                                                                                                       echo -e "${GREEN}Termux setup completed successfully!${NC}"echo -e "${BLUE}Type 'ls -G' to see your files with colors!${NC}"                                                     ```
