# CA und DNS Trust Setup

Dieses Verzeichnis enthält Skripte und Zertifikate zur Einrichtung einer lokalen Zertifizierungsstelle (CA) sowie zur Konfiguration eines benutzerdefinierten DNS-Servers im Homelab-Netzwerk.

Zwei selbstsignierte Root-CA-Zertifikate werden im System-Truststore registriert, damit alle TLS-Zertifikate, die von diesen CAs ausgestellt wurden, als vertrauenswürdig erkannt werden.

---

## Dateien

### `ca-gmk.pem`

Root-CA-Zertifikat für das Homelab-Netzwerk.

| Eigenschaft | Wert |
| --- | --- |
| Subject | `CN=Homelab Root CA, O=Homelab CA, L=LAN, ST=Germany, C=DE` |
| Gültigkeit | 10 Jahre (August 2025 – August 2035) |
| Schlüssel | RSA 4096 Bit |
| Signatur | SHA-256 |
| Typ | Self-signed Root CA |

### `ca-gmkc.pem`

Zweites Root-CA-Zertifikat (SAR-Variante), z.B. für eine separate Zertifikatskette.

| Eigenschaft | Wert |
| --- | --- |
| Subject | `CN=Homelab SAR Root CA, O=Homelab CA, L=LAN, ST=Germany, C=DE` |
| Gültigkeit | 10 Jahre (November 2025 – November 2035) |
| Schlüssel | RSA 4096 Bit |
| Signatur | SHA-256 |
| Typ | Self-signed Root CA |

---

### `create-ca.sh`

Erstellt eine neue lokale CA und installiert das Zertifikat im System-Truststore.

Ablauf:

1. Erstellt Verzeichnis `~/local-ca`
2. Generiert 4096-Bit RSA-Schlüssel (`ca.key`)
3. Erstellt selbstsigniertes Zertifikat (10 Jahre Laufzeit)
4. Kopiert das Zertifikat nach `/usr/local/share/ca-certificates/ca-test-lan.crt`
5. Führt `update-ca-certificates` aus

---

### `setup-ca-trust.sh`

Konfiguriert den systemweiten DNS-Server und installiert beide CA-Zertifikate im Truststore. Erfordert `sudo`.

```bash
./setup-ca-trust.sh [DNS-Server-IP]
# Standard: 192.168.178.91
```

Ablauf:

1. Prüft, ob `ca-gmk.pem` und `ca-gmkc.pem` vorhanden sind
2. Trägt den DNS-Server in `/etc/systemd/resolved.conf` ein (behandelt kommentierte, vorhandene und fehlende Einträge)
3. Startet `systemd-resolved` neu
4. Kopiert beide PEM-Dateien nach `/usr/local/share/ca-certificates/`
5. Führt `update-ca-certificates` aus
