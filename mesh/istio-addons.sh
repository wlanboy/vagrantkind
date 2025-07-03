#!/bin/bash

ISTIO_VERSION="1.26.2" #https://github.com/istio/istio/releases
SAMSPLES_FOLDER=~/istio-$ISTIO_VERSION/samples/addons

kubectl apply -f $SAMSPLES_FOLDER/prometheus.yaml
kubectl apply -f $SAMSPLES_FOLDER/grafana.yaml
kubectl apply -f $SAMSPLES_FOLDER/jaeger.yaml
kubectl apply -f $SAMSPLES_FOLDER/kiali.yaml
kubectl apply -f $SAMSPLES_FOLDER/loki.yaml

kubectl get all -A

