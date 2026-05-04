output "object_storage_namespace" {
  description = "Namespace OCI usado pelos buckets"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "bucket_names" {
  description = "Nomes dos buckets medallion criados"
  value       = { for k, b in oci_objectstorage_bucket.medallion : k => b.name }
}

output "vcn_id" {
  description = "OCID da VCN criada"
  value       = module.vcn-agropulse.vcn_id
}

output "public_subnet_id" {
  description = "OCID da subnet pública"
  value       = oci_core_subnet.vcn-agropulse-public-subnet.id
}
