# Healthchecks on Kubernetes

This project demonstrates deploying the Django-based Healthchecks application to Kubernetes using Helm and Helmfile.

## Components

- Django Deployment with two replicas by default
- Optional PostgreSQL StatefulSet for local development
- ClusterIP Service and NGINX Ingress
- Horizontal Pod Autoscaler (HPA) targeting 80% CPU and memory utilization, with 2–4 replicas
- ConfigMap for non-sensitive application configuration
- Kubernetes Secret generated from SOPS-encrypted configuration
- Environment-specific values for local and production deployments
- Conditional cert-manager ClusterIssuer configuration for production TLS

## Project Structure

- `helm_chart/` — Helm chart and Kubernetes resource templates
- `helmfile/` — Helmfile environment and release configuration
- `values/` — local and production configuration
- `secrets/` — encrypted secret configuration
- `documentation/deployment_guide.md` — detailed deployment guide, architecture, troubleshooting, and production preparation

## Prerequisites

The local workflow uses Docker, Minikube, kubectl, Helm, Helmfile, SOPS, and age.

## Local Validation

Run these commands from the `k8s_django_deployment_task` directory:

```bash
helm lint helm_chart \
  --set secret.dbPassword=lint-only-password \
  --set secret.djangoSecretKey=lint-only-key

helmfile -f helmfile/helmfile.yaml.gotmpl -e local lint

helmfile -f helmfile/helmfile.yaml.gotmpl -e local build
```

The example credentials are placeholders for validation only. Do not use them for an actual deployment.

## Environments

- **Local:** uses PostgreSQL running inside Kubernetes and local HTTP Ingress configuration.
- **Production:** prepared for an external managed PostgreSQL database, such as Amazon RDS, and HTTPS.

The local Minikube deployment and Helm chart validation have been tested. The production configuration is not ready to deploy until the real container image, RDS endpoint, database credentials, domain, and TLS infrastructure are configured and verified.

## Security

Use SOPS to encrypt sensitive configuration before storing it in Git. Keep the age private key outside the repository and never commit plaintext passwords or Django secret keys.

Kubernetes Secret resources do not, by themselves, encrypt secret values stored in Git. Production deployments should also use appropriate cluster access controls and encryption-at-rest settings.

## Documentation

See [`documentation/deployment_guide.md`](documentation/deployment_guide.md) for the architecture, deployment steps, troubleshooting notes, and production deployment requirements.