#!/bin/bash

kubectl create namespace gmk
kubectl label namespace gmk istio-injection=enabled --overwrite=true 
kubectl apply -f ./egress/gmk-serviceentry.yaml
kubectl apply -f ./egress/gmk-virtualservice.yaml
kubectl apply -f ./egress/destination-rule.yaml

kubectl apply -f ./egress/test.yaml
kubectl exec -it test-pod -n gmk -- curl -v http://gmkexternal:4000/
