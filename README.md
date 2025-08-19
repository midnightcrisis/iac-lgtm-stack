# LGTM Stack (Loki, Grafana, Tempo, Mimir) - Production Grade Monitoring Solution

## Overview

This repository contains a production-grade implementation of the LGTM stack for comprehensive monitoring. The stack supports two deployment modes:

1. **Native Installation on VM**: Direct installation of all components as systemd services on Ubuntu 22.04
2. **Kubernetes/GKE Deployment**: Container-based deployment using Kustomize

The stack provides:
- **Logs**: Centralized log aggregation with Loki
- **Metrics**: Time-series metrics with Prometheus & Mimir  
- **Traces**: Distributed tracing with Tempo
- **Visualization**: Unified dashboards with Grafana
- **SSL/TLS**: Nginx reverse proxy with Let's Encrypt certificates (VM installation)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         GKE Cluster                          │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ Frontend │  │ Backend  │  │ Ingress  │                  │
│  │Namespace │  │Namespace │  │Namespace │                  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                  │
│       │Logs         │Metrics       │Traces                  │
│       └─────────────┼──────────────┘                        │
│                     ▼                                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Monitoring Namespace                      │  │
│  │                                                        │  │
│  │  ┌─────────┐  ┌──────────┐  ┌───────┐  ┌────────┐   │  │
│  │  │  Loki   │  │Prometheus│  │ Tempo │  │ Mimir  │   │  │
│  │  └────┬────┘  └────┬─────┘  └───┬───┘  └───┬────┘   │  │
│  │       └────────────┼─────────────┼──────────┘        │  │
│  │                    ▼             ▼                    │  │
│  │              ┌─────────────────────┐                  │  │
│  │              │      Grafana        │                  │  │
│  │              └─────────────────────┘                  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │   VM (rizzup-    │
                    │    monitor)      │
                    │  34.87.184.134   │
                    └──────────────────┘
```

## Features

### Production-Grade Features
- ✅ High Availability deployment options
- ✅ Persistent storage for all components
- ✅ Automated backup and retention policies
- ✅ Security hardening with RBAC and network policies
- ✅ TLS/SSL encryption for all communications
- ✅ Resource limits and autoscaling
- ✅ Health checks and readiness probes
- ✅ Distributed tracing correlation
- ✅ Multi-environment support (dev, staging, uat, production)

### Monitoring Capabilities
- **Logs Collection**: From all pods in frontend, backend, and ingress namespaces
- **Metrics Scraping**: Kubernetes metrics, application metrics, and custom metrics
- **Trace Collection**: OpenTelemetry, Jaeger, and Zipkin compatible
- **Service Graph**: Automatic service dependency mapping
- **Alerting**: Prometheus AlertManager integration
- **Long-term Storage**: Mimir for historical metrics retention

## Prerequisites

### For VM Installation
- Ubuntu 22.04
- Root access
- Python 3.8+
- SSH access configured

### For GKE Installation
- GKE cluster running
- kubectl configured
- gcloud CLI authenticated
- Kustomize installed
- Helm 3.x (optional)

## Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd lgtm
```

### 2. Configure Environment Variables
```bash
# For staging environment
export ENVIRONMENT=staging
export GKE_PROJECT=checkinplus-staging
export GKE_CLUSTER=checkinplus-staging
export GKE_REGION=asia-southeast1
```

### 3. Deploy to GKE
```bash
# Deploy to staging environment
./scripts/deploy.sh staging install-gke

# Or deploy to production
./scripts/deploy.sh production install-gke
```

### 4. Deploy to VM (Alternative)
```bash
# Configure SSH key
cp ~/.ssh/your-key ~/.ssh/id_rsa

# Run Ansible playbook
./scripts/deploy.sh staging install-vm
```

## Detailed Installation

### GKE Installation with Kustomize

1. **Review base configuration**:
```bash
ls -la kustomize-manifests/base/
```

2. **Customize for your environment**:
```bash
cd kustomize-manifests/overlays/staging
# Edit kustomization.yaml with your specific values
```

3. **Preview changes**:
```bash
kustomize build overlays/staging | less
```

4. **Apply configuration**:
```bash
kustomize build overlays/staging | kubectl apply -f -
```

5. **Verify deployment**:
```bash
kubectl -n monitoring get all
kubectl -n monitoring get pvc
kubectl -n monitoring get ingress
```

### VM Installation with Ansible

1. **Configure inventory**:
```bash
vim ansible/inventory/staging.yml
# Update with your VM details
```

2. **Create vault for secrets**:
```bash
ansible-vault create ansible/group_vars/all/vault.yml
# Add: vault_grafana_admin_password: your-secure-password
```

3. **Run playbook**:
```bash
cd ansible
ansible-playbook -i inventory/staging.yml playbooks/install-lgtm.yml --ask-vault-pass
```

4. **Verify installation**:
```bash
curl -k https://stg-checkinplust-monitor.checkinplus.com/api/health
```

## Configuration

### Grafana Configuration
- Default admin user: `admin`
- Password: Set via secret or vault
- Port: 3000
- Datasources: Auto-configured for Prometheus, Loki, Tempo, Mimir

### Prometheus Configuration
- Scrape interval: 15s
- Retention: 30 days (configurable)
- Remote write to Mimir enabled
- Service discovery configured for all namespaces

### Loki Configuration
- Retention period: 30 days
- Ingestion rate limit: 100MB/s
- Storage: Filesystem (VM) or PVC (GKE)

### Tempo Configuration
- Trace retention: 30 days
- Supports: Jaeger, Zipkin, OTLP
- Metrics generator enabled

## Accessing the Services

### Grafana Dashboard
- **Staging**: https://stg-checkinplust-monitor.checkinplus.com
- **Production**: https://prod-checkinplust-monitor.checkinplus.com

### Direct Service Access (Port-Forward)
```bash
# Grafana
kubectl -n monitoring port-forward svc/grafana 3000:3000

# Prometheus
kubectl -n monitoring port-forward svc/prometheus 9090:9090

# Loki
kubectl -n monitoring port-forward svc/loki 3100:3100

# Tempo
kubectl -n monitoring port-forward svc/tempo 3200:3200
```

## Monitoring Your Applications

### Adding Prometheus Annotations to Pods
```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

### Sending Logs to Loki
Configure your applications to send logs to:
- **Service**: loki.monitoring.svc.cluster.local
- **Port**: 3100

### Sending Traces to Tempo
Configure OpenTelemetry exporters to:
- **OTLP gRPC**: tempo.monitoring.svc.cluster.local:4317
- **OTLP HTTP**: tempo.monitoring.svc.cluster.local:4318
- **Jaeger**: tempo.monitoring.svc.cluster.local:14268

## Dashboards

Pre-configured dashboards included:
- Kubernetes Cluster Overview
- Pod/Container Metrics
- Node Exporter
- Ingress Controller
- Application RED Metrics
- Trace Service Map
- Log Analysis

## Troubleshooting

### Check Component Status
```bash
# Check all pods
kubectl -n monitoring get pods

# Check logs
kubectl -n monitoring logs -l app=grafana
kubectl -n monitoring logs -l app=prometheus
kubectl -n monitoring logs -l app=loki
kubectl -n monitoring logs -l app=tempo

# Check persistent volumes
kubectl -n monitoring get pvc
```

### Common Issues

1. **Grafana not accessible**:
   - Check ingress configuration
   - Verify certificates
   - Check nginx ingress controller

2. **No metrics in Prometheus**:
   - Verify ServiceAccount permissions
   - Check network policies
   - Review scrape configurations

3. **Logs not appearing in Loki**:
   - Check log shipper configuration
   - Verify Loki is reachable
   - Check retention settings

## Maintenance

### Backup
```bash
# Backup Grafana dashboards
kubectl -n monitoring exec grafana-0 -- grafana-cli admin export-dashboard

# Backup Prometheus data
kubectl -n monitoring exec prometheus-0 -- tar czf /tmp/prometheus-backup.tar.gz /prometheus
```

### Upgrade Components
```bash
# Update image versions in kustomization.yaml
vim kustomize-manifests/overlays/staging/kustomization.yaml

# Apply updates
./scripts/deploy.sh staging upgrade
```

### Scaling
```bash
# Scale Grafana
kubectl -n monitoring scale deployment grafana --replicas=3

# Scale Prometheus
kubectl -n monitoring scale deployment prometheus --replicas=2
```

## Security Considerations

1. **Network Policies**: Restrict traffic between namespaces
2. **RBAC**: Limited permissions for service accounts
3. **TLS/SSL**: All external endpoints use HTTPS
4. **Secrets Management**: Use Kubernetes secrets or external secret managers
5. **Authentication**: Configure OAuth/LDAP for production

## Performance Tuning

### Resource Recommendations

| Component  | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|------------|-------------|-----------|----------------|--------------|---------|
| Grafana    | 250m        | 1000m     | 512Mi          | 1Gi          | 10Gi    |
| Prometheus | 500m        | 2000m     | 1Gi            | 4Gi          | 100Gi   |
| Loki       | 500m        | 2000m     | 1Gi            | 4Gi          | 50Gi    |
| Tempo      | 250m        | 1000m     | 512Mi          | 2Gi          | 50Gi    |
| Mimir      | 500m        | 2000m     | 1Gi            | 4Gi          | 100Gi   |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License

## Support

For issues and questions:
- Create an issue in the repository
- Contact the DevOps team
- Check the documentation at `/docs`

## Roadmap

- [ ] Add Alertmanager integration
- [ ] Implement automated backup solution
- [ ] Add Thanos for unlimited retention
- [ ] Integrate with CI/CD pipelines
- [ ] Add custom Grafana plugins
- [ ] Implement multi-cluster federation

## Environment-Specific Configurations

### Development
- Lower resource limits
- Shorter retention periods
- Simplified authentication

### Staging
- Production-like configuration
- Full feature set enabled
- Integration testing ready

### UAT
- User acceptance testing configuration
- Production data volumes
- Performance testing capable

### Production
- High availability mode
- Extended retention
- Full security features
- Automated backups
