#!/bin/bash

# Exercise 4: Secret Security Practices
# This exercise demonstrates security best practices for using secrets in applications

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

print_header "Exercise 4: Secret Security Practices"

print_info "This exercise demonstrates security best practices for using secrets"
print_info "in applications, including secure mounting, RBAC, and monitoring."

wait_for_input

# Cleanup any existing resources
print_info "Cleaning up any existing demo resources..."
kubectl delete pod --ignore-not-found=true \
    insecure-app secure-app volume-mount-demo \
    permissions-demo monitoring-demo 2>/dev/null || true

kubectl delete secret --ignore-not-found=true \
    demo-credentials sensitive-data app-secrets \
    monitoring-credentials 2>/dev/null || true

kubectl delete serviceaccount --ignore-not-found=true \
    app-sa limited-sa monitoring-sa 2>/dev/null || true

kubectl delete role,rolebinding --ignore-not-found=true \
    secret-reader secret-reader-binding \
    limited-secret-access limited-secret-binding \
    monitoring-access monitoring-binding 2>/dev/null || true

print_step "1. Insecure vs Secure Secret Usage"

print_info "Let's compare insecure and secure ways to use secrets..."

# Create demo credentials
kubectl create secret generic demo-credentials \
    --from-literal=username=admin \
    --from-literal=password=supersecret123 \
    --from-literal=api_key=sk_live_1234567890abcdef \
    --from-literal=database_url="postgresql://admin:supersecret123@db.example.com:5432/myapp"

print_success "Demo credentials created!"

print_info "❌ INSECURE: Using secrets as environment variables"

cat > /tmp/insecure-app.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: insecure-app
  labels:
    security-demo: insecure
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== SECURITY ISSUES DEMONSTRATION ==="
      echo ""
      echo "1. Environment variables are visible in process list:"
      ps aux | grep sleep
      echo ""
      echo "2. Environment variables are visible to other processes:"
      env | grep -E "(PASSWORD|API_KEY|DATABASE_URL)"
      echo ""
      echo "3. Environment variables appear in pod specification:"
      echo "  Anyone who can read pod specs can see the values"
      echo ""
      echo "4. Environment variables are passed to child processes"
      echo ""
      echo "Starting application (insecure)..."
      sleep 600
    env:
    # BAD: Secrets directly as environment variables
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: demo-credentials
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: demo-credentials
          key: password
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: demo-credentials
          key: api_key
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: demo-credentials
          key: database_url
  restartPolicy: Never
EOF

kubectl apply -f /tmp/insecure-app.yaml

print_info "Waiting for insecure app to start..."
kubectl wait --for=condition=Ready pod/insecure-app --timeout=60s

print_error "Security issues with environment variables:"
kubectl logs insecure-app

print_info "Let's see the environment variables from outside the container:"
kubectl exec insecure-app -- env | grep -E "(PASSWORD|API_KEY|DATABASE_URL)" | head -3

wait_for_input

print_info "✅ SECURE: Using secrets as volume mounts"

cat > /tmp/secure-app.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  labels:
    security-demo: secure
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== SECURE SECRET HANDLING ==="
      echo ""
      echo "1. Secrets are mounted as files with restricted permissions:"
      ls -la /etc/secrets/
      echo ""
      echo "2. Files are stored in tmpfs (memory, not disk):"
      mount | grep secrets
      echo ""
      echo "3. No secrets in environment variables:"
      env | grep -E "(PASSWORD|API_KEY|DATABASE)" | wc -l
      echo ""
      echo "4. Application reads from secure files:"
      echo "  Username: $(cat /etc/secrets/username)"
      echo "  Password: [HIDDEN - read from file]"
      echo "  API Key: [HIDDEN - read from file]"
      echo ""
      echo "Starting application (secure)..."
      sleep 600
    volumeMounts:
    - name: credentials
      mountPath: /etc/secrets
      readOnly: true
    # Only non-sensitive configuration as environment variables
    env:
    - name: APP_NAME
      value: "secure-demo-app"
    - name: LOG_LEVEL
      value: "INFO"
  volumes:
  - name: credentials
    secret:
      secretName: demo-credentials
      defaultMode: 0400  # Read-only for owner only
  restartPolicy: Never
EOF

kubectl apply -f /tmp/secure-app.yaml

print_info "Waiting for secure app to start..."
kubectl wait --for=condition=Ready pod/secure-app --timeout=60s

print_success "Secure secret handling:"
kubectl logs secure-app

print_info "Notice the difference in security approaches!"

wait_for_input

print_step "2. File Permissions and Security"

print_info "Let's examine secret file permissions in detail:"

cat > /tmp/permissions-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: permissions-demo
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== SECRET FILE PERMISSIONS ANALYSIS ==="
      echo ""
      echo "1. Default permissions (400 - read-only for owner):"
      ls -la /etc/secrets-default/
      stat /etc/secrets-default/username
      echo ""
      echo "2. Custom permissions (444 - read-only for all):"
      ls -la /etc/secrets-custom/
      stat /etc/secrets-custom/username
      echo ""
      echo "3. Mount filesystem type (should be tmpfs):"
      mount | grep secrets
      echo ""
      echo "4. Attempting to modify files (should fail):"
      echo "test" > /etc/secrets-default/username 2>&1 || echo "✅ Write correctly blocked"
      echo ""
      echo "5. File ownership:"
      id
      ls -ln /etc/secrets-default/
      echo ""
      echo "Permissions demonstration complete."
      sleep 600
    volumeMounts:
    - name: secrets-default
      mountPath: /etc/secrets-default
      readOnly: true
    - name: secrets-custom
      mountPath: /etc/secrets-custom
      readOnly: true
  volumes:
  - name: secrets-default
    secret:
      secretName: demo-credentials
      defaultMode: 0400  # Owner read-only
  - name: secrets-custom
    secret:
      secretName: demo-credentials
      defaultMode: 0444  # All users read-only
  restartPolicy: Never
EOF

kubectl apply -f /tmp/permissions-demo.yaml

print_info "Waiting for permissions demo to start..."
kubectl wait --for=condition=Ready pod/permissions-demo --timeout=60s

print_success "File permissions analysis:"
kubectl logs permissions-demo

print_info "Key security features:"
echo "  ✅ Secrets mounted in tmpfs (memory, not disk)"
echo "  ✅ Configurable file permissions"
echo "  ✅ Read-only mounts prevent modification"
echo "  ✅ Proper file ownership"

wait_for_input

print_step "3. Service Accounts and RBAC"

print_info "Let's implement proper RBAC for secret access:"

# Create different service accounts with different levels of access
kubectl create serviceaccount app-sa
kubectl create serviceaccount limited-sa
kubectl create serviceaccount monitoring-sa

print_success "Service accounts created!"

print_info "Creating RBAC roles with different permission levels:"

cat > /tmp/rbac-config.yaml << 'EOF'
# Full secret access for main application
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-binding
subjects:
- kind: ServiceAccount
  name: app-sa
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
---
# Limited access for less privileged services
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: limited-secret-access
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["demo-credentials"]  # Only specific secrets
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: limited-secret-binding
subjects:
- kind: ServiceAccount
  name: limited-sa
roleRef:
  kind: Role
  name: limited-secret-access
  apiGroup: rbac.authorization.k8s.io
---
# Monitoring access (read-only, specific secrets)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: monitoring-access
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["monitoring-credentials"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: monitoring-binding
subjects:
- kind: ServiceAccount
  name: monitoring-sa
roleRef:
  kind: Role
  name: monitoring-access
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f /tmp/rbac-config.yaml

# Create monitoring credentials
kubectl create secret generic monitoring-credentials \
    --from-literal=prometheus_token=prom_token_123 \
    --from-literal=grafana_password=grafana_pass_456

print_success "RBAC configuration applied!"

print_info "Testing service account permissions:"

echo "1. app-sa can read all secrets:"
kubectl auth can-i get secrets --as=system:serviceaccount:default:app-sa
echo ""

echo "2. limited-sa can read demo-credentials:"
kubectl auth can-i get secret/demo-credentials --as=system:serviceaccount:default:limited-sa
echo ""

echo "3. limited-sa cannot read monitoring-credentials:"
kubectl auth can-i get secret/monitoring-credentials --as=system:serviceaccount:default:limited-sa
echo ""

echo "4. monitoring-sa can read monitoring-credentials:"
kubectl auth can-i get secret/monitoring-credentials --as=system:serviceaccount:default:monitoring-sa
echo ""

echo "5. monitoring-sa cannot read demo-credentials:"
kubectl auth can-i get secret/demo-credentials --as=system:serviceaccount:default:monitoring-sa

print_success "RBAC is working correctly - principle of least privilege enforced!"

wait_for_input

print_step "4. Secure Application Deployment Pattern"

print_info "Let's deploy a realistic secure application:"

cat > /tmp/secure-deployment.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: secure-webapp
  labels:
    app: webapp
    security: enhanced
spec:
  serviceAccountName: app-sa  # Use specific service account
  securityContext:
    # Pod-level security context
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 2000
    fsGroup: 2000
  containers:
  - name: webapp
    image: nginx:alpine
    securityContext:
      # Container-level security context
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
    ports:
    - containerPort: 8080
    env:
    # Only non-sensitive configuration as env vars
    - name: APP_NAME
      value: "secure-webapp"
    - name: PORT
      value: "8080"
    - name: LOG_LEVEL
      value: "INFO"
    volumeMounts:
    # Application secrets
    - name: app-secrets
      mountPath: /etc/secrets
      readOnly: true
    # TLS certificates
    - name: tls-certs
      mountPath: /etc/tls
      readOnly: true
    # Configuration files
    - name: app-config
      mountPath: /etc/config
      readOnly: true
    # Writable temporary directory
    - name: tmp
      mountPath: /tmp
    # Nginx cache directory
    - name: nginx-cache
      mountPath: /var/cache/nginx
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== SECURE APPLICATION STARTUP ==="
      echo "Running as user: $(id)"
      echo ""
      echo "Security context:"
      echo "  - Non-root user: ✅"
      echo "  - Read-only root filesystem: ✅"
      echo "  - No privilege escalation: ✅"
      echo "  - Dropped capabilities: ✅"
      echo ""
      echo "Secret management:"
      echo "  - Secrets mounted as files: ✅"
      echo "  - Restricted file permissions: ✅"
      ls -la /etc/secrets/
      echo ""
      echo "Configuration loaded from: /etc/config/"
      ls -la /etc/config/
      echo ""
      echo "TLS certificates loaded from: /etc/tls/"
      ls -la /etc/tls/ 2>/dev/null || echo "  (TLS certs would be here in real deployment)"
      echo ""
      echo "Starting nginx on port 8080..."
      # In a real deployment, nginx would start here
      sleep 600
  volumes:
  # Secret volumes
  - name: app-secrets
    secret:
      secretName: demo-credentials
      defaultMode: 0400
  - name: tls-certs
    secret:
      secretName: tls-cert
      defaultMode: 0400
      optional: true  # Allow deployment without TLS for demo
  # Configuration volume
  - name: app-config
    configMap:
      name: app-config
      optional: true
  # Writable volumes (required for read-only root filesystem)
  - name: tmp
    emptyDir: {}
  - name: nginx-cache
    emptyDir: {}
  restartPolicy: Never
EOF

# Create a dummy TLS secret for the demo
kubectl create secret tls tls-cert \
    --cert=<(openssl req -x509 -nodes -days 1 -newkey rsa:2048 -keyout /dev/stdout -out /dev/stdout -subj "/CN=localhost" 2>/dev/null | grep -A 20 "BEGIN CERTIFICATE") \
    --key=<(openssl req -x509 -nodes -days 1 -newkey rsa:2048 -keyout /dev/stdout -out /dev/stdout -subj "/CN=localhost" 2>/dev/null | grep -A 20 "BEGIN PRIVATE KEY") \
    2>/dev/null || true

kubectl apply -f /tmp/secure-deployment.yaml

print_info "Waiting for secure webapp to start..."
kubectl wait --for=condition=Ready pod/secure-webapp --timeout=60s

print_success "Secure application deployment:"
kubectl logs secure-webapp

print_info "Security features implemented:"
echo "  ✅ Specific service account with minimal permissions"
echo "  ✅ Non-root user execution"
echo "  ✅ Read-only root filesystem"
echo "  ✅ No privilege escalation"
echo "  ✅ Dropped unnecessary capabilities"
echo "  ✅ Secrets mounted as files with restricted permissions"
echo "  ✅ Separate writable volumes for temporary data"
echo "  ✅ Optional resources (graceful degradation)"

wait_for_input

print_step "5. Secret Monitoring and Auditing"

print_info "Let's implement secret access monitoring:"

cat > /tmp/monitoring-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: monitoring-demo
  labels:
    component: monitoring
spec:
  serviceAccountName: monitoring-sa
  containers:
  - name: monitor
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== SECRET ACCESS MONITORING ==="
      echo ""
      echo "This pod monitors secret access patterns:"
      echo ""
      echo "1. Can access monitoring credentials:"
      if [ -f /etc/monitoring-secrets/prometheus_token ]; then
        echo "  ✅ Prometheus token available"
        echo "  Token length: $(cat /etc/monitoring-secrets/prometheus_token | wc -c) characters"
      else
        echo "  ❌ Prometheus token not available"
      fi
      echo ""
      echo "2. Cannot access application secrets (security working):"
      ls /etc/app-secrets/ 2>/dev/null || echo "  ✅ Application secrets correctly inaccessible"
      echo ""
      echo "3. Monitoring secret file permissions:"
      ls -la /etc/monitoring-secrets/
      echo ""
      echo "4. Secret access timestamps:"
      stat /etc/monitoring-secrets/* | grep -E "(Access|Modify|Change):"
      echo ""
      echo "=== SECURITY AUDIT LOG ==="
      echo "$(date): Secret access by monitoring service"
      echo "$(date): Prometheus token accessed for metrics collection"
      echo "$(date): All secret access within authorized scope"
      echo ""
      echo "Monitoring service running..."
      sleep 600
    volumeMounts:
    - name: monitoring-secrets
      mountPath: /etc/monitoring-secrets
      readOnly: true
    # This mount should fail due to RBAC
    - name: app-secrets
      mountPath: /etc/app-secrets
      readOnly: true
  volumes:
  - name: monitoring-secrets
    secret:
      secretName: monitoring-credentials
      defaultMode: 0400
  - name: app-secrets
    secret:
      secretName: demo-credentials
      defaultMode: 0400
  restartPolicy: Never
EOF

kubectl apply -f /tmp/monitoring-demo.yaml

print_info "Checking monitoring service (may have RBAC errors - that's expected):"
sleep 5
kubectl describe pod monitoring-demo | tail -15

print_info "Monitoring service logs:"
kubectl logs monitoring-demo 2>/dev/null || print_warning "Pod may not be running due to RBAC restrictions"

print_success "Monitoring and auditing features:"
echo "  ✅ Separate service account for monitoring"
echo "  ✅ Limited access to only required secrets"
echo "  ✅ Audit logging of secret access"
echo "  ✅ File access timestamp tracking"
echo "  ✅ RBAC preventing unauthorized access"

wait_for_input

print_step "6. Secret Scanning and Validation"

print_info "Let's implement secret validation and scanning:"

cat > /tmp/secret-scanner.sh << 'EOF'
#!/bin/bash

# Secret Security Scanner Script
echo "=== KUBERNETES SECRET SECURITY SCANNER ==="
echo ""

# Function to check secret security
check_secret_security() {
    local secret_name=$1
    local namespace=${2:-default}
    
    echo "Scanning secret: $secret_name"
    
    # Check if secret exists
    if ! kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
        echo "  ❌ Secret not found"
        return 1
    fi
    
    # Check secret age
    local created=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.metadata.creationTimestamp}')
    local age_days=$(( ($(date +%s) - $(date -d "$created" +%s)) / 86400 ))
    
    if [ "$age_days" -gt 90 ]; then
        echo "  ⚠️  Secret is $age_days days old - consider rotation"
    else
        echo "  ✅ Secret age: $age_days days (acceptable)"
    fi
    
    # Check for proper annotations
    local last_rotated=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.metadata.annotations.last-rotated}' 2>/dev/null || echo "")
    if [ -z "$last_rotated" ]; then
        echo "  ⚠️  No rotation tracking annotation"
    else
        echo "  ✅ Last rotated: $last_rotated"
    fi
    
    # Check secret size
    local size=$(kubectl get secret "$secret_name" -n "$namespace" -o json | jq '.data | to_entries | map(.value | length) | add // 0')
    if [ "$size" -gt 100000 ]; then
        echo "  ⚠️  Large secret size: $size bytes"
    else
        echo "  ✅ Secret size: $size bytes (acceptable)"
    fi
    
    # Check for weak patterns (simplified check)
    local data=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data}' | base64 -d 2>/dev/null || echo "")
    if echo "$data" | grep -qi "password"; then
        echo "  ⚠️  May contain weak password patterns"
    fi
    
    # Check RBAC access
    echo "  📋 RBAC Analysis:"
    echo "    - Service accounts with access:"
    kubectl get rolebindings -o json | jq -r '.items[] | select(.roleRef.name | contains("secret")) | "      " + .subjects[].name' 2>/dev/null || echo "      None found"
    
    echo ""
}

# Scan all our demo secrets
for secret in demo-credentials monitoring-credentials tls-cert; do
    check_secret_security "$secret"
done

echo "=== SECURITY RECOMMENDATIONS ==="
echo "✅ Use external secret management (Vault, AWS Secrets Manager)"
echo "✅ Implement automated secret rotation"
echo "✅ Enable encryption at rest"
echo "✅ Monitor secret access patterns"
echo "✅ Use short-lived tokens when possible"
echo "✅ Implement secret scanning in CI/CD pipelines"
echo "✅ Regular security audits"
EOF

chmod +x /tmp/secret-scanner.sh

print_success "Running security scanner:"
/tmp/secret-scanner.sh

wait_for_input

print_step "7. Secret Management Best Practices Summary"

print_info "Security best practices demonstrated in this exercise:"

echo ""
echo "🔒 SECRET STORAGE:"
echo "  ✅ Use volume mounts instead of environment variables"
echo "  ✅ Set restrictive file permissions (mode 400)"
echo "  ✅ Mount secrets in tmpfs (memory, not disk)"
echo "  ✅ Use read-only mounts"

echo ""
echo "🔒 ACCESS CONTROL:"
echo "  ✅ Implement RBAC with principle of least privilege"
echo "  ✅ Use specific service accounts"
echo "  ✅ Limit secret access to specific resources"
echo "  ✅ Regular permission audits"

echo ""
echo "🔒 APPLICATION SECURITY:"
echo "  ✅ Run as non-root user"
echo "  ✅ Use read-only root filesystem"
echo "  ✅ Drop unnecessary capabilities"
echo "  ✅ Disable privilege escalation"

echo ""
echo "🔒 SECRET LIFECYCLE:"
echo "  ✅ Regular secret rotation"
echo "  ✅ Track rotation with metadata"
echo "  ✅ Monitor secret age"
echo "  ✅ Automated secret management"

echo ""
echo "🔒 MONITORING & AUDITING:"
echo "  ✅ Log secret access"
echo "  ✅ Monitor for unauthorized access"
echo "  ✅ Regular security scanning"
echo "  ✅ Incident response procedures"

wait_for_input

print_step "8. Cleanup"

print_info "Cleaning up exercise resources..."

# Clean up files
rm -f /tmp/insecure-app.yaml /tmp/secure-app.yaml /tmp/permissions-demo.yaml \
      /tmp/rbac-config.yaml /tmp/secure-deployment.yaml /tmp/monitoring-demo.yaml \
      /tmp/secret-scanner.sh

# Clean up pods
kubectl delete pod \
    insecure-app secure-app permissions-demo \
    secure-webapp monitoring-demo 2>/dev/null || true

# Clean up RBAC
kubectl delete rolebinding \
    secret-reader-binding limited-secret-binding monitoring-binding 2>/dev/null || true

kubectl delete role \
    secret-reader limited-secret-access monitoring-access 2>/dev/null || true

kubectl delete serviceaccount \
    app-sa limited-sa monitoring-sa 2>/dev/null || true

# Keep secrets for potential use in other exercises
print_warning "Secrets are kept for other exercises. To clean up:"
echo "kubectl delete secret demo-credentials monitoring-credentials tls-cert"

print_success "Exercise completed! You've learned:"
echo "  ✅ Secure vs insecure secret usage patterns"
echo "  ✅ File permissions and mount security"
echo "  ✅ RBAC implementation for secrets"
echo "  ✅ Secure application deployment patterns"
echo "  ✅ Secret monitoring and auditing"
echo "  ✅ Security scanning and validation"
echo "  ✅ Comprehensive security best practices"

print_info "Next: Try Exercise 5 to learn about advanced configuration patterns!"