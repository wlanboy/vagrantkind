#!/usr/bin/env python3
"""Vagrantkind Setup – ersetzt die Shell-Scripte durch eine einzige Python Console App.

Repliziert die Funktionalität von:
  - ca_dns/create-ca.sh
  - amd64-tools.sh
  - install-wsl-kind.sh
  - install-istio.sh
  - install-certmanager.sh
  - install-argocd.sh
  - oldstuff/install-dns-records.sh
"""

import base64
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# ---------------------------------------------------------------------------
# Versionen (aus versions.sh)
# ---------------------------------------------------------------------------
HELM_VERSION = "3.19.4"
KIND_VERSION = "0.31.0"
ISTIO_VERSION = "1.28.2"
K9S_VERSION = "0.50.16"
ARGOCD_VERSION = "v3.2.3"
METALLB_VERSION = "0.15.2"

DEFAULT_IP = "172.18.100.10"


# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------
def run(
    cmd: "list[str] | str",
    *,
    check: bool = True,
    capture: bool = False,
    input_data: "str | None" = None,
    shell: bool = False,
    quiet: bool = False,
) -> subprocess.CompletedProcess:
    """Führt einen Befehl aus und gibt das Ergebnis zurück."""
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


# ---------------------------------------------------------------------------
# 1) Tools prüfen & installieren  (amd64-tools.sh)
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# 2) Lokale CA erstellen  (ca_dns/create-ca.sh)
# ---------------------------------------------------------------------------
def create_ca(ca_dir: Path) -> None:
    step("Lokale CA erstellen")

    ca_dir.mkdir(parents=True, exist_ok=True)
    ca_key = ca_dir / "ca.key"
    ca_pem = ca_dir / "ca.pem"

    if ca_key.exists() and ca_pem.exists():
        print(f"CA-Dateien existieren bereits in {ca_dir}")
        if not ask_yes_no("  Neu erstellen?", default=False):
            return

    print("Generiere CA-Key (4096 bit)...")
    run(["openssl", "genrsa", "-out", str(ca_key), "4096"])

    print("Generiere CA-Zertifikat (10 Jahre)...")
    run(
        [
            "openssl",
            "req",
            "-x509",
            "-new",
            "-nodes",
            "-key",
            str(ca_key),
            "-sha256",
            "-days",
            "3650",
            "-out",
            str(ca_pem),
            "-subj",
            "/C=DE/ST=Germany/L=LAN/O=Homelab CA/CN=Homelab Test Root CA",
        ]
    )

    print("Installiere CA im System-Trust-Store...")
    run(
        [
            "sudo",
            "cp",
            str(ca_pem),
            "/usr/local/share/ca-certificates/ca-test-lan.crt",
        ]
    )
    run(["sudo", "update-ca-certificates"])

    print(f"CA erstellt in {ca_dir}")


# ---------------------------------------------------------------------------
# 3) Kind Cluster + MetalLB  (install-wsl-kind.sh)
# ---------------------------------------------------------------------------
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


def create_kind_cluster(ip: str) -> None:
    step("Kind Cluster erstellen")

    for cmd in ("kind", "kubectl"):
        if not tool_exists(cmd):
            print(f"Fehler: {cmd} ist nicht installiert")
            sys.exit(1)

    # Prüfen ob Cluster bereits existiert
    result = run(["kind", "get", "clusters"], capture=True, check=False, quiet=True)
    if "local" in result.stdout.splitlines():
        print("Kind Cluster 'local' existiert bereits.")
        if ask_yes_no("  Loeschen und neu erstellen?", default=False):
            run(["kind", "delete", "cluster", "--name", "local"])
        else:
            print("  Ueberspringe Cluster-Erstellung, fahre mit MetalLB fort...\n")
            _install_metallb(ip)
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

    _install_metallb(ip)

    print("\nKind Cluster Installation abgeschlossen.")


def _install_metallb(ip: str) -> None:
    # Prüfen ob MetalLB bereits läuft
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


# ---------------------------------------------------------------------------
# 4) Istio  (install-istio.sh)
# ---------------------------------------------------------------------------
def _echo_service_yaml(hostname: str) -> str:
    return f"""\
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: demo-app
  name: demo-app
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: demo
        image: nginx:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          protocol: TCP
        resources: {{}}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {{}}
      terminationGracePeriodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: demo
spec:
  selector:
    app: demo-app
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: demo-gateway
  namespace: demo
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "demo.{hostname}"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: demo-service
  namespace: demo
spec:
  hosts:
  - "demo.{hostname}"
  exportTo:
  - "."
  - istio-ingress
  - istio-system
  gateways:
  - demo-gateway
  - mesh
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: demo-app.demo.svc.cluster.local
        port:
          number: 80
"""


def _helm_release_exists(name: str, namespace: str) -> bool:
    """Prüft ob ein Helm Release in einem Namespace existiert."""
    result = run(
        ["helm", "list", "-n", namespace, "-q", "--filter", f"^{name}$"],
        check=False, capture=True, quiet=True,
    )
    return name in result.stdout.splitlines()


def install_istio(hostname: str) -> None:
    step("Istio installieren")

    for cmd in ("helm", "kubectl"):
        if not tool_exists(cmd):
            print(f"Fehler: {cmd} ist nicht installiert")
            sys.exit(1)

    # Prüfen ob Istio bereits läuft
    istio_running = _helm_release_exists("istiod", "istio-system")
    if istio_running:
        print("Istio laeuft bereits (Helm Release 'istiod' gefunden).")
        if not ask_yes_no("  Trotzdem neu installieren/aktualisieren?", default=False):
            print("  Ueberspringe Istio, fahre mit Demo-Service fort...\n")
            _deploy_demo_service(hostname)
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

    _deploy_demo_service(hostname)

    print("\nIstio Installation abgeschlossen.")


def _deploy_demo_service(hostname: str) -> None:
    # Prüfen ob Demo-Service bereits läuft
    result = run(
        ["kubectl", "-n", "demo", "get", "deployment", "demo-app"],
        check=False, capture=True, quiet=True,
    )
    if result.returncode == 0:
        print("Demo-Service laeuft bereits.")
        if not ask_yes_no("  Trotzdem neu deployen/aktualisieren?", default=False):
            print("  Ueberspringe Demo-Service.\n")
            return

    ensure_namespace("demo")

    print("Aktiviere Istio Injection fuer 'demo' Namespace...")
    run(["kubectl", "label", "namespace", "demo", "istio-injection=enabled", "--overwrite"])

    print("Deploye Demo Service...")
    kubectl_apply_stdin(_echo_service_yaml(hostname))

    print("Warte auf Demo-Service Pods...")
    run(
        [
            "kubectl",
            "-n",
            "demo",
            "wait",
            "--for=condition=Ready",
            "--all",
            "pods",
            "--timeout=120s",
        ]
    )


# ---------------------------------------------------------------------------
# 5) cert-manager  (install-certmanager.sh)
# ---------------------------------------------------------------------------
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

    # Prüfen ob cert-manager bereits läuft
    cm_running = _helm_release_exists("cert-manager", "cert-manager")
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
    # dry-run + apply für Idempotenz
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


# ---------------------------------------------------------------------------
# 6) ArgoCD  (install-argocd.sh)
# ---------------------------------------------------------------------------
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

    # Prüfen ob ArgoCD bereits läuft
    argocd_running = _helm_release_exists("argocd", "argocd")
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

    print("Warte auf ArgoCD Pods...")
    run(
        [
            "kubectl",
            "-n",
            "argocd",
            "wait",
            "--for=condition=Ready",
            "--all",
            "pods",
            "--timeout=220s",
        ]
    )

    _create_argocd_istio_resources(hostname)

    print("\nArgoCD Installation abgeschlossen.")


def _get_argocd_password() -> str:
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


# ---------------------------------------------------------------------------
# 7) DNS-Eintraege  (oldstuff/install-dns-records.sh)
# ---------------------------------------------------------------------------
def install_dns_records(hostname: str, ip: str) -> None:
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
    saved_ip = config.get("ip", DEFAULT_IP)

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
    _save_config({"hostname": hostname, "ip": ip})
    print(f"  Konfiguration gespeichert in {_CONFIG_FILE}")

    ca_dir = Path.home() / "local-ca"

    print(f"\nKonfiguration:")
    print(f"  Hostname:  {hostname}")
    print(f"  DNS-IP:    {ip}")
    print(f"  CA-Dir:    {ca_dir}")
    print(f"  Domains:   argocd.{hostname}, demo.{hostname}")
    print()

    if not ask_yes_no("Setup starten?"):
        print("Abgebrochen.")
        _show_summary_if_cluster_running(hostname, ca_dir)
        sys.exit(0)

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
    print(f"  ArgoCD PW:  {_get_argocd_password()}")
    print()


if __name__ == "__main__":
    main()
