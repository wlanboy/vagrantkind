# Java Truststore für eigene CA

Dieses Setup importiert eigene Root-CA-Zertifikate in einen Java-Truststore (PKCS12-Format), damit Java-Anwendungen im Kubernetes-Cluster TLS-Verbindungen zu intern signierten Diensten vertrauen.

## Voraussetzungen

- `keytool` (Teil des JDK) muss installiert sein
- Die CA-Zertifikate `ca-gmk.pem` und `ca-gmkc.pem` müssen im selben Verzeichnis liegen
- Zugriff auf einen Kubernetes-Cluster (für das Secret)

---

## 1. Truststore erstellen

```bash
./truststore.sh
```

Das Skript importiert die beiden CA-Zertifikate (`ca-gmk.pem` und `ca-gmkc.pem`) mit `keytool` in eine gemeinsame PKCS12-Datei (`gmk-truststore.p12`).

- **Alias `gmk`** – erste Root-CA
- **Alias `gmkc`** – zweite Root-CA (z. B. für eine Sub-CA)
- **Passwort**: `changeit` (Standard für Java-Truststores)
- Am Ende listet das Skript die enthaltenen Zertifikate zur Kontrolle auf.

---

## 2. Kubernetes Secret anlegen

```bash
kubectl create secret generic gmk-truststore \
  --from-file=gmk-truststore.p12
```

Speichert die `gmk-truststore.p12`-Datei als Kubernetes Secret. Das Secret wird anschließend als Volume in Pods eingebunden, damit die Datei zur Laufzeit verfügbar ist.

> Tipp: Das Secret muss im selben Namespace wie das Deployment angelegt werden.

---

## 3. Deployment konfigurieren

Die folgenden Snippets ins Deployment-Manifest einfügen:

```yaml
volumeMounts:
  - name: trust
    mountPath: /opt/trust        # Pfad im Container, unter dem der Truststore liegt

volumes:
  - name: trust
    secret:
      secretName: gmk-truststore # Name des oben erstellten Secrets

env:
  - name: JAVA_TOOL_OPTIONS
    # Teilt der JVM mit, wo der Truststore liegt und wie das Passwort lautet.
    # JAVA_TOOL_OPTIONS wird automatisch von jeder JVM-Instanz im Container ausgewertet.
    value: "-Djavax.net.ssl.trustStore=/opt/trust/gmk-truststore.p12 -Djavax.net.ssl.trustStorePassword=changeit"
```

### Wie es funktioniert

| Schritt | Was passiert |
|---|---|
| Secret als Volume | Kubernetes legt die `gmk-truststore.p12` unter `/opt/trust/` im Container ab. |
| `JAVA_TOOL_OPTIONS` | Die JVM liest die Umgebungsvariable beim Start und verwendet den angegebenen Truststore statt des Standard-Cacerts. |
| TLS-Handshake | Wenn die App eine HTTPS-Verbindung zu einem intern signierten Dienst aufbaut, findet sie die CA im Truststore und vertraut dem Zertifikat. |