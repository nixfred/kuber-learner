#!/bin/bash

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

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_hint() {
    echo -e "${PURPLE}💡 HINT:${NC} $1"
}

print_command() {
    echo -e "${CYAN}$ $1${NC}"
}

# Function to run command and show output
run_command() {
    local cmd="$1"
    local description="$2"
    
    echo
    print_status "$description"
    print_command "$cmd"
    echo
    eval "$cmd"
    local exit_code=$?
    echo
    if [ $exit_code -eq 0 ]; then
        print_success "Command executed successfully!"
    else
        print_error "Command failed with exit code $exit_code"
    fi
    return $exit_code
}

# Function to wait for user input
wait_for_user() {
    echo
    read -p "Press Enter to continue..."
    echo
}

# Function to check if cluster exists
check_cluster() {
    if kubectl cluster-info &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to create kind cluster if it doesn't exist
ensure_cluster() {
    if ! check_cluster; then
        print_warning "No Kubernetes cluster found. Let's create one with kind!"
        echo
        print_status "Creating a local Kubernetes cluster with kind..."
        print_command "kind create cluster --name kuber-learner"
        echo
        
        if kind create cluster --name kuber-learner; then
            print_success "Cluster created successfully!"
            echo
            print_status "Waiting for cluster to be ready..."
            sleep 5
        else
            print_error "Failed to create cluster. Please check your kind and Docker installation."
            exit 1
        fi
    else
        print_success "Kubernetes cluster is already running!"
    fi
}

# Main script
clear
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                     Kubernetes Cluster Explorer                 ║
║                           Exercise 2                            ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status "This exercise will guide you through exploring a Kubernetes cluster and its components."
echo

# Check prerequisites
print_header "Checking Prerequisites"
if ! command -v kubectl &>/dev/null; then
    print_error "kubectl is not installed. Please run 01-verify-tools.sh first."
    exit 1
fi

if ! command -v kind &>/dev/null; then
    print_error "kind is not installed. Please run 01-verify-tools.sh first."
    exit 1
fi

print_success "All prerequisites are met!"
wait_for_user

# Ensure we have a cluster
print_header "Setting Up Kubernetes Cluster"
ensure_cluster
wait_for_user

# Exercise 1: Cluster Information
print_header "Exercise 1: Basic Cluster Information"
echo "Let's start by getting basic information about our Kubernetes cluster."

run_command "kubectl cluster-info" "Getting cluster information"
wait_for_user

run_command "kubectl version --short" "Checking Kubernetes version"
wait_for_user

# Exercise 2: Explore Nodes
print_header "Exercise 2: Exploring Cluster Nodes"
echo "Nodes are the worker machines in Kubernetes. Let's explore them."

run_command "kubectl get nodes" "Listing all nodes in the cluster"

echo
print_hint "In a kind cluster, you typically see one control-plane node."
print_hint "The STATUS should be 'Ready' and ROLES should show 'control-plane'."
wait_for_user

run_command "kubectl get nodes -o wide" "Getting detailed node information"

echo
print_hint "The -o wide flag shows additional information like internal/external IPs and container runtime."
wait_for_user

run_command "kubectl describe nodes" "Getting detailed node description"

echo
print_hint "The describe command shows comprehensive information including:"
echo "   • Node conditions (Ready, MemoryPressure, DiskPressure, etc.)"
echo "   • Capacity and allocatable resources"
echo "   • System information"
echo "   • Currently running pods"
wait_for_user

# Exercise 3: Explore Namespaces
print_header "Exercise 3: Understanding Namespaces"
echo "Namespaces provide a way to divide cluster resources between multiple users."

run_command "kubectl get namespaces" "Listing all namespaces"

echo
print_hint "Default namespaces in Kubernetes:"
echo "   • default: Default namespace for objects with no other namespace"
echo "   • kube-system: Namespace for objects created by Kubernetes system"
echo "   • kube-public: Readable by all users (including those not authenticated)"
echo "   • kube-node-lease: Holds lease objects associated with each node"
wait_for_user

run_command "kubectl get all --all-namespaces" "Viewing all resources across all namespaces"

echo
print_hint "This shows all resources (pods, services, deployments, etc.) in all namespaces."
print_hint "Notice how system components run in the kube-system namespace."
wait_for_user

# Exercise 4: Explore System Pods
print_header "Exercise 4: System Components (Pods)"
echo "Let's explore the system components that make Kubernetes work."

run_command "kubectl get pods -n kube-system" "Viewing system pods"

echo
print_hint "Key system components you should see:"
echo "   • etcd: Kubernetes' database"
echo "   • kube-apiserver: The API server"
echo "   • kube-controller-manager: Runs controllers"
echo "   • kube-scheduler: Schedules pods to nodes"
echo "   • coredns: Cluster DNS"
echo "   • kube-proxy: Network proxy"
wait_for_user

# Let's describe a few key components
run_command "kubectl describe pod -n kube-system -l component=etcd" "Exploring etcd (cluster database)"
wait_for_user

run_command "kubectl describe pod -n kube-system -l component=kube-apiserver" "Exploring kube-apiserver"
wait_for_user

# Exercise 5: Explore Services
print_header "Exercise 5: Cluster Services"
echo "Services provide stable endpoints for pods."

run_command "kubectl get services --all-namespaces" "Viewing all services"

echo
print_hint "The kubernetes service in the default namespace is how you access the API server."
echo "Services in kube-system namespace support cluster operations."
wait_for_user

run_command "kubectl describe service kubernetes" "Describing the kubernetes API service"
wait_for_user

# Exercise 6: Interactive Exploration
print_header "Exercise 6: Interactive Exploration"
echo "Now it's your turn! Try some commands yourself."
echo

commands=(
    "kubectl get componentstatuses"
    "kubectl get endpoints --all-namespaces"
    "kubectl top nodes"
    "kubectl api-resources"
    "kubectl api-versions"
)

echo "Here are some useful commands to try:"
for cmd in "${commands[@]}"; do
    echo "   • $cmd"
done
echo

while true; do
    echo
    print_status "Enter a kubectl command to try (or 'exit' to continue):"
    read -p "kubectl " user_command
    
    if [ "$user_command" = "exit" ]; then
        break
    fi
    
    if [ -n "$user_command" ]; then
        echo
        print_command "kubectl $user_command"
        echo
        kubectl $user_command
        echo
        if [ $? -eq 0 ]; then
            print_success "Great! Command executed successfully."
        else
            print_error "Command failed. Try again or type 'exit' to continue."
            print_hint "Make sure your command syntax is correct."
        fi
    fi
done

# Exercise Summary
print_header "Exercise Summary - What You've Learned"
echo
print_success "🎉 Congratulations! You've successfully explored a Kubernetes cluster!"
echo
echo "Key concepts covered:"
echo "✓ Cluster information and version"
echo "✓ Nodes and their roles"
echo "✓ Namespaces and resource organization"
echo "✓ System components (control plane pods)"
echo "✓ Services and endpoints"
echo "✓ Interactive kubectl exploration"
echo

print_status "Key takeaways:"
echo "• Kubernetes clusters consist of nodes that run your workloads"
echo "• The control plane components manage the cluster state"
echo "• Namespaces help organize and isolate resources"
echo "• kubectl is your primary tool for interacting with the cluster"
echo "• System components run as pods in the kube-system namespace"
echo

print_hint "Next: Run ./03-node-management.sh to learn about managing nodes"
echo
print_status "Exercise 2 completed successfully!"