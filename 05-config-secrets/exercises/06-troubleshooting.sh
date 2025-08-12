#!/bin/bash

# Exercise 6: Configuration Troubleshooting
# This exercise teaches systematic troubleshooting of configuration and secret issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

wait_for_input() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

print_header "Exercise 6: Configuration Troubleshooting"

print_info "This exercise will teach you systematic troubleshooting techniques"
print_info "for configuration and secret issues in Kubernetes."

wait_for_input

# Cleanup any existing resources
print_info "Cleaning up any existing demo resources..."
kubectl delete pod --ignore-not-found=true \
    broken-configmap broken-secret broken-volume \
    permission-issue mount-issue update-issue \
    troubleshoot-demo debug-pod 2>/dev/null || true

kubectl delete configmap --ignore-not-found=true \
    test-config broken-config working-config \
    debug-config 2>/dev/null || true

kubectl delete secret --ignore-not-found=true \
    test-secret broken-secret working-secret \
    debug-secret 2>/dev/null || true

print_step "1. Problem: ConfigMap Key Not Found"

print_info "Let's create a common configuration error and learn to diagnose it:"

# Create a ConfigMap with limited keys
kubectl create configmap test-config \
    --from-literal=app_name="Test App" \
    --from-literal=log_level="INFO" \
    --from-literal=database_host="postgres.example.com"

# Create a pod that references a non-existent key
cat > /tmp/broken-configmap-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-configmap
  labels:
    problem: missing-key
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh", "-c", "echo 'App starting...'; sleep 600"]
    env:
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: test-config
          key: app_name
    - name: MISSING_VALUE
      valueFrom:
        configMapKeyRef:
          name: test-config
          key: nonexistent_key  # This key doesn't exist!
  restartPolicy: Never
EOF

kubectl apply -f /tmp/broken-configmap-pod.yaml

print_error "Pod created with missing ConfigMap key. Let's diagnose the issue:"

sleep 5

print_info "🔍 STEP 1: Check pod status"
kubectl get pod broken-configmap

print_info "🔍 STEP 2: Describe pod to see events"
kubectl describe pod broken-configmap | tail -10

print_info "🔍 STEP 3: Check what keys are actually available"
echo "Available ConfigMap keys:"
kubectl get configmap test-config -o jsonpath='{.data}' | jq 'keys'

print_info "🔍 STEP 4: Compare with what the pod expects"
echo "Pod expects these environment variables:"
kubectl get pod broken-configmap -o yaml | grep -A 10 "env:" | grep "name:"

print_success "🛠️  DIAGNOSIS: Pod is trying to reference 'nonexistent_key' which doesn't exist in the ConfigMap"

print_info "🛠️  SOLUTION OPTIONS:"
echo "1. Add the missing key to the ConfigMap:"
echo "   kubectl patch configmap test-config -p '{\"data\":{\"nonexistent_key\":\"default_value\"}}'"
echo ""
echo "2. Fix the pod specification to use an existing key"
echo ""
echo "3. Make the environment variable optional (not possible with configMapKeyRef)"

print_info "Let's fix it by adding the missing key:"
kubectl patch configmap test-config -p '{"data":{"nonexistent_key":"fixed_value"}}'

print_info "Delete and recreate the pod to see the fix:"
kubectl delete pod broken-configmap
kubectl apply -f /tmp/broken-configmap-pod.yaml

kubectl wait --for=condition=Ready pod/broken-configmap --timeout=60s
print_success "Pod is now running! Check the environment variables:"
kubectl exec broken-configmap -- env | grep -E "(APP_NAME|MISSING_VALUE)"

wait_for_input

print_step "2. Problem: Secret Not Found"

print_info "Let's diagnose a missing secret issue:"

cat > /tmp/broken-secret-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-secret
  labels:
    problem: missing-secret
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh", "-c", "echo 'App starting...'; sleep 600"]
    env:
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: nonexistent-secret  # This secret doesn't exist!
          key: password
  restartPolicy: Never
EOF

kubectl apply -f /tmp/broken-secret-pod.yaml

print_error "Pod created with missing secret reference:"

sleep 5

print_info "🔍 STEP 1: Check pod status"
kubectl get pod broken-secret

print_info "🔍 STEP 2: Check pod events"
kubectl describe pod broken-secret | tail -10

print_info "🔍 STEP 3: List available secrets"
echo "Available secrets in this namespace:"
kubectl get secrets --field-selector type=Opaque

print_info "🔍 STEP 4: Check pod specification"
echo "Pod expects secret:"
kubectl get pod broken-secret -o yaml | grep -A 5 "secretKeyRef:"

print_success "🛠️  DIAGNOSIS: Pod references 'nonexistent-secret' which doesn't exist"

print_info "🛠️  SOLUTION: Create the missing secret"
kubectl create secret generic nonexistent-secret \
    --from-literal=password=secret_password_123

print_info "Delete and recreate the pod:"
kubectl delete pod broken-secret
kubectl apply -f /tmp/broken-secret-pod.yaml

kubectl wait --for=condition=Ready pod/broken-secret --timeout=60s
print_success "Pod is now running with the secret!"

wait_for_input

print_step "3. Problem: Volume Mount Issues"

print_info "Let's troubleshoot volume mount problems:"

# Create a secret for testing
kubectl create secret generic test-secret \
    --from-literal=username=admin \
    --from-literal=password=secret123

cat > /tmp/broken-volume-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-volume
  labels:
    problem: volume-mount
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Starting application..."
      echo "Checking mounted secrets..."
      ls -la /etc/secrets/
      echo "Trying to read secret files..."
      cat /etc/secrets/username
      cat /etc/secrets/password
      sleep 600
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: test-secret
      items:
      - key: username
        path: username
      - key: password
        path: password
      - key: nonexistent_key  # This key doesn't exist!
        path: nonexistent_file
  restartPolicy: Never
EOF

kubectl apply -f /tmp/broken-volume-pod.yaml

print_error "Pod created with problematic volume mount:"

sleep 5

print_info "🔍 STEP 1: Check pod status"
kubectl get pod broken-volume

print_info "🔍 STEP 2: Check pod events"
kubectl describe pod broken-volume | tail -15

print_info "🔍 STEP 3: Check the secret content"
echo "Secret keys available:"
kubectl get secret test-secret -o jsonpath='{.data}' | jq 'keys'

print_info "🔍 STEP 4: Check what the volume mount expects"
echo "Volume mount expects these keys:"
kubectl get pod broken-volume -o yaml | grep -A 10 "items:" | grep "key:"

print_success "🛠️  DIAGNOSIS: Volume mount references 'nonexistent_key' which doesn't exist in the secret"

print_info "🛠️  SOLUTION: Fix the volume mount specification"

cat > /tmp/fixed-volume-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: fixed-volume
  labels:
    problem: fixed
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Starting application..."
      echo "Checking mounted secrets..."
      ls -la /etc/secrets/
      echo "Reading secret files..."
      echo "Username: $(cat /etc/secrets/username)"
      echo "Password: [HIDDEN]"
      sleep 600
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: test-secret
      # Remove the nonexistent key reference
      items:
      - key: username
        path: username
      - key: password
        path: password
  restartPolicy: Never
EOF

kubectl delete pod broken-volume
kubectl apply -f /tmp/fixed-volume-pod.yaml

kubectl wait --for=condition=Ready pod/fixed-volume --timeout=60s
print_success "Fixed pod is running! Check the logs:"
kubectl logs fixed-volume

wait_for_input

print_step "4. Problem: Permission and Access Issues"

print_info "Let's troubleshoot RBAC and permission issues:"

# Create a service account with limited permissions
kubectl create serviceaccount limited-sa 2>/dev/null || true

cat > /tmp/permission-issue-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: permission-issue
  labels:
    problem: rbac
spec:
  serviceAccountName: limited-sa  # Service account with no secret access
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Starting application..."
      echo "Trying to access secret files..."
      ls -la /etc/secrets/ || echo "Cannot access secret directory"
      echo "Trying to read secret content..."
      cat /etc/secrets/username 2>/dev/null || echo "Cannot read secret files"
      sleep 600
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: test-secret
  restartPolicy: Never
EOF

kubectl apply -f /tmp/permission-issue-pod.yaml

print_error "Pod created with potential permission issues:"

sleep 5

print_info "🔍 STEP 1: Check pod status"
kubectl get pod permission-issue

print_info "🔍 STEP 2: Check service account permissions"
echo "Service account can access secrets:"
kubectl auth can-i get secrets --as=system:serviceaccount:default:limited-sa

print_info "🔍 STEP 3: Check pod logs"
kubectl logs permission-issue

print_info "🔍 STEP 4: Check file permissions inside pod"
kubectl exec permission-issue -- ls -la /etc/secrets/ 2>/dev/null || echo "Cannot execute commands in pod"

print_success "🛠️  DIAGNOSIS: Service account permissions are working correctly"
print_info "The secret is accessible because volume mounts don't require specific secret permissions"
print_info "RBAC controls API access, not volume mount access"

wait_for_input

print_step "5. Problem: Configuration Update Issues"

print_info "Let's troubleshoot configuration update problems:"

# Create a ConfigMap and pod
kubectl create configmap working-config \
    --from-literal=message="Original message" \
    --from-literal=version="1.0"

cat > /tmp/update-issue-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: update-issue
  labels:
    problem: config-updates
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== CONFIGURATION UPDATE TEST ==="
      
      while true; do
        echo ""
        echo "$(date): Current configuration:"
        echo "  Environment MESSAGE: $MESSAGE"
        echo "  Environment VERSION: $VERSION"
        
        if [ -f /etc/config/message ]; then
          echo "  File MESSAGE: $(cat /etc/config/message)"
          echo "  File VERSION: $(cat /etc/config/version)"
        else
          echo "  Config files not found"
        fi
        
        echo "  Waiting for configuration updates..."
        sleep 30
      done
    env:
    # Environment variables (won't update without pod restart)
    - name: MESSAGE
      valueFrom:
        configMapKeyRef:
          name: working-config
          key: message
    - name: VERSION
      valueFrom:
        configMapKeyRef:
          name: working-config
          key: version
    volumeMounts:
    # Volume mounts (will update automatically)
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: working-config
  restartPolicy: Never
EOF

kubectl apply -f /tmp/update-issue-pod.yaml

kubectl wait --for=condition=Ready pod/update-issue --timeout=60s

print_info "Initial configuration state:"
kubectl logs update-issue --tail=10

print_info "Now let's update the ConfigMap and observe the differences:"

wait_for_input

# Update the ConfigMap
kubectl patch configmap working-config -p '{"data":{"message":"Updated message!","version":"2.0"}}'

print_success "ConfigMap updated! Let's see what happens:"

sleep 35  # Wait for the pod to log again

kubectl logs update-issue --tail=10

print_info "🔍 OBSERVATIONS:"
echo "  • Environment variables: Still show old values (require pod restart)"
echo "  • Volume mounted files: Show new values (updated automatically)"

print_warning "🛠️  CONFIGURATION UPDATE BEHAVIOR:"
echo "  ❌ Environment variables from ConfigMaps don't update automatically"
echo "  ✅ Volume-mounted ConfigMaps update automatically (with some delay)"
echo "  ⚠️  Applications must handle configuration changes gracefully"

wait_for_input

print_step "6. Comprehensive Debugging Toolkit"

print_info "Let's create a comprehensive debugging pod:"

# Create comprehensive test resources
kubectl create configmap debug-config \
    --from-literal=debug_enabled="true" \
    --from-literal=log_level="DEBUG" \
    --from-literal=app_name="Debug App"

kubectl create secret generic debug-secret \
    --from-literal=api_key="debug_api_key_123" \
    --from-literal=database_password="debug_password"

cat > /tmp/debug-toolkit.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: debug-pod
  labels:
    purpose: debugging
spec:
  containers:
  - name: debug-toolkit
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== KUBERNETES CONFIGURATION DEBUG TOOLKIT ==="
      echo ""
      
      # Function to check ConfigMaps
      check_configmaps() {
        echo "📋 CONFIGMAP ANALYSIS:"
        echo "Available ConfigMaps:"
        for cm in debug-config working-config test-config; do
          if kubectl get configmap $cm >/dev/null 2>&1; then
            echo "  ✅ $cm exists"
            echo "    Keys: $(kubectl get configmap $cm -o jsonpath='{.data}' | jq -r 'keys | join(", ")')"
            echo "    Size: $(kubectl get configmap $cm -o json | jq '.data | to_entries | map(.value | length) | add // 0') bytes"
          else
            echo "  ❌ $cm not found"
          fi
        done
        echo ""
      }
      
      # Function to check Secrets
      check_secrets() {
        echo "🔐 SECRET ANALYSIS:"
        echo "Available Secrets:"
        for secret in debug-secret test-secret; do
          if kubectl get secret $secret >/dev/null 2>&1; then
            echo "  ✅ $secret exists"
            echo "    Keys: $(kubectl get secret $secret -o jsonpath='{.data}' | jq -r 'keys | join(", ")')"
            echo "    Size: $(kubectl get secret $secret -o json | jq '.data | to_entries | map(.value | length) | add // 0') bytes"
            echo "    Type: $(kubectl get secret $secret -o jsonpath='{.type}')"
          else
            echo "  ❌ $secret not found"
          fi
        done
        echo ""
      }
      
      # Function to check environment variables
      check_environment() {
        echo "🌍 ENVIRONMENT VARIABLES:"
        echo "Configuration-related variables:"
        env | grep -E "(DEBUG|LOG|APP|API)" | sort
        echo ""
      }
      
      # Function to check mounted files
      check_mounts() {
        echo "📁 MOUNTED CONFIGURATION:"
        echo "ConfigMap mounts:"
        if [ -d /etc/config ]; then
          echo "  ✅ /etc/config exists"
          ls -la /etc/config/
          for file in /etc/config/*; do
            if [ -f "$file" ]; then
              echo "    $(basename $file): $(head -1 $file 2>/dev/null || echo '[binary or empty]')"
            fi
          done
        else
          echo "  ❌ /etc/config not found"
        fi
        
        echo ""
        echo "Secret mounts:"
        if [ -d /etc/secrets ]; then
          echo "  ✅ /etc/secrets exists"
          ls -la /etc/secrets/
          for file in /etc/secrets/*; do
            if [ -f "$file" ]; then
              echo "    $(basename $file): [HIDDEN - $(wc -c < $file) bytes]"
            fi
          done
        else
          echo "  ❌ /etc/secrets not found"
        fi
        echo ""
      }
      
      # Function to check permissions
      check_permissions() {
        echo "🔒 PERMISSION ANALYSIS:"
        echo "Current user: $(id)"
        echo "Service account: $(cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.kubernetes.io.serviceaccount.name' 2>/dev/null || echo 'default')"
        
        echo "File permissions:"
        if [ -d /etc/config ]; then
          echo "  Config files: $(ls -la /etc/config/ | head -2 | tail -1)"
        fi
        if [ -d /etc/secrets ]; then
          echo "  Secret files: $(ls -la /etc/secrets/ | head -2 | tail -1)"
        fi
        echo ""
      }
      
      # Function to run connectivity tests
      check_connectivity() {
        echo "🌐 CONNECTIVITY TESTS:"
        
        # Test DNS resolution
        echo "DNS resolution:"
        nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 && echo "  ✅ Cluster DNS working" || echo "  ❌ Cluster DNS issues"
        
        # Test API server connectivity
        echo "API server connectivity:"
        if [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
          TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
          if wget -q --header="Authorization: Bearer $TOKEN" --no-check-certificate -O- https://kubernetes.default.svc.cluster.local/api/v1/namespaces/default/configmaps >/dev/null 2>&1; then
            echo "  ✅ Can access API server"
          else
            echo "  ❌ Cannot access API server"
          fi
        else
          echo "  ❌ No service account token found"
        fi
        echo ""
      }
      
      # Run initial diagnostics
      check_configmaps
      check_secrets
      check_environment
      check_mounts
      check_permissions
      check_connectivity
      
      echo "=== DEBUG TOOLKIT READY ==="
      echo "Use 'kubectl exec debug-pod -- <command>' to run specific checks"
      echo ""
      
      # Keep running for interactive debugging
      while true; do
        echo "$(date): Debug toolkit running... (use 'kubectl logs debug-pod -f' to monitor)"
        sleep 60
      done
    env:
    - name: DEBUG_ENABLED
      valueFrom:
        configMapKeyRef:
          name: debug-config
          key: debug_enabled
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: debug-config
          key: log_level
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: debug-config
          key: app_name
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: debug-secret
          key: api_key
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: debug-config
  - name: secret-volume
    secret:
      secretName: debug-secret
  restartPolicy: Never
EOF

kubectl apply -f /tmp/debug-toolkit.yaml

kubectl wait --for=condition=Ready pod/debug-pod --timeout=60s

print_success "Debug toolkit is running! Here's the comprehensive analysis:"
kubectl logs debug-pod

print_info "🛠️  INTERACTIVE DEBUGGING COMMANDS:"
echo ""
echo "Check specific ConfigMap:"
echo "  kubectl exec debug-pod -- kubectl get configmap <name> -o yaml"
echo ""
echo "Test environment variable access:"
echo "  kubectl exec debug-pod -- env | grep <variable>"
echo ""
echo "Check file contents:"
echo "  kubectl exec debug-pod -- cat /etc/config/<file>"
echo ""
echo "Test network connectivity:"
echo "  kubectl exec debug-pod -- nslookup <hostname>"
echo ""
echo "Check file permissions:"
echo "  kubectl exec debug-pod -- ls -la /etc/secrets/"

wait_for_input

print_step "7. Troubleshooting Checklist and Best Practices"

print_info "🛠️  SYSTEMATIC TROUBLESHOOTING APPROACH:"

echo ""
echo "📋 INITIAL ASSESSMENT:"
echo "  1. Check pod status: kubectl get pods"
echo "  2. Review pod events: kubectl describe pod <name>"
echo "  3. Check pod logs: kubectl logs <pod> [-c <container>]"
echo "  4. Verify resource existence: kubectl get configmaps,secrets"

echo ""
echo "📋 CONFIGURATION ISSUES:"
echo "  1. Verify ConfigMap/Secret exists"
echo "  2. Check key names match exactly"
echo "  3. Validate data format and encoding"
echo "  4. Test with a debug pod"

echo ""
echo "📋 VOLUME MOUNT ISSUES:"
echo "  1. Check volume definition in pod spec"
echo "  2. Verify mount path permissions"
echo "  3. Test file accessibility inside pod"
echo "  4. Check for conflicting mounts"

echo ""
echo "📋 PERMISSION ISSUES:"
echo "  1. Check service account permissions"
echo "  2. Verify RBAC rules"
echo "  3. Test API access with kubectl auth can-i"
echo "  4. Check file ownership and permissions"

echo ""
echo "📋 UPDATE ISSUES:"
echo "  1. Understand env vars vs volume mounts behavior"
echo "  2. Check ConfigMap/Secret modification timestamp"
echo "  3. Test with a fresh pod"
echo "  4. Implement proper configuration reloading"

print_success "🛠️  PREVENTION STRATEGIES:"
echo ""
echo "✅ DEVELOPMENT:"
echo "  • Use init containers for configuration validation"
echo "  • Implement health checks for configuration"
echo "  • Add comprehensive logging for configuration loading"
echo "  • Use configuration schemas for validation"

echo ""
echo "✅ DEPLOYMENT:"
echo "  • Test configuration in non-production first"
echo "  • Use gradual rollouts for configuration changes"
echo "  • Implement rollback procedures"
echo "  • Monitor application health after changes"

echo ""
echo "✅ OPERATIONS:"
echo "  • Regular configuration audits"
echo "  • Monitor configuration drift"
echo "  • Implement alerting for configuration failures"
echo "  • Maintain configuration documentation"

wait_for_input

print_step "8. Quick Reference Commands"

print_info "📚 CONFIGURATION TROUBLESHOOTING COMMANDS:"

cat > /tmp/troubleshooting-commands.sh << 'EOF'
#!/bin/bash

# Configuration Troubleshooting Quick Reference

echo "=== KUBERNETES CONFIGURATION TROUBLESHOOTING COMMANDS ==="
echo ""

echo "📋 BASIC INSPECTION:"
echo "kubectl get configmaps,secrets"
echo "kubectl describe configmap <name>"
echo "kubectl describe secret <name>"
echo "kubectl get pod <name> -o yaml"
echo ""

echo "📋 POD DIAGNOSTICS:"
echo "kubectl get pods"
echo "kubectl describe pod <name>"
echo "kubectl logs <pod> [-c <container>]"
echo "kubectl exec <pod> -- env"
echo "kubectl exec <pod> -- ls -la /etc/config/"
echo ""

echo "📋 CONFIGURATION CONTENT:"
echo "kubectl get configmap <name> -o jsonpath='{.data}'"
echo "kubectl get secret <name> -o jsonpath='{.data}' | base64 -d"
echo "kubectl get configmap <name> -o yaml"
echo ""

echo "📋 PERMISSION TESTING:"
echo "kubectl auth can-i get configmaps"
echo "kubectl auth can-i get secrets"
echo "kubectl auth can-i get configmaps --as=system:serviceaccount:default:<sa-name>"
echo ""

echo "📋 DEBUGGING PODS:"
echo "kubectl run debug --rm -it --image=busybox -- sh"
echo "kubectl exec -it <pod> -- sh"
echo "kubectl cp <pod>:/etc/config/file ./local-file"
echo ""

echo "📋 EVENTS AND MONITORING:"
echo "kubectl get events --sort-by=.metadata.creationTimestamp"
echo "kubectl get events --field-selector involvedObject.name=<pod-name>"
echo "kubectl top pods"
echo ""

echo "📋 CONFIGURATION UPDATES:"
echo "kubectl patch configmap <name> -p '{\"data\":{\"key\":\"value\"}}'"
echo "kubectl patch secret <name> -p '{\"data\":{\"key\":\"<base64-value>\"}}'"
echo "kubectl rollout restart deployment/<name>"
EOF

chmod +x /tmp/troubleshooting-commands.sh

print_success "Quick reference script created! Run it anytime:"
/tmp/troubleshooting-commands.sh

wait_for_input

print_step "9. Cleanup"

print_info "Cleaning up exercise resources..."

# Clean up files
rm -f /tmp/broken-configmap-pod.yaml /tmp/broken-secret-pod.yaml /tmp/broken-volume-pod.yaml \
      /tmp/fixed-volume-pod.yaml /tmp/permission-issue-pod.yaml /tmp/update-issue-pod.yaml \
      /tmp/debug-toolkit.yaml /tmp/troubleshooting-commands.sh

# Clean up pods
kubectl delete pod \
    broken-configmap broken-secret fixed-volume \
    permission-issue update-issue debug-pod 2>/dev/null || true

# Clean up test resources
kubectl delete configmap \
    test-config working-config debug-config 2>/dev/null || true

kubectl delete secret \
    test-secret nonexistent-secret debug-secret 2>/dev/null || true

kubectl delete serviceaccount limited-sa 2>/dev/null || true

print_success "Exercise completed! You've learned:"
echo "  ✅ Systematic troubleshooting approach"
echo "  ✅ Diagnosing ConfigMap and Secret issues"
echo "  ✅ Debugging volume mount problems"
echo "  ✅ Understanding permission and RBAC issues"
echo "  ✅ Configuration update behavior"
echo "  ✅ Comprehensive debugging toolkit"
echo "  ✅ Prevention strategies"
echo "  ✅ Quick reference commands"

print_info "🎓 CONGRATULATIONS!"
print_info "You have completed all Configuration & Secrets exercises!"
print_info "You now have the skills to:"
echo "  • Create and manage ConfigMaps and Secrets"
echo "  • Use configuration securely in applications"
echo "  • Implement advanced configuration patterns"
echo "  • Troubleshoot configuration issues systematically"
echo "  • Apply security best practices"

print_info "Next: Move on to Module 6: Storage Solutions!"