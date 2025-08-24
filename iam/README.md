# IAM Policy for Cloud Build Service Account

This sample IAM policy grants the minimum required permissions for the Cloud Build
service account to execute Packer builds and manage images.

## Roles Granted
- `roles/compute.admin` – allows creating temporary build VMs and images.
- `roles/iam.serviceAccountUser` – required for Cloud Build to impersonate the worker pool service account.
- `roles/storage.objectViewer` – read access to the GCS bucket containing packer and plugin binaries.

## Usage

1. Replace `YOUR_CLOUDBUILD_SA@YOUR_PROJECT_ID.iam.gserviceaccount.com` with your actual Cloud Build service account email.
2. Apply with:

```bash
gcloud projects set-iam-policy YOUR_PROJECT_ID iam-policy.json
```

Or, bind roles individually with:

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID   --member="serviceAccount:YOUR_CLOUDBUILD_SA@YOUR_PROJECT_ID.iam.gserviceaccount.com"   --role="roles/compute.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID   --member="serviceAccount:YOUR_CLOUDBUILD_SA@YOUR_PROJECT_ID.iam.gserviceaccount.com"   --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID   --member="serviceAccount:YOUR_CLOUDBUILD_SA@YOUR_PROJECT_ID.iam.gserviceaccount.com"   --role="roles/storage.objectViewer"
```
