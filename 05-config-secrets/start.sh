#!/bin/bash

# Module 5: Configuration & Secrets Interactive Workshop
# This script provides an interactive learning experience for Kubernetes configuration management

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
    if ! kubectl auth can-i create configmaps &> /dev/null; then
        print_error "Insufficient permissions to create ConfigMaps"
        exit 1
    fi
    
    if ! kubectl auth can-i create secrets &> /dev/null; then
        print_error "Insufficient permissions to create Secrets"
        exit 1
    fi
    
    print_success "All prerequisites satisfied!"
    
    # Show cluster info
    print_info "Connected to cluster: $(kubectl config current-context)"
    print_info "Current namespace: $(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo 'default')"
}

cleanup_previous() {
    print_header "Cleaning Up Previous Resources"
    
    print_info "Removing any existing demo resources..."
    
    # Clean up pods
    kubectl delete pod --ignore-not-found=true \
        hardcoded-app configmap-env-demo configmap-volume-demo \
        secret-env-demo secret-volume-demo config-inspector \
        hot-reload-demo 2>/dev/null || true
    
    # Clean up configmaps
    kubectl delete configmap --ignore-not-found=true \
        app-config file-config nginx-config web-config \
        app-config-dev app-config-prod app-base-config app-env-config \
        reload-scripts 2>/dev/null || true
    
    # Clean up secrets
    kubectl delete secret --ignore-not-found=true \
        database-credentials file-credentials manual-secret \
        database-credentials-v2 tls-secret registry-secret 2>/dev/null || true
    
    print_success "Cleanup completed!"
}

demo_configuration_challenge() {
    print_header "Understanding the Configuration Challenge"
    
    print_info "Let's see why hard-coding configuration is problematic..."
    
    print_step "1. Creating a pod with hard-coded configuration"
    
    # Create a pod with hard-coded configuration
    cat << 'EOF' > /tmp/hardcoded-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardcoded-app
  labels:
    app: hardcoded-demo
spec:
  containers:
  - name: web-server
    image: nginx:alpine
    env:
    - name: DATABASE_HOST
      value: "hardcoded-prod-db.company.com"
    - name: LOG_LEVEL
      value: "INFO"
    - name: API_KEY
      value: "hardcoded-secret-key-123"
    ports:
    - containerPort: 80
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/hardcoded-pod.yaml
    
    print_info "Pod created with hard-coded configuration. Let's examine it:"
    kubectl get pod hardcoded-app
    
    wait_for_input
    
    print_step "2. Examining the hard-coded environment variables"
    kubectl exec hardcoded-app -- env | grep -E "(DATABASE_HOST|LOG_LEVEL|API_KEY)"
    
    print_warning "Problems with this approach:"
    echo "  • Cannot change configuration without rebuilding image"
    echo "  • Same image cannot be used for different environments"
    echo "  • Secrets are visible in plain text"
    echo "  • Configuration is scattered across multiple pod definitions"
    
    wait_for_input
    
    print_info "Now let's see the Kubernetes way..."
    kubectl delete pod hardcoded-app
}

demo_configmaps() {
    print_header "Working with ConfigMaps"
    
    print_step "1. Creating ConfigMaps from literal values"
    
    kubectl create configmap app-config \
        --from-literal=database_host=postgres.example.com \
        --from-literal=database_port=5432 \
        --from-literal=log_level=INFO \
        --from-literal=max_connections=100
    
    print_success "ConfigMap created! Let's examine it:"
    kubectl get configmap app-config -o yaml
    
    wait_for_input
    
    print_step "2. Creating ConfigMaps from files"
    
    # Create configuration files
    mkdir -p /tmp/config-files
    cat > /tmp/config-files/database.conf << EOF
host=postgres.example.com
port=5432
database=myapp
pool_size=10
timeout=30s
EOF

    cat > /tmp/config-files/nginx.conf << 'EOF'
server {
    listen 80;
    server_name example.com;
    
    location / {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /health {
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
EOF

    kubectl create configmap file-config --from-file=/tmp/config-files/
    
    print_success "File-based ConfigMap created!"
    kubectl get configmap file-config -o yaml
    
    wait_for_input
    
    print_step "3. Creating ConfigMaps from YAML manifests"
    
    cat << 'EOF' > /tmp/web-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
  namespace: default
data:
  # Simple key-value pairs
  app_name: "my-web-app"
  version: "1.2.3"
  environment: "production"
  
  # File-like data
  database.conf: |
    host=postgres.example.com
    port=5432
    database=myapp
    pool_size=10
    
  app.properties: |
    # Application Configuration
    server.port=8080
    management.endpoints.web.exposure.include=health,info,metrics
    logging.level.com.example=INFO
    
    # Database Configuration
    spring.datasource.url=jdbc:postgresql://${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}
    spring.datasource.driver-class-name=org.postgresql.Driver
EOF

    kubectl apply -f /tmp/web-config.yaml
    
    print_success "YAML-based ConfigMap created!"
    kubectl describe configmap web-config
    
    wait_for_input
}

demo_configmap_usage() {
    print_header "Using ConfigMaps in Pods"
    
    print_step "1. Using ConfigMaps as environment variables"
    
    cat << 'EOF' > /tmp/configmap-env-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-env-demo
spec:
  containers:
  - name: demo-container
    image: busybox:1.35
    command: [ "/bin/sh", "-c" ]
    args:
    - |
      echo "=== Environment Variables from ConfigMap ==="
      env | grep -E "(APP_|DATABASE_)" | sort
      echo ""
      echo "Sleeping for demonstration..."
      sleep 300
    env:
    # Single environment variable from ConfigMap
    - name: APP_DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_host
    - name: APP_LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: log_level
    # All keys from ConfigMap as environment variables
    envFrom:
    - configMapRef:
        name: app-config
        prefix: "DATABASE_"
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/configmap-env-pod.yaml
    
    print_info "Waiting for pod to start..."
    kubectl wait --for=condition=Ready pod/configmap-env-demo --timeout=60s
    
    print_success "Pod started! Let's see the environment variables:"
    kubectl logs configmap-env-demo
    
    wait_for_input
    
    print_step "2. Using ConfigMaps as volume mounts"
    
    cat << 'EOF' > /tmp/configmap-volume-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-volume-demo
spec:
  containers:
  - name: demo-container
    image: busybox:1.35
    command: [ "/bin/sh", "-c" ]
    args:
    - |
      echo "=== Configuration Files from ConfigMap ==="
      echo "Files in /etc/config:"
      ls -la /etc/config/
      echo ""
      echo "=== database.conf content ==="
      cat /etc/config/database.conf
      echo ""
      echo "=== app.properties content ==="
      cat /etc/config/app.properties
      echo ""
      echo "Sleeping for demonstration..."
      sleep 300
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: web-config
      items:
      - key: database.conf
        path: database.conf
      - key: app.properties
        path: app.properties
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/configmap-volume-pod.yaml
    
    print_info "Waiting for pod to start..."
    kubectl wait --for=condition=Ready pod/configmap-volume-demo --timeout=60s
    
    print_success "Pod started! Let's see the mounted configuration files:"
    kubectl logs configmap-volume-demo
    
    wait_for_input
    
    print_info "Comparison: Environment Variables vs Volume Mounts"
    echo "Environment Variables:"
    echo "  ✅ Simple key-value configuration"
    echo "  ✅ Application expects environment variables"
    echo "  ❌ Limited to simple values"
    echo "  ❌ Requires pod restart for updates"
    echo ""
    echo "Volume Mounts:"
    echo "  ✅ Support for complex configuration files"
    echo "  ✅ Can be updated without pod restart"
    echo "  ✅ Better for large configuration data"
    echo "  ❌ Application must read from files"
}

demo_secrets() {
    print_header "Working with Secrets"
    
    print_step "1. Creating secrets securely"
    
    print_info "Creating a generic secret..."
    kubectl create secret generic database-credentials \
        --from-literal=username=postgres \
        --from-literal=password=supersecret123 \
        --from-literal=database=myapp
    
    print_success "Secret created! Let's examine it (safely):"
    kubectl get secret database-credentials
    
    print_info "Notice that the data is not visible in the normal output."
    
    wait_for_input
    
    print_step "2. Understanding secret encoding"
    
    print_info "Secrets are base64 encoded (NOT encrypted):"
    kubectl get secret database-credentials -o yaml
    
    print_warning "Base64 is encoding, not encryption!"
    echo "Let's decode one value to show this:"
    kubectl get secret database-credentials -o jsonpath='{.data.username}' | base64 -d
    echo ""
    
    wait_for_input
    
    print_step "3. Creating secrets from files"
    
    # Create credential files
    echo -n 'admin' > /tmp/username.txt
    echo -n 'megasecret456' > /tmp/password.txt
    
    kubectl create secret generic file-credentials \
        --from-file=/tmp/username.txt \
        --from-file=/tmp/password.txt
    
    # Clean up files immediately
    rm /tmp/username.txt /tmp/password.txt
    
    print_success "File-based secret created!"
    kubectl describe secret file-credentials
    
    wait_for_input
}

demo_secret_usage() {
    print_header "Using Secrets in Applications"
    
    print_step "1. Using secrets as environment variables"
    
    cat << 'EOF' > /tmp/secret-env-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-demo
spec:
  containers:
  - name: demo-container
    image: postgres:13-alpine
    env:
    - name: POSTGRES_USER
      valueFrom:
        secretKeyRef:
          name: database-credentials
          key: username
    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef:
          name: database-credentials
          key: password
    - name: POSTGRES_DB
      valueFrom:
        secretKeyRef:
          name: database-credentials
          key: database
    # Show that PostgreSQL is configured correctly
    command: [ "/bin/sh", "-c" ]
    args:
    - |
      echo "PostgreSQL configured with:"
      echo "User: $POSTGRES_USER"
      echo "Database: $POSTGRES_DB"
      echo "Password: [HIDDEN]"
      echo ""
      echo "Starting PostgreSQL..."
      exec docker-entrypoint.sh postgres
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/secret-env-pod.yaml
    
    print_info "PostgreSQL pod starting with secret-based configuration..."
    sleep 5
    kubectl logs secret-env-demo --tail=10
    
    wait_for_input
    
    print_step "2. Using secrets as volume mounts (more secure)"
    
    cat << 'EOF' > /tmp/secret-volume-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-demo
spec:
  containers:
  - name: demo-container
    image: busybox:1.35
    command: [ "/bin/sh", "-c" ]
    args:
    - |
      echo "=== Secret Files ==="
      ls -la /etc/secrets/
      echo ""
      echo "=== File Permissions ==="
      stat /etc/secrets/*
      echo ""
      echo "=== Username (safe to show) ==="
      cat /etc/secrets/username
      echo ""
      echo "Password file exists but content hidden for security"
      echo ""
      echo "Sleeping for demonstration..."
      sleep 300
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: database-credentials
      defaultMode: 0400  # Read-only for owner only
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/secret-volume-pod.yaml
    
    print_info "Waiting for pod to start..."
    kubectl wait --for=condition=Ready pod/secret-volume-demo --timeout=60s
    
    print_success "Pod started! Let's examine the mounted secrets:"
    kubectl logs secret-volume-demo
    
    wait_for_input
    
    print_info "Security best practices for secrets:"
    echo "  ✅ Use volume mounts instead of environment variables when possible"
    echo "  ✅ Set restrictive file permissions (defaultMode: 0400)"
    echo "  ✅ Use specific service accounts with RBAC"
    echo "  ✅ Rotate secrets regularly"
    echo "  ✅ Never log secret values"
    echo "  ✅ Use external secret management systems in production"
}

demo_advanced_patterns() {
    print_header "Advanced Configuration Patterns"
    
    print_step "1. Multi-environment configuration"
    
    print_info "Creating environment-specific configurations..."
    
    # Development environment
    kubectl create configmap app-config-dev \
        --from-literal=log_level=DEBUG \
        --from-literal=database_host=dev-db.company.internal \
        --from-literal=cache_enabled=false \
        --from-literal=replicas=1
    
    # Production environment
    kubectl create configmap app-config-prod \
        --from-literal=log_level=WARN \
        --from-literal=database_host=prod-db.company.internal \
        --from-literal=cache_enabled=true \
        --from-literal=replicas=3
    
    print_success "Environment-specific configs created!"
    echo "Development config:"
    kubectl get configmap app-config-dev -o yaml | grep -A 10 "data:"
    echo ""
    echo "Production config:"
    kubectl get configmap app-config-prod -o yaml | grep -A 10 "data:"
    
    wait_for_input
    
    print_step "2. Configuration inspection and debugging"
    
    cat << 'EOF' > /tmp/config-inspector.yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-inspector
  labels:
    app: config-inspector
spec:
  containers:
  - name: inspector
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== CONFIGURATION INSPECTOR ==="
      echo ""
      echo "=== Environment Variables ==="
      env | sort | grep -E "(APP_|DATABASE_|LOG_)"
      echo ""
      echo "=== Mounted Configuration Files ==="
      find /etc -type f -exec ls -la {} \; 2>/dev/null | head -20
      echo ""
      echo "=== Configuration File Contents ==="
      for file in $(find /etc -type f 2>/dev/null | head -5); do
        echo "=== $file ==="
        cat "$file" 2>/dev/null | head -10
        echo ""
      done
      echo ""
      echo "Inspector ready. Sleeping..."
      sleep 3600
    env:
    - name: APP_ENVIRONMENT
      value: "development"
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config-dev
          key: log_level
    envFrom:
    - configMapRef:
        name: app-config-dev
        prefix: "APP_"
    volumeMounts:
    - name: config
      mountPath: /etc/config
    - name: secrets
      mountPath: /etc/secrets
  volumes:
  - name: config
    configMap:
      name: web-config
  - name: secrets
    secret:
      secretName: database-credentials
      defaultMode: 0400
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/config-inspector.yaml
    
    print_info "Starting configuration inspector..."
    kubectl wait --for=condition=Ready pod/config-inspector --timeout=60s
    
    print_success "Inspector running! Let's see the complete configuration:"
    kubectl logs config-inspector
    
    wait_for_input
}

interactive_troubleshooting() {
    print_header "Interactive Troubleshooting Session"
    
    print_info "Let's practice troubleshooting common configuration issues..."
    
    print_step "1. ConfigMap key not found"
    
    # Create a pod with a missing ConfigMap key
    cat << 'EOF' > /tmp/broken-config-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-config
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh", "-c", "env; sleep 300"]
    env:
    - name: MISSING_CONFIG
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: nonexistent_key  # This key doesn't exist!
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/broken-config-pod.yaml
    
    print_info "Pod created with missing ConfigMap key. Let's diagnose:"
    
    sleep 3
    
    print_info "1. Check pod status:"
    kubectl get pod broken-config
    
    print_info "2. Check pod events:"
    kubectl describe pod broken-config | tail -10
    
    print_info "3. Fix the issue by checking available ConfigMap keys:"
    kubectl get configmap app-config -o jsonpath='{.data}' | jq .
    
    print_success "Troubleshooting tip: Always verify ConfigMap keys exist!"
    
    kubectl delete pod broken-config
    
    wait_for_input
    
    print_step "2. Secret mount permission issues"
    
    print_info "Let's simulate and fix permission issues..."
    kubectl exec config-inspector -- ls -la /etc/secrets/
    
    print_info "Notice the restrictive permissions (400) - this is correct for secrets!"
    
    wait_for_input
    
    print_success "Troubleshooting complete!"
}

cleanup_demo() {
    print_header "Cleaning Up Demo Resources"
    
    print_info "Removing demo resources..."
    
    # Clean up pods
    kubectl delete pod --ignore-not-found=true \
        configmap-env-demo configmap-volume-demo \
        secret-env-demo secret-volume-demo config-inspector 2>/dev/null || true
    
    print_info "Resources cleaned up!"
    print_warning "ConfigMaps and Secrets are kept for your continued learning."
    print_info "To clean them up manually, run:"
    echo "  kubectl delete configmap app-config file-config web-config app-config-dev app-config-prod"
    echo "  kubectl delete secret database-credentials file-credentials"
}

show_next_steps() {
    print_header "Next Steps"
    
    print_success "Congratulations! You've completed the Configuration & Secrets workshop!"
    
    print_info "What you've learned:"
    echo "  ✅ Why configuration should be separate from code"
    echo "  ✅ Creating and using ConfigMaps"
    echo "  ✅ Securing sensitive data with Secrets"
    echo "  ✅ Environment variables vs volume mounts"
    echo "  ✅ Real-world configuration patterns"
    echo "  ✅ Security best practices"
    echo "  ✅ Troubleshooting configuration issues"
    
    echo ""
    print_info "Recommended next steps:"
    echo "  1. Complete the exercises in the exercises/ directory"
    echo "  2. Try the module challenge"
    echo "  3. Read the full README.md for deeper understanding"
    echo "  4. Proceed to Module 6: Storage Solutions"
    
    echo ""
    print_info "Quick reference commands:"
    echo "  kubectl get configmaps,secrets"
    echo "  kubectl describe configmap <name>"
    echo "  kubectl describe secret <name>"
    echo "  kubectl exec <pod> -- env | grep <prefix>"
}

# Main execution
main() {
    print_header "Kubernetes Configuration & Secrets Workshop"
    
    print_info "This interactive workshop will teach you:"
    echo "  • Why configuration matters in Kubernetes"
    echo "  • How to use ConfigMaps effectively"
    echo "  • How to secure sensitive data with Secrets"
    echo "  • Real-world configuration patterns"
    echo "  • Security best practices"
    echo "  • Troubleshooting techniques"
    
    wait_for_input
    
    check_prerequisites
    cleanup_previous
    demo_configuration_challenge
    demo_configmaps
    demo_configmap_usage
    demo_secrets
    demo_secret_usage
    demo_advanced_patterns
    interactive_troubleshooting
    cleanup_demo
    show_next_steps
    
    print_success "Workshop completed successfully!"
}

# Run the workshop
main "$@"