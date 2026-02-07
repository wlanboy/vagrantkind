"""cert-manager Installation (install-certmanager.sh)."""

import sys
from pathlib import Path

from helpers import (
    ask_yes_no,
    ensure_namespace,
    helm_release_exists,
    kubectl_apply_stdin,
    run,
    step,
    tool_exists,
)

_CLUSTER_ISSUER = """\
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: local-ca-issuer
spec:
  ca:
    secretName: my-local-ca-secret
"""


def install_certmanager(ca_dir: Path) -> None:
    step("cert-manager installieren")

    ca_cert = ca_dir / "ca.pem"
    ca_key = ca_dir / "ca.key"

    for cmd in ("helm", "kubectl"):
        if not tool_exists(cmd):
            print(f"Fehler: {cmd} ist nicht installiert")
            sys.exit(1)

    if not ca_cert.exists():
        print(f"Fehler: CA-Zertifikat nicht gefunden: {ca_cert}")
        sys.exit(1)
    if not ca_key.exists():
        print(f"Fehler: CA-Key nicht gefunden: {ca_key}")
        sys.exit(1)

    # Pruefen ob cert-manager bereits laeuft
    cm_running = helm_release_exists("cert-manager", "cert-manager")
    if cm_running:
        print("cert-manager laeuft bereits (Helm Release gefunden).")
        if not ask_yes_no("  Trotzdem neu installieren/aktualisieren?", default=False):
            print("  Ueberspringe cert-manager Installation, erstelle Secret & Issuer...\n")
            _create_ca_secret_and_issuer(ca_cert, ca_key)
            return

    ensure_namespace("cert-manager")

    print("Fuege Jetstack Helm Repository hinzu...")
    run(["helm", "repo", "add", "jetstack", "https://charts.jetstack.io"])
    run(["helm", "repo", "update"])

    print("Installiere cert-manager...")
    run(
        [
            "helm",
            "upgrade",
            "--install",
            "cert-manager",
            "jetstack/cert-manager",
            "--namespace",
            "cert-manager",
            "--set",
            "crds.enabled=true",
            "--wait",
        ]
    )

    print("Warte auf cert-manager Pods...")
    run(
        [
            "kubectl",
            "-n",
            "cert-manager",
            "wait",
            "--for=condition=Ready",
            "--all",
            "pods",
            "--timeout=120s",
        ]
    )

    _create_ca_secret_and_issuer(ca_cert, ca_key)

    print("\ncert-manager Status:")
    run(["kubectl", "get", "pods", "-n", "cert-manager", "-o", "wide"])
    run(["kubectl", "get", "clusterissuers"])

    print("\ncert-manager Installation abgeschlossen.")


def _create_ca_secret_and_issuer(ca_cert: Path, ca_key: Path) -> None:
    print("Erstelle CA Secret...")
    # dry-run + apply fuer Idempotenz
    dry_run = run(
        [
            "kubectl",
            "create",
            "secret",
            "tls",
            "my-local-ca-secret",
            "--namespace",
            "cert-manager",
            f"--cert={ca_cert}",
            f"--key={ca_key}",
            "--dry-run=client",
            "-o",
            "yaml",
        ],
        capture=True,
    )
    kubectl_apply_stdin(dry_run.stdout)

    print("Erstelle ClusterIssuer...")
    kubectl_apply_stdin(_CLUSTER_ISSUER)
