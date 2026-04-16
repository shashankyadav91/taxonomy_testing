locals {
  root_tags = {
    for k, v in var.policy_tags : k => v
    if try(v.parent_key, null) == null
  }

  level_1_tags = {
    for k, v in var.policy_tags : k => v
    if try(v.parent_key, null) != null && try(var.policy_tags[v.parent_key].parent_key, null) == null
  }

  level_2_tags = {
    for k, v in var.policy_tags : k => v
    if try(v.parent_key, null) != null && try(var.policy_tags[v.parent_key].parent_key, null) != null
  }
}

resource "google_data_catalog_taxonomy" "this" {
  project                = var.project_id
  region                 = var.location
  display_name           = var.taxonomy_display_name
  description            = var.taxonomy_description
  activated_policy_types = var.activated_policy_types
}

resource "google_data_catalog_taxonomy_iam_binding" "admins" {
  count    = length(var.taxonomy_admin_members) > 0 ? 1 : 0
  taxonomy = google_data_catalog_taxonomy.this.id
  role     = "roles/datacatalog.policyTagAdmin"
  members  = var.taxonomy_admin_members
}

resource "google_data_catalog_policy_tag" "root" {
  for_each = local.root_tags

  taxonomy     = google_data_catalog_taxonomy.this.name
  display_name = each.value.display_name
  description  = try(each.value.description, "")
}

resource "google_data_catalog_policy_tag" "level_1" {
  for_each = local.level_1_tags

  taxonomy     = google_data_catalog_taxonomy.this.name
  display_name = each.value.display_name
  description  = try(each.value.description, "")

  parent_policy_tag = google_data_catalog_policy_tag.root[each.value.parent_key].name
}

resource "google_data_catalog_policy_tag" "level_2" {
  for_each = local.level_2_tags

  taxonomy     = google_data_catalog_taxonomy.this.name
  display_name = each.value.display_name
  description  = try(each.value.description, "")

  parent_policy_tag = google_data_catalog_policy_tag.level_1[each.value.parent_key].name
}

# ---------------------------------------------------------------------------
# BigQuery Data Policies — column-level masking rules
#
# Rules are applied ONLY to the two tags that carry structured masking
# requirements per the data classification standard:
#
#   government_id      → SHA256 hash (authorised group: joins still work,
#                         raw value never exposed)
#                        + ALWAYS_NULL (all other users)
#
#   financial_personal → LAST_FOUR_CHARACTERS (e.g. credit card last 4 digits
#                         for authorised finance group)
#                        + ALWAYS_NULL (all other users)
#
# All remaining tags rely solely on fine-grained access control enforced
# by the policy tag itself — no additional masking rule.
#
# Design: instead of one resource block per tag, two for_each resource blocks
# cover all tags:
#   - google_bigquery_datapolicy_data_policy.transform_masking  (SHA256 / LAST_FOUR_CHARACTERS)
#   - google_bigquery_datapolicy_data_policy.null_masking       (ALWAYS_NULL)
# Adding a new tag only requires a new entry in the local maps below.
# ---------------------------------------------------------------------------

locals {
  # Tags that need a transform mask (SHA256 or LAST_FOUR_CHARACTERS).
  # Add new entries here whenever a tag requires a non-null mask.
  transform_masking_configs = {
    for k, cfg in {
      government_id = {
        expression = "SHA256"
        suffix     = "hash"
        members    = var.government_id_hash_members
      }
      financial_personal = {
        expression = "LAST_FOUR_CHARACTERS"
        suffix     = "last4"
        members    = var.financial_personal_last4_members
      }
    } : k => cfg
    if length(cfg.members) > 0
  }

  # Tags that need an ALWAYS_NULL mask.
  # Add new entries here whenever a tag requires full redaction for a group.
  null_masking_configs = {
    for k, cfg in {
      government_id = {
        members = var.government_id_null_members
      }
      financial_personal = {
        members = var.financial_personal_null_members
      }
    } : k => cfg
    if length(cfg.members) > 0
  }
}

# ---------- Transform masking (SHA256 / LAST_FOUR_CHARACTERS) --------------
# One resource block covers all tags. policy_tag resolves from level_1 by key.

resource "google_bigquery_datapolicy_data_policy" "transform_masking" {
  for_each         = local.transform_masking_configs
  project          = var.project_id
  location         = var.location
  data_policy_id   = "${each.key}_${each.value.suffix}"
  policy_tag       = google_data_catalog_policy_tag.level_1[each.key].name
  data_policy_type = "DATA_MASKING_POLICY"

  data_masking_policy {
    predefined_expression = each.value.expression
  }
}

resource "google_bigquery_datapolicy_data_policy_iam_binding" "transform_masking_binding" {
  for_each       = local.transform_masking_configs
  project        = var.project_id
  location       = var.location
  data_policy_id = google_bigquery_datapolicy_data_policy.transform_masking[each.key].data_policy_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  members        = each.value.members
}

# ---------- Null masking (ALWAYS_NULL) -------------------------------------
# One resource block covers all tags requiring full redaction.

resource "google_bigquery_datapolicy_data_policy" "null_masking" {
  for_each         = local.null_masking_configs
  project          = var.project_id
  location         = var.location
  data_policy_id   = "${each.key}_null"
  policy_tag       = google_data_catalog_policy_tag.level_1[each.key].name
  data_policy_type = "DATA_MASKING_POLICY"

  data_masking_policy {
    predefined_expression = "ALWAYS_NULL"
  }
}

resource "google_bigquery_datapolicy_data_policy_iam_binding" "null_masking_binding" {
  for_each       = local.null_masking_configs
  project        = var.project_id
  location       = var.location
  data_policy_id = google_bigquery_datapolicy_data_policy.null_masking[each.key].data_policy_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  members        = each.value.members
}
