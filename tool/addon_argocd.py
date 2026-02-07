"""ArgoCD Installation mit Istio-Integration (install-argocd.sh)."""

import base64
import os
import sys
import tempfile

from helpers import (
    ask_yes_no,
    helm_release_exists,
    kubectl_apply_stdin,
    run,
    step,
    tool_exists,
)

_ARGOCD_VALUES = """\
server:
  insecure: true
  extraArgs:
    - --insecure
  service:
    type: ClusterIP
redis:
  auth:
    enabled: true
    existingSecret: argocd-redis
"""


def install_argocd(hostname: str) -> None:
    step("ArgoCD installieren")

    for cmd in ("helm", "kubectl"):
        if not tool_exists(cmd):
            print(f"Fehler: {cmd} ist nicht installiert")
            sys.exit(1)

    # Pruefen ob ArgoCD bereits laeuft
    argocd_running = helm_release_exists("argocd", "argocd")
    if argocd_running:
        print("ArgoCD laeuft bereits (Helm Release gefunden).")
        if not ask_yes_no("  Trotzdem neu installieren/aktualisieren?", default=False):
            print("  Ueberspringe ArgoCD Installation, erstelle Istio-Ressourcen...\n")
            _create_argocd_istio_resources(hostname)
            return

    print("Fuege Argo Helm Repository hinzu...")
    run(["helm", "repo", "add", "argo", "https://argoproj.github.io/argo-helm"])
    run(["helm", "repo", "update"])

    print("Installiere ArgoCD...")
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".yaml", delete=False
    ) as tmp:
        tmp.write(_ARGOCD_VALUES)
        values_path = tmp.name
    try:
        run(
            [
                "helm",
                "upgrade",
                "--install",
                "argocd",
                "argo/argo-cd",
                "-n",
                "argocd",
                "--create-namespace",
                "-f",
                values_path,
                "--wait",
            ]
        )
    finally:
        os.unlink(values_path)

    _create_argocd_istio_resources(hostname)

    print("\nArgoCD Installation abgeschlossen.")


def get_argocd_password() -> str:
    """Liest das ArgoCD Admin-Passwort aus dem Cluster-Secret."""
    result = run(
        [
            "kubectl",
            "-n",
            "argocd",
            "get",
            "secret",
            "argocd-initial-admin-secret",
            "-o",
            "jsonpath={.data.password}",
        ],
        capture=True,
        check=False,
        quiet=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return "<nicht verfuegbar>"
    return base64.b64decode(result.stdout).decode()


def _create_argocd_istio_resources(hostname: str) -> None:
    # --- Certificate ---
    argocd_cert = f"""\
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-cert-secret
  namespace: istio-ingress
spec:
  secretName: argocd-cert-secret
  duration: 2160h
  renewBefore: 360h
  commonName: argocd.{hostname}
  isCA: false
  usages:
    - server auth
    - client auth
  dnsNames:
    - argocd.{hostname}
  issuerRef:
    name: local-ca-issuer
    kind: ClusterIssuer
"""
    print("Erstelle ArgoCD Certificate...")
    kubectl_apply_stdin(argocd_cert)

    # --- Istio Gateway ---
    argocd_gateway = f"""\
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: argocd-gateway
  namespace: istio-ingress
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: argocd-cert-secret
    hosts:
    - "argocd.{hostname}"
"""
    print("Erstelle Istio Gateway...")
    kubectl_apply_stdin(argocd_gateway)

    # --- VirtualService ---
    argocd_vs = f"""\
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: argocd-vs
  namespace: argocd
spec:
  hosts:
  - "argocd.{hostname}"
  exportTo:
  - "."
  - istio-ingress
  - istio-system
  gateways:
  - istio-ingress/argocd-gateway
  - mesh
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: argocd-server
        port:
          number: 80
"""
    print("Erstelle VirtualService...")
    kubectl_apply_stdin(argocd_vs)
