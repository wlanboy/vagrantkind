docker run -d \
  --name nginx-ssl-proxy \
  --network kind \
  -p 443:443 \
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v /certs:/etc/nginx/certs:ro \
  nginx:latest
