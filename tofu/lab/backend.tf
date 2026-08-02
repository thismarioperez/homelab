terraform {
  backend "s3" {
    bucket = "storage-homelab-theforce"
    key    = "tofu-state-lab/terraform.tfstate"
    region = "us-west-002"

    endpoints = {
      s3 = "https://s3.us-west-002.backblazeb2.com"
    }

    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
