# Kubernetes Audit Logging

## Architecture

- **API Server** — records Kubernetes API requests.
- **Filebeat** — collects audit logs.
- **Logstash** — parses JSON events and forwards them.
- **Elasticsearch** — stores events.
- **Kibana** — provides log search and analysis.

## Audit Configuration

Policy: `/etc/kubernetes/audit/policy.yaml`

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - RequestReceived
rules:
  - level: Metadata
```

Audit log: `/var/log/kubernetes/audit/audit.log`

API server settings:

```text
--audit-policy-file=/etc/kubernetes/audit/policy.yaml
--audit-log-path=/var/log/kubernetes/audit/audit.log
--audit-log-maxage=7
--audit-log-maxbackup=3
--audit-log-maxsize=100
```

`Metadata` records request metadata without request or response bodies.

## ELK Configuration

Helm values are stored in `values/`:

- `elasticsearch.yaml` — single-node Elasticsearch, 5 GiB PVC.
- `kibana.yaml` — internal Kibana service.
- `logstash-config.yaml` — Beats input on TCP 5044, JSON parsing, Elasticsearch output.
- `filebeat.yaml` — collects `audit.log` and forwards events to `audit-logstash-logstash:5044`.

Chart version: `8.5.1`.

Render validation:

```bash
helm template audit-es elastic/elasticsearch --version 8.5.1 -n audit-logging -f k8s_audit_logging/values/elasticsearch.yaml
helm template audit-kibana elastic/kibana --version 8.5.1 -n audit-logging -f k8s_audit_logging/values/kibana.yaml
helm template audit-logstash elastic/logstash --version 8.5.1 -n audit-logging -f k8s_audit_logging/values/logstash-config.yaml
helm template audit-filebeat elastic/filebeat --version 8.5.1 -n audit-logging -f k8s_audit_logging/values/filebeat.yaml
```

## Deployment and Verification

Install Elasticsearch first, then Kibana and Logstash, and finally Filebeat. Check Minikube resources before deployment.

```bash
kubectl get pods,svc,pvc -n audit-logging
kubectl logs -n audit-logging <pod-name>
kubectl port-forward -n audit-logging svc/audit-kibana-kibana 5601:5601
```

Open `http://localhost:5601` to access Kibana.

## Suspicious Activity Example

Hypothetical scenario: an account repeatedly attempts to list Secrets in unexpected namespaces.

Kibana Discover KQL:

```text
audit.verb: "list" AND audit.objectRef.resource: "secrets"
```

Find denied requests:

```text
audit.responseStatus.code: 403
```

Review the username, source IP, namespace, timestamp, and response status. Repeated unexpected requests may warrant investigation; a `403` alone does not prove malicious activity.

## Limitations

- Single-node Elasticsearch is not highly available.
- Audit metadata can still contain sensitive information.
- Verify ingestion, index creation, and Kibana searches before considering the stack operational.

## Verification Results

The audit logging stack was deployed and tested locally using Minikube.

The Kubernetes API server audit policy was configured at `/etc/kubernetes/audit/policy.yaml`. Audit events were written to `/var/log/kubernetes/audit/audit.log`. The API server was configured with audit policy and log rotation arguments.

The ELK stack consisted of Elasticsearch, Logstash, Kibana, and Filebeat, deployed in the `audit-logging` namespace using Helm charts version `8.5.1`.

Verification results:
- The Kubernetes audit log file was created and contained JSON audit events.
- Filebeat read audit events and successfully forwarded them to Logstash.
- Logstash connected to Elasticsearch using HTTPS.
- Elasticsearch created the `kubernetes-audit-*` index.
- The index `kubernetes-audit-2026.10.28` contained 977 documents at the time of verification.
- Kibana was accessible, and audit log data was visible for inspection and search.
- The local Minikube cluster was stopped after verification to release system resources. The cluster and its configuration were preserved.

The Elasticsearch document count and index name above reflect the state observed during testing and may differ after the stack is started again and new audit events are generated.
