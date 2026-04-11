#!/usr/bin/env python3
"""
Caddy reverse proxy setup script.
Starts Caddy as a Docker container with Let's Encrypt SSL and configures
subdomains for existing Docker containers.

If DUCK_DNS_TOKEN is defined in .env, a custom Caddy image with the
caddy-dns/duckdns plugin is built and DNS-01 challenge is used.
"""

import json
import os
import subprocess
import sys


CADDY_CONTAINER_NAME = "caddy"
CADDY_IMAGE_DEFAULT = "caddy:latest"
CADDY_IMAGE_DUCKDNS = "caddy-duckdns:local"
CADDY_CONFIG_DIR = os.path.expanduser("~/.caddy")
CADDYFILE_PATH = os.path.join(CADDY_CONFIG_DIR, "Caddyfile")
CADDY_DATA_DIR = os.path.join(CADDY_CONFIG_DIR, "data")
CADDY_CONFIG_STORAGE = os.path.join(CADDY_CONFIG_DIR, "config")
CADDY_DOCKERFILE_PATH = os.path.join(CADDY_CONFIG_DIR, "Dockerfile.duckdns")

DUCKDNS_DOCKERFILE = """\
FROM caddy:builder AS builder
RUN xcaddy build --with github.com/caddy-dns/duckdns

FROM caddy:latest
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
"""


def run(cmd, capture=True, check=True):
    result = subprocess.run(
        cmd, shell=True, capture_output=capture, text=True, check=False
    )
    if check and result.returncode != 0:
        print(f"Error running: {cmd}")
        print(result.stderr.strip())
        sys.exit(1)
    return result


def docker_available():
    result = run("docker info", capture=True, check=False)
    return result.returncode == 0


def get_running_containers():
    result = run(
        'docker ps --format \'{"id":"{{.ID}}","name":"{{.Names}}","ports":"{{.Ports}}"}\' ',
        check=False,
    )
    containers = []
    for line in result.stdout.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            containers.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return containers


def parse_exposed_ports(ports_str):
    """Extract unique container ports from Docker's port mapping string."""
    ports = set()
    if not ports_str:
        return ports
    for mapping in ports_str.split(","):
        mapping = mapping.strip()
        # formats: "0.0.0.0:8080->80/tcp"  or  "80/tcp"
        if "->" in mapping:
            container_part = mapping.split("->")[1]
            port = container_part.split("/")[0].strip()
        else:
            port = mapping.split("/")[0].strip()
        if port.isdigit():
            ports.add(int(port))
    return ports


def get_container_ip(container_id):
    result = run(
        f"docker inspect --format '{{{{.NetworkSettings.IPAddress}}}}' {container_id}",
        check=False,
    )
    ip = result.stdout.strip()
    if ip:
        return ip
    # Try first network
    result = run(
        f"docker inspect --format '{{{{range .NetworkSettings.Networks}}}}{{{{.IPAddress}}}}{{{{end}}}}' {container_id}",
        check=False,
    )
    ips = result.stdout.strip().split()
    return ips[0] if ips else None


def ask(prompt, default=None):
    suffix = f" [{default}]" if default else ""
    try:
        value = input(f"{prompt}{suffix}: ").strip()
    except (KeyboardInterrupt, EOFError):
        print()
        sys.exit(0)
    return value if value else default


def ask_yes_no(prompt, default="y"):
    hint = "Y/n" if default == "y" else "y/N"
    try:
        value = input(f"{prompt} [{hint}]: ").strip().lower()
    except (KeyboardInterrupt, EOFError):
        print()
        sys.exit(0)
    if not value:
        return default == "y"
    return value in ("y", "yes")


def load_env_file(path=".env"):
    """Load key=value pairs from a .env file, return as dict."""
    env = {}
    if not os.path.isfile(path):
        return env
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def build_duckdns_image():
    os.makedirs(CADDY_CONFIG_DIR, exist_ok=True)
    with open(CADDY_DOCKERFILE_PATH, "w") as f:
        f.write(DUCKDNS_DOCKERFILE)
    print(f"Building custom Caddy image '{CADDY_IMAGE_DUCKDNS}' with DuckDNS plugin...")
    print("(This may take a few minutes on first run.)")
    result = run(
        f"docker build -t {CADDY_IMAGE_DUCKDNS} -f {CADDY_DOCKERFILE_PATH} {CADDY_CONFIG_DIR}",
        capture=False,
        check=False,
    )
    if result.returncode != 0:
        print("Failed to build DuckDNS Caddy image. Aborting.")
        sys.exit(1)
    print(f"Image '{CADDY_IMAGE_DUCKDNS}' built successfully.\n")


def stop_existing_caddy():
    result = run(
        f"docker inspect {CADDY_CONTAINER_NAME}", capture=True, check=False
    )
    if result.returncode == 0:
        print(f"Stopping existing '{CADDY_CONTAINER_NAME}' container...")
        run(f"docker rm -f {CADDY_CONTAINER_NAME}", check=False)


def write_caddyfile(domain, email, routes, duck_dns_token=None):
    os.makedirs(CADDY_CONFIG_DIR, exist_ok=True)
    os.makedirs(CADDY_DATA_DIR, exist_ok=True)
    os.makedirs(CADDY_CONFIG_STORAGE, exist_ok=True)

    lines = []
    lines.append("# Caddyfile generated by caddy.py")
    lines.append(f"# Domain: {domain}")
    lines.append("")
    lines.append("{")
    lines.append(f"    email {email}")
    if duck_dns_token:
        lines.append("    acme_dns duckdns {env.DUCK_DNS_TOKEN}")
    lines.append("}")
    lines.append("")

    for route in routes:
        subdomain = route["subdomain"]
        target_ip = route["ip"]
        port = route["port"]
        lines.append(f"{subdomain}.{domain} {{")
        lines.append(f"    reverse_proxy {target_ip}:{port}")
        lines.append("}")
        lines.append("")

    content = "\n".join(lines)
    with open(CADDYFILE_PATH, "w") as f:
        f.write(content)
    print(f"Caddyfile written to {CADDYFILE_PATH}")
    return content


def start_caddy(duck_dns_token=None):
    image = CADDY_IMAGE_DUCKDNS if duck_dns_token else CADDY_IMAGE_DEFAULT
    env_flag = f"-e DUCK_DNS_TOKEN={duck_dns_token} " if duck_dns_token else ""
    cmd = (
        f"docker run -d "
        f"--name {CADDY_CONTAINER_NAME} "
        f"--restart unless-stopped "
        f"-p 80:80 "
        f"-p 443:443 "
        f"-p 443:443/udp "
        f"{env_flag}"
        f"-v {CADDYFILE_PATH}:/etc/caddy/Caddyfile "
        f"-v {CADDY_DATA_DIR}:/data "
        f"-v {CADDY_CONFIG_STORAGE}:/config "
        f"--network host "
        f"{image}"
    )
    print("Starting Caddy container...")
    run(cmd, capture=False)
    print(f"Caddy started as '{CADDY_CONTAINER_NAME}'.")


def main():
    print("=== Caddy Docker Setup ===\n")

    if not docker_available():
        print("Docker is not running or not accessible. Aborting.")
        sys.exit(1)

    env = load_env_file(".env")
    duck_dns_token = env.get("DUCK_DNS_TOKEN")
    if duck_dns_token:
        print(f"DuckDNS token found in .env — DNS-01 challenge will be used.\n")
    else:
        print("No DUCK_DNS_TOKEN in .env — HTTP-01 challenge will be used.\n")

    domain = ask("Enter your VPS domain (e.g. homelab.duckdns.org)")
    if not domain:
        print("No domain provided. Aborting.")
        sys.exit(1)

    email = ask("Enter your email address for Let's Encrypt")
    if not email or "@" not in email:
        print("Invalid email address. Aborting.")
        sys.exit(1)

    if duck_dns_token:
        build_duckdns_image()

    print("\nScanning running Docker containers...\n")
    containers = get_running_containers()

    # Filter out caddy itself
    containers = [c for c in containers if c["name"] != CADDY_CONTAINER_NAME]

    if not containers:
        print("No running containers found (other than Caddy).")

    routes = []
    for container in containers:
        name = container["name"]
        ports = parse_exposed_ports(container["ports"])

        if not ports:
            print(f"  [{name}] No exposed ports — skipping.")
            continue

        ports_sorted = sorted(ports)
        print(f"\n  Container: {name}")
        print(f"  Exposed ports: {', '.join(str(p) for p in ports_sorted)}")

        if not ask_yes_no(f"  Add '{name}.{domain}' to Caddy config?"):
            continue

        if len(ports_sorted) == 1:
            chosen_port = ports_sorted[0]
            print(f"  Using port {chosen_port}.")
        else:
            port_input = ask(
                f"  Which port to proxy? {ports_sorted}",
                default=str(ports_sorted[0]),
            )
            if not port_input or not port_input.isdigit():
                print("  Invalid port, skipping container.")
                continue
            chosen_port = int(port_input)

        ip = get_container_ip(container["id"])
        if not ip:
            print(f"  Could not determine IP for '{name}', skipping.")
            continue

        routes.append(
            {
                "subdomain": name,
                "ip": ip,
                "port": chosen_port,
            }
        )
        print(f"  Added: {name}.{domain} -> {ip}:{chosen_port}")

    if not routes:
        print("\nNo containers selected. Caddyfile will have no routes.")
        if not ask_yes_no("Continue anyway (Caddy will start but serve nothing)?", default="n"):
            sys.exit(0)

    print("\n--- Caddyfile Preview ---")
    content = write_caddyfile(domain, email, routes, duck_dns_token=duck_dns_token)
    print(content)
    print("-------------------------\n")

    stop_existing_caddy()
    start_caddy(duck_dns_token=duck_dns_token)

    print("\nDone! Caddy is running.")
    print("Let's Encrypt will issue certificates automatically for:")
    for route in routes:
        print(f"  https://{route['subdomain']}.{domain}")
    if duck_dns_token:
        print("\nUsing DNS-01 challenge via DuckDNS — no inbound port 80 required.")
    else:
        print(
            "\nNote: Make sure ports 80 and 443 are open in your firewall "
            "and your DNS records point to this server."
        )


if __name__ == "__main__":
    main()
