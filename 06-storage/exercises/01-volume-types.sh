#!/bin/bash

# Exercise 1: Volume Types Exploration
# This exercise demonstrates different volume types and their characteristics

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

wait_for_input() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

print_header "Exercise 1: Volume Types Exploration"

print_info "This exercise will demonstrate different volume types in Kubernetes"
print_info "and help you understand their characteristics and use cases."

wait_for_input

# Cleanup
print_info "Cleaning up any existing resources..."
kubectl delete pod --ignore-not-found=true \
    emptydir-demo hostpath-demo configmap-demo secret-demo 2>/dev/null || true

kubectl delete configmap --ignore-not-found=true volume-config 2>/dev/null || true
kubectl delete secret --ignore-not-found=true volume-secret 2>/dev/null || true

print_step "1. EmptyDir Volumes - Temporary Shared Storage"

print_info "EmptyDir volumes are created when a pod is assigned to a node"
print_info "and exist for the lifetime of that pod."

cat > /tmp/emptydir-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-demo
spec:
  containers:
  - name: writer
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== EmptyDir Writer Container ==="
      echo "Writing data to shared emptyDir volume..."
      
      for i in $(seq 1 10); do
        echo "Message $i from writer at $(date)" >> /shared/messages.txt
        echo "Log entry $i from writer" >> /shared/writer.log
        sleep 2
      done
      
      echo "Writer finished. Sleeping..."
      sleep 300
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  - name: reader
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== EmptyDir Reader Container ==="
      echo "Reading data from shared emptyDir volume..."
      
      while true; do
        if [ -f /shared/messages.txt ]; then
          echo "--- Latest Messages ---"
          tail -3 /shared/messages.txt
          echo "Total messages: $(wc -l < /shared/messages.txt)"
        else
          echo "No messages file yet..."
        fi
        
        if [ -f /shared/writer.log ]; then
          echo "Writer log entries: $(wc -l < /shared/writer.log)"
        fi
        
        echo "------------------------"
        sleep 5
      done
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  volumes:
  - name: shared-data
    emptyDir:
      sizeLimit: 100Mi  # Optional size limit
  restartPolicy: Never
EOF

kubectl apply -f /tmp/emptydir-demo.yaml

print_info "Waiting for emptyDir demo to start..."
kubectl wait --for=condition=Ready pod/emptydir-demo --timeout=60s

print_success "EmptyDir demo running! Let's see both containers working:"
sleep 8

echo "Writer container output:"
kubectl logs emptydir-demo -c writer --tail=5

echo ""
echo "Reader container output:"
kubectl logs emptydir-demo -c reader --tail=10

print_info "EmptyDir characteristics:"
echo "  ✅ Shared between containers in the same pod"
echo "  ✅ Initially empty when pod starts"
echo "  ✅ Good for temporary data sharing"
echo "  ❌ Data is lost when pod is deleted"
echo "  ❌ Cannot be shared between different pods"

wait_for_input

print_step "2. HostPath Volumes - Node Filesystem Access"

print_warning "HostPath volumes should ONLY be used for development/testing!"

cat > /tmp/hostpath-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-demo
spec:
  containers:
  - name: host-explorer
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== HostPath Volume Demo ==="
      echo "Accessing node's filesystem through hostPath volume"
      
      # Create a directory on the host
      mkdir -p /host-data/demo-app
      
      # Write some data
      echo "Data from pod $(hostname)" > /host-data/demo-app/pod-data.txt
      echo "Created at: $(date)" >> /host-data/demo-app/pod-data.txt
      
      # Show what's on the host filesystem
      echo "Contents of host directory:"
      ls -la /host-data/
      
      echo "Our data file:"
      cat /host-data/demo-app/pod-data.txt
      
      echo ""
      echo "This data will persist on the node even after pod deletion"
      echo "(because it's written to the node's filesystem)"
      
      sleep 300
    volumeMounts:
    - name: host-storage
      mountPath: /host-data
    securityContext:
      privileged: true  # Required for hostPath in some cases
  volumes:
  - name: host-storage
    hostPath:
      path: /tmp/k8s-hostpath-demo
      type: DirectoryOrCreate
  restartPolicy: Never
EOF

kubectl apply -f /tmp/hostpath-demo.yaml

print_info "Waiting for hostPath demo to start..."
kubectl wait --for=condition=Ready pod/hostpath-demo --timeout=60s

print_success "HostPath demo running:"
kubectl logs hostpath-demo --tail=15

print_warning "HostPath volume risks:"
echo "  ❌ Ties pod to specific node"
echo "  ❌ Security risk (access to host filesystem)"
echo "  ❌ Not portable between nodes"
echo "  ❌ Can conflict with other pods"
echo "  ⚠️  Use only for development or node-specific tools"

wait_for_input

print_step "3. ConfigMap Volumes - Configuration as Files"

# Create a configmap for demonstration
kubectl create configmap volume-config \
    --from-literal=app.name="Volume Demo App" \
    --from-literal=log.level="INFO" \
    --from-literal=database.host="postgres.example.com"

# Add a configuration file
cat > /tmp/app-config.properties << 'EOF'
# Application Configuration
app.name=Volume Demo Application
app.version=1.0.0
server.port=8080

# Database Configuration
database.host=postgres.example.com
database.port=5432
database.pool.size=10

# Logging Configuration
logging.level=INFO
logging.format=json
logging.output=/var/log/app.log
EOF

kubectl create configmap volume-config --from-file=app.properties=/tmp/app-config.properties --dry-run=client -o yaml | kubectl apply -f -

cat > /tmp/configmap-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: configmap-demo
spec:
  containers:
  - name: config-consumer
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== ConfigMap Volume Demo ==="
      echo "Configuration mounted as files in /etc/config"
      
      echo "Available configuration files:"
      ls -la /etc/config/
      
      echo ""
      echo "=== Individual Configuration Values ==="
      echo "App Name: $(cat /etc/config/app.name)"
      echo "Log Level: $(cat /etc/config/log.level)"
      echo "Database Host: $(cat /etc/config/database.host)"
      
      echo ""
      echo "=== Configuration File Content ==="
      echo "app.properties:"
      cat /etc/config/app.properties
      
      echo ""
      echo "Configuration loaded successfully!"
      
      # Demonstrate configuration monitoring
      while true; do
        echo "$(date): Monitoring configuration changes..."
        if [ -f /etc/config/app.name ]; then
          echo "  Current app name: $(cat /etc/config/app.name)"
        fi
        sleep 30
      done
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: volume-config
  restartPolicy: Never
EOF

kubectl apply -f /tmp/configmap-demo.yaml

print_info "Waiting for configMap demo to start..."
kubectl wait --for=condition=Ready pod/configmap-demo --timeout=60s

print_success "ConfigMap volume demo running:"
kubectl logs configmap-demo --tail=20

print_info "ConfigMap volume characteristics:"
echo "  ✅ Configuration files mounted as read-only"
echo "  ✅ Automatic updates when ConfigMap changes (with delay)"
echo "  ✅ Each key becomes a separate file"
echo "  ✅ Perfect for application configuration files"

wait_for_input

print_step "4. Secret Volumes - Sensitive Data as Files"

# Create a secret for demonstration
kubectl create secret generic volume-secret \
    --from-literal=username=admin \
    --from-literal=password=supersecret123 \
    --from-literal=api-key=sk-1234567890abcdef

cat > /tmp/secret-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: secret-demo
spec:
  containers:
  - name: secret-consumer
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== Secret Volume Demo ==="
      echo "Secrets mounted as files in /etc/secrets"
      
      echo "Available secret files:"
      ls -la /etc/secrets/
      
      echo ""
      echo "=== File Permissions and Security ==="
      echo "File permissions (should be restrictive):"
      stat /etc/secrets/username
      
      echo ""
      echo "=== Secret Content (be careful in production!) ==="
      echo "Username: $(cat /etc/secrets/username)"
      echo "Password: [HIDDEN FOR SECURITY]"
      echo "API Key length: $(cat /etc/secrets/api-key | wc -c) characters"
      
      echo ""
      echo "=== Mount Information ==="
      echo "Mount point filesystem type:"
      mount | grep secrets
      
      echo ""
      echo "Secrets loaded securely!"
      
      # Keep running for inspection
      sleep 300
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: volume-secret
      defaultMode: 0400  # Read-only for owner only
  restartPolicy: Never
EOF

kubectl apply -f /tmp/secret-demo.yaml

print_info "Waiting for secret demo to start..."
kubectl wait --for=condition=Ready pod/secret-demo --timeout=60s

print_success "Secret volume demo running:"
kubectl logs secret-demo --tail=20

print_info "Secret volume characteristics:"
echo "  ✅ Secrets mounted as read-only files"
echo "  ✅ Stored in tmpfs (memory, not disk)"
echo "  ✅ Configurable file permissions"
echo "  ✅ More secure than environment variables"
echo "  ✅ Each secret key becomes a separate file"

wait_for_input

print_step "5. Volume Comparison and Best Practices"

print_info "Volume type comparison:"

echo ""
echo "📁 EMPTYDIR:"
echo "  Use for: Temporary data sharing between containers"
echo "  Lifetime: Pod lifetime"
echo "  Sharing: Within pod only"
echo "  Examples: Cache, temporary files, shared processing"

echo ""
echo "📁 HOSTPATH:"
echo "  Use for: Development only, node-specific tools"
echo "  Lifetime: Node lifetime"
echo "  Sharing: All pods on same node (dangerous!)"
echo "  Examples: Docker socket, node monitoring"

echo ""
echo "📁 CONFIGMAP:"
echo "  Use for: Application configuration files"
echo "  Lifetime: Until ConfigMap is deleted"
echo "  Sharing: Any pod can mount"
echo "  Examples: nginx.conf, application.properties"

echo ""
echo "📁 SECRET:"
echo "  Use for: Sensitive configuration data"
echo "  Lifetime: Until Secret is deleted"
echo "  Sharing: Any pod with permission can mount"
echo "  Examples: Passwords, API keys, certificates"

echo ""
echo "📁 PERSISTENTVOLUMECLAIM:"
echo "  Use for: Long-term data storage"
echo "  Lifetime: Until explicitly deleted"
echo "  Sharing: Depends on access mode"
echo "  Examples: Database data, user uploads, logs"

wait_for_input

print_step "6. Volume Update Behavior"

print_info "Let's test how volumes respond to updates..."

# Update the ConfigMap
kubectl patch configmap volume-config -p '{"data":{"app.name":"Updated Volume Demo App","new.setting":"This is new!"}}'

print_success "ConfigMap updated! Let's see if the pod notices:"
sleep 10

echo "Latest logs from configmap-demo pod:"
kubectl logs configmap-demo --tail=5

print_info "ConfigMap updates in volumes:"
echo "  ✅ Files are updated automatically (with delay)"
echo "  ⏱️  Update propagation can take 10-60 seconds"
echo "  🔄 Applications must handle file changes gracefully"

wait_for_input

print_step "7. Cleanup"

print_info "Cleaning up exercise resources..."

# Clean up pods
kubectl delete pod \
    emptydir-demo hostpath-demo configmap-demo secret-demo 2>/dev/null || true

# Clean up ConfigMaps and Secrets
kubectl delete configmap volume-config 2>/dev/null || true
kubectl delete secret volume-secret 2>/dev/null || true

# Clean up temporary files
rm -f /tmp/emptydir-demo.yaml /tmp/hostpath-demo.yaml /tmp/configmap-demo.yaml \
      /tmp/secret-demo.yaml /tmp/app-config.properties

print_success "Exercise completed! You've learned:"
echo "  ✅ EmptyDir volumes for temporary shared storage"
echo "  ✅ HostPath volumes and their security implications"
echo "  ✅ ConfigMap volumes for configuration files"
echo "  ✅ Secret volumes for sensitive data"
echo "  ✅ Volume update behavior and timing"
echo "  ✅ Best practices for each volume type"

print_info "Next: Try Exercise 2 to learn about PersistentVolumes and PersistentVolumeClaims!"