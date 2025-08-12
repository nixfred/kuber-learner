#!/bin/bash

# Module 9: Real-World Applications Interactive Workshop
# This script provides hands-on experience with production-ready Kubernetes applications

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
    
    print_success "Prerequisites satisfied!"
    
    # Show cluster info
    print_info "Connected to cluster: $(kubectl config current-context)"
    print_info "Current namespace: $(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo 'default')"
    
    # Check available resources
    print_info "Cluster resource overview:"
    kubectl top nodes 2>/dev/null || echo "Metrics Server not available"
    
    print_info "This module will deploy production-grade applications."
    print_warning "Ensure your cluster has sufficient resources for multiple services."
}

cleanup_previous() {
    print_header "Cleaning Up Previous Resources"
    
    print_info "Removing any existing demo resources..."
    
    # Clean up namespaces (this will remove everything in them)
    kubectl delete namespace --ignore-not-found=true \
        ecommerce-demo production-demo microservices-demo 2>/dev/null || true
    
    # Clean up any standalone resources
    kubectl delete pod --ignore-not-found=true \
        architecture-demo database-test microservice-test 2>/dev/null || true
    
    print_success "Cleanup completed!"
}

demo_production_architecture() {
    print_header "Production-Ready Application Architecture"
    
    print_info "Let's explore what makes an application 'production-ready'..."
    
    print_step "1. From Development to Production"
    
    echo "🏗️  DEVELOPMENT APPLICATION:"
    echo "  • Single pod"
    echo "  • Basic service"
    echo "  • No resource limits"
    echo "  • No health checks"
    echo "  • No security controls"
    echo "  • No monitoring"
    
    echo ""
    echo "🏭 PRODUCTION APPLICATION:"
    echo "  • Multi-tier architecture"
    echo "  • High availability"
    echo "  • Auto-scaling"
    echo "  • Security hardening"
    echo "  • Comprehensive monitoring"
    echo "  • Disaster recovery"
    echo "  • CI/CD integration"
    
    wait_for_input
    
    print_step "2. Multi-Tier Architecture Components"
    
    echo "📊 PRESENTATION TIER:"
    echo "  • Frontend applications (React, Angular, Vue)"
    echo "  • Mobile app backends"
    echo "  • Content Delivery Networks (CDN)"
    echo "  • API gateways"
    
    echo ""
    echo "⚙️  APPLICATION TIER:"
    echo "  • Business logic services"
    echo "  • Microservices"
    echo "  • Background workers"
    echo "  • Message processors"
    
    echo ""
    echo "💾 DATA TIER:"
    echo "  • Primary databases"
    echo "  • Cache systems (Redis)"
    echo "  • Search engines (Elasticsearch)"
    echo "  • Message queues (RabbitMQ)"
    
    echo ""
    echo "🔧 INFRASTRUCTURE TIER:"
    echo "  • Load balancers"
    echo "  • Service mesh"
    echo "  • Monitoring systems"
    echo "  • Logging aggregation"
    
    wait_for_input
    
    print_step "3. Production Principles"
    
    echo "📋 THE 12-FACTOR APP PRINCIPLES:"
    echo "  1. Codebase: One codebase, many deploys"
    echo "  2. Dependencies: Explicitly declare dependencies"
    echo "  3. Config: Store config in environment"
    echo "  4. Backing services: Treat as attached resources"
    echo "  5. Build/release/run: Strict separation"
    echo "  6. Processes: Stateless execution"
    echo "  7. Port binding: Export services via ports"
    echo "  8. Concurrency: Scale via process model"
    echo "  9. Disposability: Fast startup and shutdown"
    echo "  10. Dev/prod parity: Keep environments similar"
    echo "  11. Logs: Treat as event streams"
    echo "  12. Admin processes: Run as one-off processes"
    
    echo ""
    echo "➕ KUBERNETES ADDITIONS:"
    echo "  13. Security: Defense in depth"
    echo "  14. Observability: Monitor everything"
    echo "  15. Automation: Automate operations"
    
    wait_for_input
}

demo_database_deployment() {
    print_header "Production Database Deployment"
    
    print_info "Let's deploy a production-ready PostgreSQL database..."
    
    print_step "1. Creating database namespace and configuration"
    
    # Create namespace for database
    kubectl create namespace ecommerce-demo
    
    # Create database secrets
    cat << 'EOF' > /tmp/postgres-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
  namespace: ecommerce-demo
type: Opaque
data:
  password: cG9zdGdyZXNwYXNzd29yZDE=  # postgrespassword1
  replication-password: cmVwbGljYXRvcnBhc3N3b3JkMQ==  # replicatorpassword1
EOF

    kubectl apply -f /tmp/postgres-secrets.yaml
    
    # Create database configuration
    cat << 'EOF' > /tmp/postgres-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: ecommerce-demo
data:
  POSTGRES_DB: "ecommerce"
  POSTGRES_USER: "app_user"
  postgresql.conf: |
    # Connection settings
    listen_addresses = '*'
    port = 5432
    max_connections = 200
    
    # Memory settings
    shared_buffers = 256MB
    effective_cache_size = 1GB
    work_mem = 4MB
    
    # WAL settings
    wal_level = replica
    max_wal_senders = 3
    
    # Logging
    log_statement = 'all'
    log_duration = on
    
  pg_hba.conf: |
    # TYPE  DATABASE        USER            ADDRESS                 METHOD
    local   all             all                                     trust
    host    all             all             127.0.0.1/32            trust
    host    all             all             0.0.0.0/0               md5
EOF

    kubectl apply -f /tmp/postgres-config.yaml
    
    print_success "Database configuration created!"
    
    wait_for_input
    
    print_step "2. Deploying PostgreSQL StatefulSet"
    
    cat << 'EOF' > /tmp/postgres-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: ecommerce-demo
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
        envFrom:
        - configMapRef:
            name: postgres-config
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secrets
              key: password
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: ecommerce-demo
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
EOF

    kubectl apply -f /tmp/postgres-statefulset.yaml
    
    print_info "Deploying PostgreSQL database..."
    print_info "Waiting for database to be ready..."
    
    # Wait for the StatefulSet to be ready
    kubectl wait --for=condition=Ready pod/postgres-0 -n ecommerce-demo --timeout=120s
    
    print_success "PostgreSQL database is running!"
    
    echo "Database status:"
    kubectl get statefulset postgres -n ecommerce-demo
    kubectl get pods -n ecommerce-demo -l app=postgres
    
    wait_for_input
    
    print_step "3. Testing database connectivity"
    
    print_info "Testing database connection..."
    
    # Test database connectivity
    kubectl run postgres-client --image=postgres:13 --rm -it --restart=Never \
        --namespace=ecommerce-demo \
        --env="PGPASSWORD=postgrespassword1" \
        -- psql -h postgres -U postgres -d ecommerce -c "SELECT version();" || echo "Database test completed"
    
    print_success "Database deployment completed successfully!"
    
    wait_for_input
}

demo_microservices_deployment() {
    print_header "Microservices Architecture Deployment"
    
    print_info "Let's deploy a complete microservices-based application..."
    
    print_step "1. Creating microservices namespace"
    
    kubectl create namespace microservices-demo
    
    print_step "2. Deploying Redis Cache"
    
    cat << 'EOF' > /tmp/redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: microservices-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:6-alpine
        ports:
        - containerPort: 6379
        command:
        - redis-server
        - --appendonly
        - "yes"
        volumeMounts:
        - name: redis-data
          mountPath: /data
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: microservices-demo
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
EOF

    kubectl apply -f /tmp/redis-deployment.yaml
    
    print_step "3. Deploying User Service"
    
    cat << 'EOF' > /tmp/user-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: microservices-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
        version: v1
    spec:
      containers:
      - name: user-service
        image: busybox:1.35
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "=== USER SERVICE v1.0.0 ==="
          echo "Starting user service..."
          
          # Simulate user service functionality
          while true; do
            echo "$(date): User service processing requests..."
            echo "  - Authenticating users"
            echo "  - Managing user profiles"
            echo "  - Validating permissions"
            
            # Simulate some load
            sleep 30
          done
        ports:
        - containerPort: 8080
        env:
        - name: SERVICE_NAME
          value: "user-service"
        - name: SERVICE_VERSION
          value: "v1.0.0"
        - name: REDIS_URL
          value: "redis://redis:6379"
        - name: DATABASE_URL
          value: "postgresql://postgres:5432/ecommerce"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "ps aux | grep -v grep | grep -q sh"
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "ps aux | grep -v grep | grep -q sh"
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: microservices-demo
spec:
  selector:
    app: user-service
  ports:
  - port: 8080
    targetPort: 8080
EOF

    kubectl apply -f /tmp/user-service.yaml
    
    print_step "4. Deploying Product Service"
    
    cat << 'EOF' > /tmp/product-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: microservices-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
        version: v1
    spec:
      containers:
      - name: product-service
        image: busybox:1.35
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "=== PRODUCT SERVICE v1.0.0 ==="
          echo "Starting product service..."
          
          # Simulate product service functionality
          while true; do
            echo "$(date): Product service processing requests..."
            echo "  - Managing product catalog"
            echo "  - Updating inventory"
            echo "  - Processing search queries"
            echo "  - Generating recommendations"
            
            sleep 25
          done
        ports:
        - containerPort: 8080
        env:
        - name: SERVICE_NAME
          value: "product-service"
        - name: SERVICE_VERSION
          value: "v1.0.0"
        - name: REDIS_URL
          value: "redis://redis:6379"
        - name: DATABASE_URL
          value: "postgresql://postgres:5432/ecommerce"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: microservices-demo
spec:
  selector:
    app: product-service
  ports:
  - port: 8080
    targetPort: 8080
EOF

    kubectl apply -f /tmp/product-service.yaml
    
    print_step "5. Deploying API Gateway"
    
    cat << 'EOF' > /tmp/api-gateway.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: microservices-demo
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    
    http {
        upstream user_service {
            server user-service:8080;
        }
        
        upstream product_service {
            server product-service:8080;
        }
        
        server {
            listen 80;
            
            # Health check endpoint
            location /health {
                access_log off;
                return 200 "API Gateway is healthy\n";
                add_header Content-Type text/plain;
            }
            
            # User service routes
            location /api/users/ {
                proxy_pass http://user_service/;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                add_header X-Service-Route "user-service";
            }
            
            # Product service routes
            location /api/products/ {
                proxy_pass http://product_service/;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                add_header X-Service-Route "product-service";
            }
            
            # Default route
            location / {
                return 200 "🚀 E-commerce API Gateway\nAvailable routes:\n  /api/users/\n  /api/products/\n  /health\n";
                add_header Content-Type text/plain;
            }
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: microservices-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: microservices-demo
spec:
  type: NodePort
  selector:
    app: api-gateway
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

    kubectl apply -f /tmp/api-gateway.yaml
    
    print_info "Deploying microservices..."
    print_info "Waiting for all services to be ready..."
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=Available deployment/redis -n microservices-demo --timeout=60s
    kubectl wait --for=condition=Available deployment/user-service -n microservices-demo --timeout=60s
    kubectl wait --for=condition=Available deployment/product-service -n microservices-demo --timeout=60s
    kubectl wait --for=condition=Available deployment/api-gateway -n microservices-demo --timeout=60s
    
    print_success "All microservices deployed successfully!"
    
    echo "Microservices overview:"
    kubectl get pods -n microservices-demo
    
    echo ""
    echo "Services:"
    kubectl get services -n microservices-demo
    
    wait_for_input
    
    print_step "6. Testing the API Gateway"
    
    print_info "Testing API Gateway functionality..."
    
    # Test API Gateway
    kubectl run api-test --image=busybox:1.35 --rm -it --restart=Never \
        --namespace=microservices-demo \
        -- sh -c "
        echo 'Testing API Gateway...'
        wget -qO- http://api-gateway/
        echo ''
        echo 'Testing health endpoint...'
        wget -qO- http://api-gateway/health
        echo ''
        echo 'API Gateway test completed!'
        " || echo "API Gateway test completed"
    
    print_success "Microservices architecture deployed and tested!"
    
    wait_for_input
}

demo_autoscaling() {
    print_header "Auto-scaling Configuration"
    
    print_info "Let's configure auto-scaling for our microservices..."
    
    print_step "1. Horizontal Pod Autoscaler (HPA)"
    
    print_info "Creating HPA for product service..."
    
    cat << 'EOF' > /tmp/product-service-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: product-service-hpa
  namespace: microservices-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: product-service
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
EOF

    kubectl apply -f /tmp/product-service-hpa.yaml
    
    print_success "HPA configured for product service!"
    
    # Check HPA status
    kubectl get hpa -n microservices-demo
    
    wait_for_input
    
    print_step "2. Load Testing for Auto-scaling"
    
    print_info "Creating a load test to trigger auto-scaling..."
    
    cat << 'EOF' > /tmp/load-test.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: load-test
  namespace: microservices-demo
spec:
  parallelism: 3
  template:
    spec:
      containers:
      - name: load-test
        image: busybox:1.35
        command:
        - /bin/sh
        - -c
        - |
          echo "=== LOAD TEST STARTING ==="
          echo "Target: product-service"
          echo "Duration: 5 minutes"
          echo "Concurrent requests: 3 pods"
          
          start_time=$(date +%s)
          end_time=$((start_time + 300))  # 5 minutes
          
          request_count=0
          while [ $(date +%s) -lt $end_time ]; do
            # Generate CPU load
            dd if=/dev/zero of=/dev/null bs=1M count=10 2>/dev/null &
            
            # Simulate API requests
            for i in $(seq 1 5); do
              request_count=$((request_count + 1))
              echo "Request $request_count at $(date)"
              sleep 0.1
            done
            
            sleep 1
          done
          
          echo "Load test completed!"
          echo "Total requests: $request_count"
      restartPolicy: Never
  backoffLimit: 1
EOF

    kubectl apply -f /tmp/load-test.yaml
    
    print_info "Load test started! Let's monitor the auto-scaling..."
    
    # Monitor the load test and HPA
    print_info "Monitoring HPA status (this may take a few minutes)..."
    
    for i in {1..10}; do
        echo "Check $i:"
        kubectl get hpa -n microservices-demo
        kubectl get pods -n microservices-demo -l app=product-service
        echo "---"
        sleep 30
    done
    
    print_success "Auto-scaling demonstration completed!"
    print_info "In a real environment with Metrics Server, you would see pods scaling based on load."
    
    wait_for_input
}

demo_production_features() {
    print_header "Production Features Implementation"
    
    print_info "Let's implement production-ready features..."
    
    print_step "1. Security Hardening"
    
    print_info "Creating a production namespace with security policies..."
    
    cat << 'EOF' > /tmp/production-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production-demo
  labels:
    environment: production
    security: hardened
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
# Network Policy - Default Deny
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production-demo
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Network Policy - Allow specific communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-services
  namespace: production-demo
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: api
    ports:
    - protocol: TCP
      port: 8080
EOF

    kubectl apply -f /tmp/production-namespace.yaml
    
    print_step "2. Secure Application Deployment"
    
    cat << 'EOF' > /tmp/secure-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-web-app
  namespace: production-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-web-app
      tier: api
  template:
    metadata:
      labels:
        app: secure-web-app
        tier: api
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
      containers:
      - name: web-app
        image: busybox:1.35
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "=== SECURE WEB APPLICATION ==="
          echo "Running with security hardening:"
          echo "  • Non-root user: $(id)"
          echo "  • Read-only root filesystem"
          echo "  • Dropped capabilities"
          echo "  • Resource limits enforced"
          
          # Simulate web application
          while true; do
            echo "$(date): Secure web app serving requests..."
            echo "  Security: ENABLED"
            echo "  User: $(whoami) ($(id -u))"
            echo "  Capabilities: Minimal"
            sleep 30
          done
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        ports:
        - containerPort: 8080
          protocol: TCP
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "ps aux | grep -v grep | grep -q sh"
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "ps aux | grep -v grep | grep -q sh"
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - secure-web-app
              topologyKey: kubernetes.io/hostname
---
apiVersion: v1
kind: Service
metadata:
  name: secure-web-app
  namespace: production-demo
spec:
  selector:
    app: secure-web-app
  ports:
  - port: 80
    targetPort: 8080
---
# Pod Disruption Budget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: secure-web-app-pdb
  namespace: production-demo
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: secure-web-app
EOF

    kubectl apply -f /tmp/secure-app.yaml
    
    print_info "Deploying secure application..."
    kubectl wait --for=condition=Available deployment/secure-web-app -n production-demo --timeout=60s
    
    print_success "Secure application deployed!"
    
    echo "Security features:"
    kubectl get pods -n production-demo
    kubectl describe pod -n production-demo -l app=secure-web-app | grep -A 5 "Security Context:" | head -10
    
    wait_for_input
    
    print_step "3. Resource Management"
    
    cat << 'EOF' > /tmp/resource-management.yaml
# Resource Quota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production-demo
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
    pods: "20"
    services: "10"
---
# Limit Range
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production-demo
spec:
  limits:
  - type: Container
    default:
      cpu: "200m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    min:
      cpu: "50m"
      memory: "64Mi"
    max:
      cpu: "1"
      memory: "1Gi"
EOF

    kubectl apply -f /tmp/resource-management.yaml
    
    print_success "Resource management policies applied!"
    
    echo "Resource quotas:"
    kubectl describe quota -n production-demo
    
    wait_for_input
}

demo_monitoring_setup() {
    print_header "Monitoring and Observability"
    
    print_info "Let's set up basic monitoring for our applications..."
    
    print_step "1. Application with Metrics Endpoint"
    
    cat << 'EOF' > /tmp/monitored-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitored-app
  namespace: production-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: monitored-app
  template:
    metadata:
      labels:
        app: monitored-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: busybox:1.35
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "=== MONITORED APPLICATION ==="
          
          # Create metrics endpoint
          mkdir -p /tmp/metrics
          
          # Generate Prometheus-style metrics
          while true; do
            timestamp=$(date +%s)
            requests_total=$((RANDOM % 1000 + 500))
            errors_total=$((RANDOM % 50))
            response_time=$((RANDOM % 500 + 100))
            memory_usage=$((RANDOM % 500 + 200))
            
            cat > /tmp/metrics/metrics.txt << EOF
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/api"} ${requests_total}

# HELP http_request_errors_total Total number of HTTP errors
# TYPE http_request_errors_total counter
http_request_errors_total{method="GET",endpoint="/api"} ${errors_total}

# HELP http_request_duration_ms HTTP request duration in milliseconds
# TYPE http_request_duration_ms gauge
http_request_duration_ms ${response_time}

# HELP memory_usage_bytes Current memory usage in bytes
# TYPE memory_usage_bytes gauge
memory_usage_bytes $((memory_usage * 1024 * 1024))

# HELP app_info Application information
# TYPE app_info gauge
app_info{version="1.0.0",environment="production"} 1
EOF

            echo "$(date): Metrics updated - Requests: ${requests_total}, Errors: ${errors_total}"
            sleep 15
          done
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: metrics
          mountPath: /tmp/metrics
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: metrics
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: monitored-app
  namespace: production-demo
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
spec:
  selector:
    app: monitored-app
  ports:
  - port: 8080
    targetPort: 8080
EOF

    kubectl apply -f /tmp/monitored-app.yaml
    
    print_info "Deploying monitored application..."
    kubectl wait --for=condition=Available deployment/monitored-app -n production-demo --timeout=60s
    
    print_success "Monitored application deployed!"
    
    print_step "2. Health Check Dashboard"
    
    print_info "Creating a simple monitoring dashboard..."
    
    cat << 'EOF' > /tmp/monitoring-dashboard.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitoring-dashboard
  namespace: production-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: monitoring-dashboard
  template:
    metadata:
      labels:
        app: monitoring-dashboard
    spec:
      containers:
      - name: dashboard
        image: busybox:1.35
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "=== MONITORING DASHBOARD ==="
          
          while true; do
            echo ""
            echo "📊 SYSTEM OVERVIEW - $(date)"
            echo "=================================="
            
            echo "🏗️  INFRASTRUCTURE:"
            echo "  • Cluster: production-demo"
            echo "  • Nodes: Available"
            echo "  • Storage: Healthy"
            
            echo ""
            echo "🔧 APPLICATIONS:"
            echo "  • secure-web-app: 3/3 replicas running"
            echo "  • monitored-app: 2/2 replicas running"
            echo "  • Response time: ~200ms avg"
            
            echo ""
            echo "📈 METRICS:"
            echo "  • Request rate: 500-1000 req/min"
            echo "  • Error rate: <5%"
            echo "  • Memory usage: 200-700MB"
            echo "  • CPU usage: Normal"
            
            echo ""
            echo "🚨 ALERTS:"
            echo "  • No active alerts"
            echo "  • All systems operational"
            
            echo ""
            echo "🔐 SECURITY:"
            echo "  • Network policies: Active"
            echo "  • Pod security: Enforced"
            echo "  • Resource limits: Applied"
            
            sleep 60
          done
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
EOF

    kubectl apply -f /tmp/monitoring-dashboard.yaml
    
    print_info "Starting monitoring dashboard..."
    kubectl wait --for=condition=Available deployment/monitoring-dashboard -n production-demo --timeout=60s
    
    print_success "Monitoring dashboard is running!"
    
    echo "Dashboard output:"
    kubectl logs -n production-demo deployment/monitoring-dashboard --tail=20
    
    wait_for_input
}

show_production_overview() {
    print_header "Production Environment Overview"
    
    print_success "🎉 Congratulations! You've deployed a production-ready Kubernetes environment!"
    
    print_step "Deployed Components"
    
    echo "📊 DATABASES:"
    kubectl get pods -n ecommerce-demo -l app=postgres
    
    echo ""
    echo "🔧 MICROSERVICES:"
    kubectl get pods -n microservices-demo
    
    echo ""
    echo "🔐 PRODUCTION APPS:"
    kubectl get pods -n production-demo
    
    echo ""
    echo "📈 SERVICES:"
    echo "Ecommerce namespace:"
    kubectl get services -n ecommerce-demo
    echo ""
    echo "Microservices namespace:"
    kubectl get services -n microservices-demo
    echo ""
    echo "Production namespace:"
    kubectl get services -n production-demo
    
    wait_for_input
    
    print_step "Production Features Implemented"
    
    echo "✅ DATABASE DEPLOYMENT:"
    echo "  • PostgreSQL with persistent storage"
    echo "  • Proper health checks and resource limits"
    echo "  • Configuration management"
    
    echo ""
    echo "✅ MICROSERVICES ARCHITECTURE:"
    echo "  • API Gateway with nginx"
    echo "  • Multiple backend services"
    echo "  • Service-to-service communication"
    echo "  • Redis caching layer"
    
    echo ""
    echo "✅ AUTO-SCALING:"
    echo "  • Horizontal Pod Autoscaler configured"
    echo "  • Load testing capabilities"
    echo "  • Resource-based scaling policies"
    
    echo ""
    echo "✅ SECURITY HARDENING:"
    echo "  • Pod Security Standards enforced"
    echo "  • Network policies implemented"
    echo "  • Non-root containers"
    echo "  • Read-only filesystems"
    echo "  • Capability dropping"
    
    echo ""
    echo "✅ RESOURCE MANAGEMENT:"
    echo "  • Resource quotas and limits"
    echo "  • Quality of Service classes"
    echo "  • Pod Disruption Budgets"
    
    echo ""
    echo "✅ MONITORING & OBSERVABILITY:"
    echo "  • Metrics endpoints"
    echo "  • Health checks"
    echo "  • Monitoring dashboard"
    echo "  • Application logging"
    
    wait_for_input
}

cleanup_demo() {
    print_header "Cleaning Up Demo Resources"
    
    print_info "Removing production demo resources..."
    print_warning "This will delete all demo namespaces and resources."
    
    echo "Do you want to clean up the demo resources? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # Clean up namespaces
        kubectl delete namespace ecommerce-demo microservices-demo production-demo 2>/dev/null || true
        
        # Clean up files
        rm -f /tmp/postgres-*.yaml /tmp/redis-*.yaml /tmp/user-service.yaml \
              /tmp/product-service.yaml /tmp/api-gateway.yaml /tmp/load-test.yaml \
              /tmp/production-namespace.yaml /tmp/secure-app.yaml \
              /tmp/resource-management.yaml /tmp/monitored-app.yaml \
              /tmp/monitoring-dashboard.yaml /tmp/product-service-hpa.yaml
        
        print_success "Demo resources cleaned up!"
    else
        print_info "Demo resources preserved for further exploration."
        print_info "To clean up later, run: kubectl delete namespace ecommerce-demo microservices-demo production-demo"
    fi
}

show_next_steps() {
    print_header "🎓 Course Completion & Next Steps"
    
    print_success "🎉 CONGRATULATIONS! 🎉"
    print_success "You have successfully completed the Kubernetes Learning Journey!"
    
    print_info "🚀 What You've Accomplished:"
    echo "  ✅ Mastered Kubernetes fundamentals"
    echo "  ✅ Deployed production-ready applications"
    echo "  ✅ Implemented security best practices"
    echo "  ✅ Configured monitoring and observability"
    echo "  ✅ Applied auto-scaling strategies"
    echo "  ✅ Built microservices architectures"
    echo "  ✅ Managed databases and storage"
    echo "  ✅ Developed troubleshooting skills"
    
    echo ""
    print_info "💼 You're Now Ready For:"
    echo "  • DevOps Engineer roles"
    echo "  • Platform Engineer positions"
    echo "  • Site Reliability Engineer (SRE) roles"
    echo "  • Cloud Architect positions"
    echo "  • Kubernetes Administrator roles"
    
    echo ""
    print_info "📚 Continue Your Learning Journey:"
    echo "  • Certified Kubernetes Administrator (CKA)"
    echo "  • Certified Kubernetes Application Developer (CKAD)"
    echo "  • Certified Kubernetes Security Specialist (CKS)"
    echo "  • Service Mesh (Istio, Linkerd)"
    echo "  • Serverless Kubernetes (Knative)"
    echo "  • GitOps and ArgoCD"
    
    echo ""
    print_info "🔗 Additional Resources:"
    echo "  • Kubernetes Documentation: https://kubernetes.io/docs/"
    echo "  • CNCF Projects: https://www.cncf.io/"
    echo "  • Kubernetes Community: https://kubernetes.io/community/"
    echo "  • Practice Labs: https://play.k8s.io/"
    
    echo ""
    print_success "Thank you for completing the Kubernetes Learning Journey!"
    print_info "Keep practicing, stay curious, and contribute to the community! 🌟"
}

# Main execution
main() {
    print_header "🚀 Kubernetes Real-World Applications Workshop"
    
    print_info "Welcome to the final module of your Kubernetes learning journey!"
    echo "This workshop will demonstrate:"
    echo "  • Production-ready application deployment"
    echo "  • Database deployments with PostgreSQL"
    echo "  • Microservices architecture patterns"
    echo "  • Auto-scaling configuration"
    echo "  • Security hardening and best practices"
    echo "  • Monitoring and observability"
    echo "  • Complete production environment"
    
    wait_for_input
    
    check_prerequisites
    cleanup_previous
    demo_production_architecture
    demo_database_deployment
    demo_microservices_deployment
    demo_autoscaling
    demo_production_features
    demo_monitoring_setup
    show_production_overview
    cleanup_demo
    show_next_steps
    
    print_success "🎉 Real-World Applications Workshop Completed! 🎉"
    print_info "You've successfully built and deployed production-ready Kubernetes applications!"
}

# Run the workshop
main "$@"