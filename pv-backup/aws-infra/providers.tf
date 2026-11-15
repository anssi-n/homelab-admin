terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
  }

  backend "s3" {
    bucket       = "udemy-terraform-remote-backend-anyman"
    key          = "udemy-terraform-backends/pv-backup/state.tfstate"
    use_lockfile = true
    region       = "eu-north-1"
  }
}

provider "aws" {
  region = var.region
}
