# AccuKnox QA Trainee Practical Assessment

Complete implementation for the **AccuKnox QA Trainee Practical Assessment**, covering containerization, Kubernetes deployment with TLS termination, automated CI/CD via GitHub Actions, and Linux system/application health monitoring scripts.

## Repository Structure

```text
accuknox-qa-assessment/
├── README.md                        # Setup, architecture, and verification guide
├── wisecow.sh                       # Wisecow HTTP fortune server (port 4499)
├── Dockerfile                       # Ubuntu container definition for Wisecow
├── k8s/
│   ├── deployment.yaml              # Kubernetes Deployment (2 replicas + TCP probes)
│   ├── service.yaml                 # Kubernetes ClusterIP Service (port 80 -> 4499)
│   └── ingress.yaml                 # NGINX Ingress with TLS termination
├── .github/
│   └── workflows/
│       └── ci-cd.yml                # GitHub Actions CI/CD build & K8s deploy workflow
└── scripts/
    ├── system_health_monitor.sh     # Bash Linux CPU/Memory/Disk/Process monitor
    └── app_health_checker.py        # Python HTTP/HTTPS uptime & status checker
```

---

## Problem Statement 1: Wisecow Containerization & Kubernetes Deployment

### 1. Local Docker Build & Test
```bash
docker build -t wisecow:local .
docker run -d -p 4499:4499 --name wisecow-test wisecow:local
curl http://localhost:4499
```

### 2. Kubernetes & TLS Deployment (Minikube / Cluster)
Enable the NGINX Ingress controller and create a TLS secret for `wisecow.local`:
```bash
minikube addons enable ingress

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=wisecow.local/O=wisecow" \
  -addext "subjectAltName=DNS:wisecow.local"

kubectl create secret tls wisecow-tls --key tls.key --cert tls.crt
kubectl apply -f k8s/
```
Map `wisecow.local` to your Ingress IP in `/etc/hosts` and verify HTTPS:
```bash
curl -k [https://wisecow.local](https://wisecow.local)
```

### 3. GitHub Actions CI/CD Secrets
Configure these secrets under **Settings → Secrets and variables → Actions**:
* `DOCKERHUB_USERNAME`: Your Docker Hub username
* `DOCKERHUB_TOKEN`: Docker Hub Personal Access Token (Read/Write)
* `KUBE_CONFIG`: Base64-encoded kubeconfig (`cat ~/.kube/config | base64 -w 0`)

---

## Problem Statement 2: Health Monitoring Scripts

### 1. System Health Monitoring Script (`scripts/system_health_monitor.sh`)
Monitors CPU usage, memory usage, root disk usage, and running process count against predefined thresholds (`CPU > 80%`, `Memory > 80%`, `Disk > 85%`, `Processes > 300`), logging alerts to console and `/var/log/system_health.log` (or `./system_health.log`).
```bash
chmod +x scripts/system_health_monitor.sh
./scripts/system_health_monitor.sh
```

### 2. Application Health Checker (`scripts/app_health_checker.py`)
Checks HTTP/HTTPS status codes (`200–399` = `UP`, `4xx/5xx`/timeout = `DOWN`) and logs latency to console and `app_health.log`:
```bash
python3 scripts/app_health_checker.py [https://wisecow.local](https://wisecow.local) --insecure
```
