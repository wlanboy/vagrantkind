#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="longhorn-system"
SCHEDULE="0 3 * * *"
RETAIN=3

echo "=== Longhorn Recurring Backup Setup (Group Method) ==="

# Create or Update the RecurringJob with the 'default' group
echo "-> Applying RecurringJob 'nightly-backup'..."
cat <<EOF | kubectl apply -f -
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: nightly-backup
  namespace: ${NAMESPACE}
spec:
  cron: "${SCHEDULE}"
  task: "backup"
  retain: ${RETAIN}
  concurrency: 1
  groups:
  - default  # <--- This is the magic part!
EOF

echo "-> Success! All volumes will now inherit this job automatically."
echo "=== Fertig ==="