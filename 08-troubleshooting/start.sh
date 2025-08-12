#!/bin/bash

# Module 8: Troubleshooting Mastery Interactive Workshop
# This script provides hands-on troubleshooting scenarios and techniques

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================================${NC}\n"
}

print_step() {
    echo -e "\n${GREEN}Step: $1${NC}\n"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

wait_for_input() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_info "Make sure your cluster is running and kubectl is configured"
        exit 1
    fi
    
    print_success "Prerequisites satisfied!"
    
    # Show cluster info
    print_info "Connected to cluster: $(kubectl config current-context)"
    print_info "Current namespace: $(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo 'default')"
}

cleanup_previous() {
    print_header "Cleaning Up Previous Resources"
    
    print_info "Removing any existing demo resources..."
    
    # Clean up troubleshooting scenarios
    kubectl delete pod --ignore-not-found=true \
        broken-pod crash-loop-pod pending-pod \
        network-test-pod debug-pod troubleshoot-demo 2>/dev/null || true
    
    kubectl delete service --ignore-not-found=true \
        broken-service test-service 2>/dev/null || true
    
    kubectl delete namespace --ignore-not-found=true \
        troubleshooting-demo 2>/dev/null || true
    
    print_success "Cleanup completed!"
}

demo_systematic_approach() {
    print_header "Systematic Troubleshooting Approach"
    
    print_info "Let's learn the scientific method for Kubernetes debugging..."
    
    print_step "1. The Troubleshooting Methodology"
    
    echo "🔬 SCIENTIFIC METHOD FOR DEBUGGING:"
    echo "  1. OBSERVE: What symptoms are you seeing?"
    echo "  2. HYPOTHESIZE: What could be causing this?"
    echo "  3. TEST: Verify your hypothesis with evidence"
    echo "  4. ANALYZE: What do the results tell you?"
    echo "  5. ITERATE: Refine and test new hypotheses"
    
    echo ""
    echo "🎯 DEBUGGING HIERARCHY:"
    echo "  Layer 1: Infrastructure (nodes, cluster)"
    echo "  Layer 2: Platform (Kubernetes services, DNS)"
    echo "  Layer 3: Application (pods, services, configs)"
    echo "  Layer 4: Business Logic (application code)"
    
    wait_for_input
    
    print_step "2. Essential Information Gathering"
    
    print_info "Let's gather baseline information about our cluster..."
    
    echo "Cluster overview:"
    kubectl cluster-info
    
    echo ""
    echo "Node status:"
    kubectl get nodes -o wide
    
    echo ""
    echo "Recent events (last 10):"
    kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces | tail -10
    
    echo ""
    echo "Resource usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics Server not available"
    
    print_info "Always start with this baseline information!"
    
    wait_for_input
}

demo_pod_troubleshooting() {
    print_header "Pod Troubleshooting Scenarios"
    
    print_info "Let's create some common pod issues and learn to diagnose them..."
    
    print_step "1. ImagePullBackOff Scenario"
    
    print_info "Creating a pod with an invalid image..."
    
    cat << 'EOF' > /tmp/broken-image-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod
  labels:
    scenario: image-pull-error
spec:
  containers:
  - name: app
    image: nonexistent/invalid-image:latest
    command: ["/bin/sh", "-c", "echo 'This will never run'; sleep 300"]
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/broken-image-pod.yaml
    
    print_info "Waiting for the issue to manifest..."
    sleep 10
    
    print_error "Let's diagnose the ImagePullBackOff issue:"
    
    echo "1. Check pod status:"
    kubectl get pod broken-pod
    
    echo ""
    echo "2. Describe the pod for detailed events:"
    kubectl describe pod broken-pod | tail -15
    
    print_success "🔍 DIAGNOSIS COMPLETE!"
    echo "  • Issue: ImagePullBackOff"
    echo "  • Cause: Invalid/nonexistent image name"
    echo "  • Solution: Fix image name or check registry access"
    
    kubectl delete pod broken-pod
    
    wait_for_input
    
    print_step "2. CrashLoopBackOff Scenario"
    
    print_info "Creating a pod that crashes immediately..."
    
    cat << 'EOF' > /tmp/crash-loop-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: crash-loop-pod
  labels:
    scenario: crash-loop
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh", "-c", "echo 'Starting app...'; sleep 2; echo 'Simulating crash!'; exit 1"]
  restartPolicy: Always
EOF

    kubectl apply -f /tmp/crash-loop-pod.yaml
    
    print_info "Waiting for crash loop to start..."
    sleep 15
    
    print_error "Let's diagnose the CrashLoopBackOff issue:"
    
    echo "1. Check pod status:"
    kubectl get pod crash-loop-pod
    
    echo ""
    echo "2. Check current logs:"
    kubectl logs crash-loop-pod
    
    echo ""
    echo "3. Check previous container logs:"
    kubectl logs crash-loop-pod --previous
    
    echo ""
    echo "4. Check restart count:"
    kubectl get pod crash-loop-pod -o jsonpath='{.status.containerStatuses[0].restartCount}'
    
    print_success "🔍 DIAGNOSIS COMPLETE!"
    echo "  • Issue: CrashLoopBackOff"
    echo "  • Cause: Application exits with error code"
    echo "  • Solution: Fix application logic or configuration"
    
    kubectl delete pod crash-loop-pod
    
    wait_for_input
    
    print_step "3. Pending Pod Scenario"
    
    print_info "Creating a pod that can't be scheduled..."
    
    cat << 'EOF' > /tmp/pending-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pending-pod
  labels:
    scenario: pending
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh", "-c", "echo 'This pod requires too many resources'; sleep 300"]
    resources:
      requests:
        memory: "100Gi"  # Impossible memory request
        cpu: "50"        # 50 CPU cores
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/pending-pod.yaml
    
    print_info "Waiting for scheduling issues..."
    sleep 5
    
    print_error "Let's diagnose the Pending issue:"
    
    echo "1. Check pod status:"
    kubectl get pod pending-pod
    
    echo ""
    echo "2. Check scheduling events:"
    kubectl describe pod pending-pod | grep -A 10 Events:
    
    echo ""
    echo "3. Check node resources:"
    kubectl describe nodes | grep -A 5 "Allocated resources:"
    
    print_success "🔍 DIAGNOSIS COMPLETE!"
    echo "  • Issue: Pod Pending"
    echo "  • Cause: Insufficient node resources"
    echo "  • Solution: Reduce resource requests or add nodes"
    
    kubectl delete pod pending-pod
    
    wait_for_input
}

demo_network_troubleshooting() {
    print_header "Network Troubleshooting"
    
    print_info "Let's explore network debugging techniques..."
    
    print_step "1. DNS Resolution Testing"
    
    print_info "Creating a debug pod for network testing..."
    
    cat << 'EOF' > /tmp/network-debug-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: network-test-pod
spec:
  containers:
  - name: debug
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== NETWORK DEBUGGING POD ==="
      echo "This pod will be used for network testing"
      
      echo "Testing DNS resolution..."
      nslookup kubernetes.default.svc.cluster.local || echo "DNS resolution failed"
      
      echo "Network interface info:"
      ip addr show
      
      echo "Routing table:"
      route -n
      
      echo "DNS configuration:"
      cat /etc/resolv.conf
      
      echo "Pod is ready for network testing!"
      sleep 3600
    
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/network-debug-pod.yaml
    
    print_info "Waiting for debug pod to start..."
    kubectl wait --for=condition=Ready pod/network-test-pod --timeout=60s
    
    print_success "Debug pod is ready! Let's test network connectivity:"
    
    echo "1. DNS resolution test:"
    kubectl exec network-test-pod -- nslookup kubernetes.default.svc.cluster.local
    
    echo ""
    echo "2. Test connectivity to Kubernetes API:"
    kubectl exec network-test-pod -- wget -qO- --timeout=5 https://kubernetes.default.svc.cluster.local/version || echo "HTTPS connection failed (expected in some setups)"
    
    wait_for_input
    
    print_step "2. Service Connectivity Testing"
    
    print_info "Creating a test service and checking connectivity..."
    
    # Create a simple service
    cat << 'EOF' > /tmp/test-service.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-server
  labels:
    app: test-server
spec:
  containers:
  - name: server
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Starting simple HTTP server..."
      while true; do
        echo -e "HTTP/1.1 200 OK\r\n\r\nHello from test server!" | nc -l -p 8080
      done
    ports:
    - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
spec:
  selector:
    app: test-server
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
EOF

    kubectl apply -f /tmp/test-service.yaml
    
    print_info "Waiting for test service to be ready..."
    sleep 10
    
    echo "Service status:"
    kubectl get service test-service
    
    echo ""
    echo "Service endpoints:"
    kubectl get endpoints test-service
    
    echo ""
    echo "Testing service connectivity:"
    kubectl exec network-test-pod -- wget -qO- --timeout=5 http://test-service/  || echo "Service connection failed"
    
    print_success "Network connectivity test completed!"
    
    # Cleanup test service
    kubectl delete -f /tmp/test-service.yaml 2>/dev/null || true
    
    wait_for_input
}

demo_performance_debugging() {
    print_header "Performance and Resource Debugging"
    
    print_info "Let's explore resource constraint debugging..."
    
    print_step "1. Resource Monitoring"
    
    print_info "Creating a resource-intensive pod..."
    
    cat << 'EOF' > /tmp/resource-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== RESOURCE DEMONSTRATION ==="
      
      # Show initial resource usage
      echo "Initial memory info:"
      cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable)"
      
      echo "Initial CPU info:"
      cat /proc/loadavg
      
      # Simulate some load
      echo "Creating memory load..."
      dd if=/dev/zero of=/tmp/memory-eater bs=1M count=50 2>/dev/null &
      
      echo "Creating CPU load..."
      dd if=/dev/zero of=/dev/null bs=1M count=1000 2>/dev/null &
      
      # Monitor resources
      while true; do
        echo "$(date): Memory usage:"
        cat /proc/meminfo | grep -E "(MemFree|MemAvailable)" | head -2
        echo "Load average:"
        cat /proc/loadavg
        echo "---"
        sleep 10
      done
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/resource-demo.yaml
    
    print_info "Waiting for resource demo to start..."
    kubectl wait --for=condition=Ready pod/resource-demo --timeout=60s
    
    print_success "Resource demo is running!"
    
    echo "Checking resource usage with kubectl top:"
    kubectl top pod resource-demo 2>/dev/null || echo "Metrics Server not available"
    
    echo ""
    echo "Checking resource limits:"
    kubectl describe pod resource-demo | grep -A 5 -B 2 "Limits:"
    
    echo ""
    echo "Monitoring resource usage in real-time:"
    kubectl logs resource-demo --tail=10
    
    wait_for_input
    
    kubectl delete pod resource-demo
}

demo_debugging_tools() {
    print_header "Advanced Debugging Tools and Techniques"
    
    print_info "Let's explore advanced debugging capabilities..."
    
    print_step "1. Creating a Debug Toolkit Pod"
    
    cat << 'EOF' > /tmp/debug-toolkit.yaml
apiVersion: v1
kind: Pod
metadata:
  name: debug-toolkit
  labels:
    purpose: debugging
spec:
  containers:
  - name: toolkit
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== KUBERNETES DEBUG TOOLKIT ==="
      echo ""
      echo "Available debugging commands:"
      echo "  • Network: ping, wget, nc, nslookup"
      echo "  • Process: ps, top, kill"
      echo "  • System: ls, cat, grep, find"
      echo "  • File: cat, head, tail, less"
      echo ""
      echo "Common debugging tasks:"
      echo "1. Test network connectivity:"
      echo "   wget -qO- http://service-name:port/"
      echo ""
      echo "2. Check DNS resolution:"
      echo "   nslookup service-name.namespace.svc.cluster.local"
      echo ""
      echo "3. Test port connectivity:"
      echo "   nc -zv hostname port"
      echo ""
      echo "4. Monitor processes:"
      echo "   ps aux"
      echo ""
      echo "Toolkit ready for debugging!"
      sleep 3600
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/debug-toolkit.yaml
    
    print_info "Starting debug toolkit..."
    kubectl wait --for=condition=Ready pod/debug-toolkit --timeout=60s
    
    print_success "Debug toolkit is ready!"
    
    echo "Let's test some debugging commands:"
    
    echo "1. Network interface information:"
    kubectl exec debug-toolkit -- ip addr show
    
    echo ""
    echo "2. Process list:"
    kubectl exec debug-toolkit -- ps aux
    
    echo ""
    echo "3. File system information:"
    kubectl exec debug-toolkit -- df -h
    
    print_info "Advanced debugging techniques:"
    echo "  🔧 kubectl exec: Execute commands in containers"
    echo "  🔧 kubectl port-forward: Access services locally"
    echo "  🔧 kubectl proxy: Access Kubernetes API"
    echo "  🔧 kubectl logs --previous: Check previous container logs"
    echo "  🔧 kubectl describe: Get detailed resource information"
    
    wait_for_input
    
    print_step "2. Using kubectl for Advanced Queries"
    
    print_info "Let's explore advanced kubectl techniques..."
    
    echo "1. Custom columns output:"
    kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,IP:.status.podIP
    
    echo ""
    echo "2. JSONPath queries:"
    echo "Container restart count:"
    kubectl get pod debug-toolkit -o jsonpath='{.status.containerStatuses[0].restartCount}'
    echo ""
    
    echo "3. Field selectors:"
    echo "Recent events for our debug pod:"
    kubectl get events --field-selector involvedObject.name=debug-toolkit
    
    echo ""
    echo "4. Label selectors:"
    echo "Pods with purpose=debugging label:"
    kubectl get pods -l purpose=debugging
    
    wait_for_input
}

create_troubleshooting_scenario() {
    print_header "Interactive Troubleshooting Challenge"
    
    print_info "Let's create a realistic troubleshooting scenario..."
    
    print_step "The Scenario"
    
    echo "🚨 INCIDENT ALERT 🚨"
    echo "  • Time: $(date)"
    echo "  • Issue: Application not responding"
    echo "  • Impact: Users cannot access the application"
    echo "  • Your mission: Find and fix the problem!"
    
    wait_for_input
    
    print_info "Creating the broken application..."
    
    # Create a namespace for the scenario
    kubectl create namespace troubleshooting-demo 2>/dev/null || true
    
    # Create a broken deployment
    cat << 'EOF' > /tmp/broken-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: troubleshooting-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: broken-app
  template:
    metadata:
      labels:
        app: broken-app
    spec:
      containers:
      - name: app
        image: busybox:1.35
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "Starting application..."
          sleep 10
          echo "Simulating application failure..."
          exit 1  # This will cause crash loops
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: broken-service
  namespace: troubleshooting-demo
spec:
  selector:
    app: broken-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080  # Wrong target port - service will fail
EOF

    kubectl apply -f /tmp/broken-app.yaml
    
    print_warning "Application deployed! Let's wait for the issues to manifest..."
    sleep 15
    
    print_error "🔍 YOUR TURN TO TROUBLESHOOT!"
    echo ""
    echo "Available commands to help you:"
    echo "  kubectl get pods -n troubleshooting-demo"
    echo "  kubectl describe pod <pod-name> -n troubleshooting-demo"
    echo "  kubectl logs <pod-name> -n troubleshooting-demo"
    echo "  kubectl get service -n troubleshooting-demo"
    echo "  kubectl get events -n troubleshooting-demo"
    
    wait_for_input
    
    print_info "Let's investigate together..."
    
    echo "1. Check pod status:"
    kubectl get pods -n troubleshooting-demo
    
    echo ""
    echo "2. Check recent events:"
    kubectl get events -n troubleshooting-demo --sort-by=.metadata.creationTimestamp | tail -10
    
    echo ""
    echo "3. Check service configuration:"
    kubectl get service broken-service -n troubleshooting-demo
    
    echo ""
    echo "4. Check service endpoints:"
    kubectl get endpoints broken-service -n troubleshooting-demo
    
    print_success "🔍 ISSUES IDENTIFIED!"
    echo "  1. Pods are crash looping (application exits with error)"
    echo "  2. Service target port mismatch (service expects 8080, pods don't expose it)"
    echo "  3. No healthy endpoints for the service"
    
    wait_for_input
    
    print_info "Let's fix the issues step by step..."
    
    # Fix the deployment
    cat << 'EOF' > /tmp/fixed-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: troubleshooting-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: broken-app
  template:
    metadata:
      labels:
        app: broken-app
    spec:
      containers:
      - name: app
        image: busybox:1.35
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "Starting fixed application..."
          echo "Application is now stable and serving traffic"
          
          # Simple HTTP server
          while true; do
            echo -e "HTTP/1.1 200 OK\r\n\r\nApplication is working!" | nc -l -p 8080
          done
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF

    kubectl apply -f /tmp/fixed-app.yaml
    
    print_info "Waiting for fixed application to deploy..."
    sleep 20
    
    echo "Check pod status after fix:"
    kubectl get pods -n troubleshooting-demo
    
    echo ""
    echo "Check service endpoints after fix:"
    kubectl get endpoints broken-service -n troubleshooting-demo
    
    print_success "🎉 ISSUE RESOLVED!"
    echo "  ✅ Pods are now running successfully"
    echo "  ✅ Service has healthy endpoints"
    echo "  ✅ Application is responding to requests"
    
    wait_for_input
}

cleanup_demo() {
    print_header "Cleaning Up Demo Resources"
    
    print_info "Removing troubleshooting demo resources..."
    
    # Clean up all demo resources
    kubectl delete pod --ignore-not-found=true \
        network-test-pod debug-toolkit resource-demo 2>/dev/null || true
    
    kubectl delete namespace --ignore-not-found=true \
        troubleshooting-demo 2>/dev/null || true
    
    # Clean up files
    rm -f /tmp/broken-image-pod.yaml /tmp/crash-loop-pod.yaml /tmp/pending-pod.yaml \
          /tmp/network-debug-pod.yaml /tmp/test-service.yaml /tmp/resource-demo.yaml \
          /tmp/debug-toolkit.yaml /tmp/broken-app.yaml /tmp/fixed-app.yaml
    
    print_info "Resources cleaned up!"
}

show_next_steps() {
    print_header "Next Steps"
    
    print_success "Congratulations! You've completed the Troubleshooting Mastery workshop!"
    
    print_info "What you've learned:"
    echo "  ✅ Systematic troubleshooting approaches"
    echo "  ✅ Common pod failure scenarios and diagnosis"
    echo "  ✅ Network debugging techniques"
    echo "  ✅ Resource constraint troubleshooting"
    echo "  ✅ Advanced debugging tools and commands"
    echo "  ✅ Real-world problem-solving skills"
    
    echo ""
    print_info "Recommended next steps:"
    echo "  1. Complete the exercises in the exercises/ directory"
    echo "  2. Try the master troubleshooter challenge"
    echo "  3. Practice with real applications and scenarios"
    echo "  4. Build your own troubleshooting runbooks"
    echo "  5. Proceed to Module 9: Real-World Applications"
    
    echo ""
    print_info "Key troubleshooting commands to remember:"
    echo "  kubectl get pods --all-namespaces | grep -v Running"
    echo "  kubectl describe pod <pod-name>"
    echo "  kubectl logs <pod-name> --previous"
    echo "  kubectl get events --sort-by=.metadata.creationTimestamp"
    echo "  kubectl exec -it <pod-name> -- /bin/sh"
}

# Main execution
main() {
    print_header "Kubernetes Troubleshooting Mastery Workshop"
    
    print_info "This interactive workshop will teach you:"
    echo "  • Systematic approaches to debugging"
    echo "  • Common failure scenarios and solutions"
    echo "  • Network and connectivity troubleshooting"
    echo "  • Resource and performance debugging"
    echo "  • Advanced debugging tools and techniques"
    echo "  • Real-world problem-solving skills"
    
    wait_for_input
    
    check_prerequisites
    cleanup_previous
    demo_systematic_approach
    demo_pod_troubleshooting
    demo_network_troubleshooting
    demo_performance_debugging
    demo_debugging_tools
    create_troubleshooting_scenario
    cleanup_demo
    show_next_steps
    
    print_success "Workshop completed successfully!"
    print_info "You're now ready to tackle real-world Kubernetes troubleshooting challenges!"
}

# Run the workshop
main "$@"