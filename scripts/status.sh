#!/usr/bin/env bash
set -euo pipefail

NS=${NS:-platform}
ok=0; fail=0

log_ok()   { printf "✅  %s\n" "$1"; ok=$((ok+1)); }
log_fail() { printf "❌  %s\n" "$1"; fail=$((fail+1)); }
check()    { local desc="$1"; shift; if eval "$@"; then log_ok "$desc"; else log_fail "$desc"; fi; }

echo "== Kubernetes objects =="
check "Namespace exists (platform)" "kubectl get ns \"$NS\" >/dev/null 2>&1"
check "Ingress-NGINX controller Ready" "kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller >/dev/null 2>&1"
check "Gitea deployment Ready" "kubectl -n \"$NS\" rollout status deploy/gitea >/dev/null 2>&1"
check "Registry deployment Ready" "kubectl -n \"$NS\" rollout status deploy/registry >/dev/null 2>&1"
check "Jenkins deployment Ready" "kubectl -n \"$NS\" rollout status deploy/jenkins >/dev/null 2>&1"
check "TLS secret platform-tls present" "kubectl -n \"$NS\" get secret platform-tls >/dev/null 2>&1"
check "Ingresses present (gitea/registry/jenkins)" "kubectl -n \"$NS\" get ingress gitea jenkins registry >/dev/null 2>&1"
check "Gitea service has endpoints" "kubectl -n \"$NS\" get endpoints gitea -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q ."
check "Registry service has endpoints" "kubectl -n \"$NS\" get endpoints registry -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q ."
check "Jenkins service has endpoints" "kubectl -n \"$NS\" get endpoints jenkins -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q ."

echo
echo "== External HTTPS checks =="
curl_code() { local host="$1"; curl -sSIL --max-time 10 "https://$host" -o /dev/null -w "%{http_code}" || true; }
for host in gitea.local.test registry.local.test jenkins.local.test; do
  code=$(curl_code "$host")
  if [[ "$code" == "200" || "$code" == "302" || "$code" == "405" ]]; then
    log_ok "https://$host responds ($code)"
  else
    log_fail "https://$host responds ($code)"
  fi
done

echo
printf "Summary: ✅ %d, ❌ %d\n" "$ok" "$fail"
echo
echo "Endpoints:"
echo "  Gitea:    https://gitea.local.test"
echo "  Registry: https://registry.local.test"
echo "  Jenkins:  https://jenkins.local.test"
echo
echo "If hosts don't resolve, add to /etc/hosts: 127.0.0.1 gitea.local.test registry.local.test jenkins.local.test"
echo "Jenkins admin: admin / admin123 (change in secret-admin.yaml)"

exit $([[ "$fail" -eq 0 ]])


