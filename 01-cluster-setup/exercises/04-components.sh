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

print_component() {
    echo -e "${YELLOW}🔧 COMPONENT:${NC} $1"
}

# Function to run command and show output
run_command() {
    local cmd="$1"
    local description="$2"
    local hide_output="$3"
    
    echo
    print_status "$description"
    print_command "$cmd"
    echo
    
    if [ "$hide_output" = "quiet" ]; then
        eval "$cmd" &>/dev/null
    else
        eval "$cmd"
    fi
    
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

# Function to explain component
explain_component() {
    local component="$1"
    local description="$2"
    local purpose="$3"
    
    echo
    print_component "$component"
    echo "Description: $description"
    echo "Purpose: $purpose"
    echo
}

# Main script
clear
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                 Kubernetes Components Deep Dive                 ║
║                           Exercise 4                            ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status "This exercise will give you a comprehensive understanding of Kubernetes components and how they work together."
echo

# Check prerequisites
print_header "Checking Prerequisites"
if ! command -v kubectl &>/dev/null; then
    print_error "kubectl is not installed. Please run 01-verify-tools.sh first."
    exit 1
fi

if ! check_cluster; then
    print_error "No Kubernetes cluster found. Please run 02-explore-cluster.sh first."
    exit 1
fi

print_success "Cluster is accessible!"
wait_for_user

# Exercise 1: Control Plane Components Overview
print_header "Exercise 1: Control Plane Components"
echo "The control plane manages the cluster and makes global decisions about the cluster."

explain_component "kube-apiserver" \
    "The API server is the front end for the Kubernetes control plane" \
    "Validates and configures data for API objects (pods, services, etc.)"

run_command "kubectl get pods -n kube-system -l component=kube-apiserver" "Finding API server pods"

run_command "kubectl describe pod -n kube-system -l component=kube-apiserver" "Examining API server configuration"

echo
print_hint "Key things to notice in API server:"
echo "   • It runs as a static pod (managed by kubelet directly)"
echo "   • Listens on port 6443 (secure) and sometimes 8080 (insecure)"
echo "   • Contains admission controllers and authentication mechanisms"
wait_for_user

explain_component "etcd" \
    "Consistent and highly-available key value store" \
    "Stores all cluster data - the single source of truth for your cluster"

run_command "kubectl get pods -n kube-system -l component=etcd" "Finding etcd pods"

run_command "kubectl describe pod -n kube-system -l component=etcd" "Examining etcd configuration"

echo
print_hint "etcd is critical because:"
echo "   • All cluster state is stored here"
echo "   • If etcd is down, the cluster is effectively down"
echo "   • In production, it's usually run with multiple replicas"
wait_for_user

explain_component "kube-scheduler" \
    "Watches for newly created pods and assigns them to nodes" \
    "Makes scheduling decisions based on resource requirements and constraints"

run_command "kubectl get pods -n kube-system -l component=kube-scheduler" "Finding scheduler pods"

run_command "kubectl logs -n kube-system -l component=kube-scheduler --tail=20" "Viewing scheduler logs"
wait_for_user

explain_component "kube-controller-manager" \
    "Runs controller processes that regulate the state of the cluster" \
    "Includes controllers for nodes, endpoints, replication, service accounts, etc."

run_command "kubectl get pods -n kube-system -l component=kube-controller-manager" "Finding controller manager pods"

run_command "kubectl describe pod -n kube-system -l component=kube-controller-manager" "Examining controller manager"
wait_for_user

# Exercise 2: Node Components
print_header "Exercise 2: Node Components"
echo "These components run on every node and maintain running pods."

explain_component "kubelet" \
    "The primary node agent that manages pods and containers" \
    "Ensures containers are running and healthy according to pod specifications"

print_status "kubelet doesn't run as a pod - it's a system service"
run_command "kubectl get nodes -o wide" "Viewing node information (kubelet versions shown)"

echo
print_hint "kubelet responsibilities:"
echo "   • Registers the node with the API server"
echo "   • Manages pod lifecycle (start, stop, restart containers)"
echo "   • Reports node and pod status back to the API server"
echo "   • Manages static pods (like control plane components)"
wait_for_user

explain_component "kube-proxy" \
    "Network proxy that maintains network rules on nodes" \
    "Enables the Kubernetes service abstraction by maintaining network rules"

run_command "kubectl get pods -n kube-system -l k8s-app=kube-proxy" "Finding kube-proxy pods"

run_command "kubectl get daemonset -n kube-system kube-proxy" "Viewing kube-proxy DaemonSet"

echo
print_hint "kube-proxy runs as a DaemonSet because:"
echo "   • Every node needs a kube-proxy instance"
echo "   • It handles service discovery and load balancing"
echo "   • Implements services by maintaining iptables or ipvs rules"
wait_for_user

explain_component "Container Runtime" \
    "Software responsible for running containers" \
    "Pulls images and runs containers according to the CRI (Container Runtime Interface)"

run_command "kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.containerRuntimeVersion}'" "Checking container runtime version"

echo
print_hint "Common container runtimes:"
echo "   • containerd: Graduated CNCF project, default in many distributions"
echo "   • CRI-O: Kubernetes-specific runtime"
echo "   • Docker: Original runtime (now uses containerd under the hood)"
wait_for_user

# Exercise 3: Addon Components
print_header "Exercise 3: Cluster Addon Components"
echo "These components provide cluster-level features like DNS and monitoring."

explain_component "CoreDNS" \
    "Provides DNS services for the cluster" \
    "Enables service discovery - pods can find services by name"

run_command "kubectl get pods -n kube-system -l k8s-app=kube-dns" "Finding DNS pods (CoreDNS)"

run_command "kubectl get service -n kube-system kube-dns" "Viewing DNS service"

run_command "kubectl get configmap -n kube-system coredns" "Viewing CoreDNS configuration"

echo
print_hint "DNS in Kubernetes:"
echo "   • Services get DNS names like: service-name.namespace.svc.cluster.local"
echo "   • Pods can resolve service names to IP addresses"
echo "   • Essential for service discovery"
wait_for_user

# Exercise 4: Component Communication
print_header "Exercise 4: How Components Communicate"
echo "Understanding how components interact is crucial for troubleshooting."

print_status "Let's trace a pod creation request through the system:"
echo
echo "1. User runs: kubectl apply -f pod.yaml"
echo "2. kubectl sends HTTP request to kube-apiserver"
echo "3. kube-apiserver validates and stores in etcd"
echo "4. kube-scheduler notices new pod, assigns it to a node"
echo "5. kubelet on target node pulls image and starts container"
echo "6. kube-proxy updates network rules if needed"
echo

print_status "Let's create a pod and watch this process:"

cat << EOF > /tmp/test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: communication-test
  labels:
    app: test
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

print_command "kubectl apply -f /tmp/test-pod.yaml"
kubectl apply -f /tmp/test-pod.yaml

print_status "Watching the pod creation process..."
run_command "kubectl get pod communication-test -w --timeout=30s" "Watching pod creation"

run_command "kubectl describe pod communication-test" "Examining pod events"

echo
print_hint "Notice the events section showing the component interactions!"
wait_for_user

# Exercise 5: Component Health and Status
print_header "Exercise 5: Monitoring Component Health"
echo "Let's check the health of all cluster components."

run_command "kubectl get componentstatuses" "Checking component status (deprecated but informative)"

if [ $? -ne 0 ]; then
    print_warning "componentstatuses command is deprecated in newer Kubernetes versions."
fi

print_status "Let's check component health using pod status:"
run_command "kubectl get pods -n kube-system" "Viewing all system pods"

print_status "Checking specific component health:"
for component in kube-apiserver etcd kube-scheduler kube-controller-manager; do
    echo
    print_status "Checking $component health..."
    kubectl get pods -n kube-system -l component=$component -o jsonpath='{.items[0].status.phase}' 2>/dev/null
    echo
done
wait_for_user

# Exercise 6: Component Logs
print_header "Exercise 6: Component Logs and Troubleshooting"
echo "Logs are essential for understanding component behavior and troubleshooting."

components=("kube-apiserver" "etcd" "kube-scheduler" "kube-controller-manager")

for component in "${components[@]}"; do
    echo
    print_status "Recent logs from $component:"
    print_command "kubectl logs -n kube-system -l component=$component --tail=5"
    kubectl logs -n kube-system -l component=$component --tail=5 2>/dev/null || echo "No logs available"
    echo
done
wait_for_user

# Exercise 7: Interactive Component Exploration
print_header "Exercise 7: Interactive Exploration"
echo "Try exploring components yourself with these commands:"
echo

commands=(
    "get pods -n kube-system -o wide"
    "describe pod -n kube-system <pod-name>"
    "logs -n kube-system <pod-name>"
    "get events --sort-by=.metadata.creationTimestamp"
    "top pods -n kube-system"
    "get endpoints kubernetes"
)

echo "Useful commands to try:"
for cmd in "${commands[@]}"; do
    echo "   • kubectl $cmd"
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

# Exercise 8: Component Architecture Summary
print_header "Exercise 8: Architecture Summary"
echo
print_status "Kubernetes Component Architecture:"
echo
echo "Control Plane (Master) Components:"
echo "├── kube-apiserver     → API gateway for all cluster operations"
echo "├── etcd              → Persistent storage for cluster state"
echo "├── kube-scheduler    → Assigns pods to nodes"
echo "└── kube-controller-manager → Manages controllers (replication, endpoints, etc.)"
echo
echo "Node Components:"
echo "├── kubelet           → Node agent (manages pods and containers)"
echo "├── kube-proxy        → Network proxy (enables services)"
echo "└── Container Runtime → Runs containers (containerd, CRI-O, etc.)"
echo
echo "Addon Components:"
echo "├── CoreDNS          → Cluster DNS for service discovery"
echo "├── Metrics Server   → Resource usage metrics (optional)"
echo "└── Dashboard        → Web UI for cluster management (optional)"
echo

# Cleanup
print_status "Cleaning up test resources..."
kubectl delete pod communication-test --ignore-not-found
rm -f /tmp/test-pod.yaml

# Exercise Summary
print_header "Exercise Summary - What You've Learned"
echo
print_success "🎉 Outstanding! You now understand Kubernetes architecture in depth!"
echo
echo "Key concepts mastered:"
echo "✓ Control plane components and their roles"
echo "✓ Node components and their responsibilities"
echo "✓ Addon components for cluster functionality"
echo "✓ Component communication patterns"
echo "✓ Health monitoring and troubleshooting"
echo "✓ Log analysis for component debugging"
echo

print_status "Critical insights:"
echo "• kube-apiserver is the central hub for all cluster communication"
echo "• etcd is the single source of truth for cluster state"
echo "• Controllers continuously reconcile desired vs actual state"
echo "• Each node runs kubelet and kube-proxy for local operations"
echo "• Addons provide essential cluster services like DNS"
echo "• Component logs are invaluable for troubleshooting"
echo

print_hint "Next: Run ./05-kubectl-config.sh to master kubectl configuration"
echo
print_status "Exercise 4 completed successfully!"