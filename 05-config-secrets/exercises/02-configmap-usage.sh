#!/bin/bash

# Exercise 2: ConfigMap Usage Patterns
# This exercise demonstrates different ways to consume ConfigMaps in pods

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

wait_for_input() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

print_header "Exercise 2: ConfigMap Usage Patterns"

print_info "This exercise will show you different ways to consume ConfigMaps in pods"
print_info "and help you understand when to use each approach."

wait_for_input

# Cleanup any existing resources
print_info "Cleaning up any existing demo resources..."
kubectl delete pod --ignore-not-found=true \
    env-demo volume-demo selective-env selective-volume \
    webapp-demo update-demo 2>/dev/null || true

kubectl delete configmap --ignore-not-found=true \
    app-config web-config database-config logging-config \
    feature-flags 2>/dev/null || true

print_step "1. Setting Up Demo ConfigMaps"

print_info "Creating various ConfigMaps for our demonstrations..."

# Application configuration
kubectl create configmap app-config \
    --from-literal=app_name="My Web Application" \
    --from-literal=app_version="1.2.3" \
    --from-literal=environment="development" \
    --from-literal=debug_enabled="true" \
    --from-literal=max_connections="100" \
    --from-literal=timeout_seconds="30"

# Database configuration
kubectl create configmap database-config \
    --from-literal=host="postgres.example.com" \
    --from-literal=port="5432" \
    --from-literal=database="myapp" \
    --from-literal=pool_size="10" \
    --from-literal=ssl_mode="require"

# Feature flags
kubectl create configmap feature-flags \
    --from-literal=new_ui="true" \
    --from-literal=analytics="false" \
    --from-literal=payment_v2="true" \
    --from-literal=dark_mode="false"

# Complex configuration files
cat > /tmp/web-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  nginx.conf: |
    server {
        listen 8080;
        server_name _;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        
        location / {
            proxy_pass http://backend:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /health {
            return 200 "OK";
            add_header Content-Type text/plain;
        }
    }
  
  application.properties: |
    # Server Configuration
    server.port=3000
    server.host=0.0.0.0
    
    # Database Configuration
    database.url=jdbc:postgresql://${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}
    database.pool.size=${DATABASE_POOL_SIZE:10}
    
    # Logging Configuration
    logging.level=${LOG_LEVEL:INFO}
    logging.format=json
    
    # Feature Flags
    feature.new_ui=${FEATURE_NEW_UI:false}
    feature.analytics=${FEATURE_ANALYTICS:true}
  
  startup.sh: |
    #!/bin/bash
    set -e
    
    echo "Starting application: $APP_NAME"
    echo "Version: $APP_VERSION"
    echo "Environment: $ENVIRONMENT"
    
    # Validate required environment variables
    if [ -z "$DATABASE_HOST" ]; then
        echo "ERROR: DATABASE_HOST not set"
        exit 1
    fi
    
    # Wait for database
    echo "Waiting for database at $DATABASE_HOST:$DATABASE_PORT..."
    timeout 30 bash -c 'until nc -z $DATABASE_HOST $DATABASE_PORT; do sleep 1; done'
    
    echo "Database is ready!"
    echo "Starting application..."
    exec node app.js
EOF

kubectl apply -f /tmp/web-config.yaml

print_success "ConfigMaps created! Let's see what we have:"
kubectl get configmaps

wait_for_input

print_step "2. Using ConfigMaps as Environment Variables"

print_info "Let's create a pod that uses ConfigMaps as environment variables:"

cat > /tmp/env-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: env-demo
  labels:
    app: config-demo
    type: env-vars
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== APPLICATION ENVIRONMENT ==="
      echo "App Name: $APP_NAME"
      echo "Version: $APP_VERSION"
      echo "Environment: $ENVIRONMENT"
      echo "Debug: $DEBUG_ENABLED"
      echo ""
      echo "=== DATABASE CONFIGURATION ==="
      echo "Host: $DATABASE_HOST"
      echo "Port: $DATABASE_PORT"
      echo "Database: $DATABASE_NAME"
      echo "Pool Size: $DATABASE_POOL_SIZE"
      echo ""
      echo "=== FEATURE FLAGS ==="
      env | grep "FEATURE_" | sort
      echo ""
      echo "=== ALL CONFIG VARIABLES ==="
      env | grep -E "(APP_|DATABASE_|FEATURE_)" | sort
      echo ""
      echo "Sleeping for demonstration..."
      sleep 600
    env:
    # Individual environment variables from specific ConfigMaps
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: app_name
    - name: APP_VERSION
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: app_version
    - name: ENVIRONMENT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: environment
    - name: DEBUG_ENABLED
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: debug_enabled
    envFrom:
    # Load all keys from ConfigMaps with prefixes
    - configMapRef:
        name: database-config
        prefix: "DATABASE_"
    - configMapRef:
        name: feature-flags
        prefix: "FEATURE_"
  restartPolicy: Never
EOF

kubectl apply -f /tmp/env-demo.yaml

print_info "Waiting for pod to start..."
kubectl wait --for=condition=Ready pod/env-demo --timeout=60s

print_success "Pod started! Let's see the environment variables:"
kubectl logs env-demo

print_info "Key points about environment variables:"
echo "  ✅ Simple to use and widely supported"
echo "  ✅ Perfect for key-value configuration"
echo "  ✅ Can use prefixes to avoid naming conflicts"
echo "  ❌ Limited to string values"
echo "  ❌ Can be visible in process lists"
echo "  ❌ Require pod restart to update"

wait_for_input

print_step "3. Using ConfigMaps as Volume Mounts"

print_info "Now let's see how to mount ConfigMaps as files:"

cat > /tmp/volume-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: volume-demo
  labels:
    app: config-demo
    type: volumes
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== MOUNTED CONFIGURATION FILES ==="
      echo ""
      echo "Files in /etc/config:"
      ls -la /etc/config/
      echo ""
      echo "=== nginx.conf ==="
      cat /etc/config/nginx.conf
      echo ""
      echo "=== application.properties ==="
      cat /etc/config/application.properties
      echo ""
      echo "=== startup.sh permissions ==="
      ls -la /etc/config/startup.sh
      echo ""
      echo "=== Simple configuration values ==="
      echo "App config files:"
      ls -la /etc/app-config/
      echo ""
      for file in /etc/app-config/*; do
        echo "$(basename $file): $(cat $file)"
      done
      echo ""
      echo "Sleeping for demonstration..."
      sleep 600
    volumeMounts:
    # Mount complex configuration files
    - name: web-config
      mountPath: /etc/config
      readOnly: true
    # Mount simple key-value pairs as individual files
    - name: app-config
      mountPath: /etc/app-config
      readOnly: true
  volumes:
  - name: web-config
    configMap:
      name: web-config
      # Set executable permissions for shell scripts
      defaultMode: 0755
      items:
      - key: nginx.conf
        path: nginx.conf
      - key: application.properties
        path: application.properties
      - key: startup.sh
        path: startup.sh
        mode: 0755
  - name: app-config
    configMap:
      name: app-config
      # Each key becomes a file
  restartPolicy: Never
EOF

kubectl apply -f /tmp/volume-demo.yaml

print_info "Waiting for pod to start..."
kubectl wait --for=condition=Ready pod/volume-demo --timeout=60s

print_success "Pod started! Let's see the mounted files:"
kubectl logs volume-demo

print_info "Key points about volume mounts:"
echo "  ✅ Perfect for configuration files"
echo "  ✅ Support for file permissions"
echo "  ✅ Can be updated without pod restart (with some limitations)"
echo "  ✅ More secure for sensitive configuration"
echo "  ❌ Requires application to read from files"
echo "  ❌ More complex setup"

wait_for_input

print_step "4. Selective Configuration Loading"

print_info "You can also select specific keys from ConfigMaps:"

cat > /tmp/selective-env.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: selective-env
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh", "-c", "env | grep -E '(APP_|SELECT_)' | sort; sleep 600"]
    env:
    # Select only specific keys we need
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: app_name
    - name: SELECT_DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: database-config
          key: host
    - name: SELECT_NEW_UI_FLAG
      valueFrom:
        configMapKeyRef:
          name: feature-flags
          key: new_ui
  restartPolicy: Never
EOF

cat > /tmp/selective-volume.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: selective-volume
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh", "-c", "ls -la /etc/config/; cat /etc/config/*; sleep 600"]
    volumeMounts:
    - name: selected-config
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: selected-config
    configMap:
      name: web-config
      # Only mount specific files
      items:
      - key: nginx.conf
        path: nginx.conf
      - key: startup.sh
        path: start.sh  # Rename the file
        mode: 0755
  restartPolicy: Never
EOF

kubectl apply -f /tmp/selective-env.yaml
kubectl apply -f /tmp/selective-volume.yaml

print_info "Waiting for pods to start..."
kubectl wait --for=condition=Ready pod/selective-env --timeout=60s
kubectl wait --for=condition=Ready pod/selective-volume --timeout=60s

print_success "Selective environment variables:"
kubectl logs selective-env

print_success "Selective volume mounts:"
kubectl logs selective-volume

print_info "Benefits of selective loading:"
echo "  ✅ Reduces environment variable clutter"
echo "  ✅ Only loads configuration that's actually needed"
echo "  ✅ Can rename files during mounting"
echo "  ✅ Better security (principle of least access)"

wait_for_input

print_step "5. Real-World Application Example"

print_info "Let's create a more realistic web application example:"

cat > /tmp/webapp-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: webapp-demo
  labels:
    app: webapp
    component: backend
spec:
  containers:
  - name: webapp
    image: nginx:alpine
    ports:
    - containerPort: 8080
    env:
    # Application-level configuration
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: app_name
    - name: APP_VERSION
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: app_version
    - name: ENVIRONMENT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: environment
    # Database configuration with prefixes
    envFrom:
    - configMapRef:
        name: database-config
        prefix: "DATABASE_"
    - configMapRef:
        name: feature-flags
        prefix: "FEATURE_"
    volumeMounts:
    # Mount nginx configuration
    - name: nginx-config
      mountPath: /etc/nginx/conf.d/default.conf
      subPath: nginx.conf
      readOnly: true
    # Mount application properties
    - name: app-properties
      mountPath: /etc/app/application.properties
      subPath: application.properties
      readOnly: true
    # Mount startup script
    - name: startup-script
      mountPath: /usr/local/bin/startup.sh
      subPath: startup.sh
      mode: 0755
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Starting $APP_NAME version $APP_VERSION"
      echo "Environment: $ENVIRONMENT"
      echo ""
      echo "Configuration loaded:"
      echo "  - Nginx config: /etc/nginx/conf.d/default.conf"
      echo "  - App properties: /etc/app/application.properties"
      echo "  - Startup script: /usr/local/bin/startup.sh"
      echo ""
      echo "Database configuration:"
      env | grep DATABASE_ | sort
      echo ""
      echo "Feature flags:"
      env | grep FEATURE_ | sort
      echo ""
      echo "Starting nginx..."
      nginx -g 'daemon off;' &
      nginx_pid=$!
      
      echo "Web server is running on port 8080"
      echo "Nginx PID: $nginx_pid"
      
      # Keep the container running
      wait $nginx_pid
  volumes:
  - name: nginx-config
    configMap:
      name: web-config
  - name: app-properties
    configMap:
      name: web-config
  - name: startup-script
    configMap:
      name: web-config
  restartPolicy: Never
EOF

kubectl apply -f /tmp/webapp-demo.yaml

print_info "Waiting for web application to start..."
kubectl wait --for=condition=Ready pod/webapp-demo --timeout=60s

print_success "Web application started! Let's see the logs:"
kubectl logs webapp-demo --tail=20

print_info "Let's test the web server:"
kubectl exec webapp-demo -- wget -qO- localhost:8080/health

print_success "The application successfully combines multiple configuration approaches!"

wait_for_input

print_step "6. Configuration Updates and Hot Reloading"

print_info "Let's see what happens when we update a ConfigMap:"

print_info "Current app version:"
kubectl get configmap app-config -o jsonpath='{.data.app_version}'
echo ""

print_info "Current nginx configuration (first few lines):"
kubectl get configmap web-config -o jsonpath='{.data.nginx\.conf}' | head -5

print_info "Updating the ConfigMaps..."

# Update app version
kubectl patch configmap app-config -p '{"data":{"app_version":"1.2.4"}}'

# Update nginx config to add a new location
cat > /tmp/updated-nginx.conf << 'EOF'
server {
    listen 8080;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    location / {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /health {
        return 200 "OK";
        add_header Content-Type text/plain;
    }
    
    # NEW: API documentation endpoint
    location /docs {
        return 200 "API Documentation - Version 1.2.4";
        add_header Content-Type text/plain;
    }
}
EOF

kubectl patch configmap web-config -p "{\"data\":{\"nginx.conf\":\"$(cat /tmp/updated-nginx.conf | sed 's/"/\\"/g' | tr '\n' '\\n')\"}}"

print_success "ConfigMaps updated!"

print_info "Updated app version:"
kubectl get configmap app-config -o jsonpath='{.data.app_version}'
echo ""

wait_for_input

print_info "Checking if changes are reflected in the pod:"

echo "Environment variable (requires restart):"
kubectl exec webapp-demo -- env | grep APP_VERSION

echo ""
echo "Mounted file (should update automatically):"
kubectl exec webapp-demo -- head -10 /etc/nginx/conf.d/default.conf

print_info "Let's test the new endpoint:"
if kubectl exec webapp-demo -- wget -qO- localhost:8080/docs 2>/dev/null; then
    echo ""
    print_success "New endpoint works! File-based config updated automatically."
else
    print_warning "New endpoint not working yet. nginx might need to reload config."
    print_info "In a real application, you'd implement config reloading."
fi

wait_for_input

print_step "7. Configuration Validation and Error Handling"

print_info "Let's see what happens with configuration errors:"

cat > /tmp/broken-config-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-config
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh", "-c", "echo 'App started'; sleep 600"]
    env:
    # This will cause an error - key doesn't exist
    - name: MISSING_CONFIG
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: nonexistent_key
    # This will cause an error - ConfigMap doesn't exist
    - name: ANOTHER_MISSING
      valueFrom:
        configMapKeyRef:
          name: nonexistent-configmap
          key: some_key
  restartPolicy: Never
EOF

kubectl apply -f /tmp/broken-config-pod.yaml

print_info "Checking pod status..."
sleep 3
kubectl get pod broken-config

print_info "Pod events (showing configuration errors):"
kubectl describe pod broken-config | tail -15

print_warning "Important lessons:"
echo "  ❌ Missing ConfigMap keys cause pod startup failures"
echo "  ❌ Missing ConfigMaps cause pod startup failures"
echo "  ✅ Always validate ConfigMap keys exist"
echo "  ✅ Use optional keys when appropriate"
echo "  ✅ Implement proper error handling"

kubectl delete pod broken-config

wait_for_input

print_step "8. Best Practices Summary"

print_info "Configuration best practices demonstrated:"

echo ""
echo "✅ Use Environment Variables For:"
echo "   • Simple key-value configuration"
echo "   • Values that rarely change"
echo "   • Configuration that applications expect as env vars"

echo ""
echo "✅ Use Volume Mounts For:"
echo "   • Configuration files"
echo "   • Large or complex configuration"
echo "   • Configuration that needs to be updated without restart"
echo "   • Multiple related configuration files"

echo ""
echo "✅ General Best Practices:"
echo "   • Use descriptive names for ConfigMaps and keys"
echo "   • Group related configuration together"
echo "   • Use prefixes to avoid naming conflicts"
echo "   • Validate configuration exists before using"
echo "   • Document configuration requirements"
echo "   • Use default values where appropriate"

wait_for_input

print_step "9. Cleanup"

print_info "Cleaning up exercise resources..."

# Clean up files
rm -f /tmp/web-config.yaml /tmp/env-demo.yaml /tmp/volume-demo.yaml \
      /tmp/selective-env.yaml /tmp/selective-volume.yaml /tmp/webapp-demo.yaml \
      /tmp/broken-config-pod.yaml /tmp/updated-nginx.conf

# Clean up pods
kubectl delete pod \
    env-demo volume-demo selective-env selective-volume \
    webapp-demo 2>/dev/null || true

# Clean up ConfigMaps
kubectl delete configmap \
    app-config web-config database-config feature-flags 2>/dev/null || true

print_success "Exercise completed! You've learned:"
echo "  ✅ Using ConfigMaps as environment variables"
echo "  ✅ Using ConfigMaps as volume mounts"
echo "  ✅ Selective configuration loading"
echo "  ✅ Real-world application patterns"
echo "  ✅ Configuration updates and limitations"
echo "  ✅ Error handling and validation"
echo "  ✅ Best practices for each approach"

print_info "Next: Try Exercise 3 to learn about creating and managing secrets!"