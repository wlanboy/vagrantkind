# Zentrale Versionsverwaltung fuer alle Tools
# Werte werden aus ../versions.sh geladen (Single Source of Truth)

import re
import subprocess
from pathlib import Path

_VERSIONS_SH = Path(__file__).parent.parent / "versions.sh"


def _load_versions() -> dict[str, str]:
    """Laedt Versionen aus versions.sh per bash -c 'source ... && echo VAR=...'."""
    keys = ["HELM_VERSION", "KIND_VERSION", "ISTIO_VERSION", "K9S_VERSION", "ARGOCD_VERSION"]
    script = f'source {_VERSIONS_SH}; ' + '; '.join(f'echo {k}="${{{k}}}"' for k in keys)
    result = subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        check=True,
    )
    out: dict[str, str] = {}
    for line in result.stdout.splitlines():
        m = re.match(r"^(\w+)=(.+)$", line.strip())
        if m:
            out[m.group(1)] = m.group(2)
    return out


_v = _load_versions()

HELM_VERSION = _v["HELM_VERSION"]
KIND_VERSION = _v["KIND_VERSION"]
ISTIO_VERSION = _v["ISTIO_VERSION"]
K9S_VERSION = _v["K9S_VERSION"]
ARGOCD_VERSION = _v["ARGOCD_VERSION"]

DEFAULT_IP_LINUX = "172.18.100.10"
DEFAULT_IP_WSL = "172.18.0.10"
