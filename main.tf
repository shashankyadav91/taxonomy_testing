locals {
  project_id = "addv1-tdata-datalake"
  env_name   = "addv1"

  # Service Accounts
  cloudrun_sa = "serviceAccount:addv1-tdata-cloudrun@${local.project_id}.iam.gserviceaccount.com"
  gitlab_sa   = "serviceAccount:addv1-tdata-gitlab-cicd@${local.project_id}.iam.gserviceaccount.com"
  hvr_sa      = "serviceAccount:addv1-tdata-hvr-sa@${local.project_id}.iam.gserviceaccount.com"
  fivetran_sa = "serviceAccount:addv1-tdata-fivetran-sa@${local.project_id}.iam.gserviceaccount.com"

  # LDAP Groups — add group strings here once AD group requirements are confirmed.
  # Example: "group:it-dataengineering-eng@autozone.com"
  government_id_hash_members       = []
  government_id_null_members       = []
  financial_personal_last4_members = []
  financial_personal_null_members  = []

  # Policy taxonomy configuration
  taxonomy_location      = "us"
  taxonomy_display_name  = "enterprise_data_classification"
  taxonomy_description   = "Enterprise policy tag taxonomy for BigQuery column-level security"
  taxonomy_admin_members = [local.dataengineering_eng_grp]

  policy_tags = {
    internal = {
      display_name = "internal"
      description  = "Internal non-public data"
    }

    strategic = {
      display_name = "strategic"
      description  = "Strategic business data — plans, pricing, and forward-looking information"
    }

    private-restricted = {
      display_name = "private-restricted"
      description  = "Highly restricted data requiring explicit access controls — regulated and payment data"
    }

    personal_data = {
      display_name = "personal_data"
      description  = "Root for personal data types"
    }

    basic_contact = {
      display_name = "basic_contact"
      description  = "Name, email, phone, address"
      parent_key   = "personal_data"
    }

    employee_hr = {
      display_name = "employee_hr"
      description  = "Compensation, performance, employee relations"
      parent_key   = "personal_data"
    }

    financial_personal = {
      display_name = "financial_personal"
      description  = "Bank account, payment instrument, tax data"
      parent_key   = "personal_data"
    }

    government_id = {
      display_name = "government_id"
      description  = "National ID, passport, tax ID"
      parent_key   = "personal_data"
    }

    health_sensitive = {
      display_name = "health_sensitive"
      description  = "Health-related sensitive data"
      parent_key   = "personal_data"
    }

    business_sensitive = {
      display_name = "business_sensitive"
      description  = "Sensitive business information"
      parent_key   = "strategic"
    }

    pricing = {
      display_name = "pricing"
      description  = "Pricing and margin data"
      parent_key   = "business_sensitive"
    }

    contracts = {
      display_name = "contracts"
      description  = "Commercial and supplier contracts"
      parent_key   = "business_sensitive"
    }

    forecast = {
      display_name = "forecast"
      description  = "Forecasts and forward-looking planning data"
      parent_key   = "business_sensitive"
    }

    regulated = {
      display_name = "regulated"
      description  = "Regulated data classes — column-level controls for payment and identity data"
      parent_key   = "private-restricted"
    }

    pci = {
      display_name = "pci"
      description  = "Payment card related data"
      parent_key   = "regulated"
    }
  }
}

# service accounts
module "service-account" {
  source       = "gitlab.com/autozone/service-account/gcp"
  version      = "1.0.6"
  project_id   = local.project_id
  names        = [regex(":(.*)@", local.cloudrun_sa)[0], regex(":(.*)@", local.gitlab_sa)[0], regex(":(.*)@", local.hvr_sa)[0], regex(":(.*)@", local.fivetran_sa)[0]]
  generate_keys = true
}

# service account impersonation
data "google_iam_policy" "saUser" {
  binding {
    role = "roles/iam.serviceAccountUser"
    members = [
      local.gitlab_sa
    ]
  }
}

resource "google_service_account_iam_policy" "saUser-account-iam" {
  service_account_id = "projects/${local.project_id}/serviceAccounts/${split(":", local.cloudrun_sa)[1]}"
  policy_data        = data.google_iam_policy.saUser.policy_data
}

# BigQuery policy tagging and taxonomy
module "enterprise_policy_taxonomy" {
  source = "./policy_taxonomy"

  project_id             = local.project_id
  location               = local.taxonomy_location
  taxonomy_display_name  = local.taxonomy_display_name
  taxonomy_description   = local.taxonomy_description
  taxonomy_admin_members = local.taxonomy_admin_members
  policy_tags            = local.policy_tags

  # Masking policy memberships
  # government_id: engineers can join on hashed SSN; all others get NULL
  government_id_hash_members = local.government_id_hash_members
  government_id_null_members = local.government_id_null_members

  # financial_personal: last 4 digits for authorized finance group; null for everyone else
  financial_personal_last4_members = local.financial_personal_last4_members
  financial_personal_null_members  = local.financial_personal_null_members
}

output "taxonomy_id" {
  description = "ID of the Data Catalog taxonomy for BigQuery policy tags"
  value       = module.enterprise_policy_taxonomy.taxonomy_id
}

output "taxonomy_name" {
  description = "Fully qualified taxonomy name"
  value       = module.enterprise_policy_taxonomy.taxonomy_name
}

output "policy_tag_names" {
  description = "Map of policy tag display paths to Data Catalog policy tag names"
  value       = module.enterprise_policy_taxonomy.policy_tag_names
}

output "data_policy_ids" {
  description = "Map of all data masking policy IDs created for this project"
  value       = module.enterprise_policy_taxonomy.data_policy_ids
}
