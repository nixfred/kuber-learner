#!/bin/bash

# Exercise 1: ConfigMap Creation and Exploration
# This exercise walks through creating ConfigMaps using different methods

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

wait_for_input() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

print_header "Exercise 1: ConfigMap Creation and Exploration"

print_info "This exercise will teach you different ways to create ConfigMaps"
print_info "and how to explore their contents."

wait_for_input

# Cleanup any existing resources
print_info "Cleaning up any existing demo ConfigMaps..."
kubectl delete configmap --ignore-not-found=true \
    exercise-literals exercise-files exercise-yaml \
    nginx-conf database-conf app-settings 2>/dev/null || true

print_step "1. Creating ConfigMaps from Literal Values"

print_info "Let's create a ConfigMap for database configuration:"

kubectl create configmap exercise-literals \
    --from-literal=host=postgres.example.com \
    --from-literal=port=5432 \
    --from-literal=database=myapp \
    --from-literal=ssl_mode=require \
    --from-literal=pool_size=10

print_success "ConfigMap created! Let's examine it:"
kubectl get configmap exercise-literals -o yaml

print_info "Notice how each --from-literal becomes a key-value pair in the data section."

wait_for_input

print_step "2. Creating ConfigMaps from Files"

# Create sample configuration files
print_info "Creating sample configuration files..."

mkdir -p /tmp/exercise-configs

cat > /tmp/exercise-configs/nginx.conf << 'EOF'
server {
    listen 80;
    server_name myapp.example.com;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    
    location / {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /health {
        return 200 "OK\\n";
        add_header Content-Type text/plain;
    }
    
    location /metrics {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

cat > /tmp/exercise-configs/database.properties << 'EOF'
# Database Configuration
database.host=postgres.example.com
database.port=5432
database.name=myapp
database.ssl.mode=require
database.pool.min=5
database.pool.max=20
database.pool.timeout=30000

# Connection retry settings
database.retry.attempts=3
database.retry.delay=1000

# Logging
database.log.statements=false
database.log.slow_queries=true
database.slow_query.threshold=1000
EOF

cat > /tmp/exercise-configs/logging.yaml << 'EOF'
level: INFO
format: json
output: stdout

loggers:
  com.example.myapp: DEBUG
  org.springframework: WARN
  root: INFO

appenders:
  console:
    type: console
    pattern: "%d{ISO8601} [%thread] %-5level %logger{36} - %msg%n"
  
  file:
    type: file
    filename: /var/log/myapp.log
    maxFileSize: 100MB
    maxHistory: 30
EOF

print_info "Files created. Now creating ConfigMap from entire directory:"

kubectl create configmap exercise-files --from-file=/tmp/exercise-configs/

print_success "ConfigMap created from files! Let's examine it:"
kubectl describe configmap exercise-files

print_info "Notice how each file becomes a key with the file content as the value."

wait_for_input

print_step "3. Creating ConfigMaps with Custom Key Names"

print_info "You can also specify custom key names when creating from files:"

kubectl create configmap nginx-conf \
    --from-file=main-config=/tmp/exercise-configs/nginx.conf

kubectl create configmap database-conf \
    --from-file=db-props=/tmp/exercise-configs/database.properties

print_success "ConfigMaps created with custom key names:"
echo "nginx-conf keys:"
kubectl get configmap nginx-conf -o jsonpath='{.data}' | jq 'keys'
echo ""
echo "database-conf keys:"
kubectl get configmap database-conf -o jsonpath='{.data}' | jq 'keys'

wait_for_input

print_step "4. Creating ConfigMaps from YAML Manifests"

print_info "For complex configurations, YAML manifests provide more control:"

cat > /tmp/exercise-configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: exercise-yaml
  labels:
    app: myapp
    component: configuration
    environment: development
data:
  # Application settings
  app.name: "My Application"
  app.version: "1.2.3"
  app.debug: "true"
  
  # Feature flags
  feature.new_ui: "true"
  feature.analytics: "false"
  feature.cache: "true"
  
  # External service URLs
  api.user_service: "http://user-service:8080"
  api.payment_service: "http://payment-service:8080"
  api.notification_service: "http://notification-service:8080"
  
  # Complex configuration file
  application.yaml: |
    server:
      port: 8080
      servlet:
        context-path: /api
    
    spring:
      application:
        name: myapp
      datasource:
        url: jdbc:postgresql://${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}
        username: ${DATABASE_USER}
        password: ${DATABASE_PASSWORD}
      
      jpa:
        hibernate:
          ddl-auto: validate
        show-sql: false
    
    logging:
      level:
        com.example: ${LOG_LEVEL:INFO}
        org.springframework.security: DEBUG
    
    management:
      endpoints:
        web:
          exposure:
            include: health,info,metrics,prometheus
      endpoint:
        health:
          show-details: always
  
  # Startup script
  startup.sh: |
    #!/bin/bash
    set -e
    
    echo "Starting application..."
    echo "Environment: ${ENVIRONMENT:-development}"
    echo "Version: ${APP_VERSION:-unknown}"
    
    # Wait for database
    until pg_isready -h $DATABASE_HOST -p $DATABASE_PORT -U $DATABASE_USER; do
      echo "Waiting for database..."
      sleep 2
    done
    
    echo "Database is ready!"
    
    # Run migrations
    if [ "$RUN_MIGRATIONS" = "true" ]; then
      echo "Running database migrations..."
      java -jar app.jar --spring.profiles.active=migration
    fi
    
    echo "Starting main application..."
    exec java -jar app.jar
EOF

kubectl apply -f /tmp/exercise-configmap.yaml

print_success "YAML-based ConfigMap created! Let's examine its structure:"
kubectl get configmap exercise-yaml -o yaml

wait_for_input

print_step "5. Exploring ConfigMap Contents"

print_info "Let's explore different ways to view ConfigMap contents:"

echo "1. List all ConfigMaps:"
kubectl get configmaps

echo ""
echo "2. Get specific keys from a ConfigMap:"
kubectl get configmap exercise-literals -o jsonpath='{.data.host}'
echo ""

echo "3. Get all keys from a ConfigMap:"
kubectl get configmap exercise-literals -o jsonpath='{.data}' | jq 'keys'

echo ""
echo "4. Get a specific file-like configuration:"
echo "Database properties:"
kubectl get configmap exercise-files -o jsonpath='{.data.database\.properties}'

echo ""
echo ""
echo "5. Describe ConfigMap for detailed information:"
kubectl describe configmap exercise-yaml

wait_for_input

print_step "6. ConfigMap Size and Limitations"

print_info "Let's understand ConfigMap limitations:"

echo "ConfigMap sizes (in bytes):"
for cm in exercise-literals exercise-files exercise-yaml nginx-conf database-conf; do
    size=$(kubectl get configmap $cm -o jsonpath='{.data}' | wc -c)
    echo "  $cm: $size bytes"
done

print_info "Important limitations to remember:"
echo "  • Maximum size: 1MB per ConfigMap"
echo "  • Keys must be valid filenames (for volume mounts)"
echo "  • Values are always strings"
echo "  • No nested structure (flat key-value pairs)"

wait_for_input

print_step "7. Testing ConfigMap Updates"

print_info "Let's see how to update ConfigMaps:"

echo "Original database port:"
kubectl get configmap exercise-literals -o jsonpath='{.data.port}'
echo ""

print_info "Updating the port using kubectl patch:"
kubectl patch configmap exercise-literals -p '{"data":{"port":"5433"}}'

echo "Updated database port:"
kubectl get configmap exercise-literals -o jsonpath='{.data.port}'
echo ""

print_info "You can also edit ConfigMaps directly:"
echo "kubectl edit configmap exercise-literals"

wait_for_input

print_step "8. ConfigMap Best Practices Demonstrated"

print_info "Let's create a ConfigMap following best practices:"

cat > /tmp/best-practices-configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
  labels:
    app: myapp
    component: config
    version: "1.0"
  annotations:
    description: "Application configuration for myapp"
    last-updated: "2024-01-15"
    owner: "backend-team"
data:
  # Use descriptive key names
  database_connection_pool_size: "10"
  api_request_timeout_seconds: "30"
  log_level: "INFO"
  
  # Group related configurations with prefixes
  redis_host: "redis-cluster.example.com"
  redis_port: "6379"
  redis_timeout: "5000"
  
  # Use environment variable placeholders for dynamic values
  app_config.yaml: |
    server:
      port: ${SERVER_PORT:8080}
      host: ${SERVER_HOST:0.0.0.0}
    
    database:
      host: ${DATABASE_HOST}
      port: ${DATABASE_PORT:5432}
      name: ${DATABASE_NAME}
    
    features:
      new_ui: ${FEATURE_NEW_UI:false}
      analytics: ${FEATURE_ANALYTICS:true}
EOF

kubectl apply -f /tmp/best-practices-configmap.yaml

print_success "Best practices ConfigMap created!"
kubectl describe configmap app-settings

print_info "Best practices demonstrated:"
echo "  ✅ Descriptive metadata (labels, annotations)"
echo "  ✅ Clear, descriptive key names"
echo "  ✅ Logical grouping with prefixes"
echo "  ✅ Environment variable placeholders"
echo "  ✅ Default values for optional settings"

wait_for_input

print_step "9. Cleanup"

print_info "Cleaning up exercise resources..."

# Clean up files
rm -rf /tmp/exercise-configs /tmp/exercise-configmap.yaml /tmp/best-practices-configmap.yaml

# Clean up ConfigMaps
kubectl delete configmap \
    exercise-literals exercise-files exercise-yaml \
    nginx-conf database-conf app-settings

print_success "Exercise completed! You've learned:"
echo "  ✅ Creating ConfigMaps from literals, files, and YAML"
echo "  ✅ Using custom key names"
echo "  ✅ Exploring ConfigMap contents"
echo "  ✅ Understanding ConfigMap limitations"
echo "  ✅ Updating ConfigMaps"
echo "  ✅ ConfigMap best practices"

print_info "Next: Try Exercise 2 to learn about using ConfigMaps in pods!"