# Apicurio Registry

Apicurio Registry ist eine Schema-Registry für Event-Streaming und API-Management. Sie speichert und verwaltet Schemas (Avro, JSON Schema, Protobuf, OpenAPI, AsyncAPI u.a.) und stellt eine REST-API sowie eine Web-UI bereit.

Als Backend wird PostgreSQL 15 verwendet.

## Voraussetzungen

- k3s-Cluster mit kubectl-Zugriff
- MetalLB für LoadBalancer-Services
- cert-manager mit `local-ca-issuer` ClusterIssuer
- Istio mit Ingress-Gateway im Namespace `istio-ingress`

## Installation

```bash
./install-apicurio.sh
```

Das Script ist idempotent und kann mehrfach ausgeführt werden.

## Ressourcen

```
apicurio/
├── install-apicurio.sh           # Installations-Script
├── docker-compose.yml            # Lokale Entwicklungsumgebung
└── manifests/
    ├── namespace.yaml            # Namespace: apicurio
    ├── secret.yaml               # DB-Credentials
    ├── postgres-pvc.yaml         # PersistentVolumeClaim (5Gi)
    ├── postgres-deployment.yaml
    ├── postgres-service.yaml     # ClusterIP, Port 5432
    ├── registry-deployment.yaml
    ├── registry-service.yaml     # LoadBalancer, Port 8080
    ├── certificate.yaml          # TLS-Zertifikat via cert-manager
    ├── gateway.yaml              # Istio Gateway (HTTP + HTTPS)
    └── virtualservice.yaml       # Istio VirtualService
```

## Credentials

Die Datenbank-Credentials sind in `manifests/secret.yaml` als `stringData` hinterlegt und sollten vor dem Einsatz in Produktivumgebungen angepasst werden.

| Key               | Standardwert |
|-------------------|--------------|
| POSTGRES_DB       | apicurio     |
| POSTGRES_USER     | apicurio     |
| POSTGRES_PASSWORD | password     |

## Zugriff

| Endpunkt  | URL                                        |
|-----------|--------------------------------------------|
| Web-UI    | https://apicurio.tp.lan/ui                 |
| Web-UI    | https://apicurio.gmk.lan/ui                |
| REST-API  | https://apicurio.tp.lan/apis/registry/v2   |
| Health    | https://apicurio.tp.lan/health/ready       |

## Deployment-Details

**PostgreSQL**
- Image: `postgres:15`
- Daten werden in einem PVC gespeichert (kein `hostPath`)
- Readiness/Liveness via `pg_isready`

**Apicurio Registry**
- Image: `apicurio/apicurio-registry-sql:latest-release`
- Verbindet sich per JDBC auf `apicurio-db:5432`
- Readiness/Liveness via HTTP `/health/ready` und `/health/live`
- Startet parallel zur DB; Traffic wird erst weitergeleitet wenn die Registry bereit ist

**TLS / cert-manager**
- Certificate-Ressource im Namespace `istio-ingress`
- Aussteller: `local-ca-issuer` (ClusterIssuer)
- Laufzeit: 90 Tage, Erneuerung ab 15 Tage vor Ablauf
- Domains: `apicurio.tp.lan`, `apicurio.gmk.lan`

**Istio Gateway & VirtualService**
- Gateway im Namespace `istio-ingress`, HTTP (80) und HTTPS (443)
- VirtualService im Namespace `apicurio`, leitet alle Requests an `apicurio-registry:8080` weiter

## Alternative: docker-compose (lokale Entwicklung)

Für lokale Entwicklung ohne k3s steht `docker-compose.yml` bereit.

**Voraussetzungen:** Docker mit Compose-Plugin

```bash
docker compose up -d
```

Die Registry ist danach unter `http://localhost:8888` erreichbar.

| Endpunkt  | URL                                      |
|-----------|------------------------------------------|
| Web-UI    | http://localhost:8888/ui                 |
| REST-API  | http://localhost:8888/apis/registry/v2   |
| Health    | http://localhost:8888/health/ready       |

PostgreSQL-Daten werden unter `/mnt/sata/apicurio/data/postgres` auf dem Host gespeichert.

```bash
# Stoppen
docker compose down

# Stoppen und Daten löschen
docker compose down -v
```

## Deinstallation

```bash
kubectl delete namespace apicurio
kubectl delete certificate apicurio-cert-secret -n istio-ingress
kubectl delete gateway apicurio-gateway -n istio-ingress
```

Der PVC und damit die Daten werden beim Löschen des Namespace ebenfalls gelöscht.
