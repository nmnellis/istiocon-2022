#!/bin/sh

gcloud container clusters create "istiocon-2022-demo" \
  --project="$GCP_PROJECT" \
  --cluster-version="1.21.9-gke.1002" \
  --zone="$GCP_ZONE" \
  --machine-type="e2-standard-2" \
  --num-nodes="2" \
  --no-enable-legacy-authorization