#!/bin/bash

ISTIO_VERSION="1.26.2" #https://github.com/istio/istio/releases
SAMSPLES_FOLDER=~/istio-$ISTIO_VERSION/samples/addons

kubectl apply -f $SAMSPLES_FOLDER/grafana.yaml
kubectl apply -f $SAMSPLES_FOLDER/prometheus.yaml
kubectl apply -f $SAMSPLES_FOLDER/jaeger.yaml
kubectl apply -f $SAMSPLES_FOLDER/kiali.yaml
#kubectl apply -f $SAMSPLES_FOLDER/loki.yaml

#kubectl get all -A
kubectl apply -f gateway-monitoring.yaml
kubectl apply -f virtual-service-monitoring.yaml

kubectl patch deployment grafana -n istio-system --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/env", "value": [{"name": "GF_SERVER_ROOT_URL", "value": "http://monitoring.ser.local/grafana/"}, {"name": "GF_SERVER_SERVE_FROM_SUB_PATH", "value": "true"}]}]'
kubectl rollout restart deployment/grafana -n istio-system

# get credentials for helm deployment
kubectl get secret grafana-admin-credentials -n istio-system -o jsonpath='{.data.username}' | base64 --decode
kubectl get secret grafana-admin-credentials -n istio-system -o jsonpath='{.data.password}' | base64 --decode

#kubectl apply -f otel-collector-deployment.yaml
#kubectl apply -f istio-telemetry-otel.yaml

helm upgrade --install loki grafana/loki-distributed -n grafana-loki --create-namespace
#helm show values grafana/promtail > promtail-overrides.yaml
#- url: http://loki-loki-distributed-gateway.grafana-loki.svc.cluster.local/loki/api/v1/push
helm upgrade --install --values promtail-overrides.yaml promtail grafana/promtail -n grafana-loki

# http://monitoring.ser.local/grafana/login
# datasource loki http://loki-loki-distributed-gateway.grafana-loki.svc.cluster.local
# dashboard id 15141

kubectl apply -f istio-telemetry-envoy.yaml 
#kubectl patch istiooperator <your-istiooperator-name> -n istio-system --type='json' -p='[{"op": "add", "path": "/spec/meshConfig/accessLogFile", "value": "/dev/stdout"}]'
