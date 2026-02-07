#!/usr/bin/env python3
"""Vagrantkind Setup – Einstiegspunkt und Orchestrierung."""

import json
import subprocess
import sys
from pathlib import Path

from addon_argocd import get_argocd_password, install_argocd
from addon_certmanager import install_certmanager
from addon_istio import install_istio
from addon_localca import create_ca
from addon_metallb import create_kind_cluster
from addon_tools import check_and_install_tools
from helpers import ask_yes_no, install_dns_records, run, step
from versions import DEFAULT_IP_LINUX, DEFAULT_IP_WSL

# ---------------------------------------------------------------------------
# Konfiguration laden/speichern
# ---------------------------------------------------------------------------
_CONFIG_FILE = Path(__file__).parent / "daten.json"


def _load_config() -> dict:
    """Laedt gespeicherte Konfiguration aus daten.json."""
    if _CONFIG_FILE.exists():
        return json.loads(_CONFIG_FILE.read_text())
    return {}


def _save_config(data: dict) -> None:
    """Speichert Konfiguration in daten.json."""
    _CONFIG_FILE.write_text(json.dumps(data, indent=2) + "\n")



# ---------------------------------------------------------------------------
# Zusammenfassung
# ---------------------------------------------------------------------------
def _show_summary_if_cluster_running(hostname: str, ca_dir: Path) -> None:
    """Zeigt die Zusammenfassung nur wenn ein Kind Cluster laeuft."""
    result = run(["kind", "get", "clusters"], capture=True, check=False, quiet=True)
    if "local" in result.stdout.splitlines():
        _show_summary(hostname, ca_dir)


def _show_summary(hostname: str, ca_dir: Path) -> None:
    step("Zusammenfassung")
    print(f"  ArgoCD:     https://argocd.{hostname}")
    print(f"  Demo:       http://demo.{hostname}")
    print(f"  CA-Dir:     {ca_dir}")
    print(f"  ArgoCD PW:  {get_argocd_password()}")
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    print()
    print("+----------------------------------------------------+")
    print("|  Kind Setup                                         |")
    print("|  Kind + Istio + cert-manager + ArgoCD               |")
    print("+----------------------------------------------------+")
    print()

    config = _load_config()
    saved_hostname = config.get("hostname", "")
    saved_env = config.get("umgebung", "")

    # --- Umgebung abfragen ---
    if saved_env:
        env_input = input(f"Umgebung - wsl oder linux [{saved_env}]: ").strip().lower()
        if not env_input:
            env_input = saved_env
    else:
        env_input = input("Umgebung - wsl oder linux: ").strip().lower()
    if env_input not in ("wsl", "linux"):
        print(f"Fehler: Ungueltiger Wert '{env_input}', erlaubt: wsl, linux")
        sys.exit(1)

    default_ip = DEFAULT_IP_WSL if env_input == "wsl" else DEFAULT_IP_LINUX
    saved_ip = config.get("ip", default_ip)

    # --- Hostname abfragen ---
    if saved_hostname:
        hostname = input(f"Hostname (ersetzt .tp.lan) [{saved_hostname}]: ").strip()
        if not hostname:
            hostname = saved_hostname
    else:
        hostname = input("Hostname (ersetzt .tp.lan, z.B. 'myhost.lan'): ").strip()
        if not hostname:
            print("Fehler: Hostname darf nicht leer sein")
            sys.exit(1)

    # --- IP-Adresse abfragen ---
    ip = input(f"IP-Adresse fuer DNS-Eintraege [{saved_ip}]: ").strip()
    if not ip:
        ip = saved_ip

    # --- Werte speichern ---
    _save_config({"hostname": hostname, "ip": ip, "umgebung": env_input})
    print(f"  Konfiguration gespeichert in {_CONFIG_FILE}")

    ca_dir = Path.home() / "local-ca"

    print(f"\nKonfiguration:")
    print(f"  Umgebung:  {env_input}")
    print(f"  Hostname:  {hostname}")
    print(f"  DNS-IP:    {ip}")
    print(f"  CA-Dir:    {ca_dir}")
    print(f"  Domains:   argocd.{hostname}, demo.{hostname}")
    print()

    if not ask_yes_no("Setup starten?"):
        print("Abgebrochen.")
        _show_summary_if_cluster_running(hostname, ca_dir)
        sys.exit(0)

    # --- Bestehenden Cluster pruefen ---
    result = run(["kind", "get", "clusters"], capture=True, check=False, quiet=True)
    if "local" in result.stdout.splitlines():
        if ask_yes_no("Kind Cluster 'local' existiert bereits. Loeschen?", default=False):
            run(["kind", "delete", "clusters", "local"])
        else:
            print("  Cluster bleibt bestehen.")

    # --- Alle Schritte ausfuehren ---
    try:
        check_and_install_tools()
        create_ca(ca_dir)
        create_kind_cluster(ip)
        install_istio(hostname)
        install_certmanager(ca_dir)
        install_argocd(hostname)
        install_dns_records(hostname, ip)
    except (subprocess.CalledProcessError, KeyboardInterrupt) as exc:
        if isinstance(exc, KeyboardInterrupt):
            print("\n\nAbgebrochen durch Benutzer.")
        else:
            print(f"\nFehler aufgetreten: {exc}")
        _show_summary_if_cluster_running(hostname, ca_dir)
        sys.exit(1)

    _show_summary(hostname, ca_dir)


if __name__ == "__main__":
    main()
