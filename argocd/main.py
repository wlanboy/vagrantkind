import subprocess
import sys
from pathlib import Path

BASE_DIR = Path(__file__).parent

STEPS = [
    ("ArgoCD Cluster (local)", "cluster-local.yaml"),
    ("ArgoCD Repository (wlanboy)", "repos/repo-wlanboy.yaml"),
    ("ArgoCD Project (wlanboy)", "projects/wlanboy-project.yaml"),
    ("Namespace (mirror)", "namespaces/namespace-mirror.yaml"),
    ("Application (mirror)", "apps/app-mirror.yaml"),
    ("Namespace (javahttpclient)", "namespaces/namespace-javahttpclient.yaml"),
    ("Application (javahttpclient)", "apps/app-javahttpclient.yaml"),
    ("Namespace (kubeeventjava)", "namespaces/namespace-kubeeventjava.yaml"),
    ("Application (kubeeventjava)", "apps/app-kubeeventjava.yaml"),
    ("Namespace (randomfail)", "namespaces/namespace-randomfail.yaml"),
    ("Application (randomfail)", "apps/app-randomfail.yaml"),
]


def resource_exists(filepath: Path) -> bool:
    result = subprocess.run(
        ["kubectl", "get", "-f", str(filepath)],
        capture_output=True,
    )
    return result.returncode == 0


def apply_resource(filepath: Path) -> bool:
    result = subprocess.run(
        ["kubectl", "apply", "-f", str(filepath)],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        print(f"  -> {result.stdout.strip()}")
        return True
    else:
        print(f"  -> Fehler: {result.stderr.strip()}")
        return False


def ask_yes_no(prompt: str) -> bool:
    while True:
        answer = input(f"{prompt} [j/n]: ").strip().lower()
        if answer in ("j", "ja", "y", "yes"):
            return True
        if answer in ("n", "nein", "no"):
            return False


def main():
    print("=== ArgoCD Setup ===\n")

    for label, relative_path in STEPS:
        filepath = BASE_DIR / relative_path
        if not filepath.exists():
            print(f"[FEHLER] Datei nicht gefunden: {filepath}")
            sys.exit(1)

        print(f"Pruefe: {label}")

        if resource_exists(filepath):
            print(f"  -> Existiert bereits, ueberspringe.\n")
            continue

        print(f"  -> Existiert noch nicht.")
        if ask_yes_no(f"  Soll '{label}' angelegt werden?"):
            if not apply_resource(filepath):
                sys.exit(1)
        else:
            print("  -> Uebersprungen.")
        print()

    print("=== Fertig ===")


if __name__ == "__main__":
    main()
