# dbclient - MySQL Benchmark Client mit Istio

Sysbench-Deployment im Namespace `dbclient` mit Istio-Integration für persistente Verbindungen zum externen MySQL-Host `gmkchost.lan` (`192.168.178.28:3306`).

## Dateien

| Datei | Beschreibung |
|-------|-------------|
| `namespace.yaml` | Namespace `dbclient` mit `istio-injection: enabled` |
| `external-service.yaml` | `ServiceEntry` (STATIC) + `DestinationRule` für `192.168.178.28:3306` mit Connection Pooling |
| `secret.yaml` | MySQL-Credentials — Host als IP `192.168.178.28` eintragen |
| `configmap.yaml` | Sysbench-Skripte (prepare / run / cleanup) |
| `deployment.yaml` | Sysbench-Deployment mit Istio-Sidecar (`perconalab/sysbench`) |
| `peer-authentication.yaml` | mTLS PERMISSIVE für den Namespace |

## Deployment

Namespace zuerst anlegen, dann alle Ressourcen:

```bash
kubectl apply -f external-mysqldb/dbclient/namespace.yaml
kubectl apply -f external-mysqldb/dbclient/
```

Bei Secret-Änderungen (z.B. neue IP) Secret neu anlegen und Deployment neu starten:

```bash
kubectl delete secret mysql-credentials -n dbclient
kubectl apply -f external-mysqldb/dbclient/secret.yaml
kubectl rollout restart deployment/sysbench -n dbclient
kubectl -n dbclient rollout status deployment/sysbench
```

## Benchmark ausführen

```bash
# Pod-Name ermitteln
POD=$(kubectl get pod -n dbclient -l app=sysbench -o jsonpath='{.items[0].metadata.name}')

# Warten bis Pod bereit ist
kubectl -n dbclient wait --for=condition=Ready pod/$POD --timeout=60s

# 1. Tabellen vorbereiten
kubectl exec -n dbclient $POD -c sysbench -- /scripts/prepare.sh

# 2. Benchmark starten
kubectl exec -n dbclient $POD -c sysbench -- /scripts/run.sh

# 3. Aufräumen (optional)
kubectl exec -n dbclient $POD -c sysbench -- /scripts/cleanup.sh
```

> **Hinweis:** `-c sysbench` ist notwendig, da Istio einen zweiten Container (`istio-proxy`) in den Pod injiziert.

## Persistente Verbindungen (Istio DestinationRule)

Der `ServiceEntry` verwendet `resolution: STATIC` mit expliziter IP — damit umgeht Istio die DNS-Auflösung vollständig. Das ist robuster als `resolution: DNS` für externe Hosts mit fester IP.

Die `DestinationRule` konfiguriert:

- **maxConnections: 100** – Connection Pool Größe
- **connectTimeout: 30s** – Verbindungs-Timeout
- **tcpKeepalive** – Hält TCP-Verbindungen aktiv (7200s idle, 75s Intervall, 10 Probes)
- **outlierDetection** – Entfernt fehlerhafte Backends automatisch

## Bekannte Stolpersteine

| Problem | Ursache | Lösung |
|---------|---------|--------|
| `protocol: MySQL` im ServiceEntry | Istio analysiert MySQL-Handshake (L7), kollidiert mit externen Hosts | `protocol: TCP` + `name: tcp-mysql` verwenden |
| `Unknown MySQL server host` | sysbench-Image hat keine DNS-Bibliotheken | IP statt Hostname im Secret verwenden |
| `container not found ("sysbench")` | Falsches Image (`severalnines/sysbench`) crasht sofort | `perconalab/sysbench` verwenden |
| Secret-Änderung greift nicht | `kubectl apply` überschreibt `stringData` nicht zuverlässig | Secret löschen und neu anlegen |

## Credentials anpassen

`secret.yaml` anpassen und neu anlegen:

```bash
kubectl delete secret mysql-credentials -n dbclient
kubectl apply -f external-mysqldb/dbclient/secret.yaml
kubectl rollout restart deployment/sysbench -n dbclient
```
