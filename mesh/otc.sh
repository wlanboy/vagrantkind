#!/bin/bash

echo "Füge Helm-Repositories für Grafana und OpenTelemetry hinzu..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

echo "Installiere Loki..."
helm upgrade --install loki grafana/loki \
  --namespace loki \
  --create-namespace \
  -f loki-values.yaml \
  --wait

echo "Loki wurde erfolgreich installiert."
echo "Loki Service Endpoint: http://loki-gateway.loki.svc.cluster.local:3100/loki/api/v1/push"

echo "Installiere den OpenTelemetry Collector..."
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --namespace otel \
  --create-namespace \
  -f otel-collector-config.yaml \
  --wait

echo "OpenTelemetry Collector wurde erfolgreich installiert."

echo "Um die erstellten Ressourcen zu entfernen, führen Sie die folgenden Befehle aus:"
echo "helm delete otel-collector -n otel"
echo "helm delete loki -n loki"
echo "rm otel-collector-config.yaml"

echo "Install otel services for istio"
kubectl apply -f otel-services.yaml

echo "Set otel provider for Istio Mesh"
kubectl apply -f observability/istio-telemetry-otel.yaml

