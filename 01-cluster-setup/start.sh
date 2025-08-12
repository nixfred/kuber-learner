#!/bin/bash

# Module 1: Cluster Setup - Interactive Start Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Progress tracking
PROGRESS_FILE="../.progress/module_1.progress"
mkdir -p "../.progress"

clear

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}    MODULE 1: CLUSTER SETUP & ARCHITECTURE                     ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Welcome to your Kubernetes journey!${NC}"
echo -e "This module will guide you through setting up your first cluster."
echo ""

# Function to check if a command exists
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is not installed"
        return 1
    fi
}

# Function to pause and wait for user
pause() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

# Function to run a command with explanation
run_with_explanation() {
    local explanation=$1
    local command=$2
    
    echo -e "\n${CYAN}$explanation${NC}"
    echo -e "${WHITE}Running: ${YELLOW}$command${NC}"
    echo ""
    eval $command
}

# Check prerequisites
echo -e "${YELLOW}Step 1: Checking Prerequisites${NC}"
echo "════════════════════════════════"
echo ""

docker_installed=false
kubectl_installed=false
kind_installed=false

if check_command docker; then
    docker_installed=true
fi

if check_command kubectl; then
    kubectl_installed=true
fi

if check_command kind; then
    kind_installed=true
fi

echo ""

# Install missing tools
if [ "$kubectl_installed" = false ] || [ "$kind_installed" = false ]; then
    echo -e "${YELLOW}Some tools are missing. Would you like to install them now? (y/n)${NC}"
    read -r install_choice
    
    if [ "$install_choice" = "y" ] || [ "$install_choice" = "Y" ]; then
        if [ "$kubectl_installed" = false ]; then
            echo -e "\n${CYAN}Installing kubectl...${NC}"
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
            echo -e "${GREEN}✓ kubectl installed successfully${NC}"
        fi
        
        if [ "$kind_installed" = false ]; then
            echo -e "\n${CYAN}Installing kind...${NC}"
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
            echo -e "${GREEN}✓ kind installed successfully${NC}"
        fi
    else
        echo -e "${RED}Please install the missing tools manually and run this script again.${NC}"
        exit 1
    fi
fi

pause

# Interactive cluster creation
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}    CREATING YOUR FIRST KUBERNETES CLUSTER                     ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Let's create your Kubernetes cluster!${NC}"
echo ""
echo "Choose cluster type:"
echo "  1) Simple (single-node) - Best for learning basics"
echo "  2) Multi-node - Production-like setup"
echo "  3) Custom - Use your own configuration"
echo ""
echo -n "Your choice (1-3): "
read cluster_choice

case $cluster_choice in
    1)
        echo -e "\n${CYAN}Creating a simple single-node cluster...${NC}"
        # Check if cluster already exists
        if kind get clusters 2>/dev/null | grep -q "k8s-learning"; then
            echo -e "${YELLOW}Cluster 'k8s-learning' already exists!${NC}"
            echo -n "Delete and recreate? (y/n): "
            read recreate
            if [ "$recreate" = "y" ]; then
                kind delete cluster --name k8s-learning
                kind create cluster --name k8s-learning
            else
                echo -e "${GREEN}Using existing cluster${NC}"
            fi
        else
            kind create cluster --name k8s-learning
        fi
        ;;
    2)
        echo -e "\n${CYAN}Creating a multi-node cluster...${NC}"
        # Check if cluster already exists
        if kind get clusters 2>/dev/null | grep -q "k8s-learning"; then
            echo -e "${YELLOW}Cluster 'k8s-learning' already exists!${NC}"
            echo -n "Delete and recreate? (y/n): "
            read recreate
            if [ "$recreate" = "y" ]; then
                kind delete cluster --name k8s-learning
            else
                echo -e "${GREEN}Using existing cluster${NC}"
                pause
                break
            fi
        fi
        if [ ! -f configs/multi-node.yaml ]; then
            mkdir -p configs
            cat > configs/multi-node.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
    - containerPort: 30000
      hostPort: 30000
      protocol: TCP
    - containerPort: 30001
      hostPort: 30001
      protocol: TCP
  - role: worker
  - role: worker
EOF
        fi
        kind create cluster --config configs/multi-node.yaml --name k8s-learning
        ;;
    3)
        echo -e "${YELLOW}Please provide path to your kind config file:${NC}"
        read config_path
        kind create cluster --config "$config_path" --name k8s-learning
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}✓ Cluster created successfully!${NC}"
pause

# Explore the cluster
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}    EXPLORING YOUR CLUSTER                                     ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

run_with_explanation "Let's see your cluster information:" "kubectl cluster-info --context kind-k8s-learning"
pause

run_with_explanation "View your cluster nodes:" "kubectl get nodes -o wide"
pause

run_with_explanation "Check all running pods in the cluster:" "kubectl get pods --all-namespaces"
pause

run_with_explanation "Examine the control plane components:" "kubectl get pods -n kube-system"
pause

# Interactive exercises
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}    INTERACTIVE EXERCISES                                      ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Exercise 1: Explore a Node${NC}"
echo "Try to get detailed information about one of your nodes."
echo -e "${YELLOW}Hint: Use 'kubectl describe node <node-name>'${NC}"
echo ""
echo "Enter the command you would use:"
read user_command

if [[ $user_command == *"describe node"* ]]; then
    echo -e "${GREEN}✓ Correct! Let's run it:${NC}"
    node_name=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    kubectl describe node $node_name | head -30
else
    echo -e "${YELLOW}Not quite. Here's the correct command:${NC}"
    node_name=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    echo "kubectl describe node $node_name"
    kubectl describe node $node_name | head -30
fi

pause

echo -e "\n${CYAN}Exercise 2: Check Component Health${NC}"
echo "How would you check if all control plane components are healthy?"
echo -e "${YELLOW}Hint: Use 'kubectl get componentstatuses' or check pod status${NC}"
echo ""
echo "Enter your command:"
read user_command

echo -e "${GREEN}Let's check the component health:${NC}"
kubectl get pods -n kube-system | grep -E "Running|NAME"

pause

# Module completion
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}    MODULE SUMMARY                                             ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}🎉 Congratulations! You've completed Module 1!${NC}"
echo ""
echo "You've learned:"
echo -e "  ${GREEN}✓${NC} How to install Kubernetes tools (kubectl, kind)"
echo -e "  ${GREEN}✓${NC} How to create single and multi-node clusters"
echo -e "  ${GREEN}✓${NC} How to explore cluster components"
echo -e "  ${GREEN}✓${NC} Basic kubectl commands"
echo ""

# Save progress
touch "$PROGRESS_FILE"
echo "$(date): Module 1 completed" >> "$PROGRESS_FILE"

echo -e "${CYAN}What's Next?${NC}"
echo "1. Review the README.md for additional exercises"
echo "2. Try the challenge script: ./challenge/setup-challenge.sh"
echo "3. When ready, proceed to Module 2: Pods & Container Basics"
echo ""

echo -e "${YELLOW}Important: Keep your cluster running for the next modules!${NC}"
echo "To delete it later: kind delete cluster --name k8s-learning"
echo ""

echo -e "${GREEN}Great job! Press Enter to exit.${NC}"
read