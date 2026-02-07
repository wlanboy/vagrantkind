"""Lokale CA erstellen (ca_dns/create-ca.sh)."""

from pathlib import Path

from helpers import ask_yes_no, run, step


def create_ca(ca_dir: Path) -> None:
    step("Lokale CA erstellen")

    ca_dir.mkdir(parents=True, exist_ok=True)
    ca_key = ca_dir / "ca.key"
    ca_pem = ca_dir / "ca.pem"

    if ca_key.exists() and ca_pem.exists():
        print(f"CA-Dateien existieren bereits in {ca_dir}")
        if not ask_yes_no("  Neu erstellen?", default=False):
            return

    print("Generiere CA-Key (4096 bit)...")
    run(["openssl", "genrsa", "-out", str(ca_key), "4096"])

    print("Generiere CA-Zertifikat (10 Jahre)...")
    run(
        [
            "openssl",
            "req",
            "-x509",
            "-new",
            "-nodes",
            "-key",
            str(ca_key),
            "-sha256",
            "-days",
            "3650",
            "-out",
            str(ca_pem),
            "-subj",
            "/C=DE/ST=Germany/L=LAN/O=Homelab CA/CN=Homelab Test Root CA",
        ]
    )

    print("Installiere CA im System-Trust-Store...")
    run(
        [
            "sudo",
            "cp",
            str(ca_pem),
            "/usr/local/share/ca-certificates/ca-test-lan.crt",
        ]
    )
    run(["sudo", "update-ca-certificates"])

    print(f"CA erstellt in {ca_dir}")
