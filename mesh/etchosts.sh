#!/bin/bash

# IP-Adresse und Hostnamen definieren
IP="172.19.100.10"
HOSTS=(
  "monitoring.ser.local"
  "httpbin.ser.local"
  "http.ser.local"
  "test.ser.local"
)

# Backup der aktuellen /etc/hosts erstellen
cp /etc/hosts /etc/hosts.bak

# Host-Einträge hinzufügen, falls sie noch nicht vorhanden sind
for HOST in "${HOSTS[@]}"; do
  if ! grep -q "$HOST" /etc/hosts; then
    echo "$IP    $HOST" >> /etc/hosts
    echo "Hinzugefügt: $HOST -> $IP"
  else
    echo "Eintrag existiert bereits: $HOST"
  fi
done
