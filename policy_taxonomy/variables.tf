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

# ---------------------------------------------------------------------------
# Masking policy membership variables
# Only government_id and financial_personal have structured masking rules.
# All other tags rely on fine-grained access control via the policy tag.
# ---------------------------------------------------------------------------

variable "government_id_hash_members" {
  description = "Members who see hashed government_id values — allows joins without exposing raw SSN/passport"
  type        = list(string)
  default     = []
}

variable "government_id_null_members" {
  description = "Members who receive NULL for government_id columns (all other users)"
  type        = list(string)
  default     = []
}

# financial_personal (credit card, bank account): two distinct views
variable "financial_personal_last4_members" {
  description = "Members who see the last 4 digits of financial_personal values (e.g., credit card)"
  type        = list(string)
  default     = []
}

variable "financial_personal_null_members" {
  description = "Members who receive NULL for financial_personal columns"
  type        = list(string)
  default     = []
}
