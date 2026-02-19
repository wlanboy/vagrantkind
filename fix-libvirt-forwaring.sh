#!/usr/bin/env bash
# fix-libvirt-forwarding.sh
# Stellt sicher, dass Docker das Forwarding für libvirt-Bridges nicht blockiert.
# Unterstützte Bridges: virbr0 (libvirt default), br0 (host bridge)

set -euo pipefail

BRIDGES=("virbr0" "br0")

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Dieses Script muss als root ausgeführt werden." >&2
        exit 1
    fi
}

bridge_exists() {
    local bridge="$1"
    ip link show "$bridge" &>/dev/null
}

fix_forwarding_for_bridge() {
    local bridge="$1"

    echo ">>> Bridge '$bridge' gefunden – setze iptables-Regeln..."

    # FORWARD: Traffic durch die Bridge erlauben (Docker setzt hier oft DROP)
    iptables -I FORWARD -i "$bridge" -o "$bridge" -j ACCEPT
    iptables -I FORWARD -i "$bridge" ! -o "$bridge" -j ACCEPT
    iptables -I FORWARD -o "$bridge" -j ACCEPT

    # Docker blockiert via DOCKER-USER-Chain – dort explizit erlauben
    if iptables -L DOCKER-USER -n &>/dev/null; then
        iptables -I DOCKER-USER -i "$bridge" -j ACCEPT
        iptables -I DOCKER-USER -o "$bridge" -j ACCEPT
        echo "    DOCKER-USER-Regeln für '$bridge' gesetzt."
    else
        echo "    Keine DOCKER-USER-Chain gefunden – übersprungen."
    fi

    # sysctl: Forwarding über die Bridge sicherstellen
    local sysctl_key="net.ipv4.conf.${bridge}.forwarding"
    sysctl -w "${sysctl_key}=1" &>/dev/null && \
        echo "    sysctl ${sysctl_key}=1 gesetzt."

    # Bridge-NF: verhindert, dass iptables Bridge-Traffic filtert (optional, aber hilfreich)
    if [[ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]]; then
        sysctl -w net.bridge.bridge-nf-call-iptables=0 &>/dev/null && \
            echo "    bridge-nf-call-iptables=0 gesetzt (Bridge-Traffic umgeht iptables)."
    fi

    echo "    Fertig für '$bridge'."
}

require_root

echo "=== libvirt/br0 Forwarding Fix ==="
echo ""

fixed=0
for bridge in "${BRIDGES[@]}"; do
    if bridge_exists "$bridge"; then
        fix_forwarding_for_bridge "$bridge"
        echo ""
        ((fixed++))
    else
        echo ">>> Bridge '$bridge' nicht vorhanden – übersprungen."
    fi
done

if [[ $fixed -eq 0 ]]; then
    echo "Keine der erwarteten Bridges gefunden. Nichts zu tun." >&2
    exit 1
fi

echo "=== Alle verfügbaren Bridges wurden konfiguriert (${fixed}/${#BRIDGES[@]}) ==="
