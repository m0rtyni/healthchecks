# Healthchecks on Kubernetes

This project demonstrates deploying the Django-based Healthchecks application to Kubernetes using Helm, Helmfile, and SOPS-encrypted secrets.

## Architecture and Components

- AWS EKS cluster with two worker nodes.
- Django application deployed using a Kubernetes Deployment.
- ClusterIP Service exposing the application on port 8080.
- Horizontal Pod Autoscaler (HPA), configured for 2–4 replicas with CPU and memory targets of 80%.
- PostgreSQL StatefulSet with persistent storage for the current deployment.
- ConfigMap for non-sensitive application configuration.
- Kubernetes Secret generated from SOPS-encrypted configuration.
- Helm chart with environment-specific values managed by Helmfile.
- Production templates for NGINX Ingress, cert-manager, and HTTPS.

## Project Structure

- `helm_chart/` — Helm chart and Kubernetes resource templates.
- `helmfile/` — Helmfile environment and release configuration.
- `values/` — local and production configuration.
- `secrets/` — SOPS-encrypted secret configuration.
- `documentation/deployment_guide.md` — deployment guide, architecture, troubleshooting, and production preparation.

## Prerequisites

The project uses Docker, kubectl, Helm, Helmfile, SOPS, and age. AWS deployment additionally requires AWS CLI credentials and access to the EKS cluster.

## Validation

Run these commands from the `k8s_django_deployment_task` directory.

Lint the chart:

```bash
helm lint helm_chart \
  --set-string secret.dbPassword=lint-only-password \
  --set-string secret.djangoSecretKey=lint-only-key
```

Inspect the Helmfile release:

```bash
helmfile -f helmfile/helmfile.yaml.gotmpl list
```

Build the production configuration:

```bash
helmfile -f helmfile/helmfile.yaml.gotmpl -e production build
```

The production build decrypts the SOPS-managed secrets for rendering. Do not publish rendered output or plaintext credentials.

## Verified Deployment Status

The application has been deployed to AWS EKS. The Django application was accessed successfully through Kubernetes port forwarding at `http://localhost:8080`.

The following have been configured and checked:

- EKS worker nodes in Ready state.
- Django application pods and ClusterIP Service.
- PostgreSQL running in Kubernetes with persistent storage.
- Metrics Server and Kubernetes resource metrics.
- HPA using CPU and memory metrics, with a configured range of 2–4 replicas.
- Helm release managed by Helmfile.
- SOPS-encrypted application configuration.

Port forwarding provides temporary access from the machine running the command; it does not expose the application publicly.

## Production Readiness

The production values file is a template and must be completed before production use.

The following remain to be configured and verified:

- Amazon RDS PostgreSQL endpoint and database credentials.
- A real domain name and corresponding DNS records.
- Public Ingress and load balancer routing.
- cert-manager certificate issuance with Let's Encrypt.
- Production-specific access controls and security settings.

The current verified deployment uses PostgreSQL inside Kubernetes with persistent storage. This is not equivalent to Amazon RDS. Production Ingress, public HTTPS, and RDS connectivity must not be considered operational until tested.

## Security

- Encrypt sensitive configuration with SOPS before committing it to Git.
- Keep the age private key outside the repository.
- Never commit plaintext database passwords, Django secret keys, or rendered secret manifests.
- Restrict access to Kubernetes Secrets and AWS resources.
- Use encryption at rest and least-privilege IAM permissions where applicable.

## Documentation

See [`documentation/deployment_guide.md`](documentation/deployment_guide.md) for deployment instructions, architecture details, troubleshooting, and remaining production setup.