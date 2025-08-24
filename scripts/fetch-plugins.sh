#!/usr/bin/env bash
set -euo pipefail

BUCKET="${1:?Usage: $0 <bucket-name>}"
PACKER_VERSION="${2:-1.14.1}"
GCP_PLUGIN_VERSION="${3:-1.2.2}"

curl -fL "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip" -o "packer_${PACKER_VERSION}_linux_amd64.zip"
curl -fL "https://releases.hashicorp.com/packer-plugin-googlecompute/${GCP_PLUGIN_VERSION}/packer-plugin-googlecompute_v${GCP_PLUGIN_VERSION}_x5.0_linux_amd64.zip" -o "packer-plugin-googlecompute_v${GCP_PLUGIN_VERSION}_x5.0_linux_amd64.zip"

gsutil cp "packer_${PACKER_VERSION}_linux_amd64.zip" "gs://${BUCKET}/packer/"
gsutil cp "packer-plugin-googlecompute_v${GCP_PLUGIN_VERSION}_x5.0_linux_amd64.zip" "gs://${BUCKET}/plugins/"

echo "Uploaded to gs://${BUCKET}/packer and gs://${BUCKET}/plugins"
