# 🏦 Banking DevOps Assessment

A production-ready cloud infrastructure for a secure banking REST API, built with AWS, Docker, Jenkins, Ansible, JFrog Artifactory, SonarQube, and Splunk.

---

## 🏗️ Architecture Overview

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│                    AWS Cloud (ap-southeast-2)            │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │           Application Load Balancer (ALB)         │   │
│  │              HTTPS :443 / HTTP :80→443            │   │
│  └────────────────────┬─────────────────────────────┘   │
│                        │                                  │
│  ┌─────────────────────▼────────────────────────────┐   │
│  │  Private Subnet                                   │   │
│  │  ┌──────────────────┐   ┌──────────────────────┐ │   │
│  │  │  EC2 App Server  │   │   RDS PostgreSQL      │ │   │
│  │  │  banking-app     │──▶│   (encrypted at rest) │ │   │
│  │  │  :8090           │   │   :5432               │ │   │
│  │  └──────────────────┘   └──────────────────────┘ │   │
│  └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

DevOps Lab (EC2 Instances)
┌──────────────────────────────────────────────────────────┐
│  Jenkins (CI)       13.210.247.62:8080                   │
│  SonarQube          16.176.220.31:9000                   │
│  JFrog Artifactory  3.25.174.66:8081                     │
│  Ansible Control    13.211.167.57                        │
│  Splunk (Monitor)   3.27.228.83:8000                     │
└──────────────────────────────────────────────────────────┘
```

## 🔄 CI/CD Pipeline Flow

```
GitHub Push
    ↓
Jenkins Pipeline
    ├── 1. Checkout Code
    ├── 2. Install Dependencies
    ├── 3. Run Unit Tests (pytest + coverage)
    ├── 4. SonarQube Code Analysis
    ├── 5. Quality Gate Check
    ├── 6. Docker Build
    ├── 7. Push to JFrog Artifactory
    ├── 8. Ansible Deploy to App Server
    └── 9. Health Check
```

---

## 📁 Repository Structure

```
banking-devops-assessment/
├── app/
│   ├── app.py                  # Flask REST API
│   ├── test_app.py             # Unit tests
│   ├── requirements.txt
│   ├── Dockerfile              # Multi-stage Docker build
│   ├── docker-compose.yml      # Local development
│   └── .env.example
├── terraform/
│   ├── main.tf                 # VPC, EC2, RDS, ALB, IAM
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── ansible/
│   ├── playbook.yml            # Deploy app via Ansible
│   ├── inventory.ini
│   ├── ansible.cfg
│   └── group_vars/all/vault.yml.example
├── jenkins/
│   └── Jenkinsfile             # Full CI/CD pipeline
├── monitoring/
│   ├── splunk-inputs.conf
│   ├── splunk-outputs.conf
│   └── setup-splunk-forwarder.yml
└── docs/
    └── architecture-diagram.png
```

---

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/YOUR_USERNAME/banking-devops-assessment.git
cd banking-devops-assessment
```

### 2. Run Locally with Docker Compose
```bash
cd app
cp .env.example .env        # Edit with your values
docker-compose up --build
```

Test the API:
```bash
# Health check
curl http://localhost:8090/health

# Create account
curl -X POST http://localhost:8090/accounts \
  -H "X-API-Key: changeme-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"account_number":"ACC001","owner_name":"John Doe","initial_balance":1000}'

# Check balance
curl http://localhost:8090/accounts/ACC001/balance \
  -H "X-API-Key: changeme-secret-key"

# Deposit
curl -X POST http://localhost:8090/accounts/ACC001/deposit \
  -H "X-API-Key: changeme-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"amount": 500}'

# Withdraw
curl -X POST http://localhost:8090/accounts/ACC001/withdraw \
  -H "X-API-Key: changeme-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"amount": 200}'
```

### 3. Run Tests
```bash
cd app
pip install -r requirements.txt pytest pytest-cov
pytest test_app.py -v --cov=app
```

---

## ☁️ AWS Infrastructure Setup (Terraform)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

---

## 🔧 Jenkins Setup

1. Install plugins: `Git`, `SonarQube Scanner`, `Pipeline`, `SSH Agent`, `HTML Publisher`
2. Add credentials in Jenkins:
   - `github-credentials` — GitHub username/token
   - `jfrog-credentials` — JFrog username/password
   - `ansible-ssh-key` — SSH private key for Ansible control node
3. Configure SonarQube server at `http://16.176.220.31:9000`
4. Create a Pipeline job pointing to this repo's `jenkins/Jenkinsfile`

---

## 🔒 Security Measures

| Layer | Measure |
|-------|---------|
| **API** | X-API-Key authentication on all endpoints |
| **Transport** | HTTPS via ALB with TLS 1.3 |
| **Data at rest** | RDS storage encryption, EC2 EBS encryption |
| **Network** | Security groups: ALB→App→RDS (least privilege) |
| **Container** | Non-root user in Docker, multi-stage build |
| **Secrets** | Ansible Vault, environment variables, never hardcoded |
| **Firewall** | UFW on app server (deny all, allow 22 + 8090 only) |

---

## 📊 Monitoring & Logging

- **Splunk** dashboard at `http://3.27.228.83:8000`
- Indexes: `banking_app` (app logs), `os_security` (auth + firewall)
- Install Splunk forwarder on app server:
  ```bash
  ansible-playbook -i ansible/inventory.ini monitoring/setup-splunk-forwarder.yml
  ```

---

## 🌐 API Endpoints

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/health` | Health check | No |
| POST | `/accounts` | Create account | Yes |
| GET | `/accounts/{acc}/balance` | Get balance | Yes |
| POST | `/accounts/{acc}/deposit` | Deposit money | Yes |
| POST | `/accounts/{acc}/withdraw` | Withdraw money | Yes |
| DELETE | `/accounts/{acc}` | Close account | Yes |
| GET | `/accounts/{acc}/transactions` | Transaction history | Yes |

All authenticated endpoints require header: `X-API-Key: <your-api-key>`

---

## 🧰 Tech Stack

| Category | Tool |
|----------|------|
| Language | Python 3.11 + Flask |
| Database | PostgreSQL 15 |
| Container | Docker + Docker Compose |
| IaC | Terraform |
| CI/CD | Jenkins |
| Code Quality | SonarQube |
| Artifact Registry | JFrog Artifactory |
| Deployment | Ansible |
| Monitoring | Splunk |
| Cloud | AWS (EC2, RDS, ALB, VPC) |

