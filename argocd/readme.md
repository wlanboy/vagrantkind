# ArgoCD GitOps CI/CD Pipeline

Dieses Verzeichnis enthält alle Konfigurationen für eine vollautomatische GitOps-Pipeline auf Basis von ArgoCD und Argo Workflows. Die Pipeline verwaltet vier Microservices, baut deren Docker-Images automatisch bei neuen GitHub-Tags und synchronisiert die Deployments über Helm-Charts in einen lokalen Kubernetes-Cluster mit Istio Service Mesh.

**Verwaltete Microservices:**

- **JavaHttpClient** – HTTP-Client-Service
- **MirrorService** – Mirror-/Proxy-Service
- **RandomFail** – Service mit zufälligen Fehlern (z.B. für Chaos-Testing)
- **SimpleService** – Basis-Service

**Ablauf der Pipeline:**

1. CronWorkflow pollt alle 2 Minuten die GitHub-API auf neue Tags
2. Bei neuem Tag wird ein Webhook ausgelöst
3. Der Sensor empfängt den Webhook und startet ein Argo Workflow
4. Kaniko baut das Docker-Image und pusht es nach Docker Hub
5. Das Workflow aktualisiert den Image-Tag in der `values.yaml` des Helm-Charts
6. ArgoCD erkennt die Änderung im Git und deployt die neue Version automatisch

---

## Verzeichnisstruktur

### `argocd-projects/`

Definiert den ArgoCD-Cluster und das zugehörige Projekt.

| Datei | Inhalt |
| --- | --- |
| `cluster-gmk.yaml` | Registriert den lokalen Cluster unter dem Namen `gmk` (`https://kubernetes.default.svc`) als Kubernetes Secret in ArgoCD |
| `wlanboy-project.yaml` | ArgoCD `AppProject` mit erlaubten Source-Repositories (die 4 GitHub-Repos), erlaubten Destination-Namespaces sowie ClusterRole/ClusterRoleBinding-Whitelist |

---

### `argocd-namespaces/`

Erstellt die Kubernetes-Namespaces für die vier Services, jeweils mit Istio-Sidecar-Injection aktiviert.

| Datei | Namespace |
| --- | --- |
| `namespace-javahttpclient.yaml` | `javahttpclient` |
| `namespace-mirrorservice.yaml` | `mirrorservice` |
| `namespace-randomfail.yaml` | `randomfail` |
| `namespace-simpleservice.yaml` | `simpleservice` |

Alle Namespaces tragen das Label `istio-injection: enabled`.

---

### `argocd-apps/`

Definiert die vier ArgoCD `Application`-Ressourcen. Jede Applikation bezieht ihren Helm-Chart aus dem jeweiligen GitHub-Repository und deployt ihn in den zugehörigen Namespace auf dem `gmk`-Cluster.

| Datei | App-Name | Helm-Chart | Namespace |
| --- | --- | --- | --- |
| `app-javahttpclient.yaml` | javahttpclient | `javahttpclient-chart` | javahttpclient |
| `app-mirrorservice.yaml` | mirrorservice | `mirror-chart` | mirrorservice |
| `app-randomfail.yaml` | randomfail | `randomfail-chart` | randomfail |
| `app-simpleservice.yaml` | simpleservice | `simple-chart` | simpleservice |

Alle Apps sind mit `automated sync`, `prune` und `self-heal` konfiguriert. `CreateNamespace` ist deaktiviert – die Namespaces müssen vorab existieren.

---

### `argocd-workflows/`

Argo Workflow `WorkflowTemplate`-Ressourcen. Jedes Template führt zwei Schritte aus:

1. **Build**: Kaniko baut das Docker-Image direkt aus dem GitHub-Repository und pusht es nach Docker Hub (mit Tag und `:latest`)
2. **Update**: Das Image-Tag wird in der `values.yaml` des Helm-Charts aktualisiert und per `git commit && git push` nach GitHub übertragen

**Parameter je Template:**

| Parameter | Standard | Beschreibung |
| --- | --- | --- |
| `image-tag` | `latest` | Der zu verwendende Docker-Image-Tag |
| `git-ref` | `refs/heads/main` | Der Git-Ref für den Build-Context |
| `dockerfile` | `Dockerfile` | Pfad zur Dockerfile |

**Verwendete Secrets:**

- `regcred` – Docker-Registry-Zugangsdaten
- `github-token` – GitHub Personal Access Token für den Chart-Update-Commit

| Datei | Template-Name | GitHub-Repo |
| --- | --- | --- |
| `workflow-javahttpclient.yaml` | `javahttpclient-kaniko` | wlanboy/JavaHttpClient |
| `workflow-mirrorservice.yaml` | `mirrorservice-kaniko` | wlanboy/MirrorService |
| `workflow-randomfail.yaml` | `randomfail-kaniko` | wlanboy/randomfail |
| `workflow-simpleservice.yaml` | `simpleservice-kaniko` | wlanboy/SimpleService |

---

### `argocd-events/`

Implementiert die ereignisgesteuerte Automatisierung mit Argo Events. Besteht aus vier Komponenten-Typen:

#### EventBus (`eventbus.yaml`)

NATS-basierter Message Bus (native Mode, Single Replica) im Namespace `argo-workflows`. Verbindet EventSources und Sensors.

#### CronWorkflows – Tag Poller (4 Dateien)

Laufen alle 2 Minuten (`*/2 * * * *`). Ablauf:

1. Aktuellen Image-Tag aus `values.yaml` des Helm-Charts lesen
2. Neuesten Tag per GitHub API abfragen
3. Bei Unterschied: Webhook-POST an den jeweiligen EventSource-Service senden

Payload: `{"tag": "LATEST_TAG", "git_ref": "refs/tags/LATEST_TAG"}`

| Datei | Überwachtes Repo | Webhook-Ziel |
| --- | --- | --- |
| `cronworkflow-tag-poller-javahttpclient.yaml` | wlanboy/JavaHttpClient | `webhook-javahttpclient-eventsource-svc:12000/javahttpclient` |
| `cronworkflow-tag-poller-mirrorservice.yaml` | wlanboy/MirrorService | `webhook-mirrorservice-eventsource-svc:12000/mirrorservice` |
| `cronworkflow-tag-poller-randomfail.yaml` | wlanboy/randomfail | `webhook-randomfail-eventsource-svc:12000/randomfail` |
| `cronworkflow-tag-poller-simpleservice.yaml` | wlanboy/SimpleService | `webhook-simpleservice-eventsource-svc:12000/simpleservice` |

#### EventSources – Webhook Endpunkte (4 Dateien)

Empfangen die POST-Requests der CronWorkflows über Port `12000`.

| Datei | Service-Name | Endpunkt |
| --- | --- | --- |
| `eventsource-webhook-javahttpclient.yaml` | webhook-javahttpclient | `/javahttpclient` |
| `eventsource-webhook-mirrorservice.yaml` | webhook-mirrorservice | `/mirrorservice` |
| `eventsource-webhook-randomfail.yaml` | webhook-randomfail | `/randomfail` |
| `eventsource-webhook-simpleservice.yaml` | webhook-simpleservice | `/simpleservice` |

#### Sensors – Workflow Trigger (4 Dateien)

Lauschen auf Events der jeweiligen EventSource und instanziieren das zugehörige `WorkflowTemplate`. Die Parameter `image-tag` und `git-ref` werden direkt aus dem Event-Payload (`body.tag`, `body.git_ref`) übernommen.

| Datei | Sensor-Name | WorkflowTemplate |
| --- | --- | --- |
| `sensor-kaniko-javahttpclient.yaml` | kaniko-javahttpclient-sensor | `javahttpclient-kaniko` |
| `sensor-kaniko-mirrorservice.yaml` | kaniko-mirrorservice-sensor | `mirrorservice-kaniko` |
| `sensor-kaniko-randomfail.yaml` | kaniko-randomfail-sensor | `randomfail-kaniko` |
| `sensor-kaniko-simpleservice.yaml` | kaniko-simpleservice-sensor | `simpleservice-kaniko` |

---

## Installations-Skripte

### `install-argocd-project-apps.sh`

Erstmalige Einrichtung von Cluster, Projekt, Namespaces und ArgoCD Apps:

```bash
kubectl apply -f argocd-projects/
kubectl apply -f argocd-namespaces/
kubectl apply -f argocd-apps/
```

### `install-argocd-workflows-builds.sh`

Installiert die Workflow-Templates:

```bash
kubectl apply -f argocd-workflows/
```

### `install-argocd-workflows-events.sh`

Vollständige Einrichtung der Event-Pipeline inkl. Secret-Erstellung:

1. Fragt nach GitHub PAT (oder liest `$GITHUB_TOKEN`)
2. Erstellt Secret `github-token` im Namespace `argo-workflows`
3. Liest ArgoCD Admin-Passwort aus `argocd-initial-admin-secret`
4. Port-Forward zu ArgoCD und holt Session-Token
5. Erstellt Secret `argocd-sync-token` im Namespace `argocd`
6. Wendet alle Event-Ressourcen an (EventBus, EventSources, Sensors, CronWorkflows)

### `selector.py`

Interaktives Python-Tool zur gezielten Verwaltung einzelner Ressourcen:

- **Modi:** `apply` oder `delete`
- **Reihenfolge beim Apply:** Cluster/Projekt → je App: Namespace → App → Workflow → CronWorkflow → EventSource → Sensor
- **Reihenfolge beim Delete:** umgekehrt (Sensor zuerst, Namespace zuletzt)
- Zeigt einen Plan an und wartet auf Bestätigung vor der Ausführung
