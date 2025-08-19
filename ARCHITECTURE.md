# LGTM Stack Architecture Documentation

## 🏗️ System Architecture Overview

The LGTM (Loki, Grafana, Tempo, Mimir) stack provides comprehensive observability for modern cloud-native applications, collecting and correlating logs, metrics, and traces.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              APPLICATION LAYER                           │
├─────────────────┬────────────────┬────────────────┬────────────────────┤
│   Frontend      │    Backend      │    Ingress     │   Other Services  │
│   Namespace     │    Namespace    │    Namespace   │                   │
├─────────────────┴────────────────┴────────────────┴────────────────────┤
│                         TELEMETRY COLLECTION                             │
├───────────────────────────────────────────────────────────────────────────┤
│                    OpenTelemetry Collector (DaemonSet)                   │
│  ┌──────────────┬──────────────┬──────────────┬──────────────────────┐ │
│  │ OTLP         │ Prometheus   │ Jaeger       │ Zipkin              │ │
│  │ Receiver     │ Scraper      │ Receiver     │ Receiver            │ │
│  └──────────────┴──────────────┴──────────────┴──────────────────────┘ │
├───────────────────────────────────────────────────────────────────────────┤
│                          STORAGE & PROCESSING                            │
├──────────────┬──────────────┬──────────────┬────────────────────────────┤
│    Loki      │  Prometheus  │    Tempo     │         Mimir             │
│   (Logs)     │  (Metrics)   │   (Traces)   │  (Long-term Metrics)      │
├──────────────┴──────────────┴──────────────┴────────────────────────────┤
│                           VISUALIZATION                                  │
├───────────────────────────────────────────────────────────────────────────┤
│                              Grafana                                     │
│  ┌──────────────┬──────────────┬──────────────┬──────────────────────┐ │
│  │ Dashboards   │ Explore      │ Alerting     │ Reporting            │ │
│  └──────────────┴──────────────┴──────────────┴──────────────────────┘ │
├───────────────────────────────────────────────────────────────────────────┤
│                            ACCESS LAYER                                  │
├───────────────────────────────────────────────────────────────────────────┤
│                      Nginx Reverse Proxy (SSL/TLS)                      │
└───────────────────────────────────────────────────────────────────────────┘
```

## 📊 Component Details

### Core Services

| Service | Purpose | Default Port | Protocol | Endpoint |
|---------|---------|--------------|----------|----------|
| **Grafana** | Visualization & Dashboards | 3000 | HTTP/WS | `/` |
| **Prometheus** | Metrics Storage & Querying | 9090 | HTTP | `/api/v1/*` |
| **Loki** | Log Aggregation | 3100 | HTTP/gRPC | `/loki/api/v1/*` |
| **Tempo** | Distributed Tracing | 3200 | HTTP/gRPC | `/api/*` |
| **Mimir** | Long-term Metrics Storage | 9009 | HTTP/gRPC | `/prometheus/*` |
| **OpenTelemetry Collector** | Telemetry Collection | 4317/4318 | gRPC/HTTP | `/v1/*` |
| **Nginx** | Reverse Proxy | 80/443 | HTTP/HTTPS | `*` |
| **Semaphore** | Ansible UI | 3001 | HTTP/WS | `/api/*` |

### OpenTelemetry Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 4317 | gRPC | OTLP gRPC Receiver |
| 4318 | HTTP | OTLP HTTP Receiver |
| 14268 | HTTP | Jaeger Thrift HTTP |
| 14250 | gRPC | Jaeger gRPC |
| 6831 | UDP | Jaeger Thrift Compact |
| 6832 | UDP | Jaeger Thrift Binary |
| 9411 | HTTP | Zipkin Receiver |
| 8888 | HTTP | Metrics Endpoint |
| 13133 | HTTP | Health Check |
| 55679 | HTTP | zPages |
| 1777 | HTTP | pprof Endpoint |

## 🔄 Data Flow

### 1. Metrics Flow
```
Application (Prometheus metrics)
    ↓
OpenTelemetry Collector (scrape)
    ↓
Prometheus (immediate storage)
    ↓
Mimir (long-term storage)
    ↓
Grafana (visualization)
```

### 2. Logs Flow
```
Application (stdout/stderr)
    ↓
Container Runtime
    ↓
OpenTelemetry Collector (filelog receiver)
    ↓
Loki (storage & indexing)
    ↓
Grafana (visualization)
```

### 3. Traces Flow
```
Application (OTLP/Jaeger/Zipkin)
    ↓
OpenTelemetry Collector
    ↓
Tempo (storage)
    ↓
Grafana (visualization)
```

## 🏢 Service Architecture

### VM Deployment (Native Installation)

```yaml
Services:
  Prometheus:
    Binary: /opt/lgtm/bin/prometheus
    Config: /etc/prometheus/prometheus.yml
    Data: /opt/lgtm/prometheus/data
    Service: prometheus.service
    Port: 9090
    
  Loki:
    Binary: /opt/lgtm/bin/loki
    Config: /etc/loki/loki-config.yml
    Data: /opt/lgtm/loki/data
    Service: loki.service
    Port: 3100
    
  Tempo:
    Binary: /opt/lgtm/bin/tempo
    Config: /etc/tempo/tempo-config.yml
    Data: /opt/lgtm/tempo/data
    Service: tempo.service
    Ports:
      - 3200  # HTTP
      - 4317  # OTLP gRPC
      - 4318  # OTLP HTTP
      - 14268 # Jaeger
      - 9411  # Zipkin
    
  Mimir:
    Binary: /opt/lgtm/bin/mimir
    Config: /etc/mimir/mimir-config.yml
    Data: /opt/lgtm/mimir/data
    Service: mimir.service
    Port: 9009
    
  Grafana:
    Installation: APT package
    Config: /etc/grafana/grafana.ini
    Data: /opt/lgtm/grafana/data
    Service: grafana-server.service
    Port: 3000
    
  OpenTelemetry:
    Binary: /opt/lgtm/bin/otelcol
    Config: /opt/lgtm/otel/config/otel-collector-config.yaml
    Service: otelcol.service
    Ports:
      - 4317  # OTLP gRPC
      - 4318  # OTLP HTTP
      - Multiple trace receivers
    
  Nginx:
    Installation: APT package
    Config: /etc/nginx/sites-available/*
    Service: nginx.service
    Ports:
      - 80   # HTTP
      - 443  # HTTPS
```

### Kubernetes Deployment

```yaml
Namespace: monitoring

Deployments:
  - grafana (1-3 replicas)
  - prometheus (1-2 replicas)
  
StatefulSets:
  - loki (1-3 replicas)
  - tempo (1-3 replicas)
  - mimir (1-3 replicas)
  
DaemonSets:
  - otel-collector (on all nodes)
  
Services:
  - grafana (ClusterIP: 3000)
  - prometheus (ClusterIP: 9090)
  - loki (ClusterIP: 3100)
  - tempo (ClusterIP: 3200)
  - mimir (ClusterIP: 9009)
  - otel-collector (NodePort: various)
  
Ingress:
  - grafana-ingress (HTTPS)
```

## 🔐 Security Architecture

### Network Security
- **Firewall Rules**: UFW configured for specific ports
- **SSL/TLS**: Let's Encrypt certificates via Certbot
- **Reverse Proxy**: Nginx for SSL termination
- **Network Policies**: Kubernetes NetworkPolicy for pod-to-pod communication

### Authentication & Authorization
- **Grafana**: Local users, LDAP/OAuth support
- **Prometheus**: Basic auth optional
- **API Keys**: For programmatic access
- **RBAC**: Kubernetes role-based access control

## 📡 Integration Points

### Application Integration

#### For Metrics
```yaml
# Prometheus metrics endpoint
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

#### For Traces (OpenTelemetry SDK)
```yaml
# Environment variables for OTLP
OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4317"
OTEL_EXPORTER_OTLP_PROTOCOL: "grpc"
OTEL_SERVICE_NAME: "my-service"
OTEL_RESOURCE_ATTRIBUTES: "environment=production"
```

#### For Logs
```yaml
# Structured logging to stdout/stderr
# Automatically collected by OpenTelemetry Collector
```

### API Endpoints

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Grafana | `/api/datasources` | Manage data sources |
| Grafana | `/api/dashboards` | Manage dashboards |
| Prometheus | `/api/v1/query` | Query metrics |
| Prometheus | `/api/v1/write` | Remote write |
| Loki | `/loki/api/v1/push` | Push logs |
| Loki | `/loki/api/v1/query` | Query logs |
| Tempo | `/api/traces` | Query traces |
| Tempo | `/api/search` | Search traces |
| Mimir | `/prometheus/api/v1/*` | Prometheus-compatible API |

## 🚀 Deployment Patterns

### Development Environment
- Single instance of each component
- Local storage
- Minimal resource allocation
- No SSL required

### Staging Environment
- Moderate resource allocation
- SSL with Let's Encrypt
- 30-day retention
- Basic alerting

### Production Environment
- High availability mode
- External storage backends
- Extended retention (90+ days)
- Full alerting and notification
- Backup and disaster recovery

## 📈 Scalability Considerations

### Horizontal Scaling
- **Grafana**: Stateless, scale behind load balancer
- **Prometheus**: Federation for multiple instances
- **Loki**: Microservices mode for scale
- **Tempo**: Distributed mode with object storage
- **Mimir**: Multi-tenant, horizontally scalable

### Vertical Scaling
- **Memory**: Primary constraint for Prometheus and Mimir
- **CPU**: Important for query performance
- **Storage**: Critical for retention periods
- **Network**: Bandwidth for high-volume telemetry

## 🔧 Operational Procedures

### Health Checks
```bash
# Check all services
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3100/ready      # Loki
curl http://localhost:3200/ready      # Tempo
curl http://localhost:9009/ready      # Mimir
curl http://localhost:3000/api/health # Grafana
```

### Backup Procedures
```bash
# Prometheus data
tar -czf prometheus-backup.tar.gz /opt/lgtm/prometheus/data

# Grafana dashboards
grafana-cli admin export-dashboard

# Loki chunks
tar -czf loki-backup.tar.gz /opt/lgtm/loki/data
```

## 📊 Resource Requirements

### Minimum Requirements (Dev/Test)
- **CPU**: 4 cores
- **Memory**: 8GB RAM
- **Storage**: 50GB SSD
- **Network**: 100Mbps

### Recommended Requirements (Production)
- **CPU**: 8+ cores
- **Memory**: 32GB+ RAM
- **Storage**: 500GB+ SSD
- **Network**: 1Gbps

## 🔄 Update Strategy

### Rolling Updates
1. Update configuration files
2. Reload services gracefully
3. Verify health checks
4. Monitor for issues

### Version Compatibility Matrix
| Component | Version | Compatible With |
|-----------|---------|-----------------|
| Grafana | 10.2.3 | All current versions |
| Prometheus | 2.48.0 | Mimir 2.11.0 |
| Loki | 2.9.3 | Grafana 10.x |
| Tempo | 2.3.1 | Grafana 10.x |
| Mimir | 2.11.0 | Prometheus 2.x |
| OpenTelemetry | 0.91.0 | All current versions |

## 🆘 Troubleshooting Guide

### Common Issues

1. **High Memory Usage**
   - Check retention policies
   - Adjust batch sizes
   - Implement sampling

2. **Slow Queries**
   - Add indexes (Loki)
   - Optimize PromQL queries
   - Use recording rules

3. **Missing Data**
   - Verify network connectivity
   - Check scrape configurations
   - Review service discovery

4. **Storage Issues**
   - Monitor disk usage
   - Implement rotation policies
   - Consider object storage

## 📚 Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Tempo Documentation](https://grafana.com/docs/tempo/)
- [Mimir Documentation](https://grafana.com/docs/mimir/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Semaphore Documentation](https://docs.ansible-semaphore.com/)
