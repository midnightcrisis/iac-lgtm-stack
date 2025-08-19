# Promtail Configuration for Log Collection

This directory contains the Kubernetes manifests for deploying Promtail as a DaemonSet to collect logs from all pods in your cluster and send them to Loki.

## Components

- **ConfigMap**: Contains Promtail configuration for scraping pod logs
- **DaemonSet**: Runs Promtail on every node in the cluster
- **Service**: Exposes Promtail metrics endpoint (port 3101)
- **ServiceAccount, ClusterRole, ClusterRoleBinding**: RBAC resources for Promtail to discover pods

## Configuration

### Default Behavior

By default, Promtail is configured with two scrape jobs:

1. **kubernetes-pods**: Only scrapes pods with annotation `promtail.io/scrape=true`
2. **kubernetes-pods-all**: Scrapes all pods except those in `kube-system` and `kube-public` namespaces

### Sending Logs to External Loki

If your Loki instance is running outside the cluster (e.g., on a Grafana VM), update the Loki URL in the ConfigMap:

```yaml
clients:
  - url: http://<EXTERNAL_LOKI_IP>:3100/loki/api/v1/push
    tenant_id: <your-tenant-id>
```

### Enable Log Collection for Specific Pods

To enable log collection for specific pods only (using the first scrape job), add this annotation to your pod:

```yaml
metadata:
  annotations:
    promtail.io/scrape: "true"
```

## Deployment

### Apply with Kustomize

From the base directory:
```bash
kubectl apply -k /Users/ashira/playground/iac-lgtm-stack/kustomize-manifests/base
```

### Verify Deployment

Check if Promtail pods are running:
```bash
kubectl get daemonset -n monitoring promtail
kubectl get pods -n monitoring -l app=promtail
```

Check Promtail logs:
```bash
kubectl logs -n monitoring -l app=promtail --tail=50
```

## Monitoring

Promtail exposes metrics on port 3101 at `/metrics` path. These metrics can be scraped by Prometheus to monitor:
- Number of log entries sent
- Errors and dropped logs
- Promtail health status

## Troubleshooting

### Logs Not Appearing in Loki

1. Check Promtail pod logs for errors:
   ```bash
   kubectl logs -n monitoring -l app=promtail
   ```

2. Verify Loki is reachable from Promtail pods:
   ```bash
   kubectl exec -n monitoring -it <promtail-pod> -- wget -O- http://loki:3100/ready
   ```

3. Check if pods have the correct annotation (if using annotation-based scraping):
   ```bash
   kubectl get pods --all-namespaces -o json | jq '.items[] | select(.metadata.annotations."promtail.io/scrape" == "true") | .metadata.name'
   ```

### High Memory Usage

Adjust resource limits in the DaemonSet if needed:
```yaml
resources:
  limits:
    memory: 200Mi  # Increase as needed
    cpu: 200m
```

## Labels

Promtail automatically adds the following labels to collected logs:
- `namespace`: Kubernetes namespace
- `pod`: Pod name
- `container`: Container name
- `node_name`: Node where the pod is running
- `node_ip`: Node IP address
- All pod labels are also included

## Security Considerations

- Promtail runs with `runAsUser: 0` to access container logs
- It has read-only access to the filesystem
- RBAC is configured with minimal required permissions
