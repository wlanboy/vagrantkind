#!/bin/bash
set -euo pipefail

kubectl apply -f javahttpclient-kaniko.yaml
kubectl apply -f mirrorservice-kaniko.yaml
