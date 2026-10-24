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

## WEEK 9 Task 1 Kubernetes Security Enhancement

1. Familiarize yourself with Kubernetes security best practices.

**1. Container and Pod Security**
A container should not have more privileges than necessary. You should run the application as an unprivileged user, disable privileged mode, and, where possible, use a read-only file system.
**2. RBAC — Access Control**
Role-Based Access Control (RBAC) determines who can perform which actions in Kubernetes. For example, an application typically does not need access to create Pods or manage Secrets.
**3. Network Security**
NetworkPolicy allows you to restrict network connections between Pods. For example, a web application should have access to PostgreSQL, but other Pods do not necessarily need such access.
**4. Secret Protection**
Passwords, tokens, and keys should not be stored in plain text in Git or in container images. Kubernetes Secrets also require proper access control and, where necessary, encryption.
**5. Pod Security Admission**
A Kubernetes mechanism that helps enforce security policies on Pods. For example, the `restricted` profile imposes stricter restrictions on privileges, users, and container capabilities.
**6. Updates, Resources, and Control**
You should use up-to-date images, scan them for vulnerabilities, set CPU and memory requests/limits, and control access to the Kubernetes API.

2. Assess the Kubernetes cluster for potential security threats and propose mitigation strategies.

The following potential security threats were considered for the Kubernetes deployment, together with strategies to reduce their impact.

**1. Excessive Container Privileges**
A compromised application container could misuse excessive privileges to access resources or perform unauthorized operations.
**Mitigation:** Run the application as a non-root user, disable privilege escalation, drop unnecessary Linux capabilities, and use the `RuntimeDefault` seccomp profile.
**2. Unauthorized Access to Kubernetes Resources**
Users or workloads with excessive permissions could access, modify, or delete Kubernetes resources beyond their responsibilities.
**Mitigation:** Apply the principle of least privilege through RBAC. Disable automatic ServiceAccount token mounting for workloads that do not require access to the Kubernetes API.
**3. Unrestricted Network Communication**
Unrestricted communication between Pods could allow unauthorized workloads to connect to the PostgreSQL database or other internal services.
**Mitigation:** Use NetworkPolicy rules to restrict database ingress to the application Pods that require access. Verify that the cluster's network plugin enforces NetworkPolicy rules.
**4. Exposure of Credentials and Secrets**
Database passwords, Django secret keys, and other sensitive information could be exposed through Git, configuration files, or container images.
**Mitigation:** Encrypt sensitive configuration with SOPS, keep private decryption keys outside the repository, and restrict access to Kubernetes Secrets.
**5. Insecure Pod Configuration**
Pods that run with unnecessary privileges or do not follow security standards increase the application's attack surface.
**Mitigation:** Configure pod-level and container-level `securityContext` settings. Use Pod Security Admission to enforce or warn about applicable Pod Security Standards.
**6. Resource Exhaustion**
Excessive CPU or memory consumption could reduce application availability and affect other workloads in the cluster.
**Mitigation:** Configure CPU and memory requests and limits, and use the Horizontal Pod Autoscaler (HPA) where appropriate.
**7. Vulnerable Container Images and Dependencies**
Outdated images or application dependencies may contain known vulnerabilities that attackers could exploit. 
**Mitigation:** Use maintained container images, update dependencies regularly, and scan images for known vulnerabilities.

These mitigation strategies reduce the attack surface and the likelihood of unauthorized access, credential exposure, and service disruption. Their effectiveness depends on correct configuration and verification of the implemented security controls.

3. Update the existing Helm chart to apply pod-level security hardening (securityContext + Pod Security Admission) for the application's pods.

The application's Helm chart configures pod-level and container-level security settings.

- Runs application containers as a non-root user.
- Disables privilege escalation.
- Drops all unnecessary Linux capabilities.
- Uses the `RuntimeDefault` seccomp profile.
- Applies Pod Security Admission with the `baseline` enforcement and `restricted` warning profiles.

These settings reduce container privileges and help detect insecure Pod configurations.

4. Set up a Kubernetes Network Policy to control network traffic to and from the pods.

A Kubernetes NetworkPolicy was configured to restrict ingress traffic to PostgreSQL.

- Allows TCP traffic on port `5432` only from the application Pods.
- Restricts access to the database from unrelated Pods.

NetworkPolicy enforcement depends on the cluster's network plugin and should be verified.

5. Implement Role-Based Access Control (RBAC) for users to manage permissions within the Kubernetes cluster.

The application ServiceAccount has automatic token mounting disabled because the application does not require access to the Kubernetes API.
No additional Roles or RoleBindings have been configured for human users. User access management remains a limitation of the current setup.
RBAC should follow the principle of least privilege, granting users only the permissions required for their tasks.

6. Add tests for Helm templates

Helm charts were validated using `helm lint` and `helm test`.

- Both application and PostgreSQL charts passed `helm lint`.
- The application Helm test completed successfully.
- The test verifies HTTP connectivity to the application Service.

These checks help detect chart configuration errors and verify basic application connectivity.
