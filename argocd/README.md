# ArgoCD Setup Tool

Interaktives Python-Script zum Einrichten von ArgoCD-Ressourcen auf einem bestehenden Kubernetes-Cluster.

Das Script legt schrittweise alle benoetigten Ressourcen an und fragt vor jedem Schritt interaktiv nach, ob die Ressource erstellt werden soll. Bereits vorhandene Ressourcen werden automatisch uebersprungen.

## Voraussetzungen

- Python 3.12+
- `kubectl` mit Zugriff auf den Ziel-Cluster
- ArgoCD muss bereits im Cluster installiert sein

## Verzeichnisstruktur

```
argocd/
  main.py                              # Setup-Script
  cluster-local.yaml                   # Cluster-Secret (local)
  repos/
    repo-wlanboy.yaml                  # Git-Repository
  projects/
    wlanboy-project.yaml               # ArgoCD-Projekt
  namespaces/
    namespace-mirror.yaml              # Namespace fuer Mirror
    namespace-javahttpclient.yaml      # Namespace fuer JavaHttpClient
    namespace-kubeeventjava.yaml       # Namespace fuer KubeEventJava
    namespace-randomfail.yaml          # Namespace fuer RandomFail
  apps/
    app-mirror.yaml                    # ArgoCD-Application Mirror
    app-javahttpclient.yaml            # ArgoCD-Application JavaHttpClient
    app-kubeeventjava.yaml             # ArgoCD-Application KubeEventJava
    app-randomfail.yaml                # ArgoCD-Application RandomFail
```

## Ausfuehrung

```bash
python argocd/main.py
```

## Ablauf

Das Script arbeitet die folgenden Schritte der Reihe nach ab:

1. Cluster-Secret fuer den lokalen Cluster anlegen
2. Git-Repository registrieren
3. ArgoCD-Projekt erstellen
4. Pro Anwendung: Namespace und Application anlegen
   - Mirror
   - JavaHttpClient
   - KubeEventJava
   - RandomFail

Bei jedem Schritt wird geprueft, ob die Ressource bereits existiert (`kubectl get -f`).
Falls nicht, wird interaktiv gefragt ob sie angelegt werden soll (`kubectl apply -f`).
Bei einem Fehler bricht das Script sofort ab.
