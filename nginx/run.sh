docker run -d \
  --name nginx-ssl-proxy \
  -p 443:443 \
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v $(pwd)/certs:/certs:ro \
  nginx:latest
