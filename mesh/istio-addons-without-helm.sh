ISTIO_VERSION="1.26.2" #https://github.com/istio/istio/releases
SAMSPLES_FOLDER=~/istio-$ISTIO_VERSION/samples/addons
OBS_FOLDER=./observability
LOKI_FOLDER=./loki-prom

kubectl apply -f $SAMSPLES_FOLDER/loki.yaml -n istio-system

kubectl apply -f ${LOKI_FOLDER}/promtail-deployment.yaml -n istio-system

kubectl apply -f $SAMSPLES_FOLDER/grafana.yaml

kubectl apply -f ${OBS_FOLDER}/istio-telemetry-envoy.yaml 