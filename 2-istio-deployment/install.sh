#!/bin/sh
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

kubectl create namespace istio-system

# Install Istio CRDS
helm install istio-base istio/base \
  -n istio-system \
  --version 1.12.6

# Install istiod
helm install istiod istio/istiod \
  -f 1-istio-deployment/istiod-values.yaml \
  --namespace istio-system \
  --version 1.12.6

# Install Istio Eastwest Gateway
helm install istio-eastwestgateway istio/gateway \
  -f 1-istio-deployment/eastwest-gateway-values.yaml \
  --namespace istio-system \
  --version 1.12.6