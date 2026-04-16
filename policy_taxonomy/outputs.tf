locals {
  policy_tag_ids = merge(
    { for k, v in google_data_catalog_policy_tag.root : k => v.name },
    { for k, v in google_data_catalog_policy_tag.level_1 : k => v.name },
    { for k, v in google_data_catalog_policy_tag.level_2 : k => v.name }
  )

  policy_tag_paths = {
    for tag_key, tag in var.policy_tags :
    (
      try(tag.parent_key, null) == null ? tag.display_name :
      try(var.policy_tags[tag.parent_key].parent_key, null) == null ? "${var.policy_tags[tag.parent_key].display_name}.${tag.display_name}" :
      "${var.policy_tags[var.policy_tags[tag.parent_key].parent_key].display_name}.${var.policy_tags[tag.parent_key].display_name}.${tag.display_name}"
    ) => lookup(local.policy_tag_ids, tag_key, null)
  }
}

output "taxonomy_id" {
  value = google_data_catalog_taxonomy.this.id
}

output "taxonomy_name" {
  value = google_data_catalog_taxonomy.this.name
}

output "policy_tag_names" {
  description = "Map of human-readable paths to policy tag resource names"
  value       = local.policy_tag_paths
}

output "data_policy_ids" {
  description = "Map of data masking policy IDs — only government_id and financial_personal carry masking rules"
  value = {
    government_id_hash       = try(google_bigquery_datapolicy_data_policy.transform_masking["government_id"].id, null)
    government_id_null       = try(google_bigquery_datapolicy_data_policy.null_masking["government_id"].id, null)
    financial_personal_last4 = try(google_bigquery_datapolicy_data_policy.transform_masking["financial_personal"].id, null)
    financial_personal_null  = try(google_bigquery_datapolicy_data_policy.null_masking["financial_personal"].id, null)
  }
}
