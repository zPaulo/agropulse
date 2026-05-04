data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

resource "oci_objectstorage_bucket" "medallion" {
  for_each = toset(var.medallion_layers)

  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "${var.bucket_prefix}-${each.key}"
  versioning     = "Enabled"

  access_type  = "NoPublicAccess"
  storage_tier = "Standard"
}

resource "oci_limits_quota" "agropulse_storage_limit" {
  compartment_id = var.tenancy_ocid
  name           = "agropulse-storage-cap"
  description    = "Limita o uso de Object Storage do AgroPulse ao Always Free"
  statements = [
    "set object-storage quota storage-bytes to 21474836480 in compartment ${var.compartment_name}"
  ]
}

resource "oci_objectstorage_object_lifecycle_policy" "bronze_lifecycle" {
  namespace = data.oci_objectstorage_namespace.ns.namespace
  bucket    = oci_objectstorage_bucket.medallion["bronze"].name

  rules {
    name        = "delete-old-versions"
    action      = "DELETE"
    target      = "previous-object-versions"
    is_enabled  = true
    time_amount = 30
    time_unit   = "DAYS"
  }

  rules {
    name        = "archive-old-objects"
    action      = "ARCHIVE"
    target      = "objects"
    is_enabled  = true
    time_amount = 90
    time_unit   = "DAYS"
  }
}


resource "oci_budget_budget" "agropulse_zero_budget" {
  compartment_id = var.tenancy_ocid
  amount         = 1
  reset_period   = "MONTHLY"
  display_name   = "agropulse-zero-budget"
  target_type    = "COMPARTMENT"
  targets        = [var.compartment_id]
}

resource "oci_budget_alert_rule" "agropulse_alert" {
  budget_id      = oci_budget_budget.agropulse_zero_budget.id
  type           = "ACTUAL"
  threshold      = 1
  threshold_type = "PERCENTAGE"
  recipients     = "paulo.arruda@masterboi.com.br"
  message        = "AgroPulse gastou algo em USD. Verifique o console."
  display_name   = "agropulse-zero-spend-alert"
}
