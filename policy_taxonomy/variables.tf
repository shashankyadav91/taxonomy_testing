variable "project_id" {
  type        = string
  description = "Governance project where the taxonomy is created"
}

variable "location" {
  type        = string
  description = "BigQuery/Data Catalog location, for example us or europe-west2"
}

variable "taxonomy_display_name" {
  type        = string
  description = "Display name of the taxonomy"
}

variable "taxonomy_description" {
  type        = string
  description = "Description of the taxonomy"
  default     = "Enterprise data classification taxonomy for BigQuery columns"
}

variable "activated_policy_types" {
  type        = list(string)
  description = "Activated policy types for the taxonomy"
  default     = ["FINE_GRAINED_ACCESS_CONTROL"]
}

variable "taxonomy_admin_members" {
  type        = list(string)
  description = "IAM members who administer the taxonomy"
  default     = []
}

variable "policy_tags" {
  description = <<EOT
Map of policy tags to create.

Example:
policy_tags = {
  public = {
    display_name = "public"
    description  = "Public data"
    parent_key   = null
  }
  personal_data = {
    display_name = "personal_data"
    description  = "Personal data root"
    parent_key   = null
  }
  basic_contact = {
    display_name = "basic_contact"
    description  = "Name, email, phone"
    parent_key   = "personal_data"
  }
}
EOT

  type = map(object({
    display_name = string
    description  = optional(string, "")
    parent_key   = optional(string)
  }))
}
