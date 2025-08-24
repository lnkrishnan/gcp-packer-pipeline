# GCP Golden Image Pipeline

This repository builds a **Google Compute Engine Golden Image** (GMI) using **Packer** inside **Cloud Build Private Pool**.

## Features
- Offline Packer + googlecompute plugin (staged in GCS).
- Installs `telnet`, `jq`, `wget`.
- Partitions `/var` and `/tmp` as separate 10GiB filesystems (inside single boot disk).
- Image name: `gcp-goldenimage-baseline-YYYYMMDD`.
- Image family: `gcp-goldenimage-baseline`.
- Lifecycle: images deprecated after 3 months, obsolete + deleted after 6 months.

## Setup
1. Create a GCS bucket and upload packer + plugin using `scripts/fetch-plugins.sh`.
2. Create a Cloud Build Private Pool with Private Google Access.
3. Set IAM on the Cloud Build service account (compute.admin, storage.objectViewer).
4. Trigger Cloud Build with `cloudbuild.yaml`.

See `packer/README.md` for Packer template details, and `scripts/README.md` for offline plugin fetch instructions.

## Creating a Cloud Build Trigger

After pushing this repo to GitHub (or Cloud Source Repositories), create a Cloud Build trigger to run the pipeline automatically.

Example for GitHub repo (replace placeholders with your values):

```bash
gcloud builds triggers create github   --name="packer-goldenimage-build"   --repo-name="<YOUR_REPO_NAME>"   --repo-owner="<YOUR_GITHUB_USERNAME_OR_ORG>"   --branch-pattern="^main$"   --build-config="cloudbuild.yaml"   --region="<REGION_OF_YOUR_POOL>"
```

For Cloud Source Repositories:

```bash
gcloud builds triggers create cloud-source-repositories   --name="packer-goldenimage-build"   --repo="<YOUR_REPO_NAME>"   --branch-pattern="^main$"   --build-config="cloudbuild.yaml"   --region="<REGION_OF_YOUR_POOL>"
```

You can also trigger manually:

```bash
gcloud builds submit --config=cloudbuild.yaml .
```
