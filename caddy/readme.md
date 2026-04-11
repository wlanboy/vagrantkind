# Caddy Reverse Proxy Setup

Startet [Caddy](https://caddyserver.com/) als Docker-Container mit automatischen Let's Encrypt SSL-Zertifikaten.
Bestehende Docker-Container werden interaktiv als Subdomains konfiguriert.

## Voraussetzungen

- Docker läuft auf dem System
- Python 3.8+
- Ports 80 und 443 sind in der Firewall offen (bei HTTP-01 Challenge)
- DNS-Eintrag der Domain zeigt auf den Server

## Verwendung

```bash
python3 caddy.py
```

Das Script fragt interaktiv:

1. **Domain** des VPS (z.B. `homelab.duckdns.org`)
2. **E-Mail-Adresse** für Let's Encrypt
3. Für jeden laufenden Docker-Container: ob er als Subdomain aufgenommen werden soll

### Beispiel

Container `nginx` läuft mit Port `8080` → wird erreichbar unter `https://nginx.homelab.duckdns.org`

## DuckDNS DNS-Challenge (optional)

Wenn in einer `.env`-Datei im gleichen Verzeichnis ein DuckDNS-Token hinterlegt ist,
wird automatisch die **DNS-01 Challenge** statt der HTTP-01 Challenge verwendet.
Vorteil: Port 80 muss **nicht** erreichbar sein.

**.env anlegen:**

```env
DUCK_DNS_TOKEN=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Das Script erkennt den Token automatisch und baut beim ersten Aufruf ein Custom Caddy-Image
mit dem [caddy-dns/duckdns](https://github.com/caddy-dns/duckdns) Plugin:

```
caddy:builder  →  xcaddy build --with github.com/caddy-dns/duckdns  →  caddy-duckdns:local
```

Ab dem zweiten Aufruf nutzt Docker den Build-Cache — der Start ist dann genauso schnell wie ohne DuckDNS.

## Caddyfile

Das generierte Caddyfile wird unter `~/.caddy/Caddyfile` gespeichert.

**Ohne DuckDNS:**
```
{
    email user@example.com
}

nginx.homelab.duckdns.org {
    reverse_proxy 172.17.0.2:8080
}
```

**Mit DuckDNS:**
```
{
    email user@example.com
    acme_dns duckdns {env.DUCK_DNS_TOKEN}
}

nginx.homelab.duckdns.org {
    reverse_proxy 172.17.0.2:8080
}
```

## Verzeichnisstruktur

```
~/.caddy/
├── Caddyfile            # generierte Konfiguration
├── Dockerfile.duckdns   # nur bei DuckDNS-Modus
├── data/                # Let's Encrypt Zertifikate (persistent)
└── config/              # Caddy interne Konfiguration (persistent)
```

## Docker-Container

| Name | Wert |
|------|------|
| Container-Name | `caddy` |
| Image (Standard) | `caddy:latest` |
| Image (DuckDNS) | `caddy-duckdns:local` |
| Ports | `80`, `443`, `443/udp` |
| Netzwerk | `host` |
| Restart | `unless-stopped` |
