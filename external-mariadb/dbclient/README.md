# dbclient - MySQL Benchmark Client mit Istio

Sysbench-Deployment im Namespace `dbclient` mit Istio-Integration für persistente Verbindungen zum externen MySQL-Host `gmkchost.lan`.

## Dateien

| Datei | Beschreibung |
|-------|-------------|
| `namespace.yaml` | Namespace `dbclient` mit `istio-injection: enabled` |
| `external-service.yaml` | `ServiceEntry` + `DestinationRule` für `gmkchost.lan:3306` mit Connection Pooling |
| `secret.yaml` | MySQL-Credentials (Host, Port, User, Password, DB) |
| `configmap.yaml` | Sysbench-Skripte (prepare / run / cleanup) |
| `deployment.yaml` | Sysbench-Deployment mit Istio-Sidecar |
| `peer-authentication.yaml` | mTLS PERMISSIVE für den Namespace |

## Deployment

```bash
kubectl apply -f dbclient/namespace.yaml
kubectl apply -f dbclient/
```

## Benchmark ausführen

```bash
# Pod-Name ermitteln
POD=$(kubectl get pod -n dbclient -l app=sysbench -o jsonpath='{.items[0].metadata.name}')

# 1. Tabellen vorbereiten
kubectl exec -n dbclient $POD -- /scripts/prepare.sh

# 2. Benchmark starten
kubectl exec -n dbclient $POD -- /scripts/run.sh

# 3. Aufräumen (optional)
kubectl exec -n dbclient $POD -- /scripts/cleanup.sh
```

## Persistente Verbindungen (Istio DestinationRule)

Die `DestinationRule` in `external-service.yaml` konfiguriert:

- **maxConnections: 100** – Connection Pool Größe
- **connectTimeout: 30s** – Verbindungs-Timeout
- **tcpKeepalive** – Hält TCP-Verbindungen aktiv (7200s idle, 75s Intervall)
- **outlierDetection** – Entfernt fehlerhafte Backends automatisch

## Credentials anpassen

```bash
kubectl edit secret mysql-credentials -n dbclient
```

Oder `secret.yaml` vor dem Apply anpassen.
