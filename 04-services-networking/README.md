# Module 4: Services & Networking - Connecting Your Applications

## 🎯 Learning Objectives

By the end of this module, you will deeply understand:
- ✅ WHY pods need Services (the networking problem)
- ✅ How Kubernetes networking model works
- ✅ Service types and when to use each
- ✅ How DNS works in Kubernetes
- ✅ Ingress controllers for external access
- ✅ Network policies for security
- ✅ Debugging connectivity issues

## 🤔 The Networking Challenge

Consider these problems:
1. **Pods are ephemeral** - IPs change when pods restart
2. **Load balancing** - How to distribute traffic across replicas?
3. **Service discovery** - How do pods find each other?
4. **External access** - How do users reach your app?
5. **Security** - How to control traffic between pods?

**Services and Networking solve these problems!**

## 📚 Prerequisites

- ✅ Completed Module 3: Workload Controllers
- ✅ Understanding of Deployments and Pods
- ✅ Basic networking knowledge (IP, ports, DNS)

## 🚀 Quick Start

```bash
# Start the interactive lesson
./start.sh

# This module is very hands-on with lots of testing!
```

## 📖 Lesson 1: Understanding the Problem

### Life Without Services

Let's experience the problem firsthand:

```bash
# Deploy an application
kubectl create deployment backend --image=nginx:alpine --replicas=3

# Get pod IPs
kubectl get pods -l app=backend -o wide

# Note the IPs - they're ephemeral!
```

Now try to connect from another pod:

```bash
# Create a client pod
kubectl run client --image=busybox:1.28 --rm -it --restart=Never -- sh

# Inside the client pod, try to connect
wget -O- <pod-ip>:80  # Works!

# But what happens when the pod restarts?
exit

# Delete a backend pod
kubectl delete pod <backend-pod-name>

# Check new pod IP
kubectl get pods -l app=backend -o wide

# The IP changed! Your hardcoded connection would break!
```

### The Solution: Services

Services provide:
- **Stable endpoint** - Doesn't change
- **Load balancing** - Distributes traffic
- **Service discovery** - DNS names
- **Health checking** - Only routes to healthy pods

## 📖 Lesson 2: Service Types Deep Dive

### ClusterIP - Internal Only

The default Service type, accessible only within the cluster:

```yaml
# clusterip-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP  # Default type
  selector:
    app: backend   # Selects pods with this label
  ports:
  - port: 80       # Service port
    targetPort: 80 # Pod port
    protocol: TCP
```

Understanding the flow:
```
Client Pod → Service (ClusterIP) → Selected Pods
         ↓
   DNS: backend-service
         ↓
   IP: 10.96.x.x (stable)
         ↓
   Load Balances to:
   - Pod 1 (10.244.1.5)
   - Pod 2 (10.244.2.7)
   - Pod 3 (10.244.3.9)
```

### Testing ClusterIP

```bash
# Create the service
kubectl apply -f manifests/clusterip-service.yaml

# Check the service
kubectl get service backend-service

# Test from a client pod
kubectl run test-client --image=busybox:1.28 --rm -it --restart=Never -- sh

# Inside the pod:
# Test using service name (DNS)
wget -O- backend-service

# Test using service IP
wget -O- <service-cluster-ip>

# Both work! And load balance across pods!
exit
```

### NodePort - External Access via Node

Exposes the service on each node's IP at a static port:

```yaml
# nodeport-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80         # Service port
    targetPort: 80   # Pod port
    nodePort: 30080  # Node port (30000-32767)
```

Understanding NodePort:
```
External Client
       ↓
Node IP:30080
       ↓
Service (NodePort)
       ↓
Selected Pods
```

### Testing NodePort

```bash
# Create a frontend deployment
kubectl create deployment frontend --image=nginx:alpine --replicas=2

# Create NodePort service
kubectl apply -f manifests/nodeport-service.yaml

# Get node IP (in kind, it's localhost)
kubectl get nodes -o wide

# Access from outside cluster
curl localhost:30080

# Works from any node in the cluster!
```

### LoadBalancer - Cloud Provider Integration

In cloud environments, creates an external load balancer:

```yaml
# loadbalancer-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 80
```

Note: In kind/minikube, LoadBalancer won't get an external IP. Use in real cloud environments.

### ExternalName - DNS Alias

Maps a service to an external DNS name:

```yaml
# externalname-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
```

Use case: Abstracting external services, making migration easier.

## 📖 Lesson 3: Service Discovery & DNS

### How DNS Works in Kubernetes

Every Service gets a DNS entry:
```
<service-name>.<namespace>.svc.cluster.local
```

Examples:
- `backend-service.default.svc.cluster.local`
- `backend-service.default` (same namespace)
- `backend-service` (same namespace, short form)

### Testing DNS

```bash
# Create services in different namespaces
kubectl create namespace production
kubectl create deployment web --image=nginx:alpine -n production
kubectl expose deployment web --port=80 -n production

# Test DNS resolution
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- sh

# Inside the pod:
# Short name (only works in same namespace)
nslookup web  # Fails!

# Namespace qualified
nslookup web.production  # Works!

# Fully qualified
nslookup web.production.svc.cluster.local  # Works!

exit
```

### Headless Services

For when you need direct pod IPs, not load balancing:

```yaml
# headless-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: headless-db
spec:
  clusterIP: None  # This makes it headless
  selector:
    app: database
  ports:
  - port: 5432
```

Use case: StatefulSets, databases that handle their own clustering.

## 📖 Lesson 4: Ingress - Smart HTTP Routing

### The Problem Ingress Solves

Without Ingress:
- Need multiple LoadBalancers (expensive)
- Or multiple NodePorts (port management nightmare)

With Ingress:
- Single entry point
- Path-based routing
- Host-based routing
- SSL termination

### Understanding Ingress

```
Internet
    ↓
Ingress Controller (nginx/traefik)
    ↓
Routing Rules:
- /api → api-service
- /web → web-service
- app.com → app-service
```

### Installing Ingress Controller (nginx)

```bash
# For kind clusters
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### Creating Ingress Rules

```yaml
# ingress-rules.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### Testing Ingress

```bash
# Create services
kubectl create deployment api --image=hashicorp/http-echo -- -text="API Response"
kubectl expose deployment api --name=api-service --port=80 --target-port=5678

kubectl create deployment web --image=hashicorp/http-echo -- -text="Web Response"
kubectl expose deployment web --name=web-service --port=80 --target-port=5678

# Apply ingress
kubectl apply -f manifests/ingress-rules.yaml

# Test routing
curl localhost/api  # Returns "API Response"
curl localhost/web  # Returns "Web Response"
```

## 📖 Lesson 5: Network Policies - Security

### Default Behavior

By default, all pods can communicate with all other pods. Network Policies add restrictions.

### Understanding Network Policies

Think of them as firewall rules:
- Applied to pods via labels
- Can control ingress (incoming) and egress (outgoing)
- Default deny when policy exists

### Example: Database Isolation

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-netpol
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: backend
    ports:
    - protocol: TCP
      port: 5432
```

This means:
- Applies to pods with label `app: database`
- Only allows traffic from pods with label `role: backend`
- Only on port 5432

### Testing Network Policies

```bash
# Create isolated database
kubectl run database --image=nginx:alpine --labels="app=database" --port=80
kubectl expose pod database --port=80

# Test connection (should work)
kubectl run test1 --image=busybox:1.28 --rm -it --restart=Never -- wget -O- database

# Apply network policy
kubectl apply -f manifests/network-policy.yaml

# Test again (should fail - no role label)
kubectl run test2 --image=busybox:1.28 --rm -it --restart=Never -- wget -O- database --timeout=5

# Test with correct label (should work)
kubectl run test3 --image=busybox:1.28 --labels="role=backend" --rm -it --restart=Never -- wget -O- database
```

## 📖 Lesson 6: Debugging Network Issues

### Common Problems and Solutions

#### 1. Service Not Reachable

```bash
# Check if service exists
kubectl get svc

# Check endpoints (are pods selected?)
kubectl get endpoints <service-name>

# Check selector labels match
kubectl get svc <service-name> -o yaml
kubectl get pods --show-labels
```

#### 2. DNS Not Resolving

```bash
# Test DNS
kubectl run dns-debug --image=busybox:1.28 --rm -it --restart=Never -- nslookup <service-name>

# Check CoreDNS is running
kubectl get pods -n kube-system | grep coredns
```

#### 3. Connection Timeouts

```bash
# Check network policies
kubectl get networkpolicies

# Test from different pod
kubectl run test --image=busybox:1.28 --rm -it --restart=Never -- sh
wget -O- <service-name> --timeout=5
```

### Debugging Tools

```bash
# Use netshoot for advanced debugging
kubectl run netshoot --image=nicolaka/netshoot --rm -it --restart=Never -- sh

# Inside netshoot:
# DNS lookup
dig backend-service.default.svc.cluster.local

# Port scanning
nc -zv backend-service 80

# Trace route
traceroute backend-service

# Check connectivity
curl backend-service
```

## 🏆 Module Challenge: Build a Microservices Network

Design and implement:
1. Frontend service (public access via Ingress)
2. API service (internal only)
3. Database service (restricted access)
4. Cache service (internal only)

Requirements:
- Frontend accessible at `/`
- API accessible at `/api`
- Database only accessible from API
- Implement proper network policies

```bash
./challenge/networking-challenge.sh
```

## 💡 Key Networking Concepts

1. **Every Pod gets a unique IP** - No NAT between pods
2. **Services provide stable endpoints** - Abstract pod IPs
3. **DNS enables service discovery** - Use names, not IPs
4. **Ingress manages external access** - L7 routing
5. **Network Policies control traffic** - Security boundaries

## 🔍 Troubleshooting Checklist

```bash
# Service issues
kubectl get svc
kubectl describe svc <name>
kubectl get endpoints <name>

# DNS issues
kubectl get pods -n kube-system | grep dns
kubectl logs -n kube-system <coredns-pod>

# Ingress issues
kubectl get ingress
kubectl describe ingress <name>
kubectl logs -n ingress-nginx <controller-pod>

# Network policy issues
kubectl get netpol
kubectl describe netpol <name>
```

## 📚 Additional Resources

- [Kubernetes Networking Model](https://kubernetes.io/docs/concepts/services-networking/)
- [Service Types](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types)
- [Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

## ✅ Module Completion

You now understand Kubernetes networking from the ground up!

### Skills Mastered
- Service types and use cases
- DNS and service discovery
- Ingress routing strategies
- Network security with policies
- Debugging connectivity issues

### Next Steps
```bash
# Mark module complete
./complete.sh

# Continue to Module 5: Configuration & Secrets
cd ../05-config-secrets
```