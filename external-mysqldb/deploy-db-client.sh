#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="${SCRIPT_DIR}/dbclient"

# Prüfen ob benötigte Tools vorhanden sind
for cmd in kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Fehler: $cmd ist nicht installiert"
        exit 1
    fi
done

# Prüfen ob Manifest-Verzeichnis existiert
if [[ ! -d "$MANIFEST_DIR" ]]; then
    echo "Fehler: Manifest-Verzeichnis nicht gefunden: $MANIFEST_DIR"
    exit 1
fi

echo "=== dbclient Deployment ==="
echo "Manifeste: $MANIFEST_DIR"

# 1. Namespace anlegen (zuerst, damit nachfolgende Applies funktionieren)
echo ""
echo "--- Namespace ---"
kubectl apply -f "${MANIFEST_DIR}/namespace.yaml"

# Sicherstellen dass istio-injection Label gesetzt ist (idempotent durch --overwrite)
kubectl label namespace dbclient istio-injection=enabled --overwrite

# 2. Istio External Service + DestinationRule
echo ""
echo "--- Istio External Service (ServiceEntry + DestinationRule) ---"
kubectl apply -f "${MANIFEST_DIR}/external-service.yaml"

# 3. PeerAuthentication
echo ""
echo "--- PeerAuthentication ---"
kubectl apply -f "${MANIFEST_DIR}/peer-authentication.yaml"

# 4. Secret
echo ""
echo "--- Secret ---"
kubectl apply -f "${MANIFEST_DIR}/secret.yaml"

# 5. ConfigMap mit Benchmark-Skripten
echo ""
echo "--- ConfigMap ---"
kubectl apply -f "${MANIFEST_DIR}/configmap.yaml"

# 6. Deployment
echo ""
echo "--- Deployment ---"
kubectl apply -f "${MANIFEST_DIR}/deployment.yaml"

# 7. Warten bis Pod bereit ist
echo ""
echo "--- Warte auf sysbench Pod ---"
kubectl -n dbclient rollout status deployment/sysbench --timeout=120s

echo ""
echo "=== Deployment abgeschlossen ==="

# Pod-Name ermitteln und ausgeben
POD=$(kubectl get pod -n dbclient -l app=sysbench -o jsonpath='{.items[0].metadata.name}')
echo ""
echo "Pod: $POD"
echo ""
echo "Benchmark-Befehle:"
echo "  Vorbereiten:  kubectl exec -n dbclient $POD -- /scripts/prepare.sh"
echo "  Ausführen:    kubectl exec -n dbclient $POD -- /scripts/run.sh"
echo "  Aufräumen:    kubectl exec -n dbclient $POD -- /scripts/cleanup.sh"
echo ""
echo "MySQL-Client:   kubectl exec -n dbclient -it $POD -- mysql -h \$MYSQL_HOST -u \$MYSQL_USER -p\$MYSQL_PASSWORD \$MYSQL_DATABASE"
