provider "azurerm" {
  features {}
}

provider "github" {
  owner = local.github.organization
}


terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    github = {
      source  = "hashicorp/github"
      version = "~> 6.0"
    }
  }

  # Backend configuration for state management
  # Get this from the output of tfstate-bucket/main.tf
  backend "azurerm" {
    resource_group_name  = "extremelab-tfstate"
    storage_account_name = "extremelabtfstate91"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}



