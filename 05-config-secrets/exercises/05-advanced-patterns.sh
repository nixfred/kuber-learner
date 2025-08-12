#!/bin/bash

# Exercise 5: Advanced Configuration Patterns
# This exercise demonstrates real-world configuration management patterns

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

print_header "Exercise 5: Advanced Configuration Patterns"

print_info "This exercise demonstrates real-world configuration management patterns"
print_info "including multi-environment configurations, layered config, hot-reloading,"
print_info "and configuration validation."

wait_for_input

# Cleanup any existing resources
print_info "Cleaning up any existing demo resources..."
kubectl delete pod --ignore-not-found=true \
    dev-app staging-app prod-app \
    layered-config-demo hot-reload-demo \
    validation-demo config-watcher 2>/dev/null || true

kubectl delete configmap --ignore-not-found=true \
    base-config dev-config staging-config prod-config \
    app-base-config app-dev-overlay app-staging-overlay app-prod-overlay \
    nginx-base nginx-dev nginx-prod \
    validation-config reload-config \
    feature-flags-dev feature-flags-prod 2>/dev/null || true

kubectl delete secret --ignore-not-found=true \
    dev-secrets staging-secrets prod-secrets \
    validation-secrets 2>/dev/null || true

print_step "1. Multi-Environment Configuration Pattern"

print_info "Let's implement configuration for different environments:"

# Base configuration (shared across environments)
cat > /tmp/base-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: base-config
  labels:
    component: configuration
    layer: base
data:
  app_name: "My Web Application"
  app_version: "1.2.3"
  log_format: "json"
  health_check_path: "/health"
  metrics_path: "/metrics"
  timeout_seconds: "30"
  
  # Base application configuration
  application.yaml: |
    server:
      shutdown: graceful
      shutdown_timeout: 30s
    
    management:
      endpoints:
        web:
          exposure:
            include: health,info,metrics
      endpoint:
        health:
          show-details: when-authorized
    
    logging:
      pattern:
        console: "%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
      level:
        org.springframework.security: WARN
EOF

# Development environment overlay
cat > /tmp/dev-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: dev-config
  labels:
    component: configuration
    layer: overlay
    environment: development
data:
  environment: "development"
  log_level: "DEBUG"
  debug_enabled: "true"
  database_host: "dev-postgres.company.internal"
  redis_host: "dev-redis.company.internal"
  replicas: "1"
  
  # Development-specific features
  hot_reload: "true"
  sql_logging: "true"
  cors_enabled: "true"
  
  # Development application overrides
  application-dev.yaml: |
    spring:
      datasource:
        url: jdbc:postgresql://dev-postgres.company.internal:5432/myapp_dev
        hikari:
          maximum-pool-size: 5
      
      jpa:
        hibernate:
          ddl-auto: create-drop
        show-sql: true
      
      devtools:
        restart:
          enabled: true
        livereload:
          enabled: true
    
    logging:
      level:
        com.example: DEBUG
        org.hibernate.SQL: DEBUG
        org.hibernate.type.descriptor.sql.BasicBinder: TRACE
EOF

# Staging environment overlay
cat > /tmp/staging-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: staging-config
  labels:
    component: configuration
    layer: overlay
    environment: staging
data:
  environment: "staging"
  log_level: "INFO"
  debug_enabled: "false"
  database_host: "staging-postgres.company.internal"
  redis_host: "staging-redis.company.internal"
  replicas: "2"
  
  # Staging-specific features
  hot_reload: "false"
  sql_logging: "false"
  cors_enabled: "true"
  monitoring_enabled: "true"
  
  # Staging application overrides
  application-staging.yaml: |
    spring:
      datasource:
        url: jdbc:postgresql://staging-postgres.company.internal:5432/myapp_staging
        hikari:
          maximum-pool-size: 10
      
      jpa:
        hibernate:
          ddl-auto: validate
        show-sql: false
    
    logging:
      level:
        com.example: INFO
        org.springframework.web: DEBUG
EOF

# Production environment overlay
cat > /tmp/prod-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prod-config
  labels:
    component: configuration
    layer: overlay
    environment: production
data:
  environment: "production"
  log_level: "WARN"
  debug_enabled: "false"
  database_host: "prod-postgres.company.internal"
  redis_host: "prod-redis-cluster.company.internal"
  replicas: "5"
  
  # Production-specific features
  hot_reload: "false"
  sql_logging: "false"
  cors_enabled: "false"
  monitoring_enabled: "true"
  alerting_enabled: "true"
  
  # Production application overrides
  application-prod.yaml: |
    spring:
      datasource:
        url: jdbc:postgresql://prod-postgres.company.internal:5432/myapp
        hikari:
          maximum-pool-size: 20
          minimum-idle: 5
          connection-timeout: 30000
      
      jpa:
        hibernate:
          ddl-auto: none
        show-sql: false
    
    logging:
      level:
        com.example: WARN
        org.springframework: WARN
        org.hibernate: WARN
EOF

kubectl apply -f /tmp/base-config.yaml
kubectl apply -f /tmp/dev-config.yaml
kubectl apply -f /tmp/staging-config.yaml
kubectl apply -f /tmp/prod-config.yaml

print_success "Multi-environment configurations created!"

# Create environment-specific secrets
kubectl create secret generic dev-secrets \
    --from-literal=database_password=dev_password_123 \
    --from-literal=redis_password=dev_redis_pass \
    --from-literal=api_key=dev_api_key_123

kubectl create secret generic staging-secrets \
    --from-literal=database_password=staging_secure_pass_456 \
    --from-literal=redis_password=staging_redis_secure \
    --from-literal=api_key=staging_api_key_456

kubectl create secret generic prod-secrets \
    --from-literal=database_password=ultra_secure_prod_pass_789 \
    --from-literal=redis_password=prod_redis_ultra_secure \
    --from-literal=api_key=prod_api_key_789

print_info "Examining environment configurations:"
echo "Development environment:"
kubectl get configmap dev-config -o jsonpath='{.data}' | jq -r 'to_entries[] | select(.key | test("^[a-z_]+$")) | "\(.key): \(.value)"' | head -5

echo ""
echo "Production environment:"
kubectl get configmap prod-config -o jsonpath='{.data}' | jq -r 'to_entries[] | select(.key | test("^[a-z_]+$")) | "\(.key): \(.value)"' | head -5

wait_for_input

print_step "2. Deploying Applications with Environment-Specific Configuration"

print_info "Let's deploy the same application to different environments:"

# Development deployment
cat > /tmp/dev-app.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: dev-app
  labels:
    app: myapp
    environment: development
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== DEVELOPMENT ENVIRONMENT ==="
      echo "App: $APP_NAME v$APP_VERSION"
      echo "Environment: $ENVIRONMENT"
      echo "Log Level: $LOG_LEVEL"
      echo "Debug: $DEBUG_ENABLED"
      echo "Database: $DATABASE_HOST"
      echo "Replicas: $REPLICAS"
      echo ""
      echo "=== CONFIGURATION FILES ==="
      echo "Base configuration:"
      cat /etc/config/base/application.yaml | head -10
      echo ""
      echo "Environment-specific configuration:"
      cat /etc/config/env/application-dev.yaml | head -10
      echo ""
      echo "=== FEATURE FLAGS ==="
      echo "Hot Reload: $HOT_RELOAD"
      echo "SQL Logging: $SQL_LOGGING"
      echo "CORS: $CORS_ENABLED"
      echo ""
      echo "Development app running..."
      sleep 600
    env:
    # Base configuration
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: base-config
          key: app_name
    - name: APP_VERSION
      valueFrom:
        configMapKeyRef:
          name: base-config
          key: app_version
    # Environment-specific configuration
    envFrom:
    - configMapRef:
        name: dev-config
    # Secrets
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: dev-secrets
          key: database_password
    volumeMounts:
    - name: base-config
      mountPath: /etc/config/base
    - name: env-config
      mountPath: /etc/config/env
    - name: secrets
      mountPath: /etc/secrets
  volumes:
  - name: base-config
    configMap:
      name: base-config
  - name: env-config
    configMap:
      name: dev-config
  - name: secrets
    secret:
      secretName: dev-secrets
  restartPolicy: Never
EOF

# Production deployment (similar structure, different configs)
cat > /tmp/prod-app.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: prod-app
  labels:
    app: myapp
    environment: production
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== PRODUCTION ENVIRONMENT ==="
      echo "App: $APP_NAME v$APP_VERSION"
      echo "Environment: $ENVIRONMENT"
      echo "Log Level: $LOG_LEVEL"
      echo "Debug: $DEBUG_ENABLED"
      echo "Database: $DATABASE_HOST"
      echo "Replicas: $REPLICAS"
      echo ""
      echo "=== CONFIGURATION FILES ==="
      echo "Base configuration:"
      cat /etc/config/base/application.yaml | head -10
      echo ""
      echo "Environment-specific configuration:"
      cat /etc/config/env/application-prod.yaml | head -10
      echo ""
      echo "=== FEATURE FLAGS ==="
      echo "Hot Reload: $HOT_RELOAD"
      echo "SQL Logging: $SQL_LOGGING"
      echo "CORS: $CORS_ENABLED"
      echo "Monitoring: $MONITORING_ENABLED"
      echo "Alerting: $ALERTING_ENABLED"
      echo ""
      echo "Production app running..."
      sleep 600
    env:
    # Base configuration
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: base-config
          key: app_name
    - name: APP_VERSION
      valueFrom:
        configMapKeyRef:
          name: base-config
          key: app_version
    # Environment-specific configuration
    envFrom:
    - configMapRef:
        name: prod-config
    # Secrets
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: prod-secrets
          key: database_password
    volumeMounts:
    - name: base-config
      mountPath: /etc/config/base
    - name: env-config
      mountPath: /etc/config/env
    - name: secrets
      mountPath: /etc/secrets
  volumes:
  - name: base-config
    configMap:
      name: base-config
  - name: env-config
    configMap:
      name: prod-config
  - name: secrets
    secret:
      secretName: prod-secrets
  restartPolicy: Never
EOF

kubectl apply -f /tmp/dev-app.yaml
kubectl apply -f /tmp/prod-app.yaml

print_info "Waiting for applications to start..."
kubectl wait --for=condition=Ready pod/dev-app --timeout=60s
kubectl wait --for=condition=Ready pod/prod-app --timeout=60s

print_success "Development environment:"
kubectl logs dev-app | head -20

print_success "Production environment:"
kubectl logs prod-app | head -20

print_info "Notice how the same application uses different configurations!"

wait_for_input

print_step "3. Layered Configuration Pattern"

print_info "Let's implement a more sophisticated layered configuration:"

# Application base configuration
cat > /tmp/layered-base.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-base-config
  labels:
    config-layer: base
data:
  # Core application settings
  server_port: "8080"
  server_host: "0.0.0.0"
  shutdown_grace_period: "30s"
  
  # Default feature flags
  feature_user_registration: "true"
  feature_payment_processing: "true"
  feature_admin_panel: "true"
  
  # Base logging configuration
  log_format: "json"
  log_output: "stdout"
  
  # Base monitoring
  metrics_enabled: "true"
  health_check_interval: "30s"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-base
  labels:
    config-layer: base
    component: nginx
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    
    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;
        
        log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for"';
        
        sendfile        on;
        tcp_nopush      on;
        tcp_nodelay     on;
        keepalive_timeout  65;
        types_hash_max_size 2048;
        
        include /etc/nginx/conf.d/*.conf;
    }
EOF

# Development overlay
cat > /tmp/layered-dev.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-dev-overlay
  labels:
    config-layer: overlay
    environment: development
data:
  # Override base settings for development
  log_level: "DEBUG"
  debug_mode: "true"
  
  # Development-specific features
  feature_dev_toolbar: "true"
  feature_auto_reload: "true"
  feature_sql_debugging: "true"
  
  # Development monitoring
  profiling_enabled: "true"
  trace_all_requests: "true"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-dev
  labels:
    config-layer: overlay
    environment: development
    component: nginx
data:
  default.conf: |
    server {
        listen 8080;
        server_name localhost;
        
        # Development: Enable verbose logging
        access_log /var/log/nginx/access.log main;
        error_log /var/log/nginx/error.log debug;
        
        # Development: Allow CORS for local development
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE';
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
        
        location / {
            proxy_pass http://app:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            
            # Development: Disable caching
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }
        
        # Development: Expose debug endpoints
        location /debug {
            proxy_pass http://app:8080/actuator;
            proxy_set_header Host $host;
        }
    }
EOF

# Production overlay
cat > /tmp/layered-prod.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-prod-overlay
  labels:
    config-layer: overlay
    environment: production
data:
  # Override base settings for production
  log_level: "WARN"
  debug_mode: "false"
  
  # Production-specific features
  feature_dev_toolbar: "false"
  feature_auto_reload: "false"
  feature_sql_debugging: "false"
  feature_advanced_analytics: "true"
  
  # Production monitoring
  profiling_enabled: "false"
  trace_all_requests: "false"
  performance_monitoring: "true"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-prod
  labels:
    config-layer: overlay
    environment: production
    component: nginx
data:
  default.conf: |
    server {
        listen 8080;
        server_name myapp.company.com;
        
        # Production: Minimal logging
        access_log /var/log/nginx/access.log main;
        error_log /var/log/nginx/error.log warn;
        
        # Production: Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
        
        # Production: Rate limiting
        limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
        
        location / {
            limit_req zone=api burst=20 nodelay;
            
            proxy_pass http://app:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Production: Enable caching
            proxy_cache_valid 200 302 10m;
            proxy_cache_valid 404 1m;
        }
        
        # Production: Hide debug endpoints
        location /debug {
            return 404;
        }
        
        # Production: Health check endpoint
        location /health {
            proxy_pass http://app:8080/actuator/health;
            access_log off;
        }
    }
EOF

kubectl apply -f /tmp/layered-base.yaml
kubectl apply -f /tmp/layered-dev.yaml
kubectl apply -f /tmp/layered-prod.yaml

print_success "Layered configurations created!"

# Deploy application that uses layered configuration
cat > /tmp/layered-app.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: layered-config-demo
  labels:
    config-pattern: layered
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== LAYERED CONFIGURATION DEMO ==="
      echo ""
      echo "=== BASE CONFIGURATION ==="
      echo "Server Port: $SERVER_PORT"
      echo "Server Host: $SERVER_HOST"
      echo "Metrics Enabled: $METRICS_ENABLED"
      echo ""
      echo "=== ENVIRONMENT OVERLAY ==="
      echo "Environment: development"
      echo "Log Level: $LOG_LEVEL"
      echo "Debug Mode: $DEBUG_MODE"
      echo ""
      echo "=== FEATURE FLAGS (BASE + OVERLAY) ==="
      env | grep "^FEATURE_" | sort
      echo ""
      echo "=== NGINX CONFIGURATION LAYERS ==="
      echo "Base nginx.conf:"
      head -10 /etc/nginx/base/nginx.conf
      echo ""
      echo "Environment-specific default.conf:"
      head -15 /etc/nginx/overlay/default.conf
      echo ""
      echo "Layered configuration loaded successfully!"
      sleep 600
    envFrom:
    # Layer 1: Base configuration
    - configMapRef:
        name: app-base-config
        prefix: ""
    # Layer 2: Environment overlay (overrides base)
    - configMapRef:
        name: app-dev-overlay
        prefix: ""
    volumeMounts:
    # Mount both base and overlay nginx configs
    - name: nginx-base
      mountPath: /etc/nginx/base
    - name: nginx-overlay
      mountPath: /etc/nginx/overlay
  volumes:
  - name: nginx-base
    configMap:
      name: nginx-base
  - name: nginx-overlay
    configMap:
      name: nginx-dev
  restartPolicy: Never
EOF

kubectl apply -f /tmp/layered-app.yaml

print_info "Waiting for layered configuration demo to start..."
kubectl wait --for=condition=Ready pod/layered-config-demo --timeout=60s

print_success "Layered configuration demo:"
kubectl logs layered-config-demo

print_info "Layered configuration benefits:"
echo "  ✅ Base configuration shared across environments"
echo "  ✅ Environment-specific overrides"
echo "  ✅ Clear separation of concerns"
echo "  ✅ Easier configuration management"
echo "  ✅ Reduced duplication"

wait_for_input

print_step "4. Hot-Reloading Configuration"

print_info "Let's implement configuration hot-reloading:"

# Create a configuration that supports hot-reloading
kubectl create configmap reload-config \
    --from-literal=message="Initial configuration" \
    --from-literal=refresh_interval="5" \
    --from-literal=feature_enabled="false"

cat > /tmp/hot-reload-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: hot-reload-demo
  labels:
    pattern: hot-reload
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== HOT-RELOAD CONFIGURATION DEMO ==="
      echo ""
      echo "This demo shows how to implement configuration hot-reloading."
      echo "The application will monitor /etc/config for changes."
      echo ""
      
      # Function to load configuration
      load_config() {
        if [ -f /etc/config/message ]; then
          MESSAGE=$(cat /etc/config/message)
          REFRESH_INTERVAL=$(cat /etc/config/refresh_interval)
          FEATURE_ENABLED=$(cat /etc/config/feature_enabled)
          echo "Configuration loaded:"
          echo "  Message: $MESSAGE"
          echo "  Refresh Interval: ${REFRESH_INTERVAL}s"
          echo "  Feature Enabled: $FEATURE_ENABLED"
          echo ""
        fi
      }
      
      # Load initial configuration
      load_config
      
      # Watch for configuration changes
      echo "Watching for configuration changes..."
      while true; do
        # In a real application, you'd use inotify or similar
        # For demo, we'll just reload periodically
        sleep ${REFRESH_INTERVAL:-5}
        
        # Check if configuration has changed
        load_config
        
        if [ "$FEATURE_ENABLED" = "true" ]; then
          echo "🔥 Feature is ENABLED! Executing special logic..."
        else
          echo "💤 Feature is disabled. Normal operation."
        fi
        
        echo "$(date): $MESSAGE"
        echo "---"
      done
    volumeMounts:
    - name: config
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: config
    configMap:
      name: reload-config
  restartPolicy: Never
EOF

kubectl apply -f /tmp/hot-reload-demo.yaml

print_info "Waiting for hot-reload demo to start..."
kubectl wait --for=condition=Ready pod/hot-reload-demo --timeout=60s

print_info "Initial configuration state:"
kubectl logs hot-reload-demo --tail=10

print_info "Now let's update the configuration while the app is running..."

wait_for_input

# Update the configuration
kubectl patch configmap reload-config -p '{"data":{"message":"Configuration updated via hot-reload!","feature_enabled":"true","refresh_interval":"3"}}'

print_success "Configuration updated! Let's see the hot-reload in action:"
sleep 10
kubectl logs hot-reload-demo --tail=15

print_info "Hot-reloading benefits:"
echo "  ✅ Zero-downtime configuration updates"
echo "  ✅ Faster deployment cycles"
echo "  ✅ Dynamic feature flag control"
echo "  ✅ Improved operational flexibility"

print_warning "Hot-reloading considerations:"
echo "  ⚠️  Not all configuration changes are safe to hot-reload"
echo "  ⚠️  Application must be designed to handle config changes"
echo "  ⚠️  Some changes may require application restart"
echo "  ⚠️  Validation is crucial to prevent broken configurations"

wait_for_input

print_step "5. Configuration Validation and Health Checks"

print_info "Let's implement configuration validation:"

# Create a configuration with validation
cat > /tmp/validation-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: validation-config
  annotations:
    config.kubernetes.io/validation: "enabled"
    config.kubernetes.io/schema-version: "v1"
data:
  # Valid configuration
  database_host: "postgres.example.com"
  database_port: "5432"
  max_connections: "100"
  timeout_seconds: "30"
  
  # Configuration schema for validation
  config_schema.json: |
    {
      "type": "object",
      "required": ["database_host", "database_port", "max_connections"],
      "properties": {
        "database_host": {
          "type": "string",
          "pattern": "^[a-zA-Z0-9.-]+$"
        },
        "database_port": {
          "type": "string",
          "pattern": "^[0-9]+$",
          "minimum": 1,
          "maximum": 65535
        },
        "max_connections": {
          "type": "string",
          "pattern": "^[0-9]+$",
          "minimum": 1,
          "maximum": 1000
        },
        "timeout_seconds": {
          "type": "string",
          "pattern": "^[0-9]+$",
          "minimum": 1,
          "maximum": 300
        }
      }
    }
  
  # Validation script
  validate_config.sh: |
    #!/bin/bash
    set -e
    
    echo "=== CONFIGURATION VALIDATION ==="
    
    # Check required fields
    required_fields="database_host database_port max_connections"
    for field in $required_fields; do
      if [ -f "/etc/config/$field" ]; then
        value=$(cat "/etc/config/$field")
        echo "✅ $field: $value"
      else
        echo "❌ Required field missing: $field"
        exit 1
      fi
    done
    
    # Validate database port
    port=$(cat /etc/config/database_port)
    if [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
      echo "✅ Database port is valid: $port"
    else
      echo "❌ Invalid database port: $port"
      exit 1
    fi
    
    # Validate max connections
    max_conn=$(cat /etc/config/max_connections)
    if [ "$max_conn" -ge 1 ] && [ "$max_conn" -le 1000 ]; then
      echo "✅ Max connections is valid: $max_conn"
    else
      echo "❌ Invalid max connections: $max_conn"
      exit 1
    fi
    
    # Test database connectivity (simulation)
    db_host=$(cat /etc/config/database_host)
    echo "🔍 Testing connectivity to $db_host:$port..."
    # In real scenario: nc -z $db_host $port || exit 1
    echo "✅ Database connectivity check passed"
    
    echo "✅ All configuration validation checks passed!"
EOF

kubectl apply -f /tmp/validation-config.yaml

# Create secrets with validation
kubectl create secret generic validation-secrets \
    --from-literal=database_password=secure_password_123 \
    --from-literal=api_key=valid_api_key_456

cat > /tmp/validation-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: validation-demo
  labels:
    pattern: validation
spec:
  initContainers:
  - name: config-validator
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== CONFIGURATION VALIDATION INIT CONTAINER ==="
      
      # Run validation script
      chmod +x /etc/config/validate_config.sh
      /etc/config/validate_config.sh
      
      # Additional validation checks
      echo ""
      echo "=== ADDITIONAL VALIDATION ==="
      
      # Check secret availability
      if [ -f "/etc/secrets/database_password" ]; then
        echo "✅ Database password secret available"
      else
        echo "❌ Database password secret missing"
        exit 1
      fi
      
      if [ -f "/etc/secrets/api_key" ]; then
        echo "✅ API key secret available"
      else
        echo "❌ API key secret missing"
        exit 1
      fi
      
      # Validate secret format (example)
      api_key=$(cat /etc/secrets/api_key)
      if echo "$api_key" | grep -q "^valid_"; then
        echo "✅ API key format is valid"
      else
        echo "❌ API key format is invalid"
        exit 1
      fi
      
      echo "✅ Configuration and secrets validation completed successfully!"
      echo "✅ Application can start safely."
    volumeMounts:
    - name: config
      mountPath: /etc/config
    - name: secrets
      mountPath: /etc/secrets
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== VALIDATED APPLICATION STARTUP ==="
      echo ""
      echo "Configuration has been validated by init container."
      echo "Starting application with validated configuration:"
      echo ""
      echo "Database: $(cat /etc/config/database_host):$(cat /etc/config/database_port)"
      echo "Max Connections: $(cat /etc/config/max_connections)"
      echo "Timeout: $(cat /etc/config/timeout_seconds)s"
      echo ""
      echo "Application running with valid configuration..."
      
      # Periodic health checks
      while true; do
        sleep 30
        echo "$(date): Health check - Configuration still valid"
        
        # Re-validate critical configuration
        if [ -f /etc/config/database_host ] && [ -f /etc/secrets/database_password ]; then
          echo "$(date): Core configuration intact"
        else
          echo "$(date): ❌ Configuration corruption detected!"
          exit 1
        fi
      done
    volumeMounts:
    - name: config
      mountPath: /etc/config
    - name: secrets
      mountPath: /etc/secrets
  volumes:
  - name: config
    configMap:
      name: validation-config
  - name: secrets
    secret:
      secretName: validation-secrets
  restartPolicy: Never
EOF

kubectl apply -f /tmp/validation-demo.yaml

print_info "Waiting for validation demo to start..."
kubectl wait --for=condition=Ready pod/validation-demo --timeout=60s

print_success "Configuration validation results:"
kubectl logs validation-demo -c config-validator

print_success "Application startup with validated configuration:"
kubectl logs validation-demo -c app --tail=10

print_info "Configuration validation benefits:"
echo "  ✅ Prevents application startup with invalid configuration"
echo "  ✅ Early detection of configuration errors"
echo "  ✅ Improved reliability and stability"
echo "  ✅ Better error messages for debugging"

wait_for_input

print_step "6. Configuration Monitoring and Observability"

print_info "Let's implement configuration monitoring:"

cat > /tmp/config-monitoring.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: config-watcher
  labels:
    component: monitoring
spec:
  containers:
  - name: watcher
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== CONFIGURATION MONITORING SYSTEM ==="
      echo ""
      
      # Track configuration state
      track_config_state() {
        echo "$(date): Configuration State Report"
        echo "=================================="
        
        # Check ConfigMaps
        echo "📊 CONFIGMAP STATUS:"
        for cm in base-config dev-config prod-config validation-config reload-config; do
          if kubectl get configmap $cm >/dev/null 2>&1; then
            size=$(kubectl get configmap $cm -o json | jq '.data | to_entries | map(.value | length) | add // 0')
            age=$(kubectl get configmap $cm -o jsonpath='{.metadata.creationTimestamp}')
            echo "  ✅ $cm: ${size} bytes, created: $age"
          else
            echo "  ❌ $cm: Not found"
          fi
        done
        
        # Check Secrets
        echo ""
        echo "🔐 SECRET STATUS:"
        for secret in dev-secrets prod-secrets validation-secrets; do
          if kubectl get secret $secret >/dev/null 2>&1; then
            size=$(kubectl get secret $secret -o json | jq '.data | to_entries | map(.value | length) | add // 0')
            age=$(kubectl get secret $secret -o jsonpath='{.metadata.creationTimestamp}')
            echo "  ✅ $secret: ${size} bytes, created: $age"
          else
            echo "  ❌ $secret: Not found"
          fi
        done
        
        # Check configuration usage
        echo ""
        echo "🎯 CONFIGURATION USAGE:"
        for pod in dev-app prod-app layered-config-demo hot-reload-demo validation-demo; do
          if kubectl get pod $pod >/dev/null 2>&1; then
            status=$(kubectl get pod $pod -o jsonpath='{.status.phase}')
            echo "  📱 $pod: $status"
          fi
        done
        
        echo ""
        echo "=================================="
        echo ""
      }
      
      # Initial state
      track_config_state
      
      # Monitor configuration changes
      echo "👀 Starting configuration change monitoring..."
      while true; do
        sleep 60
        
        # Check for recent changes (simplified)
        echo "$(date): Checking for configuration changes..."
        
        # In a real system, you'd use kubectl events or API server audit logs
        recent_changes=$(kubectl get events --sort-by=.metadata.creationTimestamp | grep -E "(configmap|secret)" | tail -3)
        if [ -n "$recent_changes" ]; then
          echo "📢 Recent configuration changes detected:"
          echo "$recent_changes"
        fi
        
        # Periodic state report
        if [ $(($(date +%s) % 300)) -eq 0 ]; then
          track_config_state
        fi
      done
    # This pod needs cluster access for monitoring
    # In a real deployment, you'd configure RBAC appropriately
  restartPolicy: Never
EOF

# Note: This monitoring example would need proper RBAC in a real cluster
# kubectl apply -f /tmp/config-monitoring.yaml

print_info "Configuration monitoring script created (requires cluster-level RBAC to run)"
print_info "In a real environment, you would:"
echo "  • Set up Prometheus metrics for configuration changes"
echo "  • Implement alerts for configuration errors"
echo "  • Track configuration drift"
echo "  • Monitor configuration usage patterns"
echo "  • Log all configuration access for audit trails"

wait_for_input

print_step "7. Advanced Configuration Patterns Summary"

print_info "Advanced patterns demonstrated in this exercise:"

echo ""
echo "🔧 MULTI-ENVIRONMENT PATTERN:"
echo "  ✅ Base configuration shared across environments"
echo "  ✅ Environment-specific overlays"
echo "  ✅ Consistent deployment patterns"
echo "  ✅ Environment-specific secrets"

echo ""
echo "🔧 LAYERED CONFIGURATION:"
echo "  ✅ Hierarchical configuration structure"
echo "  ✅ Clear separation of concerns"
echo "  ✅ Override capabilities"
echo "  ✅ Reduced configuration duplication"

echo ""
echo "🔧 HOT-RELOADING:"
echo "  ✅ Zero-downtime configuration updates"
echo "  ✅ Dynamic feature flag control"
echo "  ✅ Application-level reload mechanisms"
echo "  ✅ Operational flexibility"

echo ""
echo "🔧 VALIDATION & MONITORING:"
echo "  ✅ Configuration validation on startup"
echo "  ✅ Schema-based validation"
echo "  ✅ Health checks for configuration integrity"
echo "  ✅ Configuration change monitoring"

wait_for_input

print_step "8. Cleanup"

print_info "Cleaning up exercise resources..."

# Clean up files
rm -f /tmp/base-config.yaml /tmp/dev-config.yaml /tmp/staging-config.yaml /tmp/prod-config.yaml \
      /tmp/dev-app.yaml /tmp/prod-app.yaml \
      /tmp/layered-base.yaml /tmp/layered-dev.yaml /tmp/layered-prod.yaml /tmp/layered-app.yaml \
      /tmp/hot-reload-demo.yaml /tmp/validation-config.yaml /tmp/validation-demo.yaml \
      /tmp/config-monitoring.yaml

# Clean up pods
kubectl delete pod \
    dev-app prod-app layered-config-demo \
    hot-reload-demo validation-demo 2>/dev/null || true

# Keep some ConfigMaps and Secrets for other exercises
print_warning "Some resources are kept for potential use in other exercises."
print_info "To clean up all resources from this exercise:"
echo "kubectl delete configmap base-config dev-config staging-config prod-config"
echo "kubectl delete configmap app-base-config app-dev-overlay app-staging-overlay app-prod-overlay"
echo "kubectl delete configmap nginx-base nginx-dev nginx-prod"
echo "kubectl delete configmap validation-config reload-config"
echo "kubectl delete secret dev-secrets staging-secrets prod-secrets validation-secrets"

print_success "Exercise completed! You've learned:"
echo "  ✅ Multi-environment configuration patterns"
echo "  ✅ Layered configuration architecture"
echo "  ✅ Hot-reloading configuration updates"
echo "  ✅ Configuration validation and health checks"
echo "  ✅ Configuration monitoring and observability"
echo "  ✅ Real-world configuration management strategies"

print_info "Next: Try Exercise 6 to learn about troubleshooting configuration issues!"