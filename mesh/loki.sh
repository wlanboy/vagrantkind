helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create ns loki
helm upgrade --install loki grafana/loki --namespace loki

helm upgrade --install promtail grafana/promtail --namespace loki -f values/promtail-values.yaml
