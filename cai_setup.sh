#!/bin/bash

# CAI + Ollama Complete Setup Script for Kali Linux
# This script will install and configure everything needed for bug bounty hunting with CAI
# Run with: bash setup_cai.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}
╔══════════════════════════════════════════════════════════════╗
║                    CAI + OLLAMA SETUP SCRIPT                ║
║              Bug Bounty Ready AI Installation                ║
╚══════════════════════════════════════════════════════════════╝
${NC}"
}

print_section() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_system() {
    print_section "CHECKING SYSTEM REQUIREMENTS"
    
    # Check OS
    if [[ ! -f /etc/debian_version ]]; then
        print_error "This script is designed for Debian-based systems (Kali/Ubuntu)"
        exit 1
    fi
    
    # Check available memory
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $mem_gb -lt 8 ]]; then
        print_warning "System has ${mem_gb}GB RAM. 8GB+ recommended for larger models"
    else
        print_status "System has ${mem_gb}GB RAM - Good for running large models"
    fi
    
    # Check GPU
    if command_exists nvidia-smi; then
        local gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)
        print_status "NVIDIA GPU detected: $gpu_info"
        
        # Check VRAM
        local vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
        if [[ $vram_mb -lt 4000 ]]; then
            print_warning "GPU has ${vram_mb}MB VRAM. Consider using smaller models (7B instead of 14B)"
        else
            print_status "GPU has ${vram_mb}MB VRAM - Good for large models"
        fi
    else
        print_warning "No NVIDIA GPU detected. Will use CPU-only mode (slower)"
    fi
    
    # Check internet connection
    if ping -c 1 google.com &> /dev/null; then
        print_status "Internet connection verified"
    else
        print_error "No internet connection. Cannot proceed with downloads"
        exit 1
    fi
}

# Function to update system
update_system() {
    print_section "UPDATING SYSTEM PACKAGES"
    
    print_status "Updating package lists..."
    sudo apt update -qq
    
    print_status "Upgrading system packages..."
    sudo apt upgrade -y -qq
    
    print_status "Installing essential build tools..."
    sudo apt install -y \
        software-properties-common \
        build-essential \
        curl \
        wget \
        git \
        gpg \
        ca-certificates \
        lsb-release
}

# Function to install Python 3.13
install_python() {
    print_section "INSTALLING PYTHON 3.13"
    
    # Check if Python 3.13 is already available
    if command_exists python3.13; then
        local python_version=$(python3.13 --version)
        print_status "Python 3.13 already installed: $python_version"
        return
    fi
    
    # Check if Python 3.12+ is available as fallback
    for py_ver in python3.13 python3.12; do
        if command_exists $py_ver; then
            print_status "Using $py_ver: $($py_ver --version)"
            PYTHON_CMD=$py_ver
            return
        fi
    done
    
    print_status "Installing Python development packages..."
    sudo apt install -y \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-setuptools \
        python3-wheel
    
    # Try to add deadsnakes PPA for newer Python versions
    print_status "Adding deadsnakes PPA for Python 3.13..."
    if sudo add-apt-repository ppa:deadsnakes/ppa -y 2>/dev/null; then
        sudo apt update -qq
        
        print_status "Installing Python 3.13..."
        sudo apt install -y python3.13 python3.13-venv python3.13-dev
        
        if command_exists python3.13; then
            PYTHON_CMD=python3.13
            print_status "Python 3.13 installed successfully: $(python3.13 --version)"
        else
            print_warning "Python 3.13 installation failed, will use system Python"
            PYTHON_CMD=python3
        fi
    else
        print_warning "Could not add deadsnakes PPA, using system Python"
        PYTHON_CMD=python3
    fi
}

# Function to create Python virtual environment
create_venv() {
    print_section "CREATING PYTHON VIRTUAL ENVIRONMENT"
    
    local venv_dir="$HOME/cai_env"
    
    if [[ -d "$venv_dir" ]]; then
        print_warning "Virtual environment already exists at $venv_dir"
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Removing existing virtual environment..."
            rm -rf "$venv_dir"
        else
            print_status "Using existing virtual environment..."
            return
        fi
    fi
    
    print_status "Creating virtual environment with $PYTHON_CMD..."
    $PYTHON_CMD -m venv "$venv_dir"
    
    print_status "Activating virtual environment..."
    source "$venv_dir/bin/activate"
    
    print_status "Upgrading pip..."
    pip install --upgrade pip setuptools wheel
    
    echo "export CAI_VENV_PATH=\"$venv_dir\"" >> ~/.bashrc
}

# Function to install CAI
install_cai() {
    print_section "INSTALLING CAI FRAMEWORK"
    
    local venv_dir="$HOME/cai_env"
    source "$venv_dir/bin/activate"
    
    print_status "Installing CAI framework..."
    pip install cai-framework
    
    # Verify installation
    if command_exists cai; then
        local cai_version=$(cai --version 2>/dev/null || echo "unknown")
        print_status "CAI installed successfully: $cai_version"
    else
        print_error "CAI installation verification failed"
        exit 1
    fi
}

# Function to install Ollama
install_ollama() {
    print_section "INSTALLING OLLAMA"
    
    if command_exists ollama; then
        print_status "Ollama already installed: $(ollama --version)"
        return
    fi
    
    print_status "Downloading and installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    
    # Wait a moment for installation to complete
    sleep 2
    
    if command_exists ollama; then
        print_status "Ollama installed successfully"
    else
        print_error "Ollama installation failed"
        exit 1
    fi
}

# Function to start Ollama service
start_ollama() {
    print_section "STARTING OLLAMA SERVICE"
    
    # Check if ollama is already running
    if pgrep -x "ollama" > /dev/null; then
        print_status "Ollama is already running"
        return
    fi
    
    print_status "Starting Ollama service..."
    ollama serve &
    
    # Wait for service to start
    print_status "Waiting for Ollama service to start..."
    local attempts=0
    while ! curl -s http://localhost:11434/api/version > /dev/null 2>&1; do
        sleep 1
        attempts=$((attempts + 1))
        if [[ $attempts -gt 30 ]]; then
            print_error "Ollama service failed to start within 30 seconds"
            exit 1
        fi
    done
    
    print_status "Ollama service is running"
}

# Function to download AI models
download_models() {
    print_section "DOWNLOADING AI MODELS"
    
    # Check available disk space
    local free_space_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $free_space_gb -lt 20 ]]; then
        print_error "Insufficient disk space: ${free_space_gb}GB free. Need at least 20GB"
        exit 1
    fi
    
    print_status "Available disk space: ${free_space_gb}GB"
    
    # Determine which models to download based on system specs
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    local models_to_download=()
    
    if [[ $mem_gb -ge 16 ]] && command_exists nvidia-smi; then
        local vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
        if [[ $vram_mb -ge 8000 ]]; then
            print_status "High-spec system detected. Downloading large models..."
            models_to_download=("qwen2.5:14b" "deepseek-coder:7b" "qwen2.5:7b")
        else
            print_status "Medium-spec system detected. Downloading medium models..."
            models_to_download=("qwen2.5:7b" "deepseek-coder:7b")
        fi
    else
        print_status "Lower-spec system detected. Downloading smaller models..."
        models_to_download=("qwen2.5:7b")
    fi
    
    for model in "${models_to_download[@]}"; do
        print_status "Downloading $model (this may take several minutes)..."
        if ollama pull "$model"; then
            print_status "Successfully downloaded $model"
        else
            print_error "Failed to download $model"
        fi
    done
    
    print_status "Listing installed models..."
    ollama list
}

# Function to create configuration files
create_config() {
    print_section "CREATING CONFIGURATION FILES"
    
    local config_dir="$HOME/.cai"
    mkdir -p "$config_dir"
    
    # Create .env file
    print_status "Creating .env configuration file..."
    cat > "$config_dir/.env" << 'EOF'
# CAI Configuration File
# Generated by setup script

# API Keys (required - use placeholder for OpenAI if not using)
OPENAI_API_KEY="sk-1234"
ANTHROPIC_API_KEY=""
OLLAMA_API_BASE="http://localhost:11434/v1"

# CAI Settings
PROMPT_TOOLKIT_NO_CPR=1
CAI_STREAM=false
CAI_MODEL="ollama/qwen2.5:7b"
CAI_DEBUG=1
CAI_TRACING=true
CAI_MAX_TURNS=20
CAI_BRIEF=false

# Memory and Context
CAI_MEMORY="episodic"
CAI_ENV_CONTEXT=true
CAI_PRICE_LIMIT="5.00"

# Workspace
CAI_WORKSPACE="bug_bounty"
CAI_WORKSPACE_DIR="./cai_workspaces/"

# Reporting
CAI_REPORT="pentesting"
EOF
    
    # Create workspace directory
    mkdir -p "$HOME/cai_workspaces"
    
    # Create activation script
    print_status "Creating CAI activation script..."
    cat > "$HOME/start_cai.sh" << EOF
#!/bin/bash
# CAI Activation Script

# Activate Python environment
source $HOME/cai_env/bin/activate

# Set environment variables
export \$(cat $HOME/.cai/.env | grep -v '^#' | xargs)

# Start Ollama if not running
if ! pgrep -x "ollama" > /dev/null; then
    echo "Starting Ollama service..."
    ollama serve &
    sleep 3
fi

# Launch CAI
echo "Starting CAI..."
cd "$HOME/cai_workspaces"
cai
EOF
    
    chmod +x "$HOME/start_cai.sh"
    
    # Add alias to .bashrc
    if ! grep -q "alias cai-start" ~/.bashrc; then
        echo 'alias cai-start="$HOME/start_cai.sh"' >> ~/.bashrc
    fi
    
    print_status "Configuration files created in $config_dir"
    print_status "Workspace directory created at $HOME/cai_workspaces"
    print_status "Activation script created at $HOME/start_cai.sh"
}

# Function to run system tests
run_tests() {
    print_section "RUNNING SYSTEM TESTS"
    
    local venv_dir="$HOME/cai_env"
    source "$venv_dir/bin/activate"
    
    # Test 1: Ollama API
    print_status "Testing Ollama API..."
    if curl -s http://localhost:11434/api/version > /dev/null; then
        print_status "✓ Ollama API responding"
    else
        print_error "✗ Ollama API not responding"
        return 1
    fi
    
    # Test 2: Model availability
    print_status "Testing model availability..."
    if ollama list | grep -q "qwen2.5"; then
        print_status "✓ Models available"
    else
        print_error "✗ No models found"
        return 1
    fi
    
    # Test 3: CAI import
    print_status "Testing CAI installation..."
    if python -c "import cai; print('CAI import successful')" 2>/dev/null; then
        print_status "✓ CAI import successful"
    else
        print_error "✗ CAI import failed"
        return 1
    fi
    
    # Test 4: Simple model inference
    print_status "Testing model inference..."
    local test_response=$(ollama run qwen2.5:7b "Say 'test successful'" 2>/dev/null | head -1)
    if [[ -n "$test_response" ]]; then
        print_status "✓ Model inference working: $test_response"
    else
        print_warning "⚠ Model inference test inconclusive (may still work)"
    fi
    
    print_status "All tests completed successfully!"
}

# Function to show final instructions
show_final_instructions() {
    print_section "INSTALLATION COMPLETE!"
    
    echo -e "${GREEN}
╔══════════════════════════════════════════════════════════════╗
║                    INSTALLATION SUCCESSFUL!                 ║
╚══════════════════════════════════════════════════════════════╝
${NC}

${YELLOW}Quick Start Commands:${NC}
  ${CYAN}cai-start${NC}                 - Start CAI with all services
  ${CYAN}source ~/cai_env/bin/activate${NC} - Activate Python environment
  ${CYAN}ollama list${NC}               - List installed models
  ${CYAN}ollama serve${NC}              - Start Ollama service manually

${YELLOW}Configuration Files:${NC}
  ${CYAN}~/.cai/.env${NC}               - CAI configuration
  ${CYAN}~/start_cai.sh${NC}            - CAI startup script
  ${CYAN}~/cai_workspaces/${NC}         - Your workspace directory

${YELLOW}Example Commands to Try in CAI:${NC}
  ${CYAN}Target IP: 127.0.0.1, perform basic port scan${NC}
  ${CYAN}Analyze this URL for security vulnerabilities: https://example.com${NC}
  ${CYAN}Help me find XSS vulnerabilities in a web application${NC}

${YELLOW}Troubleshooting:${NC}
  - If CAI won't start: Run ${CYAN}source ~/cai_env/bin/activate${NC} first
  - If Ollama errors: Run ${CYAN}ollama serve${NC} in another terminal  
  - If GPU not working: Check ${CYAN}nvidia-smi${NC} output
  - Config issues: Edit ${CYAN}~/.cai/.env${NC}

${YELLOW}Security Reminder:${NC}
${RED}⚠  ONLY test on systems you own or have permission to test!${NC}
${RED}⚠  Follow responsible disclosure for any vulnerabilities found!${NC}

${GREEN}Happy Bug Hunting! 🎯${NC}
"
}

# Main execution function
main() {
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "Don't run this script as root! Run as normal user with sudo access."
        exit 1
    fi
    
    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        print_status "This script needs sudo access for package installation"
        sudo -v
    fi
    
    print_header
    
    # Set default Python command
    PYTHON_CMD=python3
    
    # Run installation steps
    check_system
    update_system
    install_python
    create_venv
    install_cai
    install_ollama
    start_ollama
    download_models
    create_config
    
    # Run tests
    if run_tests; then
        show_final_instructions
    else
        print_error "Some tests failed. Installation may have issues."
        print_warning "Try running: source ~/cai_env/bin/activate && cai"
        exit 1
    fi
}

# Handle script interruption
trap 'echo -e "\n${RED}Installation interrupted!${NC}"; exit 130' INT

# Run main function
main "$@"
