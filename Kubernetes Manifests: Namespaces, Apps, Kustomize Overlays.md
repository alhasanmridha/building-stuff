# Kubernetes Manifests (separate `-k8s` repos per service)

You asked to keep **application code** and **Kubernetes manifests** in **separate repositories**. This update restructures the manifests so each service has its own `-k8s` repo:

* App repo: `consumer-api-kotlin`  → Manifest repo: \`\`
* App repo: `merchant-api-rust`    → Manifest repo: \`\`

Each `-k8s` repo is **raw Kubernetes YAML** using **Kustomize** (no Helm). You can `kubectl apply -k overlays/local` to deploy locally.

---

## Repository layout (per `*-k8s` repo)

```
# Example: consumer-api-kotlin-k8s (root of the k8s repo)
namespaces/
  apps-namespace.yaml         # apply once; shared "apps" namespace
base/
  deployment.yaml
  service.yaml
  configmap.yaml
  secret.example.yaml         # do NOT commit real secrets
  ingress.yaml
  hpa.yaml
  pdb.yaml
  serviceaccount.yaml
  kustomization.yaml
overlays/
  local/
    kustomization.yaml
    image-patch.yaml
    env-patch.yaml
```

> The `namespaces/apps-namespace.yaml` file is included for convenience; apply it **once** (it’s identical across repos).

---

## `namespaces/apps-namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: apps
```

---

# consumer-api-kotlin-k8s

## `base/serviceaccount.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: consumer-api
  namespace: apps
```

## `base/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: consumer-api-config
  namespace: apps
data:
  APP_NAME: "consumer-api"
  LOG_LEVEL: "INFO"
```

## `base/secret.example.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: consumer-api-secrets
  namespace: apps
type: Opaque
stringData:
  DATABASE_URL: "postgres://user:pass@postgres.apps.svc.cluster.local:5432/consumer"
  JWT_PUBLIC_KEY: "-----BEGIN PUBLIC KEY-----
...
-----END PUBLIC KEY-----"
```

## `base/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: consumer-api
  namespace: apps
  labels:
    app.kubernetes.io/name: consumer-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: consumer-api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: consumer-api
    spec:
      serviceAccountName: consumer-api
      containers:
        - name: app
          image: registry.local.test/example/consumer-api:dev
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
          envFrom:
            - configMapRef:
                name: consumer-api-config
            - secretRef:
                name: consumer-api-secrets
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /live
              port: http
            initialDelaySeconds: 15
            periodSeconds: 10
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

## `base/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: consumer-api
  namespace: apps
spec:
  selector:
    app.kubernetes.io/name: consumer-api
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
```

## `base/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: consumer-api
  namespace: apps
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
    - hosts: ["consumer.local.test"]
      secretName: platform-tls
  rules:
    - host: consumer.local.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: consumer-api
                port:
                  number: 80
```

## `base/hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: consumer-api
  namespace: apps
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: consumer-api
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

## `base/pdb.yaml`

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: consumer-api
  namespace: apps
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: consumer-api
```

## `base/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: apps
resources:
  - ../namespaces/apps-namespace.yaml
  - serviceaccount.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - hpa.yaml
  - pdb.yaml
# secrets are applied out-of-band to avoid committing real values
```

## `overlays/local/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
patches:
  - path: image-patch.yaml
  - path: env-patch.yaml
```

## `overlays/local/image-patch.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: consumer-api
  namespace: apps
spec:
  template:
    spec:
      containers:
        - name: app
          image: registry.local.test/example/consumer-api:dev
```

## `overlays/local/env-patch.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: consumer-api
  namespace: apps
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: local
```

---

# merchant-api-rust-k8s

## `base/serviceaccount.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: merchant-api
  namespace: apps
```

## `base/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: merchant-api-config
  namespace: apps
data:
  APP_NAME: "merchant-api"
  LOG_LEVEL: "INFO"
```

## `base/secret.example.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: merchant-api-secrets
  namespace: apps
type: Opaque
stringData:
  DATABASE_URL: "postgres://user:pass@postgres.apps.svc.cluster.local:5432/merchant"
  JWT_PUBLIC_KEY: "-----BEGIN PUBLIC KEY-----
...
-----END PUBLIC KEY-----"
```

## `base/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: merchant-api
  namespace: apps
  labels:
    app.kubernetes.io/name: merchant-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: merchant-api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: merchant-api
    spec:
      serviceAccountName: merchant-api
      containers:
        - name: app
          image: registry.local.test/example/merchant-api:dev
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
          envFrom:
            - configMapRef:
                name: merchant-api-config
            - secretRef:
                name: merchant-api-secrets
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /live
              port: http
            initialDelaySeconds: 15
            periodSeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 300m
              memory: 256Mi
```

## `base/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: merchant-api
  namespace: apps
spec:
  selector:
    app.kubernetes.io/name: merchant-api
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
```

## `base/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: merchant-api
  namespace: apps
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
    - hosts: ["merchant.local.test"]
      secretName: platform-tls
  rules:
    - host: merchant.local.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: merchant-api
                port:
                  number: 80
```

## `base/hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: merchant-api
  namespace: apps
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: merchant-api
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

## `base/pdb.yaml`

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: merchant-api
  namespace: apps
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: merchant-api
```

## `base/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: apps
resources:
  - ../namespaces/apps-namespace.yaml
  - serviceaccount.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - hpa.yaml
  - pdb.yaml
```

## `overlays/local/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
patches:
  - path: image-patch.yaml
  - path: env-patch.yaml
```

## `overlays/local/image-patch.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: merchant-api
  namespace: apps
spec:
  template:
    spec:
      containers:
        - name: app
          image: registry.local.test/example/merchant-api:dev
```

## `overlays/local/env-patch.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: merchant-api
  namespace: apps
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: RUST_LOG
              value: info
```

---

## How to apply (from each `*-k8s` repo)

```bash
# 1) Create the shared namespace (run once from either repo)
kubectl apply -f namespaces/apps-namespace.yaml

# 2) Create secrets from your real values (do NOT commit them)
kubectl -n apps apply -f base/secret.example.yaml

# 3) Deploy the service using the local overlay
kubectl apply -k overlays/local
```

> Add DNS entries in `/etc/hosts`: `consumer.local.test`, `merchant.local.test`. Ingress uses the shared `platform-tls` secret created in your platform repo (Milestones 1–3).

---

### Notes

* **Two repos per service:** `service` and `service-k8s`. The `-k8s` repo is the GitOps/deployment source.
* **Images:** Set the `image:` in `overlays/local/image-patch.yaml` to your registry image.
* **Secrets:** Use the `secret.example.yaml` as a template; create a **real** Secret per environment.
* **No Helm:** Pure YAML + Kustomize overlays for clarity.
* **Argo CD (later):** Point Argo applications at each `*-k8s` repo `overlays/local` (or other env overlays).
