"""Demo-Service Deployment (nginx + Istio Gateway/VirtualService)."""

from helpers import (
    ask_yes_no,
    ensure_namespace,
    kubectl_apply_stdin,
    run,
)


def _echo_service_yaml(hostname: str) -> str:
    return f"""\
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: demo-app
  name: demo-app
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: demo
        image: nginx:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          protocol: TCP
        resources: {{}}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {{}}
      terminationGracePeriodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: demo
spec:
  selector:
    app: demo-app
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: demo-gateway
  namespace: demo
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "demo.{hostname}"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: demo-service
  namespace: demo
spec:
  hosts:
  - "demo.{hostname}"
  exportTo:
  - "."
  - istio-ingress
  - istio-system
  gateways:
  - demo-gateway
  - mesh
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: demo-app.demo.svc.cluster.local
        port:
          number: 80
"""


def deploy_demo_service(hostname: str) -> None:
    # Pruefen ob Demo-Service bereits laeuft
    result = run(
        ["kubectl", "-n", "demo", "get", "deployment", "demo-app"],
        check=False, capture=True, quiet=True,
    )
    if result.returncode == 0:
        print("Demo-Service laeuft bereits.")
        if not ask_yes_no("  Trotzdem neu deployen/aktualisieren?", default=False):
            print("  Ueberspringe Demo-Service.\n")
            return

    ensure_namespace("demo")

    print("Aktiviere Istio Injection fuer 'demo' Namespace...")
    run(["kubectl", "label", "namespace", "demo", "istio-injection=enabled", "--overwrite"])

    print("Deploye Demo Service...")
    kubectl_apply_stdin(_echo_service_yaml(hostname))

    print("Warte auf Demo-Service Pods...")
    run(
        [
            "kubectl",
            "-n",
            "demo",
            "wait",
            "--for=condition=Ready",
            "--all",
            "pods",
            "--timeout=120s",
        ]
    )
