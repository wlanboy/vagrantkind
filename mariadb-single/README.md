# MariaDB Single Instance Deployment

Kubernetes-Deployment für eine einzelne MariaDB-Instanz mit persistentem Storage und benutzerdefinierter Konfiguration.

## Voraussetzungen

- Kubernetes Cluster (z.B. kind, minikube)
- kubectl konfiguriert
- LoadBalancer-Unterstützung (z.B. MetalLB für kind)

## Komponenten

| Datei | Beschreibung |
|-------|--------------|
| `deployment.yaml` | MariaDB Deployment mit Resource Limits |
| `storage.yaml` | PersistentVolume und PersistentVolumeClaim |
| `service.yaml` | LoadBalancer Service für externen Zugriff |
| `my.cnf` | MariaDB Konfigurationsdatei |

## Installation

### 1. Namespace erstellen

```bash
kubectl create namespace database
```

### 2. Storage erstellen

```bash
kubectl apply -f storage.yaml -n database
```

### 3. ConfigMap und Secrets erstellen

```bash
# MariaDB Konfiguration
kubectl create configmap mariadb-config --from-file=my.cnf -n database

# Root-Passwort (in Produktion sichere Werte verwenden!)
kubectl create secret generic mariadb-root-password --from-literal=password=secret -n database

# Benutzer-Credentials
kubectl create secret generic mariadb-user --from-literal=username=user --from-literal=password=pass -n database
```

### 4. Deployment erstellen

```bash
kubectl apply -f deployment.yaml -n database
```

### 5. Service erstellen

```bash
kubectl apply -f service.yaml -n database
```

## Verbindung testen

### Service-Informationen abrufen

```bash
kubectl get svc mariadb -n database
```

Beispielausgabe:
```
NAME      TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)          AGE
mariadb   LoadBalancer   10.96.60.2   172.18.0.101   3306:32435/TCP   29s
```

### Mit MariaDB verbinden

```bash
# Vom Pod aus
kubectl exec -it deployment/mariadb-deployment -n database -- mariadb -u user -p

# Von extern (mit MariaDB-Client installiert)
mariadb --host <EXTERNAL-IP> --port 3306 --user user --password
```

## Status prüfen

```bash
# Pod-Status
kubectl get pods -n database

# Logs anzeigen
kubectl logs deployment/mariadb-deployment -n database

# Alle Ressourcen anzeigen
kubectl get all -n database
```

## Deinstallation

```bash
# Ressourcen löschen
kubectl delete -f service.yaml -n database
kubectl delete -f deployment.yaml -n database
kubectl delete configmap mariadb-config -n database
kubectl delete secret mariadb-root-password mariadb-user -n database
kubectl delete -f storage.yaml -n database

# Namespace löschen
kubectl delete namespace database
```

## Konfiguration

### Resource Limits

Das Deployment verwendet folgende Limits (anpassbar in `deployment.yaml`):

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 1 | 2 |
| Memory | 512Mi | 1Gi |

### MariaDB Konfiguration

Die `my.cnf` ist für ressourcenschonenden Betrieb optimiert. Wichtige Parameter:

- `max_connections`: 10
- `innodb_buffer_pool_size`: 10M
- `bind-address`: 0.0.0.0 (alle Interfaces)

Für Produktionsumgebungen sollten diese Werte erhöht werden.
