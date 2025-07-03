helm upgrade --install loki-stack grafana/loki-stack --namespace logging --create-namespace --values loki-values.yaml --set grafana.enabled=true

kubectl get secret loki-stack-grafana -n logging -o jsonpath="{.data.admin-password}" | base64 --decode
echo
kubectl get secret loki-stack-grafana -n logging -o jsonpath="{.data.admin-user}" | base64 --decode
echo

kubectl port-forward svc/loki-stack-grafana 3000:80 -n logging
