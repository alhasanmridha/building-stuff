# Milestones 1–3: Local K8s (Cluster+Ingress) + Git & Registry + Jenkins

This package gives you a **ready-to-run scaffold** to stand up:

* A local **kind** Kubernetes cluster with **ingress-nginx** and TLS for `*.local.test`
* **Gitea** (local Git server) and a **Docker Registry** inside the cluster
* **Jenkins** (CI) preconfigured via JCasC (admin user, useful plugins)

> **Assumptions**: macOS/Linux, Docker Desktop installed. You can adapt paths for Windows (WSL2 recommended).

---

## 📁 Repo layout

```
infra/
  cluster/
    kind-config.yaml
    make-helpers.sh
  ingress/
    values-nginx.yaml
    tls/                # mkcert-generated certs go here (created by Makefile)
  platform/
    namespace.yaml
    gitea/
      deployment.yaml
      service.yaml
      ingress.yaml
      pvc.yaml
      secret-env.yaml
      cm-appini.yaml
      init-admin-job.yaml
    registry/
      deployment.yaml
      service.yaml
      ingress.yaml
      pvc.yaml
      htpasswd-secret.yaml   # optional if you want auth
    jenkins/
      deployment.yaml
      service.yaml
      ingress.yaml
      pvc.yaml
      secret-admin.yaml
      casc-configmap.yaml
Makefile
README.md
```

> You can copy/paste the files below into your repo with the same structure.

---

## 1) kind cluster & ingress

### `infra/cluster/kind-config.yaml`

```yaml
# Creates a kind cluster with ports 80/443 forwarded to the ingress controller
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: local-platform
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
```

### `infra/ingress/values-nginx.yaml`

```yaml
# Minimal values for ingress-nginx with kind
controller:
  replicaCount: 1
  service:
    type: NodePort
  admissionWebhooks:
    enabled: true
```

### `infra/platform/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: platform
```

---

## 2) Platform components manifests

### Gitea

`infra/platform/gitea/pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitea-data
  namespace: platform
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 5Gi
```

`infra/platform/gitea/secret-env.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitea-env
  namespace: platform
type: Opaque
stringData:
  GITEA__server__DOMAIN: gitea.local.test
  GITEA__server__ROOT_URL: https://gitea.local.test/
  GITEA__server__SSH_DOMAIN: gitea.local.test
  GITEA__server__START_SSH_SERVER: "false"
  GITEA__service__DISABLE_REGISTRATION: "false"
  GITEA__server__PROTOCOL: http
```

`infra/platform/gitea/cm-appini.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitea-appini
  namespace: platform
data:
  app.ini: |
    [server]
    DOMAIN = gitea.local.test
    ROOT_URL = https://gitea.local.test/
    PROTOCOL = http
    HTTP_PORT = 3000
    START_SSH_SERVER = false
    [service]
    DISABLE_REGISTRATION = false
```

`infra/platform/gitea/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitea
  namespace: platform
spec:
  replicas: 1
  selector:
    matchLabels: { app: gitea }
  template:
    metadata:
      labels: { app: gitea }
    spec:
      containers:
        - name: gitea
          image: gitea/gitea:1.22.3
          ports:
            - containerPort: 3000
          envFrom:
            - secretRef: { name: gitea-env }
          volumeMounts:
            - name: data
              mountPath: /data
            - name: appini
              mountPath: /data/gitea/conf
      volumes:
        - name: data
          persistentVolumeClaim: { claimName: gitea-data }
        - name: appini
          configMap:
            name: gitea-appini
            items:
              - key: app.ini
                path: app.ini
```

`infra/platform/gitea/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: gitea
  namespace: platform
spec:
  selector: { app: gitea }
  ports:
    - name: http
      port: 3000
      targetPort: 3000
```

`infra/platform/gitea/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitea
  namespace: platform
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
    - hosts: ["gitea.local.test"]
      secretName: platform-tls
  rules:
    - host: gitea.local.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: gitea
                port:
                  number: 3000
```

`infra/platform/gitea/init-admin-job.yaml` (optional: auto-create admin user on first run)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: gitea-init-admin
  namespace: platform
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: init
          image: gitea/gitea:1.22.3
          command: ["bash","-lc"]
          args:
            - >-
              gitea admin user create --admin --username admin --password admin123 --email admin@gitea.local || true
```

---

### Docker Registry

`infra/platform/registry/pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-data
  namespace: platform
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 10Gi
```

`infra/platform/registry/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: platform
spec:
  replicas: 1
  selector:
    matchLabels: { app: registry }
  template:
    metadata:
      labels: { app: registry }
    spec:
      containers:
        - name: registry
          image: registry:2
          ports:
            - containerPort: 5000
          env:
            - name: REGISTRY_STORAGE_DELETE_ENABLED
              value: "true"
          volumeMounts:
            - name: data
              mountPath: /var/lib/registry
      volumes:
        - name: data
          persistentVolumeClaim: { claimName: registry-data }
```

`infra/platform/registry/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: registry
  namespace: platform
spec:
  selector: { app: registry }
  ports:
    - name: http
      port: 5000
      targetPort: 5000
```

`infra/platform/registry/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: registry
  namespace: platform
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
    - hosts: ["registry.local.test"]
      secretName: platform-tls
  rules:
    - host: registry.local.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: registry
                port:
                  number: 5000
```

> **Docker trust note**: since we’ll use a mkcert CA, Docker will trust it if the root CA is installed at the OS level (macOS Keychain or Linux system store). If you see TLS errors when pushing, configure Docker to trust the registry’s cert or use `insecure-registries` (not recommended).

---

### Jenkins (CI)

`infra/platform/jenkins/pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-home
  namespace: platform
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 10Gi
```

`infra/platform/jenkins/secret-admin.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: jenkins-admin
  namespace: platform
type: Opaque
stringData:
  JENKINS_USER: admin
  JENKINS_PASS: admin123
```

`infra/platform/jenkins/casc-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jenkins-casc
  namespace: platform
data:
  jcasc.yaml: |
    jenkins:
      systemMessage: "Local Jenkins with JCasC"
      numExecutors: 2
      securityRealm:
        local:
          allowsSignup: false
          users:
            - id: ${JENKINS_USER}
              password: ${JENKINS_PASS}
      authorizationStrategy:
        loggedInUsersCanDoAnything:
          allowAnonymousRead: false
    tool:
      git:
        installations:
          - name: default
            home: "/usr/bin/git"
    unclassified:
      location:
        url: https://jenkins.local.test/
    credentials:
      system:
        domainCredentials:
          - credentials: []
    jobs: []
```

`infra/platform/jenkins/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: platform
spec:
  replicas: 1
  selector:
    matchLabels: { app: jenkins }
  template:
    metadata:
      labels: { app: jenkins }
    spec:
      serviceAccountName: default
      containers:
        - name: jenkins
          image: jenkins/jenkins:lts-jdk17
          ports:
            - containerPort: 8080
          env:
            - name: JAVA_OPTS
              value: "-Djenkins.install.runSetupWizard=false"
            - name: CASC_JENKINS_CONFIG
              value: /var/jenkins_home/casc_configs/jcasc.yaml
            - name: JENKINS_USER
              valueFrom: { secretKeyRef: { name: jenkins-admin, key: JENKINS_USER } }
            - name: JENKINS_PASS
              valueFrom: { secretKeyRef: { name: jenkins-admin, key: JENKINS_PASS } }
          volumeMounts:
            - name: jenkins-home
              mountPath: /var/jenkins_home
            - name: casc
              mountPath: /var/jenkins_home/casc_configs
      volumes:
        - name: jenkins-home
          persistentVolumeClaim: { claimName: jenkins-home }
        - name: casc
          configMap:
            name: jenkins-casc
            items:
              - key: jcasc.yaml
                path: jcasc.yaml
```

`infra/platform/jenkins/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: platform
spec:
  selector: { app: jenkins }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

`infra/platform/jenkins/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins
  namespace: platform
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
    - hosts: ["jenkins.local.test"]
      secretName: platform-tls
  rules:
    - host: jenkins.local.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: jenkins
                port:
                  number: 8080
```

---

## 3) Makefile & helper script

### `Makefile`

```makefile
SHELL := /bin/bash
CLUSTER_NAME := local-platform
NS := platform

.PHONY: up down cluster ingress tls platform gitea registry jenkins status

up: cluster ingress tls platform status ## Create cluster + ingress + TLS + deploy platform

cluster: ## Create kind cluster
	kind create cluster --name $(CLUSTER_NAME) --config infra/cluster/kind-config.yaml
	kubectl get nodes

ingress: ## Install ingress-nginx via Helm
	hel m repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
	hel m repo update
	hel m upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
	  --namespace ingress-nginx --create-namespace \
	  -f infra/ingress/values-nginx.yaml
	kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller

# Create wildcard TLS cert for *.local.test using mkcert and store as platform-tls secret
# Requires mkcert installed and root CA trusted locally.
tls:
	mkdir -p infra/ingress/tls
	cd infra/ingress/tls && mkcert -install && mkcert "*.local.test" local.test
	kubectl apply -f infra/platform/namespace.yaml
	kubectl -n $(NS) delete secret platform-tls >/dev/null 2>&1 || true
	kubectl -n $(NS) create secret tls platform-tls \
	  --cert=infra/ingress/tls/_wildcard.local.test+1.pem \
	  --key=infra/ingress/tls/_wildcard.local.test+1-key.pem

platform: gitea registry jenkins ## Deploy platform apps (Gitea, Registry, Jenkins)

gitea:
	kubectl apply -f infra/platform/namespace.yaml
	kubectl apply -f infra/platform/gitea/pvc.yaml
	kubectl apply -f infra/platform/gitea/secret-env.yaml
	kubectl apply -f infra/platform/gitea/cm-appini.yaml
	kubectl apply -f infra/platform/gitea/deployment.yaml
	kubectl apply -f infra/platform/gitea/service.yaml
	kubectl apply -f infra/platform/gitea/ingress.yaml
	kubectl apply -f infra/platform/gitea/init-admin-job.yaml || true
	kubectl -n $(NS) rollout status deploy/gitea

registry:
	kubectl apply -f infra/platform/registry/pvc.yaml
	kubectl apply -f infra/platform/registry/deployment.yaml
	kubectl apply -f infra/platform/registry/service.yaml
	kubectl apply -f infra/platform/registry/ingress.yaml
	kubectl -n $(NS) rollout status deploy/registry

jenkins:
	kubectl apply -f infra/platform/jenkins/pvc.yaml
	kubectl apply -f infra/platform/jenkins/secret-admin.yaml
	kubectl apply -f infra/platform/jenkins/casc-configmap.yaml
	kubectl apply -f infra/platform/jenkins/deployment.yaml
	kubectl apply -f infra/platform/jenkins/service.yaml
	kubectl apply -f infra/platform/jenkins/ingress.yaml
	kubectl -n $(NS) rollout status deploy/jenkins

status:
	@echo "\nEndpoints:" \
	&& echo "  Gitea:    https://gitea.local.test" \
	&& echo "  Registry: https://registry.local.test" \
	&& echo "  Jenkins:  https://jenkins.local.test" \
	&& echo "\nIf hosts don't resolve, add to /etc/hosts: 127.0.0.1 gitea.local.test registry.local.test jenkins.local.test" \
	&& echo "\nJenkins admin: admin / admin123 (change in secret-admin.yaml)"

clean:
	kind delete cluster --name $(CLUSTER_NAME) || true
	@echo "Cluster removed."
```

> If `helm` commands error, ensure Helm is installed. You can also install ingress-nginx via `kubectl apply` using the upstream manifest if preferred.

---

## 4) Run it

1. Append this in /etc/host:

   ```
   127.0.0.1 gitea.local.test registry.local.test jenkins.local.test
   ```
2. **Bring everything up**

   ```bash
   make up
   ```
3. Visit:

   * Gitea → `https://gitea.local.test` (admin/admin123 if init job ran)
   * Jenkins → `https://jenkins.local.test` (admin/admin123)
   * Registry → `https://registry.local.test` (plain registry, no UI)

> To push an image: tag it as `registry.local.test/myapp:dev` and `docker push`. If Docker complains about certs, confirm mkcert root CA is installed on your OS. As a last resort for local dev, configure Docker "insecure-registries" for `registry.local.test`.

---

## 5) What’s next (Milestones 4–5 preview)

* **Argo CD (GitOps)**: add manifests and an App-of-Apps so changes in Git auto-sync.
* **Observability**: Prometheus, Grafana, Loki, Tempo, OTel Collector.

I can extend this scaffold with Argo CD and a starter Kotlin/Rust service (with Helm chart + Jenkinsfile) when you’re ready.
