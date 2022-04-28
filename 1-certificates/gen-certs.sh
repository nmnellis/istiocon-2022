#!/bin/bash
echo "deploying cert-manager"

kubectl create namespace cert-manager || true
kubectl create namespace istio-system || true

mkdir ./certs

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.yaml

sleep 10

openssl req -new -newkey rsa:4096 -x509 -sha256 \
        -days 3650 -nodes -out ./certs/root-ca.crt -keyout ./certs/root-ca.key \
        -config 1-certificates/root-ca.conf

kubectl create secret generic root-ca \
  --from-file=tls.key=./certs/root-ca.key \
  --from-file=tls.crt=./certs/root-ca.crt \
  --namespace cert-manager


# wait for cert manager pods
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager
kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager

kubectl apply -f- <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: root-ca
  namespace: cert-manager
spec:
  ca:
    secretName: root-ca
EOF

kubectl apply -f- <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: istio-cacerts
  namespace: cert-manager
spec:
  secretName: istio-cacerts
  duration: 720h # 30d
  renewBefore: 360h # 15d
  commonName: istio.solo.io
  isCA: true
  usages:
    - digital signature
    - key encipherment
    - cert sign
  dnsNames:
    - istio.solo.io
  # Issuer references are always required.
  issuerRef:
    kind: ClusterIssuer
    name: root-ca
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: local-machine-cacerts
  namespace: cert-manager
spec:
  secretName: local-machine-cacerts
  duration: 720h # 30d
  renewBefore: 360h # 15d
  commonName: local-machines.solo.io
  isCA: true
  usages:
    - digital signature
    - key encipherment
    - cert sign
  dnsNames:
    - local-machines.solo.io
  # Issuer references are always required.
  issuerRef:
    kind: ClusterIssuer
    name: root-ca
---
# Create an issuer from the local-machine-ca
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: local-machine-ca
  namespace: cert-manager
spec:
  ca:
    secretName: local-machine-cacerts
EOF

# generate local-machine cert
kubectl apply -f- <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: local-machine-istio-proxy
  namespace: cert-manager
spec:
  secretName: local-machine-istio-proxy
  duration: 720h # 30d
  renewBefore: 360h # 15d
  commonName: envoy-proxy
  isCA: false
  usages:
    - client auth
  uris:
    - spiffe://local-machines.solo.io/ns/local-machines/sa/nicks-local-machine
  # Issuer references are always required.
  issuerRef:
    kind: Issuer
    name: local-machine-ca
EOF

sleep 10

# download the secret in the istio format
kubectl get secret istio-cacerts -n cert-manager -o json | jq '.data."tls.crt"' -r | base64 --decode > ./certs/ca-cert.pem
kubectl get secret istio-cacerts -n cert-manager -o json | jq '.data."tls.key"' -r | base64 --decode > ./certs/ca-key.pem
kubectl get secret istio-cacerts -n cert-manager -o json | jq '.data."ca.crt"' -r | base64 --decode > ./certs/root-cert.pem
kubectl get secret istio-cacerts -n cert-manager -o json | jq '.data."tls.crt"' -r | base64 --decode > ./certs/cert-chain.pem
kubectl get secret istio-cacerts -n cert-manager -o json | jq '.data."ca.crt"' -r | base64 --decode >> ./certs/cert-chain.pem

# create the istio secrets from the download files
kubectl create secret generic cacerts -n istio-system \
      --from-file=./certs/ca-cert.pem \
      --from-file=./certs/ca-key.pem \
      --from-file=./certs/root-cert.pem \
      --from-file=./certs/cert-chain.pem

kubectl get secret local-machine-istio-proxy -n cert-manager -o json | jq '.data."tls.crt"' -r | base64 --decode > ./certs/local-machine-cert.pem
kubectl get secret local-machine-istio-proxy -n cert-manager -o json | jq '.data."tls.key"' -r | base64 --decode > ./certs/local-machine-key.pem
kubectl get secret local-machine-istio-proxy -n cert-manager -o json | jq '.data."ca.crt"' -r | base64 --decode > ./certs/local-machine-ca-cert.pem