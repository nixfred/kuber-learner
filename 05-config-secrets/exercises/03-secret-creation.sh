#!/bin/bash

# Exercise 3: Secret Creation and Management
# This exercise teaches secure secret creation and management practices

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

print_header "Exercise 3: Secret Creation and Management"

print_info "This exercise will teach you how to create and manage secrets securely"
print_info "in Kubernetes, with emphasis on security best practices."

wait_for_input

# Cleanup any existing resources
print_info "Cleaning up any existing demo resources..."
kubectl delete secret --ignore-not-found=true \
    basic-auth database-creds api-keys tls-cert \
    docker-registry-secret file-secrets yaml-secret \
    service-account-token 2>/dev/null || true

print_step "1. Understanding Secret Types"

print_info "Kubernetes supports several built-in secret types:"
echo "  • Opaque: Generic secrets (most common)"
echo "  • kubernetes.io/service-account-token: Service account tokens"
echo "  • kubernetes.io/dockercfg: Docker registry credentials (legacy)"
echo "  • kubernetes.io/dockerconfigjson: Docker registry credentials"
echo "  • kubernetes.io/basic-auth: Basic authentication"
echo "  • kubernetes.io/ssh-auth: SSH authentication"
echo "  • kubernetes.io/tls: TLS certificates"

print_info "Let's create examples of each type..."

wait_for_input

print_step "2. Creating Generic (Opaque) Secrets"

print_info "Generic secrets are the most common type for application secrets:"

# Create basic database credentials
kubectl create secret generic database-creds \
    --from-literal=username=postgres \
    --from-literal=password=supersecret123 \
    --from-literal=database=myapp \
    --from-literal=host=postgres.example.com \
    --from-literal=port=5432

print_success "Database credentials secret created!"
kubectl get secret database-creds

print_info "Let's examine the secret structure (safely):"
kubectl describe secret database-creds

print_warning "Notice that 'kubectl describe' doesn't show the actual secret values."

wait_for_input

print_step "3. Creating API Key Secrets"

print_info "For API keys and tokens, use descriptive names:"

kubectl create secret generic api-keys \
    --from-literal=stripe_api_key=sk_test_1234567890abcdef \
    --from-literal=sendgrid_api_key=SG.abcdef123456 \
    --from-literal=github_token=ghp_abcdef1234567890 \
    --from-literal=jwt_secret=ultra_secure_jwt_signing_key_2024

print_success "API keys secret created!"
kubectl describe secret api-keys

wait_for_input

print_step "4. Creating Secrets from Files"

print_info "Creating secrets from files is more secure than command line:"

# Create temporary directory for credential files
mkdir -p /tmp/secret-files

# Create credential files with restricted permissions
umask 077  # Ensure files are created with 600 permissions

cat > /tmp/secret-files/username << 'EOF'
admin
EOF

cat > /tmp/secret-files/password << 'EOF'
mega_secure_password_2024!
EOF

cat > /tmp/secret-files/config.json << 'EOF'
{
  "database": {
    "host": "secure-db.company.internal",
    "port": 5432,
    "ssl": true,
    "connection_timeout": 30
  },
  "redis": {
    "host": "redis-cluster.company.internal",
    "port": 6379,
    "password": "redis_secret_pass"
  },
  "monitoring": {
    "prometheus_url": "https://prometheus.company.internal",
    "api_key": "prom_api_key_12345"
  }
}
EOF

# Show file permissions
print_info "File permissions (should be 600 for security):"
ls -la /tmp/secret-files/

# Create secret from files
kubectl create secret generic file-secrets --from-file=/tmp/secret-files/

# Immediately clean up the files
rm -rf /tmp/secret-files

print_success "File-based secret created and source files securely deleted!"
kubectl describe secret file-secrets

print_info "Best practices demonstrated:"
echo "  ✅ Created files with restricted permissions (600)"
echo "  ✅ Immediately deleted source files after secret creation"
echo "  ✅ Used structured data (JSON) for complex configuration"

wait_for_input

print_step "5. Creating TLS Secrets"

print_info "TLS secrets are used for HTTPS certificates:"

# Generate a self-signed certificate for demonstration
print_info "Generating self-signed certificate for demo..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/tls.key \
    -out /tmp/tls.crt \
    -subj "/CN=myapp.example.com/O=MyCompany/C=US" \
    2>/dev/null

# Create TLS secret
kubectl create secret tls tls-cert \
    --cert=/tmp/tls.crt \
    --key=/tmp/tls.key

# Clean up certificate files
rm -f /tmp/tls.key /tmp/tls.crt

print_success "TLS secret created!"
kubectl describe secret tls-cert

print_info "TLS secrets automatically have 'tls.crt' and 'tls.key' keys."

wait_for_input

print_step "6. Creating Docker Registry Secrets"

print_info "For private Docker registries:"

kubectl create secret docker-registry docker-registry-secret \
    --docker-server=registry.company.com \
    --docker-username=deploy-user \
    --docker-password=registry_password_123 \
    --docker-email=deploy@company.com

print_success "Docker registry secret created!"
kubectl describe secret docker-registry-secret

print_info "This secret can be used in pod specifications for pulling private images."

wait_for_input

print_step "7. Creating Secrets from YAML (Advanced)"

print_info "For complex secrets, YAML manifests provide more control:"

# Create a comprehensive secret with multiple data types
cat > /tmp/comprehensive-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: yaml-secret
  labels:
    app: myapp
    component: backend
    environment: production
  annotations:
    description: "Comprehensive application secrets"
    last-rotated: "2024-01-15"
    rotation-schedule: "quarterly"
type: Opaque
data:
  # Database credentials (base64 encoded)
  database-username: YWRtaW4=  # admin
  database-password: bWVnYV9zZWN1cmVfcGFzc3dvcmRfMjAyNCE=  # mega_secure_password_2024!
  
  # API keys (base64 encoded)
  stripe-api-key: c2tfdGVzdF8xMjM0NTY3ODkwYWJjZGVm  # sk_test_1234567890abcdef
  sendgrid-api-key: U0cuYWJjZGVmMTIzNDU2  # SG.abcdef123456
  
  # JWT configuration (base64 encoded)
  jwt-secret: dWx0cmFfc2VjdXJlX2p3dF9zaWduaW5nX2tleV8yMDI0  # ultra_secure_jwt_signing_key_2024
  
  # Configuration file (base64 encoded JSON)
  app-config.json: ewogICJkYXRhYmFzZSI6IHsKICAgICJob3N0IjogInNlY3VyZS1kYi5jb21wYW55LmludGVybmFsIiwKICAgICJwb3J0IjogNTQzMiwKICAgICJzc2wiOiB0cnVlCiAgfSwKICAicmVkaXMiOiB7CiAgICAiaG9zdCI6ICJyZWRpcy1jbHVzdGVyLmNvbXBhbnkuaW50ZXJuYWwiLAogICAgInBvcnQiOiA2Mzc5CiAgfQp9
stringData:
  # You can also use stringData for non-encoded values
  monitoring-url: "https://monitoring.company.internal"
  log-level: "INFO"
  feature-flags: |
    new_ui=true
    analytics=false
    payment_v2=true
    debug_mode=false
EOF

kubectl apply -f /tmp/comprehensive-secret.yaml

print_success "Comprehensive YAML secret created!"
kubectl describe secret yaml-secret

print_info "Key features of YAML secrets:"
echo "  ✅ Support for metadata (labels, annotations)"
echo "  ✅ Mix of 'data' (base64) and 'stringData' (plain text)"
echo "  ✅ Better version control (without sensitive data)"
echo "  ✅ Complex structured data support"

print_warning "Never commit secrets to version control!"

wait_for_input

print_step "8. Understanding Base64 Encoding"

print_info "Let's understand base64 encoding vs encryption:"

echo "Original password: 'mega_secure_password_2024!'"
echo "Base64 encoded: $(echo -n 'mega_secure_password_2024!' | base64)"
echo "Base64 decoded: $(echo 'bWVnYV9zZWN1cmVfcGFzc3dvcmRfMjAyNCE=' | base64 -d)"

print_warning "Important security notes:"
echo "  ❌ Base64 is encoding, NOT encryption"
echo "  ❌ Anyone can decode base64 values"
echo "  ❌ Never rely on base64 for security"
echo "  ✅ Kubernetes encrypts secrets at rest (when configured)"
echo "  ✅ Use RBAC to control secret access"
echo "  ✅ Consider external secret management systems"

wait_for_input

print_step "9. Secret Size and Limitations"

print_info "Let's understand secret limitations:"

# Check sizes of our secrets
echo "Secret sizes (in bytes):"
for secret in database-creds api-keys file-secrets tls-cert docker-registry-secret yaml-secret; do
    size=$(kubectl get secret $secret -o json | jq '.data | to_entries | map(.value | length) | add // 0')
    echo "  $secret: $size bytes"
done

print_info "Secret limitations to remember:"
echo "  • Maximum size: 1MB per secret"
echo "  • etcd has a default limit of 1.5MB per object"
echo "  • Large secrets impact API server performance"
echo "  • Consider external secret storage for large data"

wait_for_input

print_step "10. Secret Validation and Testing"

print_info "Let's validate our secrets are correctly formatted:"

# Test secret accessibility
echo "Testing secret key access:"

echo "Database username: $(kubectl get secret database-creds -o jsonpath='{.data.username}' | base64 -d)"
echo "Database host: $(kubectl get secret database-creds -o jsonpath='{.data.host}' | base64 -d)"

echo ""
echo "TLS certificate subject:"
kubectl get secret tls-cert -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject 2>/dev/null

echo ""
echo "Docker registry server:"
kubectl get secret docker-registry-secret -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq -r '.auths | keys[]'

print_success "All secrets are properly formatted and accessible!"

wait_for_input

print_step "11. Secret Security Best Practices"

print_info "Let's implement security best practices:"

# Create a service account for secret access
kubectl create serviceaccount secret-reader-sa 2>/dev/null || true

# Create a role that can only read specific secrets
cat > /tmp/secret-reader-role.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["database-creds", "api-keys"]  # Only specific secrets
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-binding
subjects:
- kind: ServiceAccount
  name: secret-reader-sa
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f /tmp/secret-reader-role.yaml

print_success "RBAC configured for limited secret access!"

# Test the permissions
print_info "Testing service account permissions:"

echo "Can read database-creds:"
if kubectl auth can-i get secret/database-creds --as=system:serviceaccount:default:secret-reader-sa; then
    echo "  ✅ Allowed"
else
    echo "  ❌ Denied"
fi

echo "Can read api-keys:"
if kubectl auth can-i get secret/api-keys --as=system:serviceaccount:default:secret-reader-sa; then
    echo "  ✅ Allowed"
else
    echo "  ❌ Denied"
fi

echo "Can read tls-cert (should be denied):"
if kubectl auth can-i get secret/tls-cert --as=system:serviceaccount:default:secret-reader-sa; then
    echo "  ❌ Unexpectedly allowed!"
else
    echo "  ✅ Correctly denied"
fi

print_info "Security best practices implemented:"
echo "  ✅ Principle of least privilege (only specific secrets)"
echo "  ✅ Service account-based access"
echo "  ✅ Role-based access control (RBAC)"

wait_for_input

print_step "12. Secret Rotation Strategy"

print_info "Let's demonstrate secret rotation:"

print_info "Current database password:"
kubectl get secret database-creds -o jsonpath='{.data.password}' | base64 -d
echo ""

print_info "Rotating the database password..."

# Create new password
new_password="rotated_password_$(date +%Y%m%d)"

# Update the secret
kubectl patch secret database-creds -p="{\"data\":{\"password\":\"$(echo -n $new_password | base64)\"}}"

print_success "Password rotated!"

print_info "New database password:"
kubectl get secret database-creds -o jsonpath='{.data.password}' | base64 -d
echo ""

# Add rotation metadata
kubectl annotate secret database-creds last-rotated="$(date -Iseconds)" --overwrite

print_info "Rotation metadata added:"
kubectl get secret database-creds -o jsonpath='{.metadata.annotations.last-rotated}'
echo ""

print_info "Secret rotation best practices:"
echo "  ✅ Regular rotation schedule"
echo "  ✅ Automated rotation when possible"
echo "  ✅ Track rotation history with annotations"
echo "  ✅ Test applications after rotation"
echo "  ✅ Coordinate with application restart if needed"

wait_for_input

print_step "13. Secret Troubleshooting"

print_info "Common secret issues and how to debug them:"

# Create a test pod that tries to use a non-existent secret
cat > /tmp/broken-secret-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-secret-pod
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh", "-c", "echo 'Starting...'; sleep 600"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: database-creds
          key: nonexistent_key  # This key doesn't exist
  restartPolicy: Never
EOF

kubectl apply -f /tmp/broken-secret-pod.yaml

print_info "Created pod with invalid secret reference..."
sleep 3

print_info "1. Check pod status:"
kubectl get pod broken-secret-pod

print_info "2. Check pod events:"
kubectl describe pod broken-secret-pod | tail -10

print_info "3. List available secret keys:"
kubectl get secret database-creds -o jsonpath='{.data}' | jq 'keys'

print_info "4. Fix the issue:"
kubectl delete pod broken-secret-pod

print_success "Troubleshooting techniques demonstrated!"

wait_for_input

print_step "14. Cleanup and Security Review"

print_info "Cleaning up exercise resources..."

# Clean up files
rm -f /tmp/comprehensive-secret.yaml /tmp/secret-reader-role.yaml /tmp/broken-secret-pod.yaml

# Clean up RBAC
kubectl delete rolebinding secret-reader-binding 2>/dev/null || true
kubectl delete role secret-reader 2>/dev/null || true
kubectl delete serviceaccount secret-reader-sa 2>/dev/null || true

# List all secrets we created (for review)
print_info "Secrets created in this exercise:"
kubectl get secrets database-creds api-keys file-secrets tls-cert docker-registry-secret yaml-secret

print_warning "In a real environment, you would:"
echo "  • Use external secret management (HashiCorp Vault, AWS Secrets Manager, etc.)"
echo "  • Enable encryption at rest"
echo "  • Implement secret scanning in CI/CD"
echo "  • Use short-lived tokens when possible"
echo "  • Monitor secret access"
echo "  • Implement secret rotation automation"

wait_for_input

print_success "Exercise completed! You've learned:"
echo "  ✅ Different types of Kubernetes secrets"
echo "  ✅ Secure secret creation methods"
echo "  ✅ Understanding base64 encoding vs encryption"
echo "  ✅ Secret size limitations"
echo "  ✅ RBAC for secret access control"
echo "  ✅ Secret rotation strategies"
echo "  ✅ Troubleshooting secret issues"
echo "  ✅ Security best practices"

print_info "Keep the secrets for the next exercises, or clean them up with:"
echo "kubectl delete secret database-creds api-keys file-secrets tls-cert docker-registry-secret yaml-secret"

print_info "Next: Try Exercise 4 to learn about using secrets securely in applications!"