# 🏦 Banking DevOps Assessment

![CI/CD](https://img.shields.io/badge/CI%2FCD-Jenkins-blue)
![Docker](https://img.shields.io/badge/Docker-25.0.14-blue)
![Python](https://img.shields.io/badge/Python-3.11-green)
![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)
![AWS](https://img.shields.io/badge/Cloud-AWS-orange)
![Status](https://img.shields.io/badge/Build-Passing-brightgreen)

A cloud-native banking REST API deployed on AWS with a full DevOps pipeline including CI/CD, IaC, automated testing, artifact management, and dual monitoring.

---

## 🏗️ Architecture

```
INTERNET
    │
    ▼
┌─────────────────────────────────────────┐
│   Application Load Balancer (ALB)        │
│   banking-alb-1942364575.ap-southeast-2  │
│   .elb.amazonaws.com:80                  │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│   Instance 3 — App Server               │
│   172.31.8.218:8090                     │
│   Docker: banking-app:latest            │
│   PostgreSQL: bankdb                    │
└─────────────────────────────────────────┘

──────── CI/CD & TOOLING ────────

┌──────────────┐  ┌──────────────────┐  ┌─────────────┐  ┌──────────────┐
│   Jenkins    │  │ SonarQube+Nexus  │  │   Ansible   │  │    Splunk    │
│ 13.210.247.62│  │  16.176.220.31   │  │13.211.167.57│  │ 3.27.228.83  │
│    :8080     │  │  :9000 / :8081   │  │             │  │    :8000     │
└──────────────┘  └──────────────────┘  └─────────────┘  └──────────────┘
```

---

## 🖥️ Infrastructure

| Instance | Role | Public IP | Private IP | Type |
|----------|------|-----------|------------|------|
| Instance 1 | CI Server (Jenkins) | 13.210.247.62 | 172.31.2.141 | t3.medium |
| Instance 2 | Code Quality (SonarQube + Nexus) | 16.176.220.31 | 172.31.15.55 | t2.large |
| Instance 3 | Deploy Target | 3.25.111.45 | 172.31.8.218 | t3.small |
| Instance 4 | Ansible Control Node | 13.211.167.57 | 172.31.6.85 | t3.small |
| Instance 5 | Monitoring (Splunk) | 3.27.228.83 | 172.31.7.82 | t3.medium |

---

## 🚀 CI/CD Pipeline

GitHub Push → Jenkins → 7 stages:

```
Checkout → Install Dependencies → Unit Tests (15/15) →
SonarQube Analysis → Docker Build → Push to Nexus → Deploy → Health Check ✅
```

**Jenkins:** http://13.210.247.62:8080 | Job: `banking-app-pipeline`

---

## 📡 API Endpoints

Base URL: `http://banking-alb-1942364575.ap-southeast-2.elb.amazonaws.com`

All endpoints (except `/health`) require header: `X-API-Key: banking-secret-key-2024`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check (no auth) |
| POST | `/accounts` | Create account |
| GET | `/accounts/{acc}/balance` | Get balance |
| POST | `/accounts/{acc}/deposit` | Deposit money |
| POST | `/accounts/{acc}/withdraw` | Withdraw money |
| DELETE | `/accounts/{acc}` | Delete account |
| GET | `/accounts/{acc}/transactions` | Transaction history |

### Example Usage

```bash
# Health check
curl http://banking-alb-1942364575.ap-southeast-2.elb.amazonaws.com/health

# Create account
curl -X POST http://banking-alb-1942364575.ap-southeast-2.elb.amazonaws.com/accounts \
  -H "X-API-Key: banking-secret-key-2024" \
  -H "Content-Type: application/json" \
  -d '{"account_number":"ACC001","owner_name":"John Doe","initial_balance":1000}'

# Get balance
curl http://banking-alb-1942364575.ap-southeast-2.elb.amazonaws.com/accounts/ACC001/balance \
  -H "X-API-Key: banking-secret-key-2024"

# Deposit
curl -X POST http://banking-alb-1942364575.ap-southeast-2.elb.amazonaws.com/accounts/ACC001/deposit \
  -H "X-API-Key: banking-secret-key-2024" \
  -H "Content-Type: application/json" \
  -d '{"amount": 500}'

# Withdraw
curl -X POST http://banking-alb-1942364575.ap-southeast-2.elb.amazonaws.com/accounts/ACC001/withdraw \
  -H "X-API-Key: banking-secret-key-2024" \
  -H "Content-Type: application/json" \
  -d '{"amount": 200}'
```

---

## 🏗️ Repository Structure

```
banking-devops-assessment/
├── app/
│   ├── app.py              # Flask REST API
│   ├── requirements.txt    # Python dependencies
│   ├── Dockerfile          # Multi-stage Docker build
│   ├── docker-compose.yml  # Local development
│   └── test_app.py         # 15 unit tests
├── jenkins/
│   └── Jenkinsfile         # CI/CD pipeline (7 stages)
├── terraform/
│   ├── main.tf             # AWS infrastructure
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   └── terraform.tfvars.example
├── ansible/
│   ├── playbook.yml        # Deployment playbook
│   └── inventory.ini       # Host inventory
├── monitoring/
│   ├── splunk-inputs.conf  # Splunk forwarder config
│   └── splunk-outputs.conf # Splunk output config
└── README.md
```

---

## 🔧 Quick Setup

### 1. Clone Repository
```bash
git clone https://github.com/sathishkrishnan645-design/banking-devops-assessment.git
cd banking-devops-assessment
```

### 2. Provision Infrastructure (Terraform)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform plan && terraform apply
```

### 3. Deploy Application (Ansible)
```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

### 4. Run Locally (Docker)
```bash
cd app
docker build -t banking-app .
docker run -p 8090:8090 \
  -e DATABASE_URL=sqlite:///banking.db \
  -e API_KEY=your-api-key \
  banking-app
```

### 5. Run Tests
```bash
cd app
pip install -r requirements.txt pytest pytest-cov
export DATABASE_URL=sqlite:///:memory:
export API_KEY=banking-secret-key-2024
pytest test_app.py -v --cov=app
```

---

## 🔒 Security

- **API Authentication** — X-API-Key header on all endpoints
- **SSH** — Key-based authentication only
- **Network** — AWS Security Groups with least-privilege rules
- **Secrets** — AWS Secrets Manager for DB credentials and API keys
  - `banking-app/db-credentials`
  - `banking-app/api-key`
- **Nexus** — forceBasicAuth on Docker registry
- **Encryption** — RDS encryption at rest, EBS encryption

---

## 📊 Monitoring

### Splunk
- URL: http://3.27.228.83:8000
- Search: `index=main sourcetype=docker_logs`
- Forwarder installed on app server → forwards Docker logs

### AWS CloudWatch
- Log Group: `/banking-app/docker`
- Metrics: CPU, Memory, Disk (60s interval)
- **Alarms:**
  - `banking-app-high-cpu` — triggers at 80% CPU
  - `banking-app-high-memory` — triggers at 85% memory
  - `banking-app-high-disk` — triggers at 80% disk

---

## 🛠️ Service URLs

| Service | URL |
|---------|-----|
| Banking App (ALB) | http://banking-alb-1942364575.ap-southeast-2.elb.amazonaws.com |
| Jenkins | http://13.210.247.62:8080 |
| SonarQube | http://16.176.220.31:9000 |
| Nexus | http://16.176.220.31:8081 |
| Splunk | http://3.27.228.83:8000 |

---

## 👤 Author

**Sathish Krishnan** — Senior DevOps Engineer
