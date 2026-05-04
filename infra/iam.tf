resource "oci_identity_dynamic_group" "agropulse_dynamic_group" {
  compartment_id = var.tenancy_ocid
  description    = var.dynamic_group_description
  matching_rule  = "ALL {instance.compartment.id = '${var.compartment_id}'}"
  name           = var.dynamic_group_name
}

locals {
  policy_statements = [
    "Allow dynamic-group ${var.dynamic_group_name} to manage object-family in compartment id ${var.compartment_id} where target.bucket.name = /${var.bucket_prefix}-*/",
    "Allow dynamic-group ${var.dynamic_group_name} to read objectstorage-namespaces in tenancy"
  ]
}

resource "oci_identity_policy" "agropulse_policy" {
  compartment_id = var.tenancy_ocid
  description    = var.policy_description
  name           = var.policy_name
  statements     = local.policy_statements
}
