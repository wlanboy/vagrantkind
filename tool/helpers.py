"""Gemeinsame Hilfsfunktionen fuer alle Addon-Module."""

import shutil
import subprocess


def run(
    cmd: "list[str] | str",
    *,
    check: bool = True,
    capture: bool = False,
    input_data: "str | None" = None,
    shell: bool = False,
    quiet: bool = False,
) -> subprocess.CompletedProcess:
    """Fuehrt einen Befehl aus und gibt das Ergebnis zurueck."""
    if not quiet:
        label = " ".join(cmd) if isinstance(cmd, list) else cmd
        print(f"  → {label}")
    return subprocess.run(
        cmd,
        check=check,
        capture_output=capture,
        text=True,
        input=input_data,
        shell=shell,
    )


def tool_exists(name: str) -> bool:
    return shutil.which(name) is not None


def ask_yes_no(prompt: str, default: bool = True) -> bool:
    suffix = " [J/n]: " if default else " [j/N]: "
    answer = input(prompt + suffix).strip().lower()
    if not answer:
        return default
    return answer in ("y", "yes", "j", "ja")


def ensure_namespace(ns: str) -> None:
    """Erstellt einen Kubernetes-Namespace, falls er noch nicht existiert."""
    result = run(["kubectl", "get", "ns", ns], check=False, capture=True, quiet=True)
    if result.returncode != 0:
        run(["kubectl", "create", "namespace", ns])
    else:
        print(f"  Namespace '{ns}' existiert bereits.")


def kubectl_apply_stdin(yaml_content: str) -> None:
    run(["kubectl", "apply", "-f", "-"], input_data=yaml_content)


def step(title: str) -> None:
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}\n")


def install_dns_records(hostname: str, ip: str) -> None:
    from pathlib import Path

    step("DNS-Eintraege konfigurieren (/etc/hosts)")

    domains = [f"argocd.{hostname}", f"demo.{hostname}"]
    hosts_content = Path("/etc/hosts").read_text()

    for domain in domains:
        if domain in hosts_content:
            print(f"  {domain} ist bereits in /etc/hosts eingetragen")
        else:
            print(f"  Fuege {domain} -> {ip} hinzu")
            run(
                f'echo "{ip}    {domain}" | sudo tee -a /etc/hosts > /dev/null',
                shell=True,
            )

    print("\nAktuelle Eintraege:")
    for domain in domains:
        result = run(
            ["grep", domain, "/etc/hosts"], check=False, capture=True, quiet=True
        )
        if result.stdout.strip():
            print(f"  {result.stdout.strip()}")


def helm_release_exists(name: str, namespace: str) -> bool:
    """Prueft ob ein Helm Release in einem Namespace existiert."""
    result = run(
        ["helm", "list", "-n", namespace, "-q", "--filter", f"^{name}$"],
        check=False, capture=True, quiet=True,
    )
    return name in result.stdout.splitlines()
