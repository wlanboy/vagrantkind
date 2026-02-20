#!/usr/bin/env python3
"""
Interactive ArgoCD deployment selector.
Apply order:  cluster/project → per app (namespace → app → workflow → eventsource → sensor) → global events
Delete order: global events (reversed) → per app (sensor → eventsource → workflow → app → namespace)
"""

import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()

APPS_DIR = SCRIPT_DIR / "argocd-apps"
NS_DIR = SCRIPT_DIR / "argocd-namespaces"
WORKFLOWS_DIR = SCRIPT_DIR / "argocd-workflows"
EVENTS_DIR = SCRIPT_DIR / "argocd-events"
PROJECTS_DIR = SCRIPT_DIR / "argocd-projects"

GLOBAL_EVENTS = ["eventbus.yaml", "eventsource-workflow-complete.yaml", "sensor-argocd-sync.yaml"]


def kubectl_apply(path: Path):
    print(f"  kubectl apply -f {path.name}")
    result = subprocess.run(["kubectl", "apply", "-f", str(path)], capture_output=False)
    if result.returncode != 0:
        print(f"  ERROR: kubectl apply failed for {path.name}", file=sys.stderr)
        sys.exit(result.returncode)


def kubectl_delete(path: Path):
    print(f"  kubectl delete -f {path.name}")
    result = subprocess.run(
        ["kubectl", "delete", "-f", str(path), "--ignore-not-found"],
        capture_output=False,
    )
    if result.returncode != 0:
        print(f"  ERROR: kubectl delete failed for {path.name}", file=sys.stderr)
        sys.exit(result.returncode)


def select_mode() -> str:
    print("\nMode:")
    print("  [1] apply  (deploy selected resources)")
    print("  [2] delete (remove selected resources)")
    raw = input("> ").strip().lower()
    if raw in ("1", "apply", "a"):
        return "apply"
    if raw in ("2", "delete", "d"):
        return "delete"
    print("Invalid mode.", file=sys.stderr)
    sys.exit(1)


def select_files(files: list[Path], label: str, mode: str, name_fn=None) -> list[Path]:
    """Show a numbered list and return the user-selected subset. Empty input = skip all."""
    if not files:
        print(f"\n(No {label} found, skipping.)")
        return []

    if name_fn is None:
        name_fn = lambda p: p.stem

    print(f"\nAvailable {label}:")
    for i, f in enumerate(files, 1):
        print(f"  [{i}] {name_fn(f)}")
    print(f"Select {label} to {mode} (e.g. 1  or  1,3  or  all  or  Enter to skip):")

    raw = input("> ").strip().lower()

    if raw == "" or raw == "0":
        return []
    if raw in ("all", "a", "*"):
        return list(files)

    selected = []
    for token in raw.replace(",", " ").split():
        try:
            idx = int(token)
        except ValueError:
            print(f"Invalid input: '{token}'", file=sys.stderr)
            sys.exit(1)
        if not 1 <= idx <= len(files):
            print(f"Number out of range: {idx}", file=sys.stderr)
            sys.exit(1)
        f = files[idx - 1]
        if f not in selected:
            selected.append(f)

    return selected


def app_short_name(p: Path) -> str:
    return p.stem.removeprefix("app-")


def find_or_none(path: Path) -> Path | None:
    return path if path.exists() else None


def per_app_files(name: str) -> dict:
    return {
        "namespace":   find_or_none(NS_DIR        / f"namespace-{name}.yaml"),
        "workflow":    find_or_none(WORKFLOWS_DIR  / f"workflow-{name}.yaml"),
        "eventsource": find_or_none(EVENTS_DIR     / f"eventsource-github-{name}.yaml"),
        "sensor":      find_or_none(EVENTS_DIR     / f"sensor-kaniko-{name}.yaml"),
    }


def main():
    apps = sorted(APPS_DIR.glob("app-*.yaml"))
    global_events = [EVENTS_DIR / f for f in GLOBAL_EVENTS if (EVENTS_DIR / f).exists()]

    print("=" * 50)
    print("  ArgoCD Deployment Selector")
    print("=" * 50)

    mode = select_mode()

    selected_apps = select_files(apps, "apps", mode, app_short_name)
    selected_globals = select_files(global_events, "global events", mode)

    if not selected_apps and not selected_globals:
        print("\nNothing selected. Aborting.")
        sys.exit(0)

    # --- Summary ---
    print(f"\n--- {'Deployment' if mode == 'apply' else 'Deletion'} plan ---")

    if mode == "apply":
        print("  [pre]    cluster-gmk.yaml, wlanboy-project.yaml")
        for app in selected_apps:
            name = app_short_name(app)
            files = per_app_files(name)
            print(f"  [{name}]")
            print(f"    1. {files['namespace'].name   if files['namespace']   else '(no namespace yaml)'}")
            print(f"    2. {app.name}")
            print(f"    3. {files['workflow'].name    if files['workflow']    else '(no workflow yaml)'}")
            print(f"    4. {files['eventsource'].name if files['eventsource'] else '(no eventsource yaml)'}")
            print(f"    5. {files['sensor'].name      if files['sensor']      else '(no sensor yaml)'}")
        if selected_globals:
            print(f"  [global events] {', '.join(f.name for f in selected_globals)}")
    else:
        if selected_globals:
            print(f"  [global events] {', '.join(f.name for f in reversed(selected_globals))}")
        for app in selected_apps:
            name = app_short_name(app)
            files = per_app_files(name)
            print(f"  [{name}]")
            print(f"    1. {files['sensor'].name      if files['sensor']      else '(no sensor yaml)'}")
            print(f"    2. {files['eventsource'].name if files['eventsource'] else '(no eventsource yaml)'}")
            print(f"    3. {files['workflow'].name    if files['workflow']    else '(no workflow yaml)'}")
            print(f"    4. {app.name}")
            print(f"    5. {files['namespace'].name   if files['namespace']   else '(no namespace yaml)'}")

    print()
    input(f"Press Enter to {mode}, Ctrl+C to abort...")

    if mode == "apply":
        # --- Pre ---
        print("\n--- [Pre] Applying cluster config and project ---")
        kubectl_apply(PROJECTS_DIR / "cluster-gmk.yaml")
        kubectl_apply(PROJECTS_DIR / "wlanboy-project.yaml")

        # --- Per app: namespace → app → workflow → eventsource → sensor ---
        for app in selected_apps:
            name = app_short_name(app)
            files = per_app_files(name)
            print(f"\n--- [{name}] ---")
            if files["namespace"]:
                kubectl_apply(files["namespace"])
            else:
                print("  (no namespace yaml found)")
            kubectl_apply(app)
            if files["workflow"]:
                kubectl_apply(files["workflow"])
            else:
                print("  (no workflow yaml found)")
            if files["eventsource"]:
                kubectl_apply(files["eventsource"])
            else:
                print("  (no eventsource yaml found)")
            if files["sensor"]:
                kubectl_apply(files["sensor"])
            else:
                print("  (no sensor yaml found)")

        # --- Global events ---
        if selected_globals:
            print("\n--- Applying global events ---")
            for ev in selected_globals:
                kubectl_apply(ev)

    else:  # delete
        # --- Global events first (reversed) ---
        if selected_globals:
            print("\n--- Deleting global events ---")
            for ev in reversed(selected_globals):
                kubectl_delete(ev)

        # --- Per app: sensor → eventsource → workflow → app → namespace ---
        for app in selected_apps:
            name = app_short_name(app)
            files = per_app_files(name)
            print(f"\n--- [{name}] ---")
            if files["sensor"]:
                kubectl_delete(files["sensor"])
            else:
                print("  (no sensor yaml found)")
            if files["eventsource"]:
                kubectl_delete(files["eventsource"])
            else:
                print("  (no eventsource yaml found)")
            if files["workflow"]:
                kubectl_delete(files["workflow"])
            else:
                print("  (no workflow yaml found)")
            kubectl_delete(app)
            if files["namespace"]:
                kubectl_delete(files["namespace"])
            else:
                print("  (no namespace yaml found)")

    print("\nDone.")


if __name__ == "__main__":
    main()
