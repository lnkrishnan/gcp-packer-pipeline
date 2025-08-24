# GCP Cloud Build + Packer Golden Image Pipeline

This guide provides a complete setup for building golden images (GMIs) on Google Cloud Platform using **Cloud Build Private Pools**, **Packer**, and offline plugin staging.  
It includes lifecycle automation, version pinning, and customizations for software installation and extra disks.

---

## 1. Step-by-Step Setup Instructions

### Prerequisites
- A GCP Project with billing enabled
- Cloud Build API, Compute Engine API, and Cloud Storage API enabled
- `gcloud` CLI installed and authenticated
- A Cloud Build service account (default or custom)

### Step 1: Prepare a GCS Bucket for Offline Plugins
```bash
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME=${PROJECT_ID}-packer-plugins

gsutil mb -p $PROJECT_ID gs://$BUCKET_NAME/
```

Run the provided script to download the Packer binary + plugins and upload them:
```bash
cd scripts/
./fetch-plugins.sh $BUCKET_NAME
```

This will place Packer and its required `googlecompute` plugin in `gs://$BUCKET_NAME/plugins/`.

### Step 2: Create a Cloud Build Private Pool
```bash
gcloud builds worker-pools create packer-pool   --region=us-central1   --worker-count=2   --peered-network=projects/$PROJECT_ID/global/networks/default
```

⚠ Ensure that **Private Google Access** is enabled on the subnet used by the worker pool.

### Step 3: Grant IAM Roles to Cloud Build SA
Bind required roles to the Cloud Build service account:

```bash
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
CLOUDBUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID   --member="serviceAccount:${CLOUDBUILD_SA}"   --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID   --member="serviceAccount:${CLOUDBUILD_SA}"   --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding $PROJECT_ID   --member="serviceAccount:${CLOUDBUILD_SA}"   --role="roles/storage.objectViewer"
```

### Step 4: Trigger a Build
Manual run:
```bash
gcloud builds submit --config=cloudbuild.yaml . --region=us-central1
```

GitHub trigger:
```bash
gcloud builds triggers create github   --name="packer-goldenimage-build"   --repo-name="<YOUR_REPO_NAME>"   --repo-owner="<YOUR_ORG_OR_USER>"   --branch-pattern="^main$"   --build-config="cloudbuild.yaml"   --region=us-central1
```

---

## 2. Updated Packer Template (ubuntu-gce.pkr.hcl)

```hcl
packer {
  required_version = ">= 1.10.0"
  required_plugins {
    googlecompute = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

locals {
  timestamp = formatdate("YYYYMMDD", timestamp())
  image_name = "gcp-goldenimage-baseline-${local.timestamp}"
  image_family = "gcp-goldenimage-baseline"
}

source "googlecompute" "ubuntu" {
  project_id         = var.project_id
  source_image_family = "ubuntu-2004-lts"
  zone               = "${var.region}-a"
  image_name         = local.image_name
  image_family       = local.image_family

  # Add extra 10GB disks for /var and /tmp
  disk_size          = 20
  additional_disks {
    disk_size = 10
  }
  additional_disks {
    disk_size = 10
  }
}

build {
  sources = ["source.googlecompute.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y telnet jq wget",
      "sudo mkfs.ext4 /dev/sdb && sudo mkdir -p /var && sudo mount /dev/sdb /var",
      "sudo mkfs.ext4 /dev/sdc && sudo mkdir -p /tmp && sudo mount /dev/sdc /tmp"
    ]
  }
}
```

---

## 3. Version Pinning

- **Packer version** pinned in `cloudbuild.yaml` by referencing a specific binary (e.g., `1.10.0`).  
- **Plugins** pinned via `required_plugins` in `pkr.hcl` and staged offline in GCS.  
- Ensures reproducible builds and prevents breakage from upstream updates.

---

## 4. Lifecycle Management

Use a scheduled Cloud Function or Scheduler job to manage old images.

Deprecate images older than 3 months:
```bash
gcloud compute images deprecate IMAGE_NAME   --state=DEPRECATED   --replacement=projects/$PROJECT_ID/global/images/NEW_IMAGE
```

Obsolete + delete after 6 months:
```bash
gcloud compute images deprecate IMAGE_NAME --state=OBSOLETE
gcloud compute images delete IMAGE_NAME --quiet
```

A cleanup script can be automated to run daily/weekly.

---

## 5. Folder Structure

```
.
├── cloudbuild.yaml
├── packer/
│   └── ubuntu-gce.pkr.hcl
├── scripts/
│   └── fetch-plugins.sh
├── iam/
│   ├── iam-policy.json
│   └── README.md
└── README.md
```

---

## 6. References

- [HashiCorp Packer Docs](https://developer.hashicorp.com/packer)
- [Google Compute Builder Plugin](https://developer.hashicorp.com/packer/plugins/builders/googlecompute)
- [Cloud Build Private Pools](https://cloud.google.com/build/docs/private-pools)
- [GCP Image Lifecycle](https://cloud.google.com/compute/docs/images/create-delete-deprecate-private-images)

---

✅ With this setup, you can build fully offline golden images in GCP with lifecycle automation and reproducibility.
