# Argo Workflows - CI/CD Pipeline mit BuildKit

Die Workflows implementieren eine vollständige GitOps-CI/CD-Pipeline mit zwei Schritten:

## Ablauf

**1. Build** - Docker-Image bauen mit [BuildKit](https://github.com/moby/buildkit) (rootless)

`buildkitd` startet rootless im Pod (UID 1000, ohne Prozess-Sandbox), zieht den Quellcode per HTTPS direkt aus GitHub und pusht das fertige Image nach Docker Hub. Ein lokales Registry-Cache (`local-registry`) beschleunigt wiederholte Builds via `--export-cache` und `--import-cache`.

**2. Update Chart** - Helm-Chart aktualisieren per Git-Commit

Nach dem Build wird der Image-Tag im `values.yaml` des zugehörigen Helm-Charts per `sed` gesetzt und als Commit zurück ins GitHub-Repository gepusht. ArgoCD erkennt die Änderung und deployed automatisch.

## BuildKit vs. Kaniko

| | BuildKit (rootless) | Kaniko |
|---|---|---|
| Image | `moby/buildkit:rootless` | `ghcr.io/osscontainertools/kaniko` |
| Daemon | `buildkitd` im Pod | kein Daemon |
| Cache | `--export-cache` / `--import-cache` | `--cache-repo` |
| Security | UID 1000, seccomp Unconfined | root im Container |
| Git-Kontext | `https://...git#ref` | `git://...git#ref` |

## Gemeinsame Parameter

| Parameter | Default | Beschreibung |
|-----------|---------|--------------|
| `image-tag` | `latest` | Tag des zu bauenden Images |
| `git-ref` | `refs/heads/main` | Git-Branch oder -Tag als Build-Quelle |
| `dockerfile` | `Dockerfile` | Pfad zum Dockerfile |

## Security Context

BuildKit läuft als UID 1000 mit folgender Kubernetes-Konfiguration:

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

`SYS_ADMIN` ist notwendig, damit `rootlesskit` innerhalb des Pods einen Mount-Namespace aufbauen kann (`failed to share mount point: /: permission denied` ohne diese Capability). `--oci-worker-no-process-sandbox` deaktiviert zusätzlich die Prozess-Isolation von buildkitd, die in einem Kubernetes-Pod nicht funktioniert.

## Secrets

- `regcred` - Docker Hub Zugangsdaten (`.dockerconfigjson`), gemountet nach `/home/user/.docker`
- `github-token` - GitHub Token für den Chart-Commit
