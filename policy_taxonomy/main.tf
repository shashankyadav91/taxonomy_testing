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
