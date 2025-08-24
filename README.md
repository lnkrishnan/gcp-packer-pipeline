
# GCP Golden Image Pipeline

  

This repository builds a **Google Compute Engine Golden Image** (GMI) using **Packer** inside **Cloud Build Private Pool**.

  

## Requirements

- Code based on https://github.com/derrickchwong/cloud-build-private-pool-packer
- provide clear step-by-step instructions on how to set this up in GCP so I can trigger a packer build to create my custom GMI
- update the packer build file to add 2 extra disks each 10 GB in size, one for /var mount and another for /tmp.
- update the packer build file to install telnet, jq and wget software
- after the packer phase is complete, the final GMI should have the name format "gcp-goldenimage-baseline-YYYYMMDD"
- perform version pinning for packer and plugin versions
- download the gcp packer plugin locally, which can be uploaded to GCP storage, for it to be referred during the packer trigger phase. Our cloud run execution does not have access to the internet so we need to provide all files required for packer to run without needing access to the internet
- Lifecycle: implement image naming/versioning as outlined earlier, and also deprecation/obsolescence policies, and automated cleanup of old images. set deprecation age as 3 months, and obsolescense age as 6 months

### Quick note on “2 extra disks for /var and /tmp”:

> GCE images can only capture a single boot disk. You can’t bake additional data disks into a GCE image
> itself; those are attached later when you create a VM or instance template. The closest image-time
> equivalent is to create separate partitions on the boot disk and mount them at /var and /tmp. That’s what
> is implemented below (10 GiB each, persisted via /etc/fstab).

  

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
gcloud  builds  triggers  create  github  --name="packer-goldenimage-build"  --repo-name="<YOUR_REPO_NAME>"  --repo-owner="<YOUR_GITHUB_USERNAME_OR_ORG>"  --branch-pattern="^main$"  --build-config="cloudbuild.yaml"  --region="<REGION_OF_YOUR_POOL>"
```

For Cloud Source Repositories:

```bash
gcloud  builds  triggers  create  cloud-source-repositories  --name="packer-goldenimage-build"  --repo="<YOUR_REPO_NAME>"  --branch-pattern="^main$"  --build-config="cloudbuild.yaml"  --region="<REGION_OF_YOUR_POOL>"
```

You can also trigger manually:

```bash
gcloud  builds  submit  --config=cloudbuild.yaml .
```