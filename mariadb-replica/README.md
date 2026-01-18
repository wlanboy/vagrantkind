# MariaDB Replica Cluster Deployment

Kubernetes StatefulSet-Deployment für einen MariaDB Primary-Replica Cluster mit automatischer Replikation.

## Voraussetzungen

- Kubernetes Cluster (z.B. kind, minikube)
- kubectl konfiguriert
- StorageClass für dynamisches PVC-Provisioning

## Architektur

```
┌─────────────────────┐     ┌─────────────────────┐
│  mariadb-stateful-0 │────▶│  mariadb-stateful-1 │
│      (Primary)      │     │      (Replica)      │
│    Read/Write       │     │     Read-Only       │
└─────────────────────┘     └─────────────────────┘
          │                           │
          └───────────┬───────────────┘
                      │
              mariadb-service
              (Headless Service)
```

## Komponenten

| Datei | Beschreibung |
|-------|--------------|
| `statefullset.yaml` | StatefulSet mit Init-Container für Konfiguration |
| `configurations.yaml` | ConfigMap mit Primary/Replica Konfiguration und Init-SQL |
| `secrets.yaml` | Secret mit Root-Passwort |
| `service.yaml` | Headless Service für Pod-Discovery |

## Installation

### 1. Namespace erstellen

```bash
kubectl create namespace database-stateful
```

### 2. Konfiguration und Secrets erstellen

```bash
kubectl apply -f configurations.yaml -n database-stateful
kubectl apply -f secrets.yaml -n database-stateful
kubectl apply -f service.yaml -n database-stateful
```

### 3. StatefulSet erstellen

```bash
kubectl apply -f statefullset.yaml -n database-stateful
```

## Status prüfen

```bash
# StatefulSet Status
kubectl get sts mariadb-statefulset -n database-stateful -o wide

# Pod Status
kubectl get pods -n database-stateful -o wide

# Logs des Primary
kubectl logs mariadb-statefulset-0 -n database-stateful

# Logs des Replica
kubectl logs mariadb-statefulset-1 -n database-stateful
```

## Skalieren

```bash
# Auf 3 Replicas skalieren
kubectl scale sts mariadb-statefulset -n database-stateful --replicas=3

# Status prüfen
kubectl get pods -n database-stateful -o wide
```

## Verbindung testen

### Mit Primary verbinden (Read/Write)

```bash
kubectl exec -it mariadb-statefulset-0 -n database-stateful -- mariadb -uroot -psecret
```

### Mit Replica verbinden (Read-Only)

```bash
kubectl exec -it mariadb-statefulset-1 -n database-stateful -- mariadb -uroot -psecret
```

### Replikationsstatus prüfen

```bash
# Auf dem Primary
kubectl exec -it mariadb-statefulset-0 -n database-stateful -- mariadb -uroot -psecret -e "SHOW MASTER STATUS\G"

# Auf dem Replica
kubectl exec -it mariadb-statefulset-1 -n database-stateful -- mariadb -uroot -psecret -e "SHOW REPLICA STATUS\G"
```

## DNS-Namen

Jeder Pod ist über einen stabilen DNS-Namen erreichbar:

| Pod | DNS-Name |
|-----|----------|
| Primary | `mariadb-statefulset-0.mariadb-service.database-stateful.svc.cluster.local` |
| Replica 1 | `mariadb-statefulset-1.mariadb-service.database-stateful.svc.cluster.local` |
| Replica N | `mariadb-statefulset-N.mariadb-service.database-stateful.svc.cluster.local` |

## Deinstallation

```bash
# StatefulSet und Service löschen
kubectl delete -f statefullset.yaml -n database-stateful
kubectl delete -f service.yaml -n database-stateful
kubectl delete -f configurations.yaml -n database-stateful
kubectl delete -f secrets.yaml -n database-stateful

# PVCs löschen (Achtung: Datenverlust!)
kubectl delete pvc -l app=mariadb -n database-stateful

# Namespace löschen
kubectl delete namespace database-stateful
```

## Konfiguration

### Resource Limits

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 500m | 2 |
| Memory | 512Mi | 1Gi |

### Replikation

- **Primary (Pod 0)**: Binlog aktiviert, Read/Write
- **Replicas (Pod 1+)**: Read-Only, automatische Replikation vom Primary

### Credentials

| Benutzer | Passwort | Verwendung |
|----------|----------|------------|
| root | secret | Administration |
| repluser | replsecret | Replikation |

**Hinweis**: Für Produktionsumgebungen sichere Passwörter verwenden!
