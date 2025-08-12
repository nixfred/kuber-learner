#!/bin/bash

# Exercise 2: PV/PVC Fundamentals
# This exercise demonstrates PersistentVolumes and PersistentVolumeClaims

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

print_header "Exercise 2: PV/PVC Fundamentals"

print_info "This exercise demonstrates PersistentVolumes and PersistentVolumeClaims"
print_info "and shows how they work together to provide persistent storage."

wait_for_input

# Cleanup
print_info "Cleaning up any existing resources..."
kubectl delete pod --ignore-not-found=true \
    pv-test-pod database-pod storage-test 2>/dev/null || true

kubectl delete pvc --ignore-not-found=true \
    test-pvc database-storage app-storage 2>/dev/null || true

kubectl delete pv --ignore-not-found=true \
    local-pv-1 local-pv-2 local-pv-3 2>/dev/null || true

print_step "1. Understanding the PV/PVC Relationship"

print_info "Think of PV/PVC like apartment rental:"
echo "  🏢 PersistentVolume (PV) = The actual apartment"
echo "  📝 PersistentVolumeClaim (PVC) = Your rental application"
echo "  🤝 Binding = Getting approved and moving in"

print_info "Let's create this relationship step by step..."

wait_for_input

print_step "2. Creating PersistentVolumes"

print_info "First, let's create some 'apartments' (PVs) with different sizes and features..."

# Prepare storage directories on the node (kind-specific)
kubectl get nodes -o jsonpath='{.items[0].metadata.name}' | xargs -I {} \
    docker exec {} sh -c 'mkdir -p /tmp/pv-storage-{1,2,3}' 2>/dev/null || true

cat > /tmp/persistent-volumes.yaml << 'EOF'
# Small, fast storage
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-1
  labels:
    type: local
    speed: fast
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/pv-storage-1
    type: DirectoryOrCreate
---
# Medium storage
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-2
  labels:
    type: local
    speed: medium
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/pv-storage-2
    type: DirectoryOrCreate
---
# Large, shared storage
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-3
  labels:
    type: local
    speed: standard
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteMany  # Can be shared
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/pv-storage-3
    type: DirectoryOrCreate
EOF

kubectl apply -f /tmp/persistent-volumes.yaml

print_success "PersistentVolumes created! Let's examine them:"
kubectl get pv

echo ""
echo "Detailed view:"
kubectl describe pv local-pv-1

print_info "Notice the PV status is 'Available' - ready to be claimed!"

wait_for_input

print_step "3. Creating PersistentVolumeClaims"

print_info "Now let's create some 'rental applications' (PVCs)..."

cat > /tmp/small-claim.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi  # Asking for 500Mi, will get 1Gi PV
  storageClassName: manual
EOF

kubectl apply -f /tmp/small-claim.yaml

print_info "PVC created! Let's see the binding magic happen:"
sleep 3
kubectl get pv,pvc

print_success "🎉 Binding successful! The PVC found a suitable PV!"

echo ""
echo "Let's see what happened:"
kubectl describe pvc test-pvc

wait_for_input

print_step "4. Using PVC in a Pod"

print_info "Now let's use our claimed storage in a pod..."

cat > /tmp/pvc-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pv-test-pod
spec:
  containers:
  - name: storage-test
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== PV/PVC Storage Test ==="
      echo "Pod using PVC-claimed storage"
      
      # Check if we have access to the storage
      echo "Storage mount point:"
      ls -la /data
      
      # Write some persistent data
      echo "Writing persistent data..."
      echo "This data was written by pod $(hostname)" > /data/pod-data.txt
      echo "Written at: $(date)" >> /data/pod-data.txt
      echo "PVC: test-pvc" >> /data/pod-data.txt
      
      # Create a unique file
      echo "Creating unique file for this pod..."
      echo "Pod $(hostname) was here!" > /data/pod-$(hostname).marker
      
      echo "Data written successfully!"
      echo "Contents of /data:"
      ls -la /data/
      
      echo ""
      echo "Our persistent data:"
      cat /data/pod-data.txt
      
      # Keep the pod running for testing
      echo ""
      echo "Pod will sleep now. Data is persistent!"
      sleep 300
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: test-pvc
  restartPolicy: Never
EOF

kubectl apply -f /tmp/pvc-pod.yaml

print_info "Waiting for pod to start and write data..."
kubectl wait --for=condition=Ready pod/pv-test-pod --timeout=60s

print_success "Pod is running! Let's see what it wrote:"
kubectl logs pv-test-pod --tail=15

wait_for_input

print_step "5. Testing Data Persistence"

print_info "The real test: Does data survive pod deletion and recreation?"

print_warning "Deleting the pod..."
kubectl delete pod pv-test-pod

print_info "Pod deleted! Now let's create a new pod with the same PVC..."

cat > /tmp/pvc-pod2.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: storage-test
spec:
  containers:
  - name: data-reader
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== Data Persistence Test ==="
      echo "New pod checking for persistent data..."
      
      echo "Contents of storage:"
      ls -la /data/
      
      if [ -f /data/pod-data.txt ]; then
        echo ""
        echo "🎉 PERSISTENT DATA FOUND!"
        echo "Original data:"
        cat /data/pod-data.txt
        
        echo ""
        echo "Adding our own entry..."
        echo "Read by pod $(hostname) at $(date)" >> /data/pod-data.txt
        
        echo ""
        echo "Updated data:"
        cat /data/pod-data.txt
      else
        echo "❌ No persistent data found!"
      fi
      
      # Check for marker files
      echo ""
      echo "Marker files from previous pods:"
      ls -la /data/*.marker 2>/dev/null || echo "No marker files found"
      
      # Create our own marker
      echo "Creating our marker..."
      echo "Pod $(hostname) was here too!" > /data/pod-$(hostname).marker
      
      echo ""
      echo "Final storage contents:"
      ls -la /data/
      
      sleep 300
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: test-pvc
  restartPolicy: Never
EOF

kubectl apply -f /tmp/pvc-pod2.yaml

print_info "Waiting for the new pod to start..."
kubectl wait --for=condition=Ready pod/storage-test --timeout=60s

print_success "New pod is running! Let's see if it found the persistent data:"
kubectl logs storage-test --tail=20

print_success "🎉 Data persisted across pod deletion and recreation!"

wait_for_input

print_step "6. Multiple PVCs and Access Modes"

print_info "Let's create different PVCs to show various scenarios..."

cat > /tmp/multiple-pvcs.yaml << 'EOF'
# Database storage - needs reliable, medium-sized storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  storageClassName: manual
---
# Application storage - larger, potentially shared
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
spec:
  accessModes:
  - ReadWriteMany  # This will bind to local-pv-3
  resources:
    requests:
      storage: 8Gi
  storageClassName: manual
EOF

kubectl apply -f /tmp/multiple-pvcs.yaml

print_info "Multiple PVCs created! Let's see how they bind:"
sleep 3
kubectl get pv,pvc

print_info "Notice how different PVCs bind to different PVs based on:"
echo "  📏 Size requirements"
echo "  🔄 Access mode compatibility"
echo "  🏷️  StorageClass matching"

wait_for_input

print_step "7. PVC Lifecycle and States"

print_info "Let's explore PVC lifecycle states..."

echo "Current PVC states:"
kubectl get pvc -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage

print_info "PVC States explained:"
echo "  📋 Pending: Waiting for a suitable PV"
echo "  ✅ Bound: Successfully bound to a PV"
echo "  🗑️  Lost: PV was deleted but PVC still exists"

# Show what happens when we try to claim more storage than available
cat > /tmp/impossible-pvc.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: impossible-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi  # More than any available PV
  storageClassName: manual
EOF

kubectl apply -f /tmp/impossible-pvc.yaml

print_info "Created a PVC requesting 100Gi..."
sleep 3

echo "Status of the impossible claim:"
kubectl get pvc impossible-claim

print_warning "This PVC will stay in 'Pending' state because no PV can satisfy it."

kubectl describe pvc impossible-claim | grep -A 5 Events:

wait_for_input

print_step "8. Reclaim Policies in Action"

print_info "Let's see what happens when we delete a PVC (Retain policy)..."

print_warning "Deleting one of our PVCs..."
kubectl delete pvc test-pvc

print_info "PVC deleted! What happened to the PV?"
kubectl get pv local-pv-1

print_info "Notice the PV status is now 'Released' not 'Available'"
print_info "With Retain policy, the data is still there but PV needs manual cleanup"

echo ""
echo "PV details:"
kubectl describe pv local-pv-1 | grep -A 10 "Status:"

print_info "Reclaim policies:"
echo "  🛡️  Retain: Manual cleanup required (safest)"
echo "  🗑️  Delete: Automatic cleanup (default for dynamic)"
echo "  ♻️  Recycle: Deprecated (don't use)"

wait_for_input

print_step "9. Storage Troubleshooting"

print_info "Let's practice troubleshooting common storage issues..."

# Create a problematic pod
cat > /tmp/problem-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: problem-pod
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh", "-c", "echo 'Waiting for storage...'; sleep 300"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: nonexistent-pvc  # This PVC doesn't exist!
  restartPolicy: Never
EOF

kubectl apply -f /tmp/problem-pod.yaml

print_warning "Created a pod with a non-existent PVC..."
sleep 3

print_info "🔍 Troubleshooting steps:"

echo "1. Check pod status:"
kubectl get pod problem-pod

echo ""
echo "2. Describe the pod for details:"
kubectl describe pod problem-pod | tail -10

echo ""
echo "3. Check available PVCs:"
kubectl get pvc

print_info "The pod is stuck because the PVC doesn't exist!"

wait_for_input

print_step "10. Cleanup and Summary"

print_info "Cleaning up exercise resources..."

# Clean up pods
kubectl delete pod \
    storage-test problem-pod 2>/dev/null || true

# Clean up PVCs
kubectl delete pvc \
    database-storage app-storage impossible-claim 2>/dev/null || true

# Clean up PVs
kubectl delete pv \
    local-pv-1 local-pv-2 local-pv-3 2>/dev/null || true

# Clean up files
rm -f /tmp/persistent-volumes.yaml /tmp/small-claim.yaml /tmp/pvc-pod.yaml \
      /tmp/pvc-pod2.yaml /tmp/multiple-pvcs.yaml /tmp/impossible-pvc.yaml \
      /tmp/problem-pod.yaml

print_success "Exercise completed! You've learned:"
echo "  ✅ PV/PVC relationship and binding process"
echo "  ✅ How to create and use PersistentVolumes"
echo "  ✅ How to claim storage with PersistentVolumeClaims"
echo "  ✅ Data persistence across pod restarts"
echo "  ✅ Access modes and storage requirements"
echo "  ✅ PVC lifecycle states"
echo "  ✅ Reclaim policies and their effects"
echo "  ✅ Basic storage troubleshooting"

print_info "Key takeaways:"
echo "  📋 PVCs are requests for storage resources"
echo "  🏢 PVs are the actual storage implementations"
echo "  🤝 Binding connects PVCs to appropriate PVs"
echo "  💾 Data persists beyond pod lifecycle"
echo "  🔄 Access modes control sharing capabilities"

print_info "Next: Try Exercise 3 to learn about dynamic provisioning with StorageClasses!"