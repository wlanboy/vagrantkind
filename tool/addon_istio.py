"""Istio Service Mesh (install-istio.sh)."""

import sys

from addon_demoservice import deploy_demo_service
from helpers import (
    ask_yes_no,
    ensure_namespace,
    helm_release_exists,
    run,
    step,
    tool_exists,
)


def install_istio(hostname: str) -> None:
    step("Istio installieren")

    for cmd in ("helm", "kubectl"):
        if not tool_exists(cmd):
            print(f"Fehler: {cmd} ist nicht installiert")
            sys.exit(1)

    # Pruefen ob Istio bereits laeuft
    istio_running = helm_release_exists("istiod", "istio-system")
    if istio_running:
        print("Istio laeuft bereits (Helm Release 'istiod' gefunden).")
        if not ask_yes_no("  Trotzdem neu installieren/aktualisieren?", default=False):
            print("  Ueberspringe Istio, fahre mit Demo-Service fort...\n")
            deploy_demo_service(hostname)
            return

    print("Fuege Istio Helm Repository hinzu...")
    run(["helm", "repo", "add", "istio", "https://istio-release.storage.googleapis.com/charts"])
    run(["helm", "repo", "update"])

    ensure_namespace("istio-system")

    print("Installiere Istio Base...")
    run(["helm", "upgrade", "--install", "istio-base", "istio/base", "-n", "istio-system", "--wait"])

    print("Installiere Istiod...")
    run(["helm", "upgrade", "--install", "istiod", "istio/istiod", "-n", "istio-system", "--wait"])

    ensure_namespace("istio-ingress")

    print("Installiere Istio Ingress Gateway...")
    run(
        [
            "helm",
            "upgrade",
            "--install",
            "istio-ingressgateway",
            "istio/gateway",
            "-n",
            "istio-ingress",
            "--wait",
        ]
    )

    deploy_demo_service(hostname)

    print("\nIstio Installation abgeschlossen.")
