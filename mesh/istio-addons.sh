#!/bin/bash

ISTIO_VERSION="1.26.2" #https://github.com/istio/istio/releases
SAMSPLES_FOLDER=~/istio-$ISTIO_VERSION/samples/addons
OBS_FOLDER=./observability

kubectl apply -f $SAMSPLES_FOLDER/grafana.yaml
kubectl apply -f $SAMSPLES_FOLDER/prometheus.yaml

kubectl -n istio-system wait --for=condition=Ready --all pods --timeout 60s

kubectl apply -f ${OBS_FOLDER}/gateway-monitoring.yaml
kubectl apply -f ${OBS_FOLDER}/virtual-service-monitoring.yaml

kubectl patch deployment grafana -n istio-system --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/env", "value": [{"name": "GF_SERVER_ROOT_URL", "value": "http://monitoring.ser.local/grafana/"}, {"name": "GF_SERVER_SERVE_FROM_SUB_PATH", "value": "true"}]}]'

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install loki grafana/loki-distributed -n grafana-loki --create-namespace --wait
helm upgrade --install --values ${OBS_FOLDER}/promtail-overrides.yaml promtail grafana/promtail -n grafana-loki --wait

kubectl apply -f ${OBS_FOLDER}/istio-telemetry-envoy.yaml 
#kubectl patch istiooperator <your-istiooperator-name> -n istio-system --type='json' -p='[{"op": "add", "path": "/spec/meshConfig/accessLogFile", "value": "/dev/stdout"}]'

kubectl get configmap grafana -n istio-system -o yaml > grafana-configmap.yaml
sed -i 's|http://loki:3100|http://loki-loki-distributed-gateway.grafana-loki.svc.cluster.local|g' grafana-configmap.yaml
kubectl apply -f grafana-configmap.yaml

kubectl rollout restart deployment/grafana -n istio-system