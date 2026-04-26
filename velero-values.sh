#!/usr/bin/env bash
set -e

GARAGE_CONTAINER="garage"

if ! docker inspect "${GARAGE_CONTAINER}" &>/dev/null; then
  echo "❌ Container '${GARAGE_CONTAINER}' nicht gefunden."
  exit 1
fi

# Access Key + Secret aus garage key list (ersten Key nehmen)
KEY_ID=$(docker exec "${GARAGE_CONTAINER}" /garage key list 2>/dev/null | awk 'NR==2 {print $1}')
if [ -z "${KEY_ID}" ]; then
  echo "❌ Kein Garage Key gefunden."
  exit 1
fi

KEY_INFO=$(docker exec "${GARAGE_CONTAINER}" /garage key info "${KEY_ID}" --show-secret 2>/dev/null)
ACCESS_KEY=$(echo "${KEY_INFO}" | grep "Key ID" | awk '{print $NF}')
SECRET_KEY=$(echo "${KEY_INFO}" | grep "Secret key" | awk '{print $NF}')

# Bucket (ersten nehmen)
BUCKET=$(docker exec "${GARAGE_CONTAINER}" /garage bucket list 2>/dev/null | awk 'NR==2 {print $1}')

# Region aus garage.toml (via docker cp, kein Shell im Container nötig)
REGION=$(docker cp "${GARAGE_CONTAINER}:/etc/garage.toml" - 2>/dev/null | tar -xO 2>/dev/null | grep 's3_region' | head -1 | tr -d '" ' | cut -d= -f2)
REGION="${REGION:-garage}"

# Host-IP des Containers ermitteln
HOST_IP=192.168.178.91
ENDPOINT="http://${HOST_IP}:3900"

cat <<EOF
export GARAGE_ACCESS_KEY="${ACCESS_KEY}"
export GARAGE_SECRET_KEY="${SECRET_KEY}"
export GARAGE_ENDPOINT="${ENDPOINT}"
export GARAGE_ALIAS="${GARAGE_CONTAINER}"
export GARAGE_BUCKET="${BUCKET}"
export GARAGE_REGION="${REGION}"
EOF
