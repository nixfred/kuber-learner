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

# Function to get node name
get_node_name() {
    kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Function to create a test pod
create_test_pod() {
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  labels:
    app: test
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
EOF
}

# Main script
clear
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                     Node Management Exercise                    ║
║                           Exercise 3                            ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status "This exercise will teach you about Kubernetes node management, including inspection, labeling, and scheduling."
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
NODE_NAME=$(get_node_name)
if [ -z "$NODE_NAME" ]; then
    print_error "Could not get node name from cluster."
    exit 1
fi
print_status "Working with node: $NODE_NAME"
wait_for_user

# Exercise 1: Node Details and Resources
print_header "Exercise 1: Understanding Node Resources"
echo "Let's examine the resources available on our node."

run_command "kubectl get nodes $NODE_NAME -o wide" "Getting basic node information"
wait_for_user

run_command "kubectl describe node $NODE_NAME" "Getting detailed node information"

echo
print_hint "Key sections in node description:"
echo "   • Conditions: Shows node health (Ready, MemoryPressure, DiskPressure, etc.)"
echo "   • Capacity: Total resources available on the node"
echo "   • Allocatable: Resources available for pods (after system overhead)"
echo "   • Allocated resources: What's currently being used"
wait_for_user

# Exercise 2: Node Labels
print_header "Exercise 2: Working with Node Labels"
echo "Labels are key-value pairs attached to nodes for organization and scheduling."

run_command "kubectl get nodes --show-labels" "Viewing current node labels"

echo
print_hint "Default labels include:"
echo "   • kubernetes.io/hostname: Node's hostname"
echo "   • kubernetes.io/arch: CPU architecture"
echo "   • kubernetes.io/os: Operating system"
echo "   • node-role.kubernetes.io/*: Node roles"
wait_for_user

print_status "Let's add some custom labels to our node:"
run_command "kubectl label node $NODE_NAME environment=learning" "Adding environment label"

run_command "kubectl label node $NODE_NAME tier=frontend" "Adding tier label"

run_command "kubectl get nodes --show-labels" "Viewing updated labels"
wait_for_user

print_status "You can also view specific labels:"
run_command "kubectl get nodes -L environment,tier" "Showing specific labels as columns"
wait_for_user

# Exercise 3: Node Selectors and Scheduling
print_header "Exercise 3: Node Selectors and Pod Scheduling"
echo "Node selectors allow you to constrain pods to run on particular nodes."

print_status "Let's create a pod that specifically targets our labeled node:"
echo

cat << 'EOF'
Creating a pod with nodeSelector:
apiVersion: v1
kind: Pod
metadata:
  name: scheduled-pod
spec:
  nodeSelector:
    environment: learning
  containers:
  - name: nginx
    image: nginx:alpine
EOF

echo
print_command "kubectl apply -f -"

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: scheduled-pod
  labels:
    purpose: scheduling-demo
spec:
  nodeSelector:
    environment: learning
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        memory: "32Mi"
        cpu: "100m"
EOF

print_success "Pod created with nodeSelector!"
wait_for_user

run_command "kubectl get pods -o wide" "Checking where the pod was scheduled"

echo
print_hint "The pod should be running on our node because it matches the environment=learning label."
wait_for_user

# Exercise 4: Node Resource Usage
print_header "Exercise 4: Monitoring Node Resource Usage"
echo "Let's monitor how resources are being used on our node."

print_status "Creating a test pod to see resource allocation:"
create_test_pod
sleep 5

run_command "kubectl get pods" "Checking our pods"
wait_for_user

run_command "kubectl top nodes" "Viewing node resource usage (if metrics-server is available)"

if [ $? -ne 0 ]; then
    print_warning "Metrics server is not available in this cluster."
    print_hint "In production clusters, you would typically have metrics-server installed."
    echo
fi

print_status "Let's check resource allocation from the node's perspective:"
run_command "kubectl describe node $NODE_NAME | grep -A 10 'Allocated resources'" "Viewing allocated resources"
wait_for_user

# Exercise 5: Node Conditions and Health
print_header "Exercise 5: Node Health and Conditions"
echo "Understanding node conditions is crucial for cluster health monitoring."

run_command "kubectl get nodes $NODE_NAME -o jsonpath='{.status.conditions}' | jq ." "Viewing node conditions (JSON format)"

if [ $? -ne 0 ]; then
    print_warning "jq is not available. Let's use a different approach:"
    run_command "kubectl describe node $NODE_NAME | grep -A 20 'Conditions:'" "Viewing node conditions"
fi

echo
print_hint "Common node conditions:"
echo "   • Ready: Node is healthy and ready to accept pods"
echo "   • MemoryPressure: Node is running out of memory"
echo "   • DiskPressure: Node is running out of disk space"
echo "   • PIDPressure: Node is running out of process IDs"
echo "   • NetworkUnavailable: Network is not correctly configured"
wait_for_user

# Exercise 6: Taints and Tolerations (Demonstration)
print_header "Exercise 6: Understanding Taints and Tolerations"
echo "Taints and tolerations work together to ensure pods are not scheduled onto inappropriate nodes."

print_status "Let's examine current taints on our node:"
run_command "kubectl describe node $NODE_NAME | grep -A 5 'Taints:'" "Checking node taints"

echo
print_hint "In a kind control-plane node, you might see:"
echo "   • node-role.kubernetes.io/control-plane:NoSchedule"
echo "This prevents regular pods from being scheduled on the control plane."
echo

print_status "Let's add a custom taint to demonstrate:"
run_command "kubectl taint node $NODE_NAME example=demo:NoSchedule" "Adding a custom taint"

print_status "Now let's try to create a pod without toleration:"
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-toleration-pod
spec:
  containers:
  - name: nginx
    image: nginx:alpine
EOF

sleep 5
run_command "kubectl get pods no-toleration-pod -o wide" "Checking pod status"

run_command "kubectl describe pod no-toleration-pod" "Checking why pod might be pending"

echo
print_hint "The pod might be pending because of the taint we added."
wait_for_user

print_status "Let's remove the taint to allow scheduling:"
run_command "kubectl taint node $NODE_NAME example=demo:NoSchedule-" "Removing the custom taint"
wait_for_user

# Exercise 7: Interactive Node Management
print_header "Exercise 7: Interactive Practice"
echo "Try these node management commands yourself:"
echo

commands=(
    "get nodes -o json | jq '.items[0].status.nodeInfo'"
    "get nodes -o yaml"
    "label node $NODE_NAME custom-label=my-value"
    "label node $NODE_NAME custom-label-"
    "get nodes --selector environment=learning"
)

echo "Suggested commands to try:"
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

# Cleanup
print_header "Cleanup"
print_status "Cleaning up test resources..."

kubectl delete pod test-pod --ignore-not-found
kubectl delete pod scheduled-pod --ignore-not-found
kubectl delete pod no-toleration-pod --ignore-not-found

# Keep the labels we added for future exercises
print_status "Keeping node labels for future exercises..."
echo

# Exercise Summary
print_header "Exercise Summary - What You've Learned"
echo
print_success "🎉 Excellent! You've mastered node management fundamentals!"
echo
echo "Key concepts covered:"
echo "✓ Node resource inspection and monitoring"
echo "✓ Node labeling and organization"
echo "✓ Node selectors for pod scheduling"
echo "✓ Understanding node conditions and health"
echo "✓ Introduction to taints and tolerations"
echo "✓ Resource allocation and capacity planning"
echo

print_status "Key takeaways:"
echo "• Nodes are the foundation of your Kubernetes cluster"
echo "• Labels help organize and target specific nodes"
echo "• Node selectors control where pods can be scheduled"
echo "• Node conditions indicate the health status of nodes"
echo "• Taints and tolerations provide advanced scheduling control"
echo "• Resource monitoring is crucial for cluster management"
echo

print_hint "Next: Run ./04-components.sh to dive deep into Kubernetes components"
echo
print_status "Exercise 3 completed successfully!"