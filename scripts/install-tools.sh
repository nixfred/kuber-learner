#!/bin/bash

# Install script with proper architecture detection

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Installing Kubernetes Tools${NC}"
echo "=============================="

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

echo -e "${CYAN}Detected: OS=$OS, Architecture=$ARCH${NC}"

# Map architecture names
case "$ARCH" in
    x86_64)
        ARCH_NAME="amd64"
        ;;
    aarch64|arm64)
        ARCH_NAME="arm64"
        ;;
    armv7l|armv7)
        ARCH_NAME="arm"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Installing for: $OS-$ARCH_NAME${NC}\n"

# Install kubectl
install_kubectl() {
    echo -e "${BLUE}Installing kubectl...${NC}"
    
    if command -v kubectl &> /dev/null; then
        echo -e "${GREEN}✓ kubectl already installed${NC}"
        kubectl version --client --short 2>/dev/null || true
    else
        # Get the latest stable version
        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
        
        # Download kubectl for the correct architecture
        echo "Downloading kubectl $KUBECTL_VERSION for $OS/$ARCH_NAME..."
        curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH_NAME}/kubectl"
        
        # Make executable and move
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        
        echo -e "${GREEN}✓ kubectl installed successfully${NC}"
        kubectl version --client --short 2>/dev/null || true
    fi
}

# Install kind
install_kind() {
    echo -e "\n${BLUE}Installing kind...${NC}"
    
    if command -v kind &> /dev/null; then
        echo -e "${GREEN}✓ kind already installed${NC}"
        kind version
    else
        # kind version
        KIND_VERSION="v0.20.0"
        
        # Download kind for the correct architecture
        echo "Downloading kind $KIND_VERSION for $OS-$ARCH_NAME..."
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${OS}-${ARCH_NAME}"
        
        # Make executable and move
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        
        echo -e "${GREEN}✓ kind installed successfully${NC}"
        kind version
    fi
}

# Install helm (optional but useful)
install_helm() {
    echo -e "\n${BLUE}Installing helm (optional)...${NC}"
    
    if command -v helm &> /dev/null; then
        echo -e "${GREEN}✓ helm already installed${NC}"
        helm version --short
    else
        echo "Installing helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        echo -e "${GREEN}✓ helm installed successfully${NC}"
    fi
}

# Main installation
main() {
    echo -e "${YELLOW}Starting installation...${NC}\n"
    
    # Check if running with proper permissions
    if [ "$EUID" -eq 0 ]; then 
        echo -e "${RED}Please don't run this script as root${NC}"
        exit 1
    fi
    
    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}This script needs sudo access to install tools in /usr/local/bin${NC}"
        echo "Please enter your password:"
        sudo true
    fi
    
    install_kubectl
    install_kind
    
    # Ask about optional tools
    echo -e "\n${YELLOW}Would you like to install helm? (y/n)${NC}"
    read -r install_helm_choice
    if [[ "$install_helm_choice" =~ ^[Yy]$ ]]; then
        install_helm
    fi
    
    echo -e "\n${GREEN}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Installation complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    
    echo -e "\nInstalled tools:"
    command -v kubectl &> /dev/null && echo -e "  ${GREEN}✓${NC} kubectl: $(kubectl version --client --short 2>/dev/null | grep Client)"
    command -v kind &> /dev/null && echo -e "  ${GREEN}✓${NC} kind: $(kind version)"
    command -v helm &> /dev/null && echo -e "  ${GREEN}✓${NC} helm: $(helm version --short)"
    
    echo -e "\n${CYAN}Next steps:${NC}"
    echo "1. Run 'make setup' to create your cluster"
    echo "2. Run 'make start' to begin learning"
}

main "$@"