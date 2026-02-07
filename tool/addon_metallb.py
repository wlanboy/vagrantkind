"""Kind Cluster + MetalLB (install-wsl-kind.sh)."""

import os
import sys
import tempfile

from helpers import ask_yes_no, kubectl_apply_stdin, run, step, tool_exists
from versions import METALLB_VERSION

_KIND_CLUSTER_CONFIG = """\
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: local
networking:
  ipFamily: ipv4
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
  podSubnet: "192.168.0.0/16"
  disableDefaultCNI: false
  kubeProxyMode: "iptables"
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  kubeadmConfigPatchesJSON6902:
  - group: kubeadm.k8s.io
    version: v1beta3
    kind: ClusterConfiguration
    patch: |
      - op: add
        path: /apiServer/certSANs/-
        value: 127.0.0.1
  extraPortMappings:
  - containerPort: 80
    hostPort: 9080
    protocol: TCP
  - containerPort: 443
    hostPort: 9443
    protocol: TCP
- role: worker
"""

_METALLB_ADV = """\
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - wsl-pool
"""


def _metallb_pool_yaml(ip: str) -> str:
    """Erzeugt MetalLB IPAddressPool YAML mit IP-Range ab der eingegebenen IP (+20)."""
    parts = ip.split(".")
    start = int(parts[3])
    end = min(start + 20, 254)
    base = ".".join(parts[:3])
    return f"""\
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: wsl-pool
  namespace: metallb-system
spec:
  addresses:
  - {base}.{start}-{base}.{end}
"""


def create_kind_cluster(ip: str) -> None:
    step("Kind Cluster erstellen")

    for cmd in ("kind", "kubectl"):
        if not tool_exists(cmd):
            print(f"Fehler: {cmd} ist nicht installiert")
            sys.exit(1)

    # Pruefen ob Cluster bereits existiert
    result = run(["kind", "get", "clusters"], capture=True, check=False, quiet=True)
    if "local" in result.stdout.splitlines():
        print("Kind Cluster 'local' existiert bereits.")
        if ask_yes_no("  Loeschen und neu erstellen?", default=False):
            run(["kind", "delete", "cluster", "--name", "local"])
        else:
            print("  Ueberspringe Cluster-Erstellung, fahre mit MetalLB fort...\n")
            install_metallb(ip)
            return

    print("Erstelle Kind Cluster...")
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".yaml", delete=False
    ) as tmp:
        tmp.write(_KIND_CLUSTER_CONFIG)
        config_path = tmp.name
    try:
        run(["kind", "create", "cluster", f"--config={config_path}"])
    finally:
        os.unlink(config_path)

    print("Warte auf Cluster-Nodes...")
    run(
        [
            "kubectl",
            "wait",
            "--for=condition=Ready",
            "nodes",
            "--all",
            "--timeout=120s",
        ]
    )

    install_metallb(ip)

    print("\nKind Cluster Installation abgeschlossen.")


def install_metallb(ip: str) -> None:
    # Pruefen ob MetalLB bereits laeuft
    result = run(
        ["kubectl", "get", "ns", "metallb-system"],
        check=False, capture=True, quiet=True,
    )
    if result.returncode == 0:
        pods = run(
            ["kubectl", "-n", "metallb-system", "get", "pods", "-o", "name"],
            check=False, capture=True, quiet=True,
        )
        if pods.stdout.strip():
            print("MetalLB laeuft bereits.")
            if ask_yes_no("  IP-Pool aktualisieren?", default=True):
                print("Aktualisiere MetalLB Pool & Advertisement...")
                kubectl_apply_stdin(_metallb_pool_yaml(ip))
                kubectl_apply_stdin(_METALLB_ADV)
            if not ask_yes_no("  MetalLB komplett neu installieren?", default=False):
                return

    print(f"\nInstalliere MetalLB v{METALLB_VERSION}...")
    metallb_url = (
        f"https://raw.githubusercontent.com/metallb/metallb/"
        f"v{METALLB_VERSION}/config/manifests/metallb-native.yaml"
    )
    run(["kubectl", "apply", "-f", metallb_url])

    print("Warte auf MetalLB Pods...")
    run(
        [
            "kubectl",
            "-n",
            "metallb-system",
            "wait",
            "--for=condition=Ready",
            "--all",
            "pods",
            "--timeout=120s",
        ]
    )

    print("Konfiguriere MetalLB Pool & Advertisement...")
    kubectl_apply_stdin(_metallb_pool_yaml(ip))
    kubectl_apply_stdin(_METALLB_ADV)
