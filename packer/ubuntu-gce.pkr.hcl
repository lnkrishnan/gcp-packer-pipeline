packer {
  required_version = "~> 1.14.1"

  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.2.2, < 2.0.0"
    }
  }
}

variable "project_id"        { type = string }
variable "region"            { type = string default = "asia-southeast1" }
variable "zone"              { type = string default = "asia-southeast1-b" }
variable "network"           { type = string default = "default" }
variable "subnetwork"        { type = string default = null }
variable "use_internal_ip"   { type = bool   default = true }
variable "source_image_family" { type = string default = "debian-12" }
variable "disk_size_gb"      { type = number default = 40 } # room for root + 10G /var + 10G /tmp

locals {
  yyyymmdd  = formatdate("YYYYMMDD", timestamp())
  image_name = "gcp-goldenimage-baseline-${local.yyyymmdd}"
}

source "googlecompute" "base" {
  project_id           = var.project_id
  zone                 = var.zone
  network              = var.network
  subnetwork           = var.subnetwork
  use_internal_ip      = var.use_internal_ip

  source_image_family  = var.source_image_family
  machine_type         = "e2-standard-2"
  disk_type            = "pd-standard"
  disk_size            = var.disk_size_gb
  ssh_username         = "packer"
  image_name           = local.image_name
  image_family         = "gcp-goldenimage-baseline"

  # Faster/safer builds
  omit_external_ip     = true
  tags                 = ["packer-build"]
  metadata = {
    block-project-ssh-keys = "true"
  }

  # Enable GCE guest environment scripts to finish properly
  preemptible = false
}

build {
  name    = "gmi-baseline"
  sources = ["source.googlecompute.base"]

  # 3) install telnet, jq, wget (+ hardening for mounts)
  provisioner "shell" {
    execute_command = "sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      # Detect package manager
      "set -euo pipefail",
      "if command -v apt-get >/dev/null 2>&1; then PM=apt; elif command -v dnf >/dev/null 2>&1; then PM=dnf; elif command -v yum >/dev/null 2>&1; then PM=yum; else echo 'No supported package manager found' >&2; exit 1; fi",

      # Refresh + install
      "if [ \"$PM\" = apt ]; then apt-get update -y && apt-get install -y --no-install-recommends telnet jq wget cloud-guest-utils parted; fi",
      "if [ \"$PM\" = yum ]; then yum install -y telnet jq wget cloud-utils-growpart parted; fi",
      "if [ \"$PM\" = dnf ]; then dnf install -y telnet jq wget cloud-utils-growpart parted; fi",

      # 2) Create two new 10GiB partitions on the boot disk and mount them at /var and /tmp.
      # Assume boot disk is /dev/sda on Debian/Ubuntu GCE images (or /dev/vda on some distros).
      "DISK=\"/dev/sda\"; [ -b $DISK ] || DISK=\"/dev/vda\"; [ -b $DISK ] || { echo 'Cannot find boot disk' >&2; exit 1; }",

      # Get total size in sectors, create two 10G partitions at the end using parted
      "parted -s $DISK mklabel gpt || true",
      "parted -s $DISK unit GiB print",
      # Find current last sector using parted and create partitions aligned from end.
      # Simpler approach: shrink root if it consumes full disk; on GCE images root is typically a single partition.
      # We'll: 1) shrink filesystem, 2) shrink partition, 3) create p2 and p3 for /var and /tmp.
      # Root is usually $DISK\"1\"
      "ROOT_PART=${DISK}1",
      "echo 'Shrinking root to free 22GiB headroom...' ",
      "e2fsck -f $ROOT_PART || true",
      "resize2fs $ROOT_PART 18G",    # keep ~18GiB for OS; adjust with disk_size_gb above if needed
      "parted -s $DISK resizepart 1 18GiB",
      "parted -s $DISK mkpart primary ext4 18GiB 28GiB",
      "parted -s $DISK mkpart primary ext4 28GiB 38GiB",

      "udevadm settle",
      "mkfs.ext4 -F ${DISK}2",
      "mkfs.ext4 -F ${DISK}3",

      # Mount points with safe options
      "mkdir -p /var /tmp",
      "mount ${DISK}2 /mnt && rsync -aXS --delete /var/ /mnt/ && umount /mnt",
      "mount ${DISK}3 /mnt && rsync -aXS --delete /tmp/ /mnt/ && umount /mnt",
      "echo \"${DISK}2 /var ext4 defaults,nodev,nosuid 0 2\" >> /etc/fstab",
      "echo \"${DISK}3 /tmp ext4 defaults,nodev,nosuid,noexec 0 2\" >> /etc/fstab",

      # Create & mount now
      "mount -a",

      # Clean apt caches / logs to minimize image size
      "if [ \"$PM\" = apt ]; then apt-get clean; fi",
      "rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*"
    ]
  }

  # 4) Image name format handled by local.image_name (YYYYMMDD)
  # 7) Lifecycle cleanup is handled in cloudbuild step after build

  post-processor "shell-local" {
    # no-op; lifecycle is driven by Cloud Build
    inline = ["echo Build finished for ${local.image_name}"]
  }
}
