#!/bin/bash

# Module 7: Monitoring & Observability Interactive Workshop
# This script provides an interactive learning experience for Kubernetes monitoring

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
    
    # Check if metrics server is available
    if kubectl get apiservice v1beta1.metrics.k8s.io &> /dev/null; then
        print_success "Metrics Server is available"
    else
        print_warning "Metrics Server not found - will demonstrate installation"
    fi
}

cleanup_previous() {
    print_header "Cleaning Up Previous Resources"
    
    print_info "Removing any existing demo resources..."
    
    # Clean up pods
    kubectl delete pod --ignore-not-found=true \
        monitoring-demo health-check-demo metrics-demo \
        logging-demo observability-test 2>/dev/null || true
    
    # Clean up services
    kubectl delete service --ignore-not-found=true \
        monitoring-demo-service health-demo-service 2>/dev/null || true
    
    # Clean up configmaps
    kubectl delete configmap --ignore-not-found=true \
        monitoring-config logging-config 2>/dev/null || true
    
    print_success "Cleanup completed!"
}

demo_observability_pillars() {
    print_header "Understanding the Three Pillars of Observability"
    
    print_info "Observability helps answer three key questions about your system:"
    
    print_step "1. METRICS: What is happening right now?"
    
    echo "Metrics tell us:"
    echo "  📊 How many requests per second?"
    echo "  📊 What's the CPU and memory usage?"
    echo "  📊 How many errors are occurring?"
    echo "  📊 What's the response time?"
    
    print_step "2. LOGS: What happened and why?"
    
    echo "Logs provide:"
    echo "  📝 Error messages and stack traces"
    echo "  📝 Application events and user actions"
    echo "  📝 Debug information for troubleshooting"
    echo "  📝 Audit trails for security"
    
    print_step "3. TRACES: How are requests flowing through the system?"
    
    echo "Traces show:"
    echo "  🔄 Request journey across microservices"
    echo "  🔄 Performance bottlenecks and slow operations"
    echo "  🔄 Service dependencies and call patterns"
    echo "  🔄 End-to-end latency breakdown"
    
    wait_for_input
    
    print_info "Let's see these pillars in action with a practical example..."
    
    # Create a demo application that demonstrates all three pillars
    cat << 'EOF' > /tmp/observability-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: observability-demo
  labels:
    app: observability-demo
spec:
  containers:
  - name: web-app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== OBSERVABILITY DEMO APPLICATION ==="
      echo ""
      
      # Simulate a web application with metrics, logs, and traces
      request_count=0
      error_count=0
      
      while true; do
        request_count=$((request_count + 1))
        
        # METRICS: Simulate request counting and timing
        response_time=$(( (RANDOM % 500) + 50 ))  # 50-550ms
        
        # LOGS: Structured logging with different levels
        if [ $((request_count % 10)) -eq 0 ]; then
          # Simulate an error (10% error rate)
          error_count=$((error_count + 1))
          echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"ERROR\",\"service\":\"web-app\",\"message\":\"Request failed\",\"request_id\":\"req-${request_count}\",\"error_code\":\"E001\",\"response_time_ms\":${response_time}}"
        else
          # Normal request
          echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"INFO\",\"service\":\"web-app\",\"message\":\"Request processed\",\"request_id\":\"req-${request_count}\",\"response_time_ms\":${response_time}}"
        fi
        
        # TRACES: Simulate distributed tracing info
        if [ $((request_count % 5)) -eq 0 ]; then
          echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"DEBUG\",\"service\":\"web-app\",\"message\":\"Trace info\",\"trace_id\":\"trace-${request_count}\",\"span_id\":\"span-web\",\"parent_span\":\"span-gateway\",\"operation\":\"handle_request\"}"
        fi
        
        # Show current metrics every 10 requests
        if [ $((request_count % 10)) -eq 0 ]; then
          success_rate=$(( (request_count - error_count) * 100 / request_count ))
          echo "📊 METRICS: Total requests: ${request_count}, Errors: ${error_count}, Success rate: ${success_rate}%"
        fi
        
        sleep 2
      done
    ports:
    - containerPort: 8080
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/observability-demo.yaml
    
    print_info "Starting observability demo application..."
    kubectl wait --for=condition=Ready pod/observability-demo --timeout=60s
    
    print_success "Demo application is running! Let's see all three pillars in action:"
    
    sleep 10
    kubectl logs observability-demo --tail=20
    
    print_info "Notice how the application generates:"
    echo "  📊 METRICS: Request counts, response times, success rates"
    echo "  📝 LOGS: Structured JSON logs with different levels"
    echo "  🔄 TRACES: Span information showing request flow"
    
    wait_for_input
}

demo_resource_monitoring() {
    print_header "Resource Monitoring with Metrics Server"
    
    print_step "1. Checking Metrics Server status"
    
    if kubectl get apiservice v1beta1.metrics.k8s.io &> /dev/null; then
        print_success "Metrics Server is installed and running!"
        
        # Show metrics server pod
        print_info "Metrics Server pod:"
        kubectl get pods -n kube-system | grep metrics-server || echo "Metrics Server pod not found in kube-system"
        
    else
        print_warning "Metrics Server not found. In a real cluster, you would install it with:"
        echo "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
        echo ""
        print_info "For kind clusters, additional configuration is needed for TLS."
    fi
    
    wait_for_input
    
    print_step "2. Resource monitoring commands"
    
    print_info "Let's explore resource monitoring commands:"
    
    echo "Node resource usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics Server required for 'kubectl top' commands"
    
    echo ""
    echo "Pod resource usage:"
    kubectl top pods 2>/dev/null || echo "Metrics Server required for 'kubectl top' commands"
    
    echo ""
    echo "All namespaces:"
    kubectl top pods --all-namespaces 2>/dev/null || echo "Metrics Server required for 'kubectl top' commands"
    
    print_info "These commands help you understand:"
    echo "  💾 Memory usage and limits"
    echo "  🖥️  CPU usage and limits" 
    echo "  📈 Resource trends over time"
    echo "  🎯 Identify resource-hungry pods"
    
    wait_for_input
}

demo_health_checks() {
    print_header "Health Checks and Probes"
    
    print_info "Health checks ensure your applications are running correctly and ready to serve traffic."
    
    print_step "1. Understanding probe types"
    
    echo "Kubernetes has three types of probes:"
    echo "  ❤️  LIVENESS: Is the application running? (restarts if fails)"
    echo "  ✅ READINESS: Is the application ready for traffic? (removes from load balancer if fails)"
    echo "  🚀 STARTUP: Has the application finished starting? (disables other probes until successful)"
    
    wait_for_input
    
    print_step "2. Creating an application with health checks"
    
    cat << 'EOF' > /tmp/health-check-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: health-check-demo
  labels:
    app: health-demo
spec:
  containers:
  - name: web-app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== HEALTH CHECK DEMO ==="
      
      # Create health check endpoints simulation
      mkdir -p /tmp/health
      
      # Initially not ready (simulating startup time)
      echo "starting" > /tmp/health/status
      echo "false" > /tmp/health/ready
      echo "true" > /tmp/health/alive
      
      echo "Application starting up..."
      sleep 10
      
      # Now ready
      echo "running" > /tmp/health/status  
      echo "true" > /tmp/health/ready
      echo "true" > /tmp/health/alive
      
      echo "Application ready to serve traffic!"
      
      # Simulate application lifecycle
      counter=0
      while true; do
        counter=$((counter + 1))
        
        # Log current status
        status=$(cat /tmp/health/status)
        ready=$(cat /tmp/health/ready)
        alive=$(cat /tmp/health/alive)
        
        echo "$(date): Status=${status}, Ready=${ready}, Alive=${alive}, Counter=${counter}"
        
        # Simulate occasional issues
        if [ $((counter % 30)) -eq 0 ]; then
          echo "Simulating temporary unavailability..."
          echo "false" > /tmp/health/ready
          sleep 5
          echo "true" > /tmp/health/ready
          echo "Recovered from temporary issue"
        fi
        
        # Simulate rare crash (very rare)
        if [ $((counter % 100)) -eq 0 ]; then
          echo "Simulating application crash..."
          echo "false" > /tmp/health/alive
          sleep 3
          echo "true" > /tmp/health/alive
          echo "Application restarted"
        fi
        
        sleep 2
      done
    
    # Liveness probe - checks if app is alive
    livenessProbe:
      exec:
        command:
        - /bin/sh
        - -c
        - "test $(cat /tmp/health/alive) = 'true'"
      initialDelaySeconds: 15
      periodSeconds: 10
      timeoutSeconds: 3
      failureThreshold: 3
    
    # Readiness probe - checks if app is ready for traffic  
    readinessProbe:
      exec:
        command:
        - /bin/sh
        - -c
        - "test $(cat /tmp/health/ready) = 'true'"
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
    
    # Startup probe - checks if app has finished starting
    startupProbe:
      exec:
        command:
        - /bin/sh
        - -c
        - "test $(cat /tmp/health/status) = 'running'"
      initialDelaySeconds: 0
      periodSeconds: 2
      timeoutSeconds: 3
      failureThreshold: 15  # Allow 30 seconds to start
    
    ports:
    - containerPort: 8080
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/health-check-demo.yaml
    
    print_info "Starting health check demo..."
    print_info "Watch how the pod goes through different states..."
    
    # Monitor the pod startup
    for i in {1..15}; do
        echo "Checking pod status (attempt $i):"
        kubectl get pod health-check-demo -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATUS:.status.phase
        sleep 2
    done
    
    print_success "Health check demo is running! Let's see the health check behavior:"
    kubectl logs health-check-demo --tail=10
    
    wait_for_input
    
    print_info "Health check best practices:"
    echo "  ⏱️  Set appropriate timeouts and thresholds"
    echo "  🎯 Make health checks lightweight"
    echo "  🔄 Test dependencies in readiness probes"
    echo "  💔 Use liveness probes sparingly (they restart pods)"
    echo "  🚀 Use startup probes for slow-starting applications"
}

demo_logging_strategies() {
    print_header "Application Logging Strategies"
    
    print_info "Effective logging is crucial for understanding application behavior and troubleshooting issues."
    
    print_step "1. Structured logging vs unstructured logging"
    
    echo "Unstructured logging (bad):"
    echo '  [ERROR] 2024-01-15 10:30:00 - User login failed for user john.doe@example.com from IP 192.168.1.100'
    echo ""
    echo "Structured logging (good):"
    echo '  {"timestamp":"2024-01-15T10:30:00.123Z","level":"ERROR","event":"user_login_failed","user":"john.doe@example.com","ip":"192.168.1.100","reason":"invalid_password"}'
    
    wait_for_input
    
    print_step "2. Log levels and when to use them"
    
    echo "Log levels in order of severity:"
    echo "  🔍 TRACE: Very detailed debugging (usually disabled in production)"
    echo "  🐛 DEBUG: Detailed debugging information"
    echo "  ℹ️  INFO: General application flow"
    echo "  ⚠️  WARN: Something unexpected but recoverable"
    echo "  ❌ ERROR: Error conditions that need attention"
    echo "  💥 FATAL: Severe errors that stop the application"
    
    wait_for_input
    
    print_step "3. Logging demo application"
    
    cat << 'EOF' > /tmp/logging-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: logging-demo
  labels:
    app: logging-demo
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== STRUCTURED LOGGING DEMO ==="
      
      # Simulate a web application with proper logging
      user_id=1001
      session_id="sess-$(date +%s)"
      
      while true; do
        request_id="req-$(date +%s)-$(( RANDOM % 1000 ))"
        
        # INFO: Normal operation
        echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"INFO\",\"service\":\"user-service\",\"event\":\"request_received\",\"request_id\":\"${request_id}\",\"user_id\":${user_id},\"session_id\":\"${session_id}\",\"endpoint\":\"/api/users\"}"
        
        # DEBUG: Detailed processing info
        echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"DEBUG\",\"service\":\"user-service\",\"event\":\"database_query\",\"request_id\":\"${request_id}\",\"query\":\"SELECT * FROM users WHERE id = ${user_id}\",\"duration_ms\":$(( RANDOM % 100 + 10 ))}"
        
        # Simulate different scenarios
        scenario=$(( RANDOM % 10 ))
        
        if [ $scenario -eq 0 ]; then
          # ERROR: Something went wrong
          echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"ERROR\",\"service\":\"user-service\",\"event\":\"database_error\",\"request_id\":\"${request_id}\",\"error\":\"Connection timeout\",\"error_code\":\"DB_TIMEOUT\",\"retry_count\":3}"
          
        elif [ $scenario -eq 1 ]; then
          # WARN: Something unusual but recoverable
          echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"WARN\",\"service\":\"user-service\",\"event\":\"slow_query\",\"request_id\":\"${request_id}\",\"duration_ms\":$(( RANDOM % 1000 + 1000 )),\"threshold_ms\":1000}"
          
        else
          # INFO: Successful completion
          response_time=$(( RANDOM % 200 + 50 ))
          echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"INFO\",\"service\":\"user-service\",\"event\":\"request_completed\",\"request_id\":\"${request_id}\",\"status_code\":200,\"response_time_ms\":${response_time}}"
        fi
        
        user_id=$(( (user_id % 9999) + 1001 ))  # Cycle through user IDs
        sleep $(( RANDOM % 3 + 1 ))  # Random delay 1-3 seconds
      done
    ports:
    - containerPort: 8080
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/logging-demo.yaml
    
    print_info "Starting logging demo..."
    kubectl wait --for=condition=Ready pod/logging-demo --timeout=60s
    
    print_success "Logging demo is running! Let's see structured logs in action:"
    sleep 5
    kubectl logs logging-demo --tail=15
    
    print_info "Benefits of structured logging:"
    echo "  🔍 Easy to search and filter"
    echo "  📊 Can be parsed for metrics"
    echo "  🏷️  Consistent format across services"
    echo "  🤖 Machine-readable for automation"
    echo "  📈 Better for monitoring and alerting"
    
    wait_for_input
}

demo_metrics_collection() {
    print_header "Metrics Collection and Monitoring"
    
    print_info "Metrics help us understand system performance and health over time."
    
    print_step "1. Types of metrics"
    
    echo "Common metric types:"
    echo "  📊 COUNTER: Monotonically increasing values (e.g., requests_total)"
    echo "  📏 GAUGE: Values that can go up or down (e.g., memory_usage_bytes)"
    echo "  ⏱️  HISTOGRAM: Observations in buckets (e.g., request_duration_seconds)"
    echo "  📋 SUMMARY: Like histogram but calculates quantiles client-side"
    
    wait_for_input
    
    print_step "2. Application with metrics endpoint"
    
    cat << 'EOF' > /tmp/metrics-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: metrics-demo
  labels:
    app: metrics-demo
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== METRICS DEMO APPLICATION ==="
      
      # Initialize counters
      requests_total=0
      errors_total=0
      startup_time=$(date +%s)
      
      # Simulate metrics collection
      while true; do
        requests_total=$((requests_total + 1))
        
        # Simulate request processing
        response_time=$(( RANDOM % 500 + 50 ))  # 50-550ms
        memory_usage=$(( (RANDOM % 500 + 500) * 1024 * 1024 ))  # 500-1000MB
        cpu_usage=$(( RANDOM % 80 + 10 ))  # 10-90%
        
        # 5% error rate
        if [ $((RANDOM % 20)) -eq 0 ]; then
          errors_total=$((errors_total + 1))
        fi
        
        # Calculate uptime
        current_time=$(date +%s)
        uptime=$((current_time - startup_time))
        
        # Create Prometheus-style metrics
        cat > /tmp/metrics.txt << EOF
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/api/users"} ${requests_total}

# HELP http_request_errors_total Total number of HTTP request errors
# TYPE http_request_errors_total counter
http_request_errors_total{method="GET",endpoint="/api/users"} ${errors_total}

# HELP http_request_duration_seconds HTTP request duration in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"} $((requests_total / 10))
http_request_duration_seconds_bucket{le="0.5"} $((requests_total / 2))
http_request_duration_seconds_bucket{le="1.0"} $((requests_total * 9 / 10))
http_request_duration_seconds_bucket{le="+Inf"} ${requests_total}
http_request_duration_seconds_sum $(( requests_total * response_time / 1000 ))
http_request_duration_seconds_count ${requests_total}

# HELP memory_usage_bytes Current memory usage in bytes
# TYPE memory_usage_bytes gauge
memory_usage_bytes ${memory_usage}

# HELP cpu_usage_percent Current CPU usage percentage
# TYPE cpu_usage_percent gauge
cpu_usage_percent ${cpu_usage}

# HELP process_uptime_seconds Process uptime in seconds
# TYPE process_uptime_seconds counter
process_uptime_seconds ${uptime}
EOF

        # Display current metrics
        echo "$(date): Metrics updated - Requests: ${requests_total}, Errors: ${errors_total}, Uptime: ${uptime}s"
        
        # Show sample metrics
        if [ $((requests_total % 10)) -eq 0 ]; then
          echo "Sample metrics endpoint output:"
          head -10 /tmp/metrics.txt
          echo "..."
        fi
        
        sleep 3
      done
    ports:
    - containerPort: 8080
  restartPolicy: Never
EOF

    kubectl apply -f /tmp/metrics-demo.yaml
    
    print_info "Starting metrics demo..."
    kubectl wait --for=condition=Ready pod/metrics-demo --timeout=60s
    
    print_success "Metrics demo is running! Let's see metrics being generated:"
    sleep 8
    kubectl logs metrics-demo --tail=20
    
    print_info "Key metrics for applications:"
    echo "  📊 Request rate and response times"
    echo "  ❌ Error rates and types"
    echo "  💾 Resource usage (CPU, memory)"
    echo "  🔄 Throughput and latency"
    echo "  ⏱️  Application-specific business metrics"
    
    wait_for_input
}

demo_alerting_concepts() {
    print_header "Alerting and Incident Response"
    
    print_info "Effective alerting helps you know about problems before users do."
    
    print_step "1. Alerting best practices"
    
    echo "Good alerts are:"
    echo "  🎯 ACTIONABLE: You can do something about them"
    echo "  🔄 RELEVANT: They indicate real problems"
    echo "  ⏰ TIMELY: They fire before users are affected"
    echo "  📖 CLEAR: They explain what's wrong and what to do"
    
    print_step "2. Alert fatigue prevention"
    
    echo "Avoid alert fatigue by:"
    echo "  📊 Setting appropriate thresholds"
    echo "  ⏱️  Using proper time windows"
    echo "  🔄 Grouping related alerts"
    echo "  📱 Routing alerts to the right teams"
    echo "  🔇 Implementing alert suppression during maintenance"
    
    wait_for_input
    
    print_step "3. Sample alert rules"
    
    echo "Common alerting scenarios:"
    echo ""
    echo "High Error Rate:"
    echo "  📊 Metric: http_requests_total{status=~\"5..\"}"
    echo "  🎯 Threshold: > 5% for 2 minutes"
    echo "  🚨 Severity: Critical"
    echo ""
    echo "High Response Time:"
    echo "  📊 Metric: histogram_quantile(0.95, http_request_duration_seconds)"
    echo "  🎯 Threshold: > 1 second for 5 minutes"
    echo "  🚨 Severity: Warning"
    echo ""
    echo "Pod Crash Looping:"
    echo "  📊 Metric: kube_pod_container_status_restarts_total"
    echo "  🎯 Threshold: > 0 restarts in 15 minutes"
    echo "  🚨 Severity: Critical"
    
    wait_for_input
}

cleanup_demo() {
    print_header "Cleaning Up Demo Resources"
    
    print_info "Removing demo resources..."
    
    # Clean up pods
    kubectl delete pod --ignore-not-found=true \
        observability-demo health-check-demo logging-demo metrics-demo 2>/dev/null || true
    
    # Clean up files
    rm -f /tmp/observability-demo.yaml /tmp/health-check-demo.yaml \
          /tmp/logging-demo.yaml /tmp/metrics-demo.yaml
    
    print_info "Resources cleaned up!"
    print_warning "In production, you would deploy comprehensive monitoring solutions."
    print_info "Consider exploring: Prometheus, Grafana, Jaeger, FluentBit, AlertManager"
}

show_next_steps() {
    print_header "Next Steps"
    
    print_success "Congratulations! You've completed the Monitoring & Observability workshop!"
    
    print_info "What you've learned:"
    echo "  ✅ The three pillars of observability (metrics, logs, traces)"
    echo "  ✅ Resource monitoring with Metrics Server"
    echo "  ✅ Health checks and probe configuration"
    echo "  ✅ Structured logging strategies"
    echo "  ✅ Metrics collection and types"
    echo "  ✅ Alerting best practices"
    
    echo ""
    print_info "Recommended next steps:"
    echo "  1. Complete the exercises in the exercises/ directory"
    echo "  2. Try the module challenge"
    echo "  3. Set up a complete monitoring stack with Prometheus/Grafana"
    echo "  4. Read the full README.md for deeper understanding"
    echo "  5. Proceed to Module 8: Troubleshooting Mastery"
    
    echo ""
    print_info "Production monitoring components to explore:"
    echo "  📊 Prometheus: Metrics collection and storage"
    echo "  📈 Grafana: Visualization and dashboards"
    echo "  🔍 Jaeger: Distributed tracing"
    echo "  📝 Elasticsearch/FluentBit: Log aggregation"
    echo "  🚨 AlertManager: Alert routing and management"
}

# Main execution
main() {
    print_header "Kubernetes Monitoring & Observability Workshop"
    
    print_info "This interactive workshop will teach you:"
    echo "  • The three pillars of observability"
    echo "  • Resource monitoring and health checks"
    echo "  • Effective logging strategies"
    echo "  • Metrics collection and monitoring"
    echo "  • Alerting and incident response"
    echo "  • Building observable applications"
    
    wait_for_input
    
    check_prerequisites
    cleanup_previous
    demo_observability_pillars
    demo_resource_monitoring
    demo_health_checks
    demo_logging_strategies
    demo_metrics_collection
    demo_alerting_concepts
    cleanup_demo
    show_next_steps
    
    print_success "Workshop completed successfully!"
}

# Run the workshop
main "$@"