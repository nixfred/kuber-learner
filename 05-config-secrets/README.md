# Module 5: Configuration & Secrets - Managing Application Settings

## 🎯 Learning Objectives

By the end of this module, you will deeply understand:
- ✅ WHY configuration should be separate from code
- ✅ ConfigMaps vs Secrets - when to use each
- ✅ Different ways to inject configuration
- ✅ Secret management best practices
- ✅ Real-world configuration patterns
- ✅ How to debug configuration issues

## 🤔 The Configuration Problem

Consider these scenarios:
1. **Different environments** - Dev uses different database than production
2. **Sensitive data** - API keys shouldn't be in your code
3. **Dynamic updates** - Change config without rebuilding images
4. **Shared configuration** - Multiple apps need same settings

**ConfigMaps and Secrets solve these problems!**

## 📚 Prerequisites

- ✅ Completed Module 4: Services & Networking
- ✅ Understanding of pods and deployments
- ✅ Basic understanding of environment variables

## 🚀 Quick Start

```bash
# Start the interactive lesson
./start.sh

# We'll explore configuration step-by-step
```

## 📖 Lesson 1: The Configuration Anti-Pattern

### What NOT to Do

Let's see why hardcoding is bad:

```dockerfile
# BAD: Configuration in Dockerfile
FROM node:14
ENV DATABASE_URL="postgres://prod-server/mydb"
ENV API_KEY="sk-1234567890abcdef"
COPY . .
CMD ["node", "app.js"]
```

Problems:
- Need different images for dev/staging/prod
- Secrets visible in image layers
- Can't change without rebuild
- API keys in version control!

### The Kubernetes Way

Separate configuration from application:
```
Application Image (immutable)
    +
Configuration (environment-specific)
    =
Running Application
```

## 📖 Lesson 2: ConfigMaps - Non-Sensitive Configuration

### What Are ConfigMaps?

ConfigMaps store non-sensitive configuration data:
- Database hostnames
- Feature flags
- Application settings
- Configuration files

### Creating ConfigMaps

Method 1: From literal values
```bash
kubectl create configmap app-config \
  --from-literal=database_host=db.example.com \
  --from-literal=feature_flag=enabled \
  --from-literal=max_connections=100
```

Method 2: From a file
```bash
# Create a config file
cat > app.properties <<EOF
database.host=db.example.com
database.port=5432
cache.size=1000
feature.newUI=true
EOF

kubectl create configmap app-config --from-file=app.properties
```

Method 3: From YAML
```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DATABASE_HOST: "db.example.com"
  DATABASE_PORT: "5432"
  LOG_LEVEL: "info"
  # Can include entire files
  nginx.conf: |
    server {
      listen 80;
      server_name example.com;
      location / {
        proxy_pass http://backend;
      }
    }
```

### Using ConfigMaps - Environment Variables

```yaml
# pod-with-env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "DB Host: $DATABASE_HOST"; sleep 3600']
    env:
    # Individual values
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: DATABASE_HOST
    # All values from ConfigMap
    envFrom:
    - configMapRef:
        name: app-config
```

### Using ConfigMaps - Volume Mounts

```yaml
# pod-with-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: config-volume
    configMap:
      name: app-config
      items:
      - key: nginx.conf
        path: default.conf
```

### Testing ConfigMap Updates

```bash
# Create a ConfigMap
kubectl create configmap live-config --from-literal=message="Hello"

# Create a pod that uses it as a volume
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: config-reader
spec:
  containers:
  - name: reader
    image: busybox
    command: ['sh', '-c', 'while true; do cat /config/message; sleep 5; done']
    volumeMounts:
    - name: config
      mountPath: /config
  volumes:
  - name: config
    configMap:
      name: live-config
EOF

# Watch the logs
kubectl logs -f config-reader &

# Update the ConfigMap
kubectl edit configmap live-config
# Change message to "Updated!"

# Watch the logs change (may take up to a minute)
```

## 📖 Lesson 3: Secrets - Sensitive Data

### What Are Secrets?

Secrets store sensitive data:
- Passwords
- API keys
- TLS certificates
- SSH keys
- OAuth tokens

### How Secrets Differ from ConfigMaps

| ConfigMap | Secret |
|-----------|--------|
| Plain text | Base64 encoded (not encrypted!) |
| For configuration | For sensitive data |
| Shown in describe | Hidden in describe |
| No size limit* | 1MB limit |

*ConfigMaps have a 1MB limit too, but it's not enforced as strictly

### Creating Secrets

Method 1: Generic secret from literals
```bash
kubectl create secret generic db-secret \
  --from-literal=username=dbuser \
  --from-literal=password='S3cur3P@ssw0rd!'
```

Method 2: From files
```bash
# Create files with sensitive data
echo -n 'admin' > username.txt
echo -n 'secretpassword' > password.txt

kubectl create secret generic user-pass \
  --from-file=username=username.txt \
  --from-file=password=password.txt
```

Method 3: YAML (base64 encoded)
```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: YWRtaW4=  # echo -n 'admin' | base64
  password: c2VjcmV0  # echo -n 'secret' | base64
```

### Special Secret Types

TLS Secrets:
```bash
# Create TLS secret
kubectl create secret tls tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
```

Docker Registry Secrets:
```bash
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=myemail@example.com
```

### Using Secrets

```yaml
# pod-with-secrets.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "User: $DB_USER Pass: $DB_PASS"; sleep 3600']
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
  # For pulling private images
  imagePullSecrets:
  - name: regcred
```

### Security Best Practices

1. **Secrets are NOT encrypted by default** - Only base64 encoded
2. **Enable encryption at rest** - Configure etcd encryption
3. **Use RBAC** - Limit who can read secrets
4. **Rotate regularly** - Change secrets periodically
5. **Never commit to Git** - Use sealed-secrets or external secret managers
6. **Audit access** - Log secret access

## 📖 Lesson 4: Real-World Patterns

### Pattern 1: Environment-Specific Configs

```yaml
# dev-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: dev
data:
  DATABASE_HOST: "dev-db.local"
  LOG_LEVEL: "debug"
---
# prod-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: prod
data:
  DATABASE_HOST: "prod-db.aws.com"
  LOG_LEVEL: "error"
```

### Pattern 2: Configuration Hot Reload

```yaml
# deployment-with-reload.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    metadata:
      annotations:
        # Change this to trigger pod restart on config change
        configHash: "{{ .ConfigMapHash }}"
    spec:
      containers:
      - name: app
        image: myapp:latest
        volumeMounts:
        - name: config
          mountPath: /etc/config
      volumes:
      - name: config
        configMap:
          name: app-config
```

### Pattern 3: External Secret Management

```bash
# Using Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Create a sealed secret
echo -n mypassword | kubectl create secret generic mysecret --dry-run=client --from-file=password=/dev/stdin -o yaml | kubeseal -o yaml > mysealedsecret.yaml

# Now mysealedsecret.yaml is safe to commit to Git!
```

## 📖 Lesson 5: Debugging Configuration Issues

### Common Problems

#### 1. ConfigMap/Secret Not Found
```bash
# Check if it exists
kubectl get configmap
kubectl get secret

# Check namespace
kubectl get configmap -n <namespace>
```

#### 2. Key Not Found
```bash
# Check keys in ConfigMap
kubectl describe configmap <name>

# Check keys in Secret
kubectl get secret <name> -o jsonpath='{.data}' | jq 'keys'
```

#### 3. Environment Variable Not Set
```bash
# Check pod environment
kubectl exec <pod> -- env | grep <VAR_NAME>

# Check pod spec
kubectl get pod <pod> -o yaml | grep -A10 env:
```

#### 4. Volume Mount Issues
```bash
# Check if files are mounted
kubectl exec <pod> -- ls -la /mount/path

# Check volume mounts
kubectl describe pod <pod> | grep -A10 Mounts:
```

### Testing Configuration

```bash
# Test ConfigMap
kubectl run test --image=busybox --rm -it --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"test","image":"busybox","env":[{"name":"TEST","valueFrom":{"configMapKeyRef":{"name":"my-config","key":"mykey"}}}]}]}}' \
  -- sh -c 'echo $TEST'

# Test Secret
kubectl run test --image=busybox --rm -it --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"test","image":"busybox","env":[{"name":"SECRET","valueFrom":{"secretKeyRef":{"name":"my-secret","key":"password"}}}]}]}}' \
  -- sh -c 'echo $SECRET'
```

## 🏆 Module Challenge: Secure Application Configuration

Build a complete configuration setup:
1. Create environment-specific configs (dev/prod)
2. Store database credentials securely
3. Implement configuration hot-reload
4. Use both env vars and volume mounts
5. Implement proper RBAC for secrets

```bash
./challenge/config-challenge.sh
```

## 💡 Key Takeaways

1. **Separate config from code** - 12-factor app principles
2. **ConfigMaps for non-sensitive** - Feature flags, URLs, settings
3. **Secrets for sensitive** - Passwords, keys, tokens
4. **Multiple injection methods** - Env vars, volumes, command args
5. **Secrets aren't encrypted** - Need additional security measures
6. **Configuration as code** - Version control your configs (not secrets!)

## 🔍 Configuration Debugging Checklist

```bash
# List all configs
kubectl get configmap,secret

# Describe specific config
kubectl describe configmap <name>
kubectl get secret <name> -o yaml

# Check pod's env vars
kubectl exec <pod> -- env

# Check mounted files
kubectl exec <pod> -- ls -la /config/

# Verify pod spec
kubectl get pod <pod> -o yaml | less

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

## 📚 Additional Resources

- [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Best Practices](https://kubernetes.io/docs/concepts/configuration/secret/#best-practices)
- [Sealed Secrets](https://sealed-secrets.netlify.app/)

## ✅ Module Completion

You now understand configuration management in Kubernetes!

### Skills Mastered
- ConfigMap and Secret creation
- Environment variables vs volume mounts
- Security best practices
- Configuration patterns
- Debugging configuration issues

### Next Steps
```bash
# Mark module complete
./complete.sh

# Continue to Module 6: Storage Solutions
cd ../06-storage
```