# 📌 Learning Roadmap — Local Production‑Style Barcode Payments Platform

This roadmap is your guide for incrementally building out the platform. Each milestone is self‑contained and can be committed to the repo as you progress.

---

## 0) Prereqs & Baseline

* Install Docker, kind/minikube, kubectl, Helm, mkcert, JDK + Rust toolchains
* Create repo structure (`infra/`, `platform/`, `services/`, `ops/`)
* Success: cluster tools installed, repo initialized

---

## 1) Local Kubernetes Cluster & Ingress

* Stand up kind cluster with port mappings for 80/443
* Install ingress‑nginx
* Configure mkcert for wildcard TLS `*.local.test`
* Success: `https://whoami.local.test` responds

---

## 2) Local Git & Container Registry

* Deploy Gitea (Git server) with persistent storage
* Deploy Docker registry with persistent storage
* Configure Docker to trust registry certs
* Success: push/pull repo in Gitea; push/pull image from registry

---

## 3) CI: Jenkins

* Deploy Jenkins in cluster with JCasC (admin user)
* Pipeline templates for Kotlin (Gradle + Jib) and Rust (cargo + docker)
* Success: commit → Jenkins builds & pushes image to registry

---

## 4) GitOps: Argo CD

* Deploy Argo CD
* App‑of‑Apps pattern for platform + apps
* Separate overlays for `local` env
* Success: apps auto‑sync from Git; rollback by git revert

---

## 5) Observability Foundation

* Deploy Prometheus, Grafana, Loki, Tempo, OTel Collector
* Wire services with OpenTelemetry SDKs
* Add base dashboards (JVM, Rust, HTTP)
* Success: metrics + logs + traces visible in Grafana/Tempo

---

## 6) Developer Portal: Backstage

* Deploy Backstage
* Add service catalog + TechDocs
* Create templates to scaffold Kotlin/Rust services with health, metrics, OpenAPI, Jenkinsfile
* Success: new service scaffolding end‑to‑end

---

## 7) Core Domain: Minimal Happy Path

* Consumer API (Kotlin): register, top‑up, pay, send‑money
* Merchant API (Rust): barcode generation, receive, transaction list
* Orchestrator (Kotlin): coordinate payments, ledger
* Add JWT auth (simple RBAC)
* Success: e2e flow from register → pay → merchant sees txn

---

## 8) API Gateway & Security

* Introduce Kong or use ingress‑nginx annotations for JWT, rate limiting
* Secrets via Vault/External Secrets
* Enforce HTTPS, secure cookies
* Success: endpoints protected, tokens validated

---

## 9) SSO Login
* Standard SSO Login

## 10) Payments & Concurrency

* Implement idempotency keys for payment flows
* Add Outbox or message bus (Kafka/Redpanda)
* Handle compensation (saga pattern)
* Success: retries don’t double‑charge; failures recover

---

## 11) Real‑Time Updates

* Merchant dashboard gets live updates (WebSocket/SSE)
* Simple UI to show updates (optional)
* Success: merchant sees txns without refresh

---

## 12) Production‑like Ops

* Add HPA, PodDisruptionBudget, probes
* Use Argo Rollouts for blue/green or canary
* Add retries, circuit breakers
* Success: rolling updates w/o downtime; resilience built in

---

## 13) Testing & Chaos

* Load test with k6
* Chaos experiments (kill pods, inject latency, DB failover)
* Add SLO dashboards + Alertmanager routes
* Success: SLOs met, alerts trigger, chaos tolerated
* **Make the chaos engineering autonomous using AI model.**

---

## 📎 Conventions

* Service contract first (OpenAPI)
* DB migrations (Flyway/sqlx)
* Tracing with W3C `traceparent`
* Config via Kustomize overlays
* Secrets not in Git (use Vault or manual create)

---

## 🧭 Suggested Flow

1. Milestones 1–3 → cluster + Git/Registry + CI
2. Milestone 4 → GitOps with Argo CD
3. Milestone 5 → Observability stack
4. Milestones 6–7 → services and happy path
5. Milestones 8–12 → hardening, scaling, chaos

---

Keep this file updated as you adapt or reorder milestones.
