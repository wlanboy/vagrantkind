# Tekton Pipeline - CI/CD mit BuildKit

Die Pipeline implementiert eine vollständige GitOps-CI/CD-Pipeline mit zwei Schritten:

**1. Build** - Docker-Image bauen mit [BuildKit](https://github.com/moby/buildkit) (rootless)

`buildkitd` läuft als persistentes Deployment im `tekton`-Namespace. Der Build-Pod verbindet sich als reiner `buildctl`-Client per TCP, zieht den Quellcode direkt aus GitHub und pusht das fertige Image nach Docker Hub. Ein lokales Registry-Cache (`local-registry`) beschleunigt wiederholte Builds via `--export-cache` und `--import-cache`.

**2. Update Chart** - Helm-Chart aktualisieren per Git-Commit

Nach dem Build wird der Image-Tag im `values.yaml` des zugehörigen Helm-Charts per `sed` gesetzt und als Commit zurück ins GitHub-Repository gepusht.

## Tekton ohne Optimierungen

Der naheliegende Weg in Tekton ist, `buildkitd` als Sidecar-Container im Task-Pod zu starten und `buildctl` über einen Unix-Socket anzusprechen:

```yaml
# Standard-Tekton-Task mit buildkitd als Sidecar
spec:
  sidecars:
    - name: buildkitd
      image: moby/buildkit:rootless
      securityContext:
        privileged: true          # oder SYS_ADMIN + Unconfined
  steps:
    - name: build
      image: moby/buildkit:rootless
      script: |
        # Warten bis buildkitd bereit ist (~10s)
        buildctl --addr unix:///run/buildkit/buildkitd.sock debug workers
        buildctl --addr unix:///run/buildkit/buildkitd.sock build ...
```

Probleme dieses Ansatzes:

```
  STANDARD TEKTON + BUILDKIT
  ──────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────┐
  │  TaskRun-Pod  (pro Build neu erstellt)      │
  │                                             │
  │  ┌──────────────────────┐                   │
  │  │  Sidecar: buildkitd  │                   │
  │  │  rootlesskit         │                   │
  │  │  Unix-Socket         │                   │
  │  │  SYS_ADMIN           │  ← pro Pod nötig  │
  │  └──────────┬───────────┘                   │
  │             │ unix://                       │
  │  ┌──────────▼───────────┐                   │
  │  │  Step: buildctl      │                   │
  │  └──────────────────────┘                   │
  └─────────────────────────────────────────────┘

  ✗  Daemon-Startup (~10s) bei jedem TaskRun
  ✗  Layer-Cache nur im RAM des Pods — geht mit Pod verloren
  ✗  SYS_ADMIN auf jedem Build-Pod
  ✗  Kein persistenter Cache zwischen Builds
  ✗  Git-Clone als anonymer Request — Rate-Limit bei GitHub
```

## Tekton mit Optimierungen

```
  DIESE IMPLEMENTIERUNG
  ──────────────────────────────────────────────────────────

  ┌───────────────────────────────────────────────────────┐
  │  buildkitd  Deployment  (persistent, läuft dauerhaft) │
  │  rootlesskit --net=host                               │
  │  TCP :1234   UID 1000 + SYS_ADMIN                     │
  └──────────────────────┬────────────────────────────────┘
                         │ TCP :1234
  ┌──────────────────────▼────────────────────────────────┐
  │  Task: buildkit-build  (TaskRun-Pod, ephemeral)       │
  │  Image: moby/buildkit:rootless                        │
  │  keine Privilegien, kein SYS_ADMIN                    │
  └───────────────────────────────────────────────────────┘

  ┌───────────────────────────────────────────────────────┐
  │  local-registry  Deployment  :5000/cache/...          │
  │  PVC-backed (20Gi) — Cache überlebt Pod-Neustarts     │
  │  --export-cache mode=max                              │
  │  --import-cache                                       │
  │  --opt build-arg:BUILDKIT_INLINE_CACHE=1              │
  └───────────────────────────────────────────────────────┘

  ✓  Daemon läuft permanent — kein Startup-Overhead
  ✓  Layer-Cache überlebt zwischen Builds (PVC-backed)
  ✓  Build-Pod ohne Privilegien (kein SYS_ADMIN)
  ✓  Git-Kontext mit Token — kein Rate-Limit, private Repos
  ✓  Mehrere PipelineRuns können gleichzeitig bauen
```

## Tekton-Ressourcen

```
  buildkitd-daemon.yaml    →  Deployment + Service (TCP :1234)
  registry-cache.yaml      →  Deployment + Service + PVC (local-registry :5000)

  task-buildkit-build.yaml →  Task: buildctl-Client, verbindet sich per TCP
  task-git-update.yaml     →  Task: git clone → sed → git commit → git push
  pipeline.yaml            →  Pipeline: build → update-chart (sequenziell)

  workflow-*.yaml          →  PipelineRun je Service (manuelles Triggern)
  triggers.yaml            →  TriggerBinding + TriggerTemplate (4x) + EventListener
  rbac.yaml                →  ServiceAccount + Role + ClusterRole (workflow-sa)
```

### Pipeline-Ablauf

```
  GitHub Webhook
       │
       ▼
  EventListener
  (CEL-Filter: body.repository.full_name == '<repo>' && body.ref == 'refs/heads/main')
       │
       ▼
  TriggerTemplate
  (erstellt PipelineRun mit service-spezifischen Parametern)
       │
       ▼
  Pipeline: buildkit-pipeline
  ├── Task: buildkit-build   (image-tag = body.after = Commit-SHA)
  └── Task: git-update       (runAfter: build)
```

## BuildKit Daemon

Der persistente BuildKit-Daemon läuft als eigenes Deployment in `tekton` und ist über den Service `buildkitd.tekton.svc.cluster.local:1234` erreichbar. Task-Pods verbinden sich als reine `buildctl`-Clients — kein Daemon-Start, kein Startup-Overhead.

Vorteile gegenüber dem Sidecar-Ansatz:
- Kein Startup-Overhead (~5–10 s) pro TaskRun
- Mehrere Pipelines können gleichzeitig bauen (BuildKit serialisiert/parallelisiert intern)
- Task-Pods brauchen keine `SYS_ADMIN`-Capability mehr

### Inline Cache

`--opt build-arg:BUILDKIT_INLINE_CACHE=1` schreibt Cache-Metadaten direkt in den Image-Manifest. Ergänzt den Registry-Cache als Fallback, wenn der lokale Cache kalt ist.

### Git-Kontext mit Token

Der `--opt context` URL enthält das GitHub-Token, sodass auch private Repos klonbar sind und GitHub-Rate-Limits für anonyme Anfragen vermieden werden.

## buildctl-Aufruf im Detail

```sh
buildctl --addr tcp://buildkitd.tekton.svc.cluster.local:1234 build \
  --frontend=dockerfile.v0 \
  --opt context=https://wlanboy:${TOKEN}@github.com/wlanboy/<repo>.git#<git-ref> \
  --opt filename=Dockerfile \
  --opt build-arg:BUILDKIT_INLINE_CACHE=1 \
  --output "type=image,name=docker.io/wlanboy/<image>:<tag>,...,push=true" \
  --export-cache type=registry,ref=local-registry.tekton.svc.cluster.local:5000/cache/<image>,mode=max,registry.insecure=true \
  --import-cache type=registry,ref=local-registry.tekton.svc.cluster.local:5000/cache/<image>,registry.insecure=true
```

### `--addr`

```
--addr tcp://buildkitd.tekton.svc.cluster.local:1234
```

Adresse des BuildKit-Daemons. Der Task-Pod ist ein reiner Client (`buildctl`) und sendet den Build-Auftrag über TCP an den persistenten `buildkitd`-Daemon im selben Namespace. Ohne diese Angabe würde `buildctl` versuchen, einen lokalen Unix-Socket anzusprechen, der im Pod nicht existiert.

### `--frontend`

```
--frontend=dockerfile.v0
```

Bestimmt den Parser/Interpreter für die Build-Definition. `dockerfile.v0` ist das eingebaute Dockerfile-Frontend von BuildKit — es versteht die Standard-Docker-Syntax (`FROM`, `RUN`, `COPY` usw.). Alternativ gibt es `gateway.v0` für versionierte externe Frontends (z. B. `docker/dockerfile:1.10`).

### `--opt context`

```
--opt context=https://wlanboy:${TOKEN}@github.com/wlanboy/<repo>.git#<git-ref>
```

Der Build-Kontext. Statt eines lokalen Verzeichnisses gibt BuildKit direkt einen Git-Clone-URL an — der Daemon klont das Repo selbst, ohne dass der Task-Pod vorher `git clone` ausführen muss. Der `#<git-ref>`-Suffix wählt Branch, Tag oder Commit-SHA aus. Das Token im URL ermöglicht den Zugriff auf private Repos und vermeidet GitHub-Rate-Limits für anonyme Requests.

### `--opt filename`

```
--opt filename=Dockerfile
```

Pfad zum Dockerfile relativ zum geklonten Repo-Root. Standardwert ist `Dockerfile`. Über den Pipeline-Parameter `dockerfile` lässt sich ein alternativer Pfad übergeben (z. B. `docker/Dockerfile.prod`).

### `--opt build-arg:BUILDKIT_INLINE_CACHE`

```
--opt build-arg:BUILDKIT_INLINE_CACHE=1
```

Spezielle BuildKit-Direktive, die das Dockerfile-Frontend anweist, Cache-Metadaten direkt in den Image-Manifest einzubetten. Das Image trägt damit seinen eigenen Cache-Fingerprint — nützlich als Fallback-Cache-Quelle, wenn der dedizierte Registry-Cache (s. `--import-cache`) nicht verfügbar ist. Muss nicht im Dockerfile per `ARG` deklariert werden; das Frontend verarbeitet es intern.

### `--output`

```
--output "type=image,name=docker.io/wlanboy/<image>:<tag>,name=docker.io/wlanboy/<image>:latest,push=true"
```

Definiert, was mit dem fertigen Build-Ergebnis passiert:

| Option | Bedeutung |
|---|---|
| `type=image` | Ausgabe als OCI/Docker-Image (nicht als tar oder lokales Verzeichnis) |
| `name=...:<tag>` | Vollständiger Image-Name mit versioniertem Tag |
| `name=...:latest` | Zweiter Name im selben Push — BuildKit pusht beide Tags in einem Schritt |
| `push=true` | Image wird direkt nach dem Build in die Registry gepusht; kein separater `docker push` nötig |

Die Registry-Credentials kommen aus `DOCKER_CONFIG` (gemountetes `regcred`-Secret) — `buildctl` liest die Config und übergibt die Auth-Daten im Build-Request an den Daemon.

### `--export-cache`

```
--export-cache type=registry,ref=local-registry.tekton.svc.cluster.local:5000/cache/<image>,mode=max,registry.insecure=true
```

Schreibt den Build-Cache nach dem Build in die lokale Registry:

| Option | Bedeutung |
|---|---|
| `type=registry` | Cache wird als OCI-Manifest in eine Container-Registry gespeichert |
| `ref=...` | Ziel-Ref im lokalen Registry-Cache (separates Repo, nicht das Image-Repo) |
| `mode=max` | Exportiert Cache-Einträge für **alle** Zwischenlayer, nicht nur den finalen Layer — maximale Cache-Trefferrate bei nachfolgenden Builds |
| `registry.insecure=true` | Die lokale Registry läuft ohne TLS; BuildKit akzeptiert HTTP statt HTTPS |

### `--import-cache`

```
--import-cache type=registry,ref=local-registry.tekton.svc.cluster.local:5000/cache/<image>,registry.insecure=true
```

Lädt den Cache vor dem Build aus der lokalen Registry:

| Option | Bedeutung |
|---|---|
| `type=registry` | Cache-Quelle ist eine Container-Registry |
| `ref=...` | Dieselbe Ref wie beim Export — Daemon liest die Layer-Metadaten und prüft, welche Schritte gecacht werden können |
| `registry.insecure=true` | Wie beim Export: HTTP statt HTTPS für die lokale Registry |

Wenn ein Layer-Hash übereinstimmt, überspringt BuildKit den `RUN`-Befehl und verwendet das gecachte Ergebnis. Das verkürzt Build-Zeiten bei reinen Dependency- oder Konfigurationsänderungen erheblich.

## Gemeinsame Parameter

| Parameter | Default | Beschreibung |
|-----------|---------|--------------|
| `github-repo` | — | GitHub-Repo-Pfad, z. B. `wlanboy/SimpleService` |
| `image-name` | — | Docker Hub Image-Name, z. B. `docker.io/wlanboy/simpleservice` |
| `cache-name` | — | Cache-Name in der lokalen Registry, z. B. `simpleservice` |
| `chart-dir` | — | Helm-Chart-Verzeichnis im Repo, z. B. `simple-chart` |
| `image-tag` | `latest` | Tag des zu bauenden Images (bei Webhook: Commit-SHA) |
| `git-ref` | `refs/heads/main` | Git-Branch oder -Tag als Build-Quelle |
| `dockerfile` | `Dockerfile` | Pfad zum Dockerfile |
| `push` | `true` | Image nach dem Build pushen (`true`/`false`) |

## Security Context

Der **BuildKit-Daemon** (Deployment) braucht `SYS_ADMIN` und Unconfined-Profile:

```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  seccompProfile:
    type: Unconfined      # erlaubt syscalls für user namespaces
  appArmorProfile:
    type: Unconfined      # erlaubt bind-mounts (auf Ubuntu/Debian notwendig)
  capabilities:
    add: ["SYS_ADMIN"]   # erlaubt mount --bind innerhalb des user namespaces
```

`SYS_ADMIN` ist notwendig, damit `rootlesskit` einen Mount-Namespace aufbauen kann. `--oci-worker-no-process-sandbox` deaktiviert die Prozess-Isolation von buildkitd, die in einem Kubernetes-Pod nicht funktioniert.

Die **Task-Pods** (buildctl-Client) benötigen keine erhöhten Privilegien — sie verbinden sich nur per TCP mit dem Daemon.

## RBAC

Der `workflow-sa` ServiceAccount wird von drei Komponenten genutzt:

| Komponente | Zweck |
|---|---|
| EventListener-Pod | liest TriggerBinding/TriggerTemplate, erstellt PipelineRuns |
| PipelineRun-Pods | führen Tasks aus, lesen Pipeline/Task-Definitionen |
| TriggerTemplate | erstellt PipelineRun-Objekte im `tekton`-Namespace |

```
rbac.yaml
├── ServiceAccount:       workflow-sa  (namespace: tekton)
├── Role:                 workflow-sa-role
│   ├── tekton.dev        pipelines, tasks           → get/list/watch
│   ├── tekton.dev        pipelineruns, taskruns      → get/list/watch/create
│   ├── triggers.tekton.dev  eventlisteners, triggerbindings,
│   │                        triggertemplates, triggers → get/list/watch
│   └── ""                secrets, configmaps,
│                          serviceaccounts            → get/list
├── RoleBinding:          workflow-sa-rolebinding     (namespace: tekton)
├── ClusterRole:          workflow-sa-clusterrole
│   └── triggers.tekton.dev  clusterinterceptors,
│                            clustertriggerbindings   → get/list/watch
└── ClusterRoleBinding:   workflow-sa-clusterrolebinding
```

Der `ClusterRole`-Teil ist notwendig, weil der CEL-Interceptor (`cel`) als `ClusterInterceptor` cluster-scoped registriert ist und der EventListener-Pod ihn auflösen muss.

## Secrets

- `regcred` - Docker Hub Zugangsdaten (`.dockerconfigjson`), gemountet nach `/home/user/.docker`
- `github-token` - GitHub Token für Build-Kontext und Chart-Commit
