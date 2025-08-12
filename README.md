# 🚀 Kubernetes Learning Lab

> **A comprehensive, hands-on Kubernetes training platform with interactive exercises and real-world scenarios**

[![Platform](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://github.com/nixfred/kuber-learner)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-326ce5.svg)](https://kubernetes.io/)
[![Docker](https://img.shields.io/badge/Docker-Required-2496ed.svg)](https://docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🎯 Overview

This learning lab provides a structured, progressive path to mastering Kubernetes through hands-on practice. Built for engineers who want production-ready skills, not toy examples.

### ✨ Features

- **🎓 Interactive Learning**: Step-by-step guided exercises with instant feedback
- **🌐 Web-Based Dashboard**: Beautiful HTML interface to track progress
- **🔄 Progressive Modules**: Each module builds on previous knowledge
- **🏭 Production Focus**: Real-world scenarios and best practices
- **🧪 Hands-On Labs**: Practice with actual Kubernetes clusters
- **📊 Progress Tracking**: Monitor your learning journey
- **🏆 Achievements**: Unlock badges as you complete modules

## 🚦 Quick Start

### Prerequisites

- Ubuntu 22.04/24.04 (or compatible Linux)
- Docker installed and running
- 4GB+ RAM available
- 20GB+ free disk space

### Installation

```bash
# Clone the repository
git clone https://github.com/nixfred/kuber-learner.git
cd kuber-learner

# Start the interactive trainer
./trainer/trainer.sh

# Or open the web dashboard
open trainer/index.html
```

## 📚 Learning Modules

### Module 1: Cluster Setup & Architecture
- Install and configure kind
- Create single and multi-node clusters
- Understand Kubernetes components
- Configure kubectl

### Module 2: Pods & Container Basics
- Pod lifecycle and management
- Multi-container patterns
- Debugging techniques
- Port forwarding

### Module 3: Workload Controllers
- Deployments and ReplicaSets
- StatefulSets for stateful apps
- DaemonSets and Jobs
- Rolling updates and rollbacks

### Module 4: Services & Networking
- Service types (ClusterIP, NodePort, LoadBalancer)
- Ingress controllers
- Network policies
- DNS and service discovery

### Module 5: Configuration & Secrets
- ConfigMaps for configuration
- Secrets management
- Environment variables
- Volume mounts

### Module 6: Storage Solutions
- Persistent Volumes (PV)
- Persistent Volume Claims (PVC)
- StorageClasses
- Dynamic provisioning

### Module 7: Monitoring & Observability
- Metrics Server setup
- Resource monitoring
- Logging strategies
- Health checks and probes

### Module 8: Troubleshooting Mastery
- Common failure patterns
- Debugging techniques
- Performance optimization
- Chaos engineering

### Module 9: Production Applications
- Multi-tier architectures
- Database deployments
- Auto-scaling strategies
- Security hardening

## 🎮 Interactive Trainer

Start your learning journey with our interactive CLI trainer:

```bash
./trainer/trainer.sh
```

Features:
- Guided learning path
- Progress tracking
- Interactive exercises
- Instant validation
- Achievement system

## 🌐 Web Dashboard

Access the beautiful web interface:

```bash
# Open in your browser
open trainer/index.html

# Or serve it locally
python3 -m http.server 8000 -d trainer
# Visit http://localhost:8000
```

## 🛠️ Makefile Commands

Use our Makefile for common operations:

```bash
# Setup everything
make setup

# Start learning
make start

# Check cluster status
make status

# Run tests
make test

# Clean up resources
make clean

# Full reset
make reset
```

## 📂 Project Structure

```
kuber-learner/
├── 01-cluster-setup/       # Module 1: Cluster setup
│   ├── README.md          # Module documentation
│   ├── start.sh           # Interactive lesson
│   ├── exercises/         # Hands-on exercises
│   └── manifests/         # YAML configurations
├── 02-pods-basics/        # Module 2: Pods
├── 03-workloads/          # Module 3: Controllers
├── ...                    # More modules
├── trainer/               # Training system
│   ├── trainer.sh         # CLI trainer
│   └── index.html         # Web dashboard
├── scripts/               # Utility scripts
├── platform-architecture.md # Web platform design
└── README.md              # This file
```

## 🚀 Advanced: Web Platform Deployment

Transform this into a multi-user web platform:

```bash
# Review the architecture
cat platform-architecture.md

# Deploy the platform (coming soon)
kubectl apply -f platform/
```

See [platform-architecture.md](platform-architecture.md) for details on hosting this as a service.

## 🧪 Testing Your Knowledge

Each module includes:
- **Exercises**: Hands-on practice with validation
- **Challenges**: Complex scenarios to solve
- **Knowledge Checks**: Test your understanding

Run module tests:
```bash
cd 01-cluster-setup
./test/knowledge-check.sh
```

## 🐛 Troubleshooting

### Docker Issues
```bash
# Check Docker status
systemctl status docker

# Start Docker
sudo systemctl start docker
```

### Cluster Creation Fails
```bash
# Clean up and retry
kind delete cluster --name k8s-learning
docker system prune -a
```

### Port Already in Use
```bash
# Find and kill process
lsof -i :8080
kill <PID>
```

## 📖 Learning Tips

1. **Complete modules in order** - Each builds on previous concepts
2. **Practice regularly** - Consistency is key
3. **Experiment freely** - Break things and learn to fix them
4. **Read the errors** - Kubernetes errors are informative
5. **Use the documentation** - Official docs are excellent

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

Areas for contribution:
- Additional exercises
- More troubleshooting scenarios
- Language translations
- Platform improvements

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

## 🙏 Acknowledgments

- Kubernetes community for excellent documentation
- kind project for local Kubernetes clusters
- All contributors and learners

## 📮 Support

- **Issues**: [GitHub Issues](https://github.com/nixfred/kuber-learner/issues)
- **Discussions**: [GitHub Discussions](https://github.com/nixfred/kuber-learner/discussions)

## 🎯 Roadmap

- [x] Core learning modules
- [x] Interactive trainer
- [x] Web dashboard
- [ ] Video tutorials
- [ ] Multi-user web platform
- [ ] Cloud deployment options
- [ ] Certificate generation
- [ ] Advanced scenarios

---

**Happy Learning! 🚀**

*Master Kubernetes one module at a time with hands-on practice and real-world scenarios.*