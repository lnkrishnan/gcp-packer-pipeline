# Packer Template

This template:
- Uses Debian 12 base.
- Creates an image named `gcp-goldenimage-baseline-YYYYMMDD`.
- Adds two partitions (10GiB each) mounted at `/var` and `/tmp`.
- Installs `telnet`, `jq`, `wget`.

Pinned versions:
- Packer ~> 1.14.1
- Google Compute Plugin >=1.2.2, <2.0.0
