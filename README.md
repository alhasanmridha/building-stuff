# Barcode Payments Lab — Local Production‑Style Platform

A hands‑on sandbox to simulate a **production‑grade barcode payment ecosystem** on your **local machine**. It leverages industry tools—**Kubernetes**, **GitOps**, **CI/CD**, and **observability**—so you can explore how complex financial systems are designed and operated.

> ✅ Milestones 1–3 complete: **kind** cluster + **ingress‑nginx** + TLS (mkcert), **Gitea** (Git), **Docker Registry**, and **Jenkins** (CI). Next: **Argo CD**, Kotlin/Rust services, and observability stack (Prometheus/Grafana/Loki/Tempo/OTel).

---

## 🎯 Goals

* Emulate a **production‑like environment** locally
* Practice with **GitOps, CI/CD, service scaffolding, and observability**
* Build a two‑sided **barcode payment system** (consumer & merchant)

## 🧩 System Components (target)

* **Consumer‑facing**: registration, top‑up, send money, payments
* **Merchant‑facing**: barcode generation, receive payments, real‑time updates, transaction history
* **Platform**: Git (Gitea), CI (Jenkins), GitOps (Argo CD), Observability (Prometheus/Grafana/Loki/Tempo), Developer Portal (Backstage)

---

## 📂 Repository Layout

```
infra/
  cluster/                # kind cluster config
  ingress/                # ingress-nginx + TLS via mkcert
  platform/               # Gitea, Registry, Jenkins manifests
services/                 # (to be added) Kotlin/Rust services
ops/                      # helper scripts (optional)
Makefile
README.md
```

---

## ✅ Prerequisites

* Docker Desktop or Docker Engine
* **kind** (default) or **minikube**
* `kubectl`, `helm`
* `mkcert` for local TLS ([mkcert](https://github.com/FiloSottile/mkcert))
* macOS/Linux (Windows users: WSL2 recommended)

---

## 🚀 Quickstart

1. **Map local hosts** — add to `/etc/hosts`:

   ```
   127.0.0.1 gitea.local.test registry.local.test jenkins.local.test
   ```

2. **Bring platform up**

   ```bash
   make up
   ```

3. **Access endpoints**

   * Gitea:    [https://gitea.local.test](https://gitea.local.test)

   * Registry: [https://registry.local.test](https://registry.local.test)

   * Jenkins:  [https://jenkins.local.test](https://jenkins.local.test)

   > Jenkins admin credentials are defined in `infra/platform/jenkins/secret-admin.yaml` (`admin` / `admin123`). Update them immediately.

4. **Push an image to registry**

   ```bash
   docker build -t registry.local.test/example/hello:dev .
   docker push registry.local.test/example/hello:dev
   ```

   If TLS issues occur, run `mkcert -install` to trust the CA.

---

## 🛠 Make Targets

* `make up` – Full setup: cluster + ingress + TLS + platform
* `make cluster` – Create kind cluster
* `make ingress` – Install ingress‑nginx via Helm
* `make tls` – Generate TLS certs and K8s secret `platform-tls`
* `make platform` – Deploy Gitea, Registry, Jenkins
* `make clean` – Delete cluster

---

## 🔐 TLS & Certificates

TLS is provided by **mkcert**. `make tls` generates a wildcard cert for `*.local.test` and creates the `platform-tls` Kubernetes secret.

> If browser or Docker trust errors occur: re‑run `mkcert -install`, recreate the secret, and restart Docker. As a fallback, configure Docker with `insecure-registries` (not recommended).

---

## 📦 What’s Included (Milestones 1–3)

* **Kubernetes** with kind (80/443 mapped)
* **ingress‑nginx** controller
* **Gitea** Git server (+ optional admin init job)
* **Docker Registry** with persistence
* **Jenkins** with JCasC (ready‑made admin)

---

## 🧭 Roadmap

The full step‑by‑step plan is documented in [ROADMAP.md](./ROADMAP.md). In brief:

* **Milestones 4–5**: Add Argo CD (GitOps) and observability (Prometheus, Grafana, Loki, Tempo)
* **Milestone 6+**: Add Kotlin/Rust services, Backstage portal, payments workflows, scaling, chaos testing

---

## 🐛 Troubleshooting

* **Ingress unreachable**: Ensure ports 80/443 free; check `kubectl -n ingress-nginx get pods`
* **TLS errors**: Run `mkcert -install`; recreate `platform-tls`; restart Docker
* **Jenkins setup wizard**: Confirm `CASC_JENKINS_CONFIG` env + ConfigMap are mounted
* **PVC Pending**: Install storage provisioner if default isn’t binding (esp. with kind)

---

## 🤝 Contributing

Contributions welcome! Please keep docs clear and examples reproducible. Aim for **minimal, idiomatic, production‑inspired** manifests.

## 📜 License

MIT
