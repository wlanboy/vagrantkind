kubectl port-forward --namespace loki svc/loki-gateway 3100:80 &

#post
curl -H "Content-Type: application/json" -XPOST -s "http://127.0.0.1:3100/loki/api/v1/push"  --data-raw "{\"streams\": [{\"stream\": {\"job\": \"test\"}, \"values\": [[\"$(date +%s)000000000\", \"fizzbuzz\"]]}]}" -H X-Scope-OrgId:foo
#query
curl "http://127.0.0.1:3100/loki/api/v1/query_range" --data-urlencode 'query={job="test"}' -H X-Scope-OrgId:foo | jq .data.result
