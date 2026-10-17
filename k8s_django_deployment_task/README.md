# Healthchecks on Kubernetes

## Components
- Django Deployment with 2 replicas
- Optional PostgreSQL StatefulSet for local development
- ClusterIP Service and NGINX Ingress
- HPA targeting 80% CPU and memory, 2–4 replicas
- Helm chart and Helmfile for environment configuration

## Local validation
Run from the repository root:

    helm lint k8s_django_deployment_task/helm_chart \
      --set secret.dbPassword=lint-only-password \
      --set secret.djangoSecretKey=lint-only-key

## Environments
- local: uses PostgreSQL inside Kubernetes
- production: intended to use an external managed database such as AWS RDS

Before production deployment, configure the real RDS endpoint, database credentials, domain, TLS, and encrypted secrets. Do not commit real passwords or Django secret keys.

## Security
Use SOPS to encrypt secrets before storing them in Git. Kubernetes Secret resources alone do not encrypt secret values in the Git repository.
