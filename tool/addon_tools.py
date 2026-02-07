"""Tool-Installation (amd64): kubectl, helm, kind, istioctl, k9s, argocd, hey, mirrord."""

import os
import shutil
import subprocess
import sys
from pathlib import Path

from helpers import ask_yes_no, run, step, tool_exists
from versions import (
    ARGOCD_VERSION,
    HELM_VERSION,
    ISTIO_VERSION,
    K9S_VERSION,
    KIND_VERSION,
)


def _install_kubectl() -> None:
    print("Installiere kubectl...")
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
    print(f"Installiere helm v{HELM_VERSION}...")
    tarball = f"helm-v{HELM_VERSION}-linux-amd64.tar.gz"
    run(["wget", "-q", f"https://get.helm.sh/{tarball}"])
    run(["tar", "-zxf", tarball])
    run(["sudo", "install", "-m", "555", "linux-amd64/helm", "/usr/local/bin/helm"])
    os.remove(tarball)
    shutil.rmtree("linux-amd64", ignore_errors=True)


def _install_kind() -> None:
    print(f"Installiere kind v{KIND_VERSION}...")
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
    print(f"Installiere istioctl v{ISTIO_VERSION}...")
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
    print(f"Installiere k9s v{K9S_VERSION}...")
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
    print(f"Installiere argocd CLI {ARGOCD_VERSION}...")
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
    print("Installiere hey...")
    run(
        ["wget", "-q", "https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64"]
    )
    run(["sudo", "install", "-m", "555", "hey_linux_amd64", "/usr/local/bin/hey"])
    os.remove("hey_linux_amd64")


def _install_mirrord() -> None:
    print("Installiere mirrord...")
    run(
        "curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/main/scripts/install.sh | bash",
        shell=True,
    )


_TOOLS: dict[str, callable] = {
    "kubectl": _install_kubectl,
    "helm": _install_helm,
    "kind": _install_kind,
    "istioctl": _install_istioctl,
    "k9s": _install_k9s,
    "argocd": _install_argocd_cli,
    "hey": _install_hey,
    "mirrord": _install_mirrord,
}


def check_and_install_tools() -> None:
    step("Tools pruefen & installieren")

    missing = [name for name in _TOOLS if not tool_exists(name)]

    if not missing:
        print("Alle Tools sind bereits installiert.")
        return

    print(f"Fehlende Tools: {', '.join(missing)}\n")

    original_dir = os.getcwd()
    os.chdir(Path.home())
    try:
        for name in missing:
            if ask_yes_no(f"  {name} installieren?"):
                try:
                    _TOOLS[name]()
                    print(f"  -> {name} installiert\n")
                except subprocess.CalledProcessError as exc:
                    print(f"  FEHLER bei Installation von {name}: {exc}")
                    sys.exit(1)
            else:
                print(f"  -> {name} uebersprungen\n")
    finally:
        os.chdir(original_dir)
