# Warten bis garage bereit ist
echo "Warte auf garage..."
until docker exec garage /garage status > /dev/null 2>&1; do
  sleep 1
done
echo "garage ist bereit."

# Layout idempotent anlegen (notwendig beim ersten Start)
if docker exec garage /garage key list 2>&1 | grep -q "Layout not ready"; then
  NODE_ID=$(docker exec garage /garage node id 2>/dev/null | awk 'NR==1{print $1}' | cut -d'@' -f1)
  docker exec garage /garage layout assign -z main -c 1073741824 "$NODE_ID"
  docker exec garage /garage layout apply --version 1
  echo "Layout angewendet (Node: $NODE_ID)."
  echo "Warte bis Layout aktiv ist..."
  until ! docker exec garage /garage key list 2>&1 | grep -q "Layout not ready"; do
    sleep 1
  done
  echo "Layout ist aktiv."
fi

# Key idempotent anlegen
if ! docker exec garage /garage key list 2>/dev/null | grep -q "s3user"; then
  KEY_OUTPUT=$(docker exec garage /garage key create s3user 2>/dev/null)
  ACCESS_KEY=$(echo "$KEY_OUTPUT" | grep "Key ID:" | awk '{print $3}')
  SECRET_KEY=$(echo "$KEY_OUTPUT" | grep "Secret key:" | awk '{print $3}')
  cat > "$(dirname "$0")/minio.env" <<EOF
export MINIO_ACCESS_KEY=$ACCESS_KEY
export MINIO_SECRET_KEY=$SECRET_KEY
EOF
  echo "Key s3user angelegt. Credentials gespeichert in minio.env."
else
  echo "Key s3user existiert bereits."
fi

# Bucket idempotent anlegen
if ! docker exec garage /garage bucket list 2>/dev/null | grep -q "velero"; then
  docker exec garage /garage bucket create velero 2>/dev/null
  echo "Bucket velero angelegt."
else
  echo "Bucket velero existiert bereits."
fi

# Bucket-Berechtigung setzen (idempotent)
KEY_ID=$(docker exec garage /garage key list 2>/dev/null | grep "s3user" | awk '{print $1}')
docker exec garage /garage bucket allow velero --read --write --owner --key "$KEY_ID" 2>/dev/null
echo "Berechtigungen für velero gesetzt (Key: $KEY_ID)."

# Website-Zugriff aktivieren (idempotent)
docker exec garage /garage bucket website --allow velero 2>/dev/null
echo "Website-Zugriff für velero aktiviert."
