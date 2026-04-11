terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.location
}

variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

variable "taxonomy_display_name" {
  type = string
}

variable "taxonomy_description" {
  type    = string
  default = "Enterprise data classification taxonomy"
}

variable "taxonomy_admin_members" {
  type    = list(string)
  default = []
}

variable "policy_tags" {
  type = map(object({
    display_name = string
    description  = optional(string, "")
    parent_key   = optional(string)
  }))
}
