"""Tool-Installation (amd64): kubectl, helm, kind, istioctl, k9s, argocd, hey, mirrord."""

import os
import re
import shutil
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path

from helpers import ask_yes_no, run, step, tool_exists
from versions import (
    ARGOCD_VERSION,
    HELM_VERSION,
    ISTIO_VERSION,
    K9S_VERSION,
    KIND_VERSION,
    S5CMD_VERSION,
    VELERO_VERSION,
)


def _installed_version(cmd: str) -> str:
    """Ermittelt die installierte Version eines Tools (analog zu whelper.sh:installed_version).

    Returns:
        Version-String, "installed" fuer hey (kein Versionscheck), "" falls nicht vorhanden.
    """
    if not tool_exists(cmd):
        return ""

    def _grep(args: list[str], pattern: str) -> str:
        try:
            r = subprocess.run(args, capture_output=True, text=True, check=False)
            m = re.search(pattern, r.stdout + r.stderr)
            return m.group(1) if m else ""
        except Exception:
            return ""

    if cmd == "kubectl":
        return _grep(
            ["kubectl", "version", "--client", "-o", "json"],
            r'"gitVersion":\s*"v?([^"]+)"',
        )
    if cmd == "helm":
        return _grep(["helm", "version", "--short"], r"v?([0-9]+\.[0-9]+\.[0-9]+)")
    if cmd == "kind":
        return _grep(["kind", "version"], r"v?([0-9]+\.[0-9]+\.[0-9]+)")
    if cmd == "istioctl":
        return _grep(
            ["istioctl", "version", "--remote=false"],
            r"([0-9]+\.[0-9]+\.[0-9]+)",
        )
    if cmd == "k9s":
        return _grep(["k9s", "version", "--short"], r"v?([0-9]+\.[0-9]+\.[0-9]+)")
    if cmd == "argocd":
        return _grep(
            ["argocd", "version", "--client", "-o", "json"],
            r'"Version":\s*"v?([^"+]+)',
        )
    if cmd == "hey":
        return "installed"
    if cmd == "velero":
        return _grep(["velero", "version", "--client-only"], r"([0-9]+\.[0-9]+\.[0-9]+)")
    if cmd == "s5cmd":
        return _grep(["s5cmd", "version"], r"([0-9]+\.[0-9]+\.[0-9]+)")
    if cmd == "mirrord":
        return _grep(["mirrord", "--version"], r"([0-9]+\.[0-9]+\.[0-9]+)")
    return ""


def _need_install(cmd: str, want: str) -> bool:
    """Prueft ob ein Tool installiert oder aktualisiert werden muss (analog zu whelper.sh:need_install)."""
    have = _installed_version(cmd)
    if not have:
        print(f"  {cmd} ist nicht installiert -> wird installiert")
        return True
    if have == "installed":
        print(f"  {cmd} ist bereits installiert -> uebersprungen")
        return False
    # Normalisiere: fuehrendes 'v' entfernen fuer Vergleich
    have_clean = have.lstrip("v")
    want_clean = want.lstrip("v")
    if have_clean == want_clean:
        print(f"  {cmd} ist bereits in Version {want} installiert -> uebersprungen")
        return False
    print(f"  {cmd} Version {have} -> wird auf {want} aktualisiert")
    return True


def _install_kubectl() -> None:
    result = run(
        ["curl", "-L", "-s", "https://dl.k8s.io/release/stable.txt"], capture=True
    )
    version = result.stdout.strip()
    url = f"https://dl.k8s.io/release/{version}/bin/linux/amd64/kubectl"
    run(["curl", "-LO", url])
    run(["chmod", "+x", "./kubectl"])
    run(["sudo", "cp", "./kubectl", "/usr/local/bin/kubectl"])
    os.remove("kubectl")


def _install_helm() -> None:
    tarball = f"helm-v{HELM_VERSION}-linux-amd64.tar.gz"
    run(["wget", "-q", f"https://get.helm.sh/{tarball}"])
    run(["tar", "-zxf", tarball])
    run(["sudo", "install", "-m", "555", "linux-amd64/helm", "/usr/local/bin/helm"])
    os.remove(tarball)
    shutil.rmtree("linux-amd64", ignore_errors=True)


def _install_kind() -> None:
    run(
        [
            "curl",
            "-Lo",
            "./kind",
            f"https://kind.sigs.k8s.io/dl/v{KIND_VERSION}/kind-linux-amd64",
        ]
    )
    run(["chmod", "+x", "./kind"])
    run(["sudo", "install", "-m", "555", "kind", "/usr/local/bin/kind"])
    os.remove("kind")


def _install_istioctl() -> None:
    tarball = f"istio-{ISTIO_VERSION}-linux-amd64.tar.gz"
    run(
        [
            "wget",
            "-q",
            f"https://github.com/istio/istio/releases/download/{ISTIO_VERSION}/{tarball}",
        ]
    )
    run(["tar", "-zxf", tarball])
    run(
        [
            "sudo",
            "install",
            "-m",
            "555",
            f"istio-{ISTIO_VERSION}/bin/istioctl",
            "/usr/local/bin/istioctl",
        ]
    )
    os.remove(tarball)
    shutil.rmtree(f"istio-{ISTIO_VERSION}", ignore_errors=True)


def _install_k9s() -> None:
    tarball = "k9s_Linux_amd64.tar.gz"
    run(
        [
            "wget",
            "-q",
            f"https://github.com/derailed/k9s/releases/download/v{K9S_VERSION}/{tarball}",
        ]
    )
    run(["tar", "-zxf", tarball])
    run(["sudo", "install", "-m", "555", "k9s", "/usr/local/bin/k9s"])
    os.remove(tarball)
    for f in ["k9s", "LICENSE", "README.md"]:
        try:
            os.remove(f)
        except FileNotFoundError:
            pass


def _install_argocd_cli() -> None:
    run(
        [
            "curl",
            "-sSL",
            "-o",
            "argocd-linux-amd64",
            f"https://github.com/argoproj/argo-cd/releases/download/{ARGOCD_VERSION}/argocd-linux-amd64",
        ]
    )
    run(["sudo", "install", "-m", "555", "argocd-linux-amd64", "/usr/local/bin/argocd"])
    os.remove("argocd-linux-amd64")


def _install_hey() -> None:
    run(
        ["wget", "-q", "https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64"]
    )
    run(["sudo", "install", "-m", "555", "hey_linux_amd64", "/usr/local/bin/hey"])
    os.remove("hey_linux_amd64")


def _install_mirrord() -> None:
    run(
        "curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash",
        shell=True,
    )


def _install_velero() -> None:
    version_tag = VELERO_VERSION if VELERO_VERSION.startswith("v") else f"v{VELERO_VERSION}"
    tarball = f"velero-{version_tag}-linux-amd64.tar.gz"
    run(
        [
            "curl",
            "-sSL",
            f"https://github.com/vmware-tanzu/velero/releases/download/{version_tag}/{tarball}",
            "-o",
            "velero.tar.gz",
        ]
    )
    run(["tar", "-xf", "velero.tar.gz"])
    run(
        [
            "sudo",
            "install",
            "-m",
            "555",
            f"velero-{version_tag}-linux-amd64/velero",
            "/usr/local/bin/velero",
        ]
    )
    os.remove("velero.tar.gz")
    shutil.rmtree(f"velero-{version_tag}-linux-amd64", ignore_errors=True)


def _install_s5cmd() -> None:
    tarball = f"s5cmd_{S5CMD_VERSION}_Linux-64bit.tar.gz"
    run(
        [
            "curl",
            "-sSL",
            f"https://github.com/peak/s5cmd/releases/download/v{S5CMD_VERSION}/{tarball}",
            "-o",
            "s5cmd.tar.gz",
        ]
    )
    run(["tar", "-xf", "s5cmd.tar.gz", "s5cmd"])
    run(["sudo", "install", "-m", "555", "s5cmd", "/usr/local/bin/s5cmd"])
    os.remove("s5cmd.tar.gz")
    try:
        os.remove("s5cmd")
    except FileNotFoundError:
        pass


# (cmd, gewuenschte Version fuer Vergleich)
_TOOLS: dict[str, tuple[str, Callable[[], None]]] = {
    "kubectl":  ("",              _install_kubectl),
    "helm":     (HELM_VERSION,    _install_helm),
    "kind":     (KIND_VERSION,    _install_kind),
    "istioctl": (ISTIO_VERSION,   _install_istioctl),
    "k9s":      (K9S_VERSION,     _install_k9s),
    "argocd":   (ARGOCD_VERSION,  _install_argocd_cli),
    "hey":      ("",              _install_hey),
    "velero":   (VELERO_VERSION,  _install_velero),
    "s5cmd":    (S5CMD_VERSION,   _install_s5cmd),
    "mirrord":  ("",              _install_mirrord),
}


def check_and_install_tools() -> None:
    step("Tools pruefen & installieren")

    original_dir = os.getcwd()
    os.chdir(Path.home())
    try:
        for name, (want, install_fn) in _TOOLS.items():
            if _need_install(name, want):
                if ask_yes_no(f"  {name} installieren/aktualisieren?"):
                    try:
                        install_fn()
                        print(f"  -> {name} installiert\n")
                    except subprocess.CalledProcessError as exc:
                        print(f"  FEHLER bei Installation von {name}: {exc}")
                        sys.exit(1)
                else:
                    print(f"  -> {name} uebersprungen\n")
    finally:
        os.chdir(original_dir)
