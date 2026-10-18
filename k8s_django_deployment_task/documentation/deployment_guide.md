# Deployment Guide: Django Healthchecks on Kubernetes

## 1. Overview

This project demonstrates the deployment of the Django-based Healthchecks application to Kubernetes using Helm and Helmfile.

The application has been deployed and tested on Amazon EKS. The container image is stored in Amazon ECR. The application uses a Kubernetes Deployment, ClusterIP Service, ConfigMap, Kubernetes Secret, Horizontal Pod Autoscaler (HPA), and an in-cluster PostgreSQL StatefulSet with persistent storage.

The application was verified through Kubernetes port forwarding. The HPA and Metrics Server were also configured and tested.

Important: The current AWS deployment uses PostgreSQL inside Kubernetes rather than Amazon RDS. A production Ingress with a public load balancer, a real domain, cert-manager, and a Let's Encrypt certificate have not been fully configured and verified. The project should not yet be considered production-ready.

## 2. Architecture

### Local environment

The local deployment consists of the following components:

- **Minikube:** runs a local Kubernetes cluster.
- **Django Deployment:** manages two application replicas.
- **PostgreSQL StatefulSet:** provides a database for local development.
- **ConfigMap:** stores non-sensitive application configuration.
- **Kubernetes Secret:** supplies the database password and Django secret key to application containers.
- **ClusterIP Services:** provide internal network access to the application and database.
- **NGINX Ingress Controller:** routes HTTP requests to the application.
- **Horizontal Pod Autoscaler (HPA):** can scale the application between two and four replicas according to CPU and memory utilization.

### Production architecture

The intended production architecture uses:

- A managed Kubernetes cluster, such as Amazon EKS.
- The Django application running in Kubernetes.
- Amazon RDS for PostgreSQL, outside the Kubernetes cluster.
- An NGINX Ingress Controller exposed through a cloud load balancer.
- cert-manager with Let's Encrypt for TLS certificate management.
- SOPS-encrypted configuration secrets.

The production configuration must be completed with a real domain, RDS endpoint, database credentials, and a container image accessible to the cluster.

## 3. Prerequisites

The following tools are used by the project:

- Docker
- Minikube
- kubectl
- Helm
- Helmfile
- SOPS
- age

The local Kubernetes cluster must be running before deploying the application.

Check the cluster status:

```bash
minikube status
kubectl get nodes
```

Verify that the node reports `Ready`.

## 4. Project Structure

```text
k8s_django_deployment_task/
├── helm_chart/
│   ├── templates/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── hpa.yaml
│   │   ├── ingress.yaml
│   │   ├── postgres.yaml
│   │   ├── secret.yaml
│   │   ├── service.yaml
│   │   └── clusterissuer.yaml
│   ├── Chart.yaml
│   └── values.yaml
├── helmfile/
│   └── helmfile.yaml.gotmpl
├── secrets/
│   └── healthchecks.sops.yaml
├── values/
│   ├── local.yaml
│   └── production.yaml
├── documentation/
│   └── deployment_guide.md
└── README.md
```

The `postgres.yaml` template is an additional resource used by the local environment. The `clusterissuer.yaml` template defines the Let's Encrypt issuer when cert-manager is enabled.

## 5. Configuration Management

### 5.1 ConfigMap

The ConfigMap stores non-sensitive environment variables, including:

- `DEBUG`
- `ALLOWED_HOSTS`
- `DB`
- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `SITE_ROOT`
- `DEFAULT_FROM_EMAIL`

The application Deployment imports these values through `envFrom`.

Sensitive information must not be stored in a ConfigMap.

### 5.2 Kubernetes Secret and SOPS

The Kubernetes Secret provides the following environment variables:

- `DB_PASSWORD`
- `SECRET_KEY`

The source secret file is encrypted using SOPS and age. This allows encrypted secrets to be stored in version control without committing their plaintext values.

The age private key must remain outside the repository and must never be committed.

Kubernetes Secrets are not automatically encrypted in Git. SOPS protects the stored configuration file, while Kubernetes cluster encryption and access controls must be configured separately where required.

### 5.3 Environment-specific values

The project separates local and production settings:

- `values/local.yaml` enables the in-cluster PostgreSQL database and local HTTP Ingress.
- `values/production.yaml` disables the in-cluster database and prepares the application to use an external PostgreSQL endpoint and HTTPS.

Production placeholders must be replaced before deployment. Real credentials should be managed securely and must not be committed in plaintext.

## 6. Helm Chart

The Helm chart defines the Kubernetes resources required by the application.

### Deployment

The Deployment runs two application replicas by default. It configures the container image, port, environment variables, resource requests and limits, and HTTP readiness and liveness probes.

The readiness probe checks whether a container is ready to receive traffic. The liveness probe helps Kubernetes detect and restart an unhealthy container.

### Service

The ClusterIP Service exposes the application internally on port `8080` and forwards traffic to the application containers.

### Ingress

The Ingress defines HTTP routing to the application Service using a configured hostname and the selected Ingress class.

Creating an Ingress resource does not install an Ingress Controller. The controller must be installed and configured separately.

### Horizontal Pod Autoscaler

The HPA uses the Kubernetes `autoscaling/v2` API.

Its configured limits are:

- Minimum replicas: `2`
- Maximum replicas: `4`
- Target CPU utilization: `80%`
- Target memory utilization: `80%`

Resource requests must be defined for utilization-based scaling. The cluster must also provide the metrics required by the HPA.

The HPA adjusts the number of application replicas; it does not automatically scale the database.

### PostgreSQL

The optional PostgreSQL StatefulSet is intended for local development. It uses persistent storage and an internal Service.

For production, the chart disables this database in favor of a managed external database.

## 7. Deployment and Verification on Amazon EKS

The application was deployed to an Amazon EKS cluster using Helm. The container image was published to Amazon ECR, and the cluster pulls the image from the registry.

### 7.1 Validate the chart

```bash
helm lint helm_chart \
  --set secret.dbPassword=lint-only-password \
  --set secret.djangoSecretKey=lint-only-key
```

The command should report that the chart passed linting.

### 7.2 Render the production templates

```bash
helm template healthchecks helm_chart \
  -f values/production.yaml \
  --set-string secret.dbPassword=lint-only-password \
  --set-string secret.djangoSecretKey=lint-only-key
```

This renders the Kubernetes manifests locally without installing or updating resources in the cluster.

The example credentials are placeholders for validation only. The production configuration contains placeholders for the RDS endpoint and domain, so the rendered manifests must not be deployed as-is.

### 7.3 Validate Helmfile

```bash
helmfile -f helmfile/helmfile.yaml.gotmpl list
helmfile -f helmfile/helmfile.yaml.gotmpl -e production build
```

Helmfile combines the chart and environment-specific configuration. The SOPS-encrypted secret file must be decryptable using the locally configured age private key.

The `build` command renders the Helmfile configuration but does not deploy resources or verify that the production infrastructure is ready.

### 7.4 Verify the deployed resources

Check the current Kubernetes context and cluster nodes:

```bash
kubectl config current-context
kubectl get nodes
```

Inspect the application and database resources:

```bash
kubectl get deployments,pods,services,hpa
kubectl get statefulsets,pvc
```

Wait until the application and database pods are ready. The application runs in a Deployment, while PostgreSQL runs in a StatefulSet with persistent storage.

### 7.5 Verify metrics and autoscaling

```bash
kubectl top nodes
kubectl top pods
kubectl describe hpa healthchecks
```

The Metrics Server provides resource metrics for the Horizontal Pod Autoscaler (HPA).

The HPA is configured to maintain between two and four application replicas, targeting CPU and memory utilization of 80%. The actual number of replicas depends on resource utilization.

### 7.6 Access the application

To access the application without exposing it publicly, start a port-forward in a separate terminal:

```bash
kubectl port-forward service/healthchecks 8080:8080
```

Keep the port-forward process running while using the application. Then open:

[http://localhost:8080](http://localhost:8080)

This provides temporary local access to the application through the Kubernetes Service. It does not create a public endpoint or configure production HTTPS.

**Important:** Do not run `helmfile sync` or `helmfile destroy` without reviewing the target Kubernetes context, environment values, and affected resources. The production configuration is not ready for deployment until the RDS endpoint, domain, and other required settings have been configured and verified.

## 8. Production Deployment Preparation

The production values file is a template and is not ready to deploy without real infrastructure details.

### 8.1 Container image

The production cluster must be able to pull the configured application image. A locally built image such as `healthchecks-local:dev` is not automatically available to EKS.

Build and publish an appropriate image to a registry accessible by the cluster, then update the production image repository and tag.

### 8.2 Amazon RDS

Create a PostgreSQL RDS instance and configure its networking and security groups so that the application can connect to it.

Replace the database host placeholder with the actual RDS endpoint. Verify the database name, username, password, port, and any required SSL settings.

Avoid exposing the database publicly unless there is a specific, justified requirement. Prefer private connectivity and least-privilege network access.

### 8.3 Ingress Controller and load balancer

Install and configure an Ingress Controller in the cluster. For an AWS deployment, configure its Service and cloud integration so that the required load balancer is provisioned.

The Ingress resource in this chart only defines application routing; it does not provision the controller itself.

### 8.4 cert-manager and Let's Encrypt

Install cert-manager and its required CRDs before deploying a chart that creates a `ClusterIssuer`.

Configure a real domain and point its DNS records to the public load balancer. The load balancer and Ingress Controller must be reachable for the selected ACME HTTP-01 challenge to succeed.

After deploying, inspect certificate resources:

```bash
kubectl get clusterissuer
kubectl get certificates
kubectl get certificaterequests
kubectl describe certificate healthchecks-tls
```

A rendered `ClusterIssuer` manifest does not prove that cert-manager is installed or that a certificate has been issued.

### 8.5 Production secrets

Encrypt production credentials with SOPS before storing them in the repository. Protect the age private key and restrict access to the Kubernetes Secret resources.

Review the rendered manifests and environment values before applying them to a production cluster.

## 9. Troubleshooting and Lessons Learned

### Helm lint errors

**Problem:** Helm reports missing values referenced by templates.

**Solution:** Add explicit defaults for all values used by templates, or define them in the relevant environment values file. Run `helm lint` again.

### Environment-specific resources

**Problem:** A resource such as `ClusterIssuer` should only be generated in production.

**Solution:** Use a conditional template based on an environment-specific value. Validate the local and production renderings separately.

### Local image unavailable in Kubernetes

**Problem:** Kubernetes cannot pull an image that exists only on the development machine.

**Solution:** Load the image into Minikube or publish it to a registry accessible by the target cluster.

### Ingress hostname does not resolve

**Problem:** The browser cannot resolve a local hostname or reach the application.

**Solution:** Check the local hostname mapping, Ingress Controller status, Ingress rules, Service endpoints, and port-forward process.

### HPA does not scale

**Problem:** The HPA reports unknown metrics or does not scale as expected.

**Solution:** Check resource requests, the metrics API, HPA events, and current utilization:

```bash
kubectl describe hpa healthchecks
kubectl top pods
kubectl get apiservices
```

### TLS certificate is not issued

**Problem:** The certificate remains pending or the ACME challenge fails.

**Solution:** Verify cert-manager installation, the ClusterIssuer status, public DNS records, load balancer reachability, port 80 access, and certificate events.

### SOPS cannot decrypt secrets

**Problem:** Helmfile cannot decrypt the environment secret file.

**Solution:** Verify the age private key is available in the expected local configuration and that the encrypted file was created using the matching public key. Never paste or commit the private key.

## 10. Benefits of Kubernetes and Helm

### Kubernetes

- Restarts failed containers and supports application self-healing.
- Runs multiple replicas for improved availability.
- Provides service discovery and internal networking.
- Supports horizontal scaling through HPA.
- Separates application configuration from container images.
- Provides a consistent deployment platform across environments.

### Helm

- Packages Kubernetes resources into reusable charts.
- Supports parameterized configuration through values files.
- Makes it easier to maintain different environment configurations.
- Simplifies installation, upgrades, and rollbacks.
- Reduces duplication across Kubernetes manifests.

### Helmfile

- Coordinates Helm releases and environment-specific values.
- Makes deployments more repeatable.
- Provides a single place to define release configuration for multiple environments.

### SOPS

- Encrypts sensitive configuration before it is stored in version control.
- Supports a safer workflow for managing deployment secrets.
- Helps separate secret access from ordinary application configuration.

These tools improve consistency and repeatability, but they do not eliminate the need for secure infrastructure configuration, monitoring, backups, and operational testing.

## 11. Cleanup

For a local deployment managed by Helmfile, review the target environment and release before removing resources:

```bash
helmfile -f helmfile/helmfile.yaml.gotmpl -e local destroy
```

Inspect remaining resources and persistent volume claims afterwards. Persistent data may require separate cleanup.

For a cloud deployment, delete resources that are no longer needed, including load balancers, managed databases, public IP addresses, and other billable infrastructure. Verify the cloud provider's billing rules before deleting production resources.

## 12. Final Status

The local Minikube deployment and Helm chart validation have been tested. The project includes environment-specific Helmfile configuration, encrypted secret management, an HPA, and conditional TLS issuer templates.

The following items remain dependent on real production infrastructure:

- Building and publishing a production application image.
- Creating and configuring the managed Kubernetes cluster.
- Provisioning and securing the RDS database.
- Installing the Ingress Controller and cert-manager.
- Configuring a public domain and validating Let's Encrypt issuance.
- Performing an end-to-end production deployment and testing.

These steps must be completed and verified before the deployment can be considered production-ready.
