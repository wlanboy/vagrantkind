# simple mesh setup
create local kind cluster with istio, metallb, istio, ingress and egress gateways and http tester service to check http and dns requests

## install cluster
* sh cluster.sh

## install istio and gateways
* sh istio.sh

## install httpbin target
* sh gateway.sh

## install egress target for docker container on host gmk
* sh egress.sh

## install http tester
* sh http-tester.sh