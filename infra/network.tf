# Source from https://registry.terraform.io/modules/oracle-terraform-modules/vcn/oci/
module "vcn-agropulse" {
  compartment_id          = var.compartment_id
  source                  = "oracle-terraform-modules/vcn/oci"
  version                 = "3.6.0"
  region                  = var.region
  vcn_name                = var.vcn_name
  create_internet_gateway = true
  create_service_gateway  = true

  vcn_dns_label = "agropulse"
}

# Source from https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_subnet
resource "oci_core_subnet" "vcn-agropulse-public-subnet" {
  compartment_id = var.compartment_id
  vcn_id         = module.vcn-agropulse.vcn_id
  cidr_block     = "10.0.0.0/24"

  route_table_id             = module.vcn-agropulse.ig_route_id
  display_name               = var.display_name_public_subnet
  prohibit_public_ip_on_vnic = false
}
