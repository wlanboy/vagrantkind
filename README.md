# Kubernetes Cluster Setup

Dieses Repository enthält Skripte zum Aufbau eines lokalen Kubernetes-Clusters mit MetalLB, Istio, Cert-Manager und ArgoCD.

## Unterstützte Plattformen

- **Kind** auf Linux
- **Kind** auf WSL (Windows Subsystem for Linux)
- **K3s** auf Linux (Single-Node oder Multi-Node)

## Voraussetzungen

Vor der Cluster-Installation müssen die benötigten CLI-Tools installiert werden.

### Client-Tools installieren

Je nach Architektur eines der folgenden Skripte ausführen:

| Skript | Beschreibung |
|--------|--------------|
| [amd64-tools.sh](amd64-tools.sh) | Installiert kubectl, helm, kind, istioctl, k9s, argocd-cli, hey und mirrord für x86_64 Systeme |
| [arm64-tools.sh](arm64-tools.sh) | Installiert kubectl, helm, kind und istioctl für ARM64 Systeme |
| [versions.sh](versions.sh) | Zentrale Versionsverwaltung für alle Tools |

```bash
# Für x86_64 / amd64
./amd64-tools.sh

# Für ARM64
./arm64-tools.sh
```

## Installation

### Option 1: Kind auf Linux

```bash
./install-local-kind.sh
./install-istio.sh
./install-certmanager.sh
./install-argocd.sh
```

### Option 2: Kind auf WSL

```bash
./install-wsl-kind.sh
./install-istio.sh
./install-certmanager.sh
./install-argocd.sh
```

### Option 3: K3s auf Linux

```bash
# Master-Node
./install-local-k3s.sh

# Weitere Worker-Nodes hinzufügen
./install-local-k3s-node.sh <MASTER_IP>

# Danach Istio, Cert-Manager und ArgoCD
./install-istio.sh
./install-certmanager.sh
./install-argocd.sh
```

## Skript-Referenz

### Cluster-Installation

| Skript | Beschreibung |
|--------|--------------|
| [install-local-kind.sh](install-local-kind.sh) | Erstellt einen Kind-Cluster auf Linux mit MetalLB |
| [install-wsl-kind.sh](install-wsl-kind.sh) | Erstellt einen Kind-Cluster auf WSL mit MetalLB (angepasster IP-Pool) |
| [install-local-k3s.sh](install-local-k3s.sh) | Installiert K3s als Master-Node mit MetalLB (ohne Traefik) |
| [install-local-k3s-node.sh](install-local-k3s-node.sh) | Fügt einen Worker-Node zu einem bestehenden K3s-Cluster hinzu |

### Komponenten-Installation

| Skript | Beschreibung |
|--------|--------------|
| [install-istio.sh](install-istio.sh) | Installiert Istio Service Mesh via Helm (Base, Istiod, Ingress Gateway) inkl. Demo-Service |
| [install-certmanager.sh](install-certmanager.sh) | Installiert Cert-Manager mit lokaler CA als ClusterIssuer (erwartet CA unter `/local-ca/`) |
| [install-argocd.sh](install-argocd.sh) | Installiert ArgoCD via Helm mit Istio-Integration, Gateway und TLS-Zertifikat |
| [install-longhorn.sh](install-longhorn.sh) | Installiert Longhorn Storage mit Istio-Integration |

### Hilfs-Skripte

| Skript | Beschreibung |
|--------|--------------|
| [install-kube-config.sh](install-kube-config.sh) | Holt die Kubeconfig von einem Remote-K3s-Server und merged sie lokal |

## Komponenten-Versionen

Die Tool-Versionen werden zentral in [versions.sh](versions.sh) definiert:

- **Helm**: 3.19.4
- **Kind**: 0.31.0
- **Istio**: 1.28.2
- **K9s**: 0.50.16
- **ArgoCD CLI**: v3.2.3

MetalLB-Version (0.15.2) ist in den Install-Skripten definiert.

## Konfigurationsdateien

### Kind Cluster-Konfiguration

| Datei | Beschreibung |
|-------|--------------|
| [kind-local.yaml](kind-local.yaml) | Kind-Cluster-Konfiguration für Linux und WSL |

Die Datei definiert einen Cluster mit Control-Plane und Worker-Node. Bei Bedarf anpassen:

```yaml
networking:
  apiServerAddress: "127.0.0.1"  # Bei Remote-Zugriff: Host-IP eintragen
  podSubnet: "192.168.0.0/16"    # Pod-Netzwerk
```

### MetalLB IP-Pool Konfiguration

MetalLB benötigt einen IP-Pool aus dem Docker-Netzwerk. Die richtige Range ermitteln:

```bash
docker network inspect -f '{{.IPAM.Config}}' kind
# Beispiel-Output: [{172.18.0.0/16  172.18.0.1 map[]}]
```

| Datei | IP-Range | Verwendung |
|-------|----------|------------|
| [metallb-pool.yaml](metallb-pool.yaml) | `172.18.100.10-172.18.100.100` | Linux Kind |
| [wsl-metallb-pool.yaml](wsl-metallb-pool.yaml) | `172.18.0.100-172.18.0.150` | WSL Kind |
| [metallb-pool-k3s.yaml](metallb-pool-k3s.yaml) | - | K3s Cluster |

Die IP-Range muss im Subnetz des Docker-Netzwerks liegen, aber außerhalb des automatisch vergebenen Bereichs.

**Anpassen der IP-Range:**

```yaml
# metallb-pool.yaml
spec:
  addresses:
  - 172.18.100.10-172.18.100.100  # An eigenes Netzwerk anpassen
```

### L2 Advertisement

| Datei | Pool-Referenz |
|-------|---------------|
| [metallb-adv.yaml](metallb-adv.yaml) | `first-pool` (für Linux) |
| [wsl-metallb-adv.yaml](wsl-metallb-adv.yaml) | `wsl-pool` (für WSL) |

## Hinweise

### Cert-Manager

Das Skript `install-certmanager.sh` erwartet eine lokale CA unter:
- `/local-ca/ca.pem` (Zertifikat)
- `/local-ca/ca.key` (Private Key)

### Cluster löschen

```bash
# Kind
kind delete clusters local

# K3s
sudo /usr/local/bin/k3s-uninstall.sh
```
