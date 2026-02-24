# Argo Workflows - CI/CD Pipeline

Die Workflows implementieren eine vollständige GitOps-CI/CD-Pipeline mit zwei Schritten:

## Ablauf

**1. Build** - Docker-Image bauen mit [Kaniko](https://github.com/osscontainertools/kaniko)

Der Kaniko-Executor baut das Image direkt im Cluster (ohne Docker-Daemon), zieht den Quellcode per `git://` direkt aus GitHub und pusht das fertige Image nach Docker Hub. Ein lokales Registry-Cache (`local-registry`) beschleunigt wiederholte Builds.

**2. Update Chart** - Helm-Chart aktualisieren per Git-Commit

Nach dem Build wird der Image-Tag im `values.yaml` des zugehörigen Helm-Charts per `sed` gesetzt und als Commit zurück ins GitHub-Repository gepusht. ArgoCD erkennt die Änderung und deployed automatisch.

## Gemeinsame Parameter

| Parameter | Default | Beschreibung |
|-----------|---------|--------------|
| `image-tag` | `latest` | Tag des zu bauenden Images |
| `git-ref` | `refs/heads/main` | Git-Branch oder -Tag als Build-Quelle |
| `dockerfile` | `Dockerfile` | Pfad zum Dockerfile |

## Secrets

- `regcred` - Docker Hub Zugangsdaten (`.dockerconfigjson`)
- `github-token` - GitHub Token für den Chart-Commit
