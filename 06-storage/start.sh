#!/bin/bash

# Module 6: Storage Solutions Interactive Workshop
# This script provides an interactive learning experience for Kubernetes storage

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
    
    # Check if we can create resources
    if ! kubectl auth can-i create persistentvolumeclaims &> /dev/null; then
        print_error "Insufficient permissions to create PersistentVolumeClaims"
        exit 1
    fi
    
    if ! kubectl auth can-i create persistentvolumes &> /dev/null; then
        print_warning "Cannot create PersistentVolumes - dynamic provisioning only"
    fi
    
    print_success "Prerequisites satisfied!"
    
    # Show cluster info
    print_info "Connected to cluster: $(kubectl config current-context)"
    print_info "Current namespace: $(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo 'default')"
    
    # Check for storage classes
    print_info "Available StorageClasses:"
    kubectl get storageclass 2>/dev/null || print_warning "No StorageClasses found"
}

cleanup_previous() {
    print_header "Cleaning Up Previous Resources"
    
    print_info "Removing any existing demo resources..."
    
    # Clean up pods
    kubectl delete pod --ignore-not-found=true \
        ephemeral-demo persistent-demo storage-inspector \
        volume-test pvc-test benchmark-pod 2>/dev/null || true
    
    # Clean up PVCs
    kubectl delete pvc --ignore-not-found=true \
        demo-pvc test-pvc benchmark-pvc storage-demo-pvc 2>/dev/null || true
    
    # Clean up PVs
    kubectl delete pv --ignore-not-found=true \
        demo-pv local-storage-pv test-storage-pv 2>/dev/null || true
    
    # Clean up StorageClasses
    kubectl delete storageclass --ignore-not-found=true \
        demo-storage fast-storage slow-storage 2>/dev/null || true
    
    print_success "Cleanup completed!"
}

demo_storage_problem() {
    print_header "Understanding the Storage Problem"
    
    print_info "Let's experience the storage problem firsthand..."
    
    print_step "1. Creating a database without persistent storage"
    
    # Create a PostgreSQL pod without persistent storage
    cat << 'EOF' > /tmp/ephemeral-db.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ephemeral-demo
  labels:
    app: storage-demo
spec:
  containers:
  - name: postgres
    image: postgres:13-alpine
    env:
    - name: POSTGRES_PASSWORD
      value: "demo123"
    - name: POSTGRES_DB
      value: "testdb"
    ports:
    - containerPort: 5432
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/ephemeral-db.yaml
    
    print_info "Waiting for database to start..."
    kubectl wait --for=condition=Ready pod/ephemeral-demo --timeout=60s
    
    print_success "Database started! Let's add some data:"
    
    # Add data to the database
    kubectl exec ephemeral-demo -- psql -U postgres -d testdb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT, email TEXT);"
    kubectl exec ephemeral-demo -- psql -U postgres -d testdb -c "INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com'), ('Bob', 'bob@example.com');"
    
    print_info "Data added! Let's verify it exists:"
    kubectl exec ephemeral-demo -- psql -U postgres -d testdb -c "SELECT * FROM users;"
    
    wait_for_input
    
    print_step "2. Simulating pod restart (data loss)"
    
    print_warning "Now let's see what happens when the pod restarts..."
    kubectl delete pod ephemeral-demo
    
    print_info "Recreating the database pod..."
    kubectl apply -f /tmp/ephemeral-db.yaml
    kubectl wait --for=condition=Ready pod/ephemeral-demo --timeout=60s
    
    print_error "Checking if our data still exists..."
    kubectl exec ephemeral-demo -- psql -U postgres -d testdb -c "SELECT * FROM users;" 2>/dev/null || {
        print_error "Data is gone! The table doesn't even exist."
        kubectl exec ephemeral-demo -- psql -U postgres -d testdb -c "\\dt" 2>/dev/null || print_error "Database is empty"
    }
    
    print_warning "This is why we need persistent storage!"
    
    kubectl delete pod ephemeral-demo
    
    wait_for_input
}

demo_persistent_volumes() {
    print_header "Working with Persistent Storage"
    
    print_step "1. Creating a PersistentVolume"
    
    # Create a directory for our storage (kind specific)
    kubectl get nodes -o jsonpath='{.items[0].metadata.name}' | xargs -I {} \
        docker exec {} mkdir -p /tmp/k8s-storage 2>/dev/null || true
    
    cat << 'EOF' > /tmp/demo-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: demo-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/k8s-storage
    type: DirectoryOrCreate
EOF

    kubectl apply -f /tmp/demo-pv.yaml
    
    print_success "PersistentVolume created! Let's examine it:"
    kubectl get pv demo-pv
    kubectl describe pv demo-pv
    
    wait_for_input
    
    print_step "2. Creating a PersistentVolumeClaim"
    
    cat << 'EOF' > /tmp/demo-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF

    kubectl apply -f /tmp/demo-pvc.yaml
    
    print_info "PVC created! Let's see it bind to the PV:"
    sleep 3
    kubectl get pvc demo-pvc
    kubectl get pv demo-pv
    
    print_success "Notice how the PVC is now Bound to the PV!"
    
    wait_for_input
    
    print_step "3. Using persistent storage in a pod"
    
    cat << 'EOF' > /tmp/persistent-db.yaml
apiVersion: v1
kind: Pod
metadata:
  name: persistent-demo
  labels:
    app: persistent-storage-demo
spec:
  containers:
  - name: postgres
    image: postgres:13-alpine
    env:
    - name: POSTGRES_PASSWORD
      value: "demo123"
    - name: POSTGRES_DB
      value: "testdb"
    - name: PGDATA
      value: "/var/lib/postgresql/data/pgdata"
    ports:
    - containerPort: 5432
    volumeMounts:
    - name: postgres-storage
      mountPath: /var/lib/postgresql/data
  volumes:
  - name: postgres-storage
    persistentVolumeClaim:
      claimName: demo-pvc
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/persistent-db.yaml
    
    print_info "Waiting for persistent database to start..."
    kubectl wait --for=condition=Ready pod/persistent-demo --timeout=120s
    
    print_success "Database with persistent storage is running!"
    
    # Add data to the persistent database
    print_info "Adding data to the persistent database..."
    kubectl exec persistent-demo -- psql -U postgres -d testdb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT, email TEXT, created_at TIMESTAMP DEFAULT NOW());"
    kubectl exec persistent-demo -- psql -U postgres -d testdb -c "INSERT INTO users (name, email) VALUES ('Alice Persistent', 'alice@persistent.com'), ('Bob Persistent', 'bob@persistent.com');"
    
    print_success "Data added! Let's verify:"
    kubectl exec persistent-demo -- psql -U postgres -d testdb -c "SELECT * FROM users;"
    
    wait_for_input
    
    print_step "4. Testing persistence (the moment of truth!)"
    
    print_warning "Now let's restart the pod and see if data survives..."
    kubectl delete pod persistent-demo
    
    print_info "Recreating the database pod..."
    kubectl apply -f /tmp/persistent-db.yaml
    kubectl wait --for=condition=Ready pod/persistent-demo --timeout=120s
    
    print_success "Checking if our data survived the restart..."
    kubectl exec persistent-demo -- psql -U postgres -d testdb -c "SELECT * FROM users;"
    
    print_success "🎉 Data survived! This is the power of persistent storage!"
    
    wait_for_input
}

demo_storage_classes() {
    print_header "Dynamic Provisioning with StorageClasses"
    
    print_step "1. Creating StorageClasses for different needs"
    
    print_info "Let's create StorageClasses for different performance tiers..."
    
    # Fast storage for databases
    cat << 'EOF' > /tmp/fast-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: kubernetes.io/no-provisioner
parameters:
  type: "ssd"
  tier: "performance"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF

    # Slow storage for archives
    cat << 'EOF' > /tmp/slow-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: slow-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: kubernetes.io/no-provisioner
parameters:
  type: "hdd"
  tier: "archive"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF

    kubectl apply -f /tmp/fast-storage.yaml
    kubectl apply -f /tmp/slow-storage.yaml
    
    print_success "StorageClasses created! Let's see them:"
    kubectl get storageclass
    
    wait_for_input
    
    print_step "2. Using dynamic provisioning"
    
    # Create a PVC that will trigger dynamic provisioning (simulated)
    cat << 'EOF' > /tmp/dynamic-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-storage-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: fast-storage
EOF

    kubectl apply -f /tmp/dynamic-pvc.yaml
    
    print_info "PVC created with StorageClass. Let's check its status:"
    kubectl get pvc dynamic-storage-pvc
    
    print_info "In a real cluster with dynamic provisioning, this PVC would:"
    echo "  • Automatically create a PV"
    echo "  • Configure the storage according to StorageClass parameters"
    echo "  • Handle binding automatically"
    
    wait_for_input
}

demo_access_modes() {
    print_header "Understanding Access Modes"
    
    print_info "Let's explore different access modes and their use cases..."
    
    print_step "1. ReadWriteOnce (RWO) - Single node access"
    
    cat << 'EOF' > /tmp/rwo-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: rwo-writer
spec:
  containers:
  - name: writer
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== ReadWriteOnce Demo ==="
      echo "This pod has exclusive write access to the volume"
      
      while true; do
        echo "$(date): Writing to RWO volume" >> /data/rwo-log.txt
        echo "Current log entries: $(wc -l < /data/rwo-log.txt)"
        sleep 10
      done
    volumeMounts:
    - name: rwo-storage
      mountPath: /data
  volumes:
  - name: rwo-storage
    persistentVolumeClaim:
      claimName: demo-pvc
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/rwo-demo.yaml
    
    print_info "Waiting for RWO demo to start..."
    kubectl wait --for=condition=Ready pod/rwo-writer --timeout=60s
    
    print_success "RWO pod is writing to the volume:"
    sleep 5
    kubectl logs rwo-writer --tail=3
    
    print_info "ReadWriteOnce characteristics:"
    echo "  ✅ Single pod can mount for read/write"
    echo "  ✅ Best for databases and single-writer applications"
    echo "  ❌ Cannot be shared between multiple pods simultaneously"
    
    wait_for_input
    
    print_step "2. Shared volume demonstration"
    
    # Create a shared emptyDir volume demo
    cat << 'EOF' > /tmp/shared-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-demo
spec:
  containers:
  - name: writer
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== Shared Volume Writer ==="
      while true; do
        echo "$(date): Writer says hello" >> /shared/messages.txt
        sleep 5
      done
    volumeMounts:
    - name: shared-vol
      mountPath: /shared
  - name: reader
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== Shared Volume Reader ==="
      while true; do
        if [ -f /shared/messages.txt ]; then
          echo "Latest messages:"
          tail -3 /shared/messages.txt
        else
          echo "No messages yet..."
        fi
        sleep 7
      done
    volumeMounts:
    - name: shared-vol
      mountPath: /shared
  volumes:
  - name: shared-vol
    emptyDir: {}  # Shared within the pod
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/shared-demo.yaml
    
    print_info "Waiting for shared volume demo to start..."
    kubectl wait --for=condition=Ready pod/shared-volume-demo --timeout=60s
    
    print_success "Shared volume demo running. Let's see both containers:"
    sleep 8
    
    echo "Writer container:"
    kubectl logs shared-volume-demo -c writer --tail=2
    echo ""
    echo "Reader container:"
    kubectl logs shared-volume-demo -c reader --tail=3
    
    print_info "Shared volume characteristics (emptyDir):"
    echo "  ✅ Multiple containers in same pod can share"
    echo "  ✅ Good for sidecar patterns"
    echo "  ❌ Data is lost when pod is deleted"
    echo "  ❌ Cannot be shared between different pods"
    
    wait_for_input
}

demo_statefulset_storage() {
    print_header "StatefulSet Storage Patterns"
    
    print_info "StatefulSets provide stable storage for each replica..."
    
    print_step "1. Understanding StatefulSet storage requirements"
    
    print_info "StatefulSets need:"
    echo "  • Stable, unique network identities"
    echo "  • Persistent storage per replica"
    echo "  • Ordered deployment and scaling"
    echo "  • Persistent storage that survives rescheduling"
    
    print_info "Let's create a simple StatefulSet example:"
    
    # Note: In a real kind cluster, this would need proper storage setup
    cat << 'EOF' > /tmp/statefulset-demo.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: storage-demo
spec:
  serviceName: storage-demo-service
  replicas: 2
  selector:
    matchLabels:
      app: storage-demo
  template:
    metadata:
      labels:
        app: storage-demo
    spec:
      containers:
      - name: demo
        image: busybox:1.35
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "=== StatefulSet Pod: $HOSTNAME ==="
          echo "My unique storage is at: /data"
          
          # Create a unique file for this pod
          echo "This is data from $HOSTNAME" > /data/pod-identity.txt
          echo "Created at: $(date)" >> /data/pod-identity.txt
          
          while true; do
            echo "$(date): $HOSTNAME is running with persistent storage"
            echo "My data: $(cat /data/pod-identity.txt | head -1)"
            sleep 30
          done
        volumeMounts:
        - name: storage
          mountPath: /data
  # This would create separate PVCs for each pod
  volumeClaimTemplates:
  - metadata:
      name: storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: manual
      resources:
        requests:
          storage: 100Mi
---
apiVersion: v1
kind: Service
metadata:
  name: storage-demo-service
spec:
  clusterIP: None  # Headless service
  selector:
    app: storage-demo
  ports:
  - port: 80
EOF

    # Create additional PVs for the StatefulSet
    cat << 'EOF' > /tmp/statefulset-pvs.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: demo-pv-0
spec:
  capacity:
    storage: 100Mi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/k8s-storage-0
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: demo-pv-1
spec:
  capacity:
    storage: 100Mi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/k8s-storage-1
    type: DirectoryOrCreate
EOF

    # Create storage directories
    kubectl get nodes -o jsonpath='{.items[0].metadata.name}' | xargs -I {} \
        docker exec {} sh -c 'mkdir -p /tmp/k8s-storage-0 /tmp/k8s-storage-1' 2>/dev/null || true

    kubectl apply -f /tmp/statefulset-pvs.yaml
    kubectl apply -f /tmp/statefulset-demo.yaml
    
    print_info "StatefulSet created! Let's watch it deploy:"
    sleep 10
    
    kubectl get statefulset storage-demo
    kubectl get pods -l app=storage-demo
    kubectl get pvc -l app=storage-demo
    
    print_success "StatefulSet storage pattern demonstrated!"
    
    print_info "Each pod gets:"
    echo "  • Unique identity: storage-demo-0, storage-demo-1"
    echo "  • Separate PVC: storage-storage-demo-0, storage-storage-demo-1"
    echo "  • Persistent data that survives pod restarts"
    
    wait_for_input
}

demo_storage_monitoring() {
    print_header "Storage Monitoring and Performance"
    
    print_step "1. Storage usage monitoring"
    
    cat << 'EOF' > /tmp/storage-monitor.yaml
apiVersion: v1
kind: Pod
metadata:
  name: storage-monitor
spec:
  containers:
  - name: monitor
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== STORAGE MONITORING DEMO ==="
      
      while true; do
        echo ""
        echo "$(date): Storage Status Report"
        echo "================================"
        
        echo "Disk Usage:"
        df -h
        
        echo ""
        echo "Mount Points:"
        mount | grep -E "(pvc|volume)" || echo "No PVC mounts found"
        
        echo ""
        echo "Storage Performance Test:"
        # Simple write test
        time_start=$(date +%s%N)
        dd if=/dev/zero of=/data/test-file bs=1M count=10 2>/dev/null
        time_end=$(date +%s%N)
        duration=$(( (time_end - time_start) / 1000000 ))
        
        echo "Wrote 10MB in ${duration}ms"
        echo "Estimated throughput: $(( 10000 / duration ))MB/s"
        
        rm -f /data/test-file
        
        sleep 60
      done
    volumeMounts:
    - name: monitored-storage
      mountPath: /data
  volumes:
  - name: monitored-storage
    persistentVolumeClaim:
      claimName: demo-pvc
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/storage-monitor.yaml
    
    print_info "Starting storage monitoring..."
    kubectl wait --for=condition=Ready pod/storage-monitor --timeout=60s
    
    print_success "Storage monitor running! Let's see the metrics:"
    sleep 5
    kubectl logs storage-monitor --tail=15
    
    print_info "In production, you would use:"
    echo "  • Prometheus node-exporter for storage metrics"
    echo "  • Grafana dashboards for visualization"
    echo "  • Alerts for storage capacity and performance"
    echo "  • Storage-specific monitoring tools"
    
    wait_for_input
}

cleanup_demo() {
    print_header "Cleaning Up Demo Resources"
    
    print_info "Removing demo resources..."
    
    # Clean up pods
    kubectl delete pod --ignore-not-found=true \
        persistent-demo rwo-writer shared-volume-demo storage-monitor 2>/dev/null || true
    
    # Clean up StatefulSet
    kubectl delete statefulset --ignore-not-found=true storage-demo 2>/dev/null || true
    kubectl delete service --ignore-not-found=true storage-demo-service 2>/dev/null || true
    
    # Clean up PVCs
    kubectl delete pvc --ignore-not-found=true \
        demo-pvc dynamic-storage-pvc \
        storage-storage-demo-0 storage-storage-demo-1 2>/dev/null || true
    
    # Clean up PVs
    kubectl delete pv --ignore-not-found=true \
        demo-pv demo-pv-0 demo-pv-1 2>/dev/null || true
    
    # Clean up StorageClasses
    kubectl delete storageclass --ignore-not-found=true \
        fast-storage slow-storage 2>/dev/null || true
    
    # Clean up files
    rm -f /tmp/ephemeral-db.yaml /tmp/demo-pv.yaml /tmp/demo-pvc.yaml \
          /tmp/persistent-db.yaml /tmp/fast-storage.yaml /tmp/slow-storage.yaml \
          /tmp/dynamic-pvc.yaml /tmp/rwo-demo.yaml /tmp/shared-demo.yaml \
          /tmp/statefulset-demo.yaml /tmp/statefulset-pvs.yaml /tmp/storage-monitor.yaml
    
    print_info "Resources cleaned up!"
    print_warning "Some storage may persist on nodes - this is normal for demonstration."
}

show_next_steps() {
    print_header "Next Steps"
    
    print_success "Congratulations! You've completed the Storage Solutions workshop!"
    
    print_info "What you've learned:"
    echo "  ✅ The difference between ephemeral and persistent storage"
    echo "  ✅ How to create and use PersistentVolumes and PersistentVolumeClaims"
    echo "  ✅ StorageClasses and dynamic provisioning concepts"
    echo "  ✅ StatefulSet storage patterns"
    echo "  ✅ Access modes and their use cases"
    echo "  ✅ Storage monitoring and performance considerations"
    
    echo ""
    print_info "Recommended next steps:"
    echo "  1. Complete the exercises in the exercises/ directory"
    echo "  2. Try the module challenge"
    echo "  3. Experiment with different storage scenarios"
    echo "  4. Read the full README.md for deeper understanding"
    echo "  5. Proceed to Module 7: Monitoring & Observability"
    
    echo ""
    print_info "Quick reference commands:"
    echo "  kubectl get pv,pvc,storageclass"
    echo "  kubectl describe pv <name>"
    echo "  kubectl describe pvc <name>"
    echo "  kubectl get events --field-selector involvedObject.name=<pvc-name>"
}

# Main execution
main() {
    print_header "Kubernetes Storage Solutions Workshop"
    
    print_info "This interactive workshop will teach you:"
    echo "  • Why persistent storage matters"
    echo "  • How to use PersistentVolumes and PersistentVolumeClaims"
    echo "  • StorageClasses and dynamic provisioning"
    echo "  • StatefulSet storage patterns"
    echo "  • Storage monitoring and performance"
    echo "  • Best practices for production storage"
    
    wait_for_input
    
    check_prerequisites
    cleanup_previous
    demo_storage_problem
    demo_persistent_volumes
    demo_storage_classes
    demo_access_modes
    demo_statefulset_storage
    demo_storage_monitoring
    cleanup_demo
    show_next_steps
    
    print_success "Workshop completed successfully!"
}

# Run the workshop
main "$@"