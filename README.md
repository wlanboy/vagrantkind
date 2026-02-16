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
| Skript | Beschreibung |
|--------|--------------|
| [amd64-tools.sh](amd64-tools.sh) | Installiert kubectl, helm, kind, istioctl, k9s, argocd-cli, hey und mirrord für x86_64 Systeme |
| [arm64-tools.sh](arm64-tools.sh) | Installiert kubectl, helm, kind und istioctl für ARM64 Systeme |
| [versions.sh](versions.sh) | Zentrale Versionsverwaltung für alle Tools |
| [whelper.sh](whelper.sh) | Hilfsfunktionen für Installations-Checks (Version, Existenz, apt, sdkman) |

Alle Installationsskripte prüfen vor jedem Schritt, ob das Tool bereits in der gewünschten Version installiert ist, und überspringen es gegebenenfalls.

```bash
# Für x86_64 / amd64
./amd64-tools.sh

# Für ARM64
./arm64-tools.sh
```

### Entwicklungsumgebung einrichten

```bash
./coding.sh
```

Installiert (mit Existenz-/Versions-Check): apt-Pakete (git, nano, htop, alacritty, ...), uv, sdkman, Java, Maven, VSCode, MarkText und LM Studio.

### Container-Runtime installieren

```bash
# Docker
./docker.sh

# Podman (Rootless-Setup)
./podman.sh
```

`podman.sh` richtet ein vollständiges Rootless-Setup ein: subuid/subgid, fuse-overlayfs Storage, Registry-Konfiguration, unprivilegierte Ports ab 80, Netzwerk-Backend (pasta/slirp4netns), Podman-Socket und Lingering.

### Versionen aktualisieren

```bash
# Prüfen welche Updates verfügbar sind (Dry-Run)
./versionsupdate.sh

# Updates anwenden
./versionsupdate.sh --apply

# Bestimmte Tools überspringen
./versionsupdate.sh --apply --skip=helm,istio
```

Ermittelt die neuesten Versionen über die GitHub API und aktualisiert [versions.sh](versions.sh). Verfügbare Tools: `helm`, `kind`, `istio`, `k9s`, `argocd`.

## Installation

### Empfohlen: Interaktives Setup-Tool (Python)

Das Python-Tool im Verzeichnis `tool/` fasst alle Schritte in einem interaktiven Setup zusammen:

```bash
cd tool
python3 main.py
```

Das Tool fragt Umgebung (Linux/WSL), Hostname und IP-Adresse ab und führt automatisch alle Schritte aus:

1. Prüfung und Installation benötigter CLI-Tools
2. Lokale CA erstellen
3. Kind Cluster erstellen (mit optionalem Löschen eines bestehenden Clusters)
4. Istio installieren
5. Cert-Manager installieren
6. ArgoCD installieren
7. DNS-Einträge in `/etc/hosts` konfigurieren

Die Konfiguration wird in `tool/daten.json` gespeichert und bei erneutem Start als Default vorgeschlagen.

### Manuelle Installation (Shell-Skripte)

#### Option 1: Kind auf Linux

```bash
./install-local-kind.sh
./install-istio.sh
./install-certmanager.sh
./install-argocd.sh
```

#### Option 2: Kind auf WSL

```bash
./install-wsl-kind.sh
./install-istio.sh
./install-certmanager.sh
./install-argocd.sh
```

#### Option 3: K3s auf Linux

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

## ArgoCD Apps

Das Python-Tool im Verzeichnis `argocd/` richtet interaktiv alle ArgoCD-Ressourcen ein (Cluster, Repository, Projekt, Namespaces und Applications). Es prueft vor jedem Schritt ob die Ressource bereits existiert und fragt per `[j/n]` nach.

```bash
python argocd/main.py
```

Details siehe [argocd/README.md](argocd/README.md).

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
| [versionsupdate.sh](versionsupdate.sh) | Prüft auf neue Tool-Versionen und aktualisiert versions.sh |
| [whelper.sh](whelper.sh) | Hilfsfunktionen für Installations-Checks |
| [docker.sh](docker.sh) | Installiert Docker CE mit Existenz-Check |
| [podman.sh](podman.sh) | Installiert Podman mit vollständigem Rootless-Setup |
| [coding.sh](coding.sh) | Richtet Entwicklungsumgebung ein (Java, Maven, VSCode, etc.) |

## Komponenten-Versionen

Die Tool-Versionen werden zentral in [versions.sh](versions.sh) definiert:

- **Helm**: 3.20
- **Kind**: 0.31.0
- **Istio**: 1.28.3
- **K9s**: 0.50.18
- **ArgoCD CLI**: v3.3.0
- **Java**: 25-tem (Temurin, via sdkman)
- **Maven**: 3.9.9 (via sdkman)

Versionen können mit `./versionsupdate.sh` automatisch auf den neuesten Stand gebracht werden.

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
