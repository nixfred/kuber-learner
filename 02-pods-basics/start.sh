#!/bin/bash

# Module 2: Pods & Container Basics - Interactive Start Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Progress tracking
PROGRESS_FILE="../.progress/module_2.progress"
mkdir -p "../.progress"
mkdir -p "manifests"

clear

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         MODULE 2: PODS & CONTAINER BASICS                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Welcome to the Pods module!${NC}"
echo -e "Pods are the fundamental building blocks of Kubernetes applications."
echo ""

# Function to create a manifest file
create_manifest() {
    local filename=$1
    local content=$2
    echo "$content" > "manifests/$filename"
    echo -e "${GREEN}✓${NC} Created manifests/$filename"
}

# Function to run command with explanation
run_command() {
    local explanation=$1
    local command=$2
    
    echo -e "\n${CYAN}$explanation${NC}"
    echo -e "${WHITE}Command: ${YELLOW}$command${NC}"
    echo ""
    eval $command || true
    echo ""
}

# Function to wait for user
pause() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
echo "═══════════════════════════════════════"

# Check if cluster exists
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Kubernetes cluster is running"
else
    echo -e "${RED}✗${NC} No cluster found. Please complete Module 1 first."
    exit 1
fi

# Check if any pods are already running from previous sessions
existing_pods=$(kubectl get pods --no-headers 2>/dev/null | wc -l)
if [ "$existing_pods" -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} Found existing pods from previous sessions"
    echo -n "Would you like to clean them up? (y/n): "
    read cleanup
    if [ "$cleanup" = "y" ]; then
        kubectl delete pods --all
        echo -e "${GREEN}✓${NC} Cleaned up existing pods"
    fi
fi

pause

# Lesson 1: Your First Pod
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}          LESSON 1: YOUR FIRST POD                             ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}What is a Pod?${NC}"
echo "• The smallest deployable unit in Kubernetes"
echo "• Can contain one or more containers"
echo "• Shares network and storage"
echo "• Has a unique IP address"
echo ""

echo -e "${CYAN}Let's create your first pod!${NC}"

# Create simple pod manifest
create_manifest "simple-pod.yaml" "apiVersion: v1
kind: Pod
metadata:
  name: my-first-pod
  labels:
    app: nginx
    environment: learning
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80"

pause

run_command "Apply the pod manifest:" "kubectl apply -f manifests/simple-pod.yaml"

run_command "Check pod status:" "kubectl get pods"

run_command "Get more details:" "kubectl get pods -o wide"

echo -e "${CYAN}Pod Status Explanation:${NC}"
echo "• NAME: The name of your pod"
echo "• READY: Number of ready containers / total containers"
echo "• STATUS: Current state (Pending, Running, etc.)"
echo "• RESTARTS: Number of container restarts"
echo "• AGE: Time since creation"
echo "• IP: Pod's internal IP address"
echo "• NODE: Which node the pod is running on"

pause

# Lesson 2: Interacting with Pods
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}          LESSON 2: INTERACTING WITH PODS                      ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

run_command "View pod logs:" "kubectl logs my-first-pod | head -10"

echo -e "${CYAN}Let's execute commands inside the pod:${NC}"
run_command "List files in nginx directory:" "kubectl exec my-first-pod -- ls /usr/share/nginx/html"

echo -e "${CYAN}Interactive shell access:${NC}"
echo -e "${YELLOW}You can connect to the pod with: kubectl exec -it my-first-pod -- /bin/sh${NC}"
echo -e "${YELLOW}Type 'exit' to leave the shell${NC}"
echo ""
echo -n "Would you like to try it? (y/n): "
read try_shell

if [ "$try_shell" = "y" ]; then
    echo -e "${CYAN}Connecting to pod shell...${NC}"
    echo -e "${YELLOW}Try these commands: ls, ps aux, cat /etc/os-release, exit${NC}"
    kubectl exec -it my-first-pod -- /bin/sh || true
fi

pause

# Lesson 3: Port Forwarding
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}          LESSON 3: PORT FORWARDING                            ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Port forwarding allows you to access pod services locally${NC}"
echo ""

echo -e "${YELLOW}Starting port forward to nginx pod...${NC}"
echo -e "${WHITE}Access URL: ${CYAN}http://localhost:8080${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop port forwarding${NC}"
echo ""

# Start port forwarding in background
kubectl port-forward my-first-pod 8080:80 &
PF_PID=$!

sleep 2

echo -e "\n${CYAN}Testing the connection:${NC}"
curl -s http://localhost:8080 | head -5

echo -e "\n${GREEN}✓ Successfully connected to pod!${NC}"
echo -e "${YELLOW}Port forwarding is running in background (PID: $PF_PID)${NC}"
echo -e "${YELLOW}Stop it with: kill $PF_PID${NC}"

pause

# Stop port forwarding
kill $PF_PID 2>/dev/null || true

# Lesson 4: Multi-Container Pods
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}          LESSON 4: MULTI-CONTAINER PODS                       ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Multi-container pods share:${NC}"
echo "• Network namespace (same IP)"
echo "• Storage volumes"
echo "• Lifecycle"
echo ""

echo -e "${CYAN}Common patterns:${NC}"
echo "• ${GREEN}Sidecar${NC}: Enhances main container (logging, monitoring)"
echo "• ${GREEN}Ambassador${NC}: Proxy for external services"
echo "• ${GREEN}Adapter${NC}: Standardizes output format"
echo ""

create_manifest "multi-container.yaml" "apiVersion: v1
kind: Pod
metadata:
  name: multi-container-demo
spec:
  containers:
  # Main application container
  - name: app
    image: busybox
    command: ['sh', '-c']
    args:
    - while true; do
        echo \"\$(date) - Application heartbeat\" >> /shared/app.log;
        sleep 5;
      done
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  
  # Sidecar container for log processing
  - name: log-processor
    image: busybox
    command: ['sh', '-c']
    args:
    - while true; do
        if [ -f /shared/app.log ]; then
          echo \"Processing logs:\";
          tail -n 3 /shared/app.log;
        fi;
        sleep 10;
      done
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  
  volumes:
  - name: shared-data
    emptyDir: {}"

run_command "Create multi-container pod:" "kubectl apply -f manifests/multi-container.yaml"

echo -e "${CYAN}Waiting for pod to start...${NC}"
sleep 5

run_command "Check both containers are running:" "kubectl get pod multi-container-demo"

run_command "View logs from app container:" "kubectl logs multi-container-demo -c app | tail -5"

run_command "View logs from log-processor:" "kubectl logs multi-container-demo -c log-processor | tail -5"

pause

# Lesson 5: Pod Lifecycle and Debugging
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}          LESSON 5: DEBUGGING PODS                             ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Essential debugging commands:${NC}"
echo ""

run_command "Describe pod for detailed info:" "kubectl describe pod my-first-pod | head -30"

echo -e "${CYAN}Let's create a failing pod to practice debugging:${NC}"

create_manifest "failing-pod.yaml" "apiVersion: v1
kind: Pod
metadata:
  name: failing-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'exit 1']  # This will cause the pod to fail"

run_command "Create the failing pod:" "kubectl apply -f manifests/failing-pod.yaml"

echo -e "${CYAN}Watch the pod fail and restart:${NC}"
kubectl get pod failing-pod -w &
WATCH_PID=$!

sleep 10
kill $WATCH_PID 2>/dev/null || true

run_command "Check pod status:" "kubectl get pod failing-pod"

run_command "View events to understand failure:" "kubectl get events --field-selector involvedObject.name=failing-pod | tail -5"

run_command "Check previous container logs:" "kubectl logs failing-pod --previous 2>/dev/null || echo 'No previous logs available yet'"

pause

# Interactive Exercise
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}          INTERACTIVE EXERCISE                                 ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Exercise: Pod Troubleshooting${NC}"
echo ""
echo "The 'failing-pod' is in CrashLoopBackOff state."
echo "Your task: Figure out why it's failing."
echo ""
echo -e "${YELLOW}Which command would you use to check the logs?${NC}"
echo "1) kubectl get pod failing-pod"
echo "2) kubectl logs failing-pod"
echo "3) kubectl describe pod failing-pod"
echo "4) All of the above"
echo ""
echo -n "Your answer (1-4): "
read answer

if [ "$answer" = "4" ]; then
    echo -e "${GREEN}✓ Correct!${NC} All these commands are useful for debugging."
else
    echo -e "${YELLOW}The best answer is 4. All commands provide different insights.${NC}"
fi

echo ""
echo -e "${CYAN}Let's fix the failing pod:${NC}"

create_manifest "fixed-pod.yaml" "apiVersion: v1
kind: Pod
metadata:
  name: fixed-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'echo \"Pod is running successfully!\"; sleep 3600']"

run_command "Delete the failing pod:" "kubectl delete pod failing-pod"
run_command "Create the fixed pod:" "kubectl apply -f manifests/fixed-pod.yaml"
run_command "Verify it's running:" "kubectl get pod fixed-pod"

pause

# Module Summary
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}          MODULE 2 COMPLETE!                                   ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}🎉 Congratulations! You've completed Module 2!${NC}"
echo ""
echo "You've learned:"
echo -e "  ${GREEN}✓${NC} How to create and manage pods"
echo -e "  ${GREEN}✓${NC} Interacting with pods (logs, exec)"
echo -e "  ${GREEN}✓${NC} Port forwarding to access services"
echo -e "  ${GREEN}✓${NC} Multi-container pod patterns"
echo -e "  ${GREEN}✓${NC} Debugging pod issues"
echo ""

# Save progress
touch "$PROGRESS_FILE"
echo "$(date): Module 2 completed" >> "$PROGRESS_FILE"

echo -e "${CYAN}Practice Exercises:${NC}"
echo "1. Create a pod with resource limits"
echo "2. Implement an init container"
echo "3. Create a pod with health checks"
echo ""

echo -e "${CYAN}Cleanup Commands:${NC}"
echo "kubectl delete pod my-first-pod multi-container-demo fixed-pod"
echo ""

echo -e "${YELLOW}Ready for Module 3: Workload Controllers${NC}"
echo ""
echo -e "${GREEN}Press Enter to exit${NC}"
read