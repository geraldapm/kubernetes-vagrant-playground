#!/bin/bash
#
# Deploys the Kubernetes dashboard when enabled in settings.yaml

set -euxo pipefail

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/headlamp/main/kubernetes-headlamp.yaml


cat << EOF | kubectl apply -f -
kind: Service
apiVersion: v1
metadata:
  name: headlamp-nodeport
  namespace: kube-system
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 4466
      nodePort: 30009
  selector:
    k8s-app: headlamp
EOF

