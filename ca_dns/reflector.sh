#!/bin/bash
set -euo pipefail

TRUSTSTORE_FILE="gmk-truststore.p12"
SECRET_NAME="gmk-truststore"
SOURCE_NAMESPACE="default"

# 1. Reflector via Helm installieren (falls noch nicht vorhanden)
if ! helm status reflector -n kube-system &>/dev/null; then
  echo ">> Installiere Reflector..."
  helm repo add emberstack https://emberstack.github.io/helm-charts
  helm repo update
  helm upgrade --install reflector emberstack/reflector \
    --namespace kube-system \
    --wait
else
  echo ">> Reflector bereits installiert, überspringe."
fi

# 2. Truststore-Datei prüfen
if [[ ! -f "$TRUSTSTORE_FILE" ]]; then
  echo "FEHLER: $TRUSTSTORE_FILE nicht gefunden. Bitte zuerst ./truststore.sh ausführen."
  exit 1
fi

# 3. Secret im default Namespace anlegen oder aktualisieren
echo ">> Erstelle Secret '$SECRET_NAME' in Namespace '$SOURCE_NAMESPACE'..."
kubectl create secret generic "$SECRET_NAME" \
  --from-file="$TRUSTSTORE_FILE" \
  --namespace "$SOURCE_NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Reflector-Annotationen setzen (spiegelt in ALLE Namespaces)
echo ">> Setze Reflector-Annotationen..."
kubectl annotate secret "$SECRET_NAME" \
  --namespace "$SOURCE_NAMESPACE" \
  --overwrite \
  reflector.v1.k8s.emberstack.com/reflection-allowed="true" \
  reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true" \
  reflector.v1.k8s.emberstack.com/reflection-auto-namespaces=""

echo ""
echo ">> Fertig. Das Secret wird in alle aktuellen und zukünftigen Namespaces gespiegelt."
echo ">> Status prüfen:"
echo "   kubectl get secrets --all-namespaces | grep $SECRET_NAME"
