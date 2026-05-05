variable "tenancy_ocid" {
  type        = string
  description = "OCID da tenancy (conta raiz) na OCI"
}

variable "user_ocid" {
  type        = string
  description = "OCID do usuário com permissões para provisionar recursos"
}

variable "fingerprint" {
  type        = string
  description = "Fingerprint da chave de API associada ao usuário"
}

variable "private_key_path" {
  type        = string
  description = "Caminho para o arquivo da chave privada (PEM) usada na autenticação da API"
}

variable "region" {
  type        = string
  description = "Região da OCI onde os recursos serão provisionados (ex: sa-saopaulo-1)"
}

variable "compartment_id" {
  type        = string
  description = "OCID do compartimento onde os recursos serão criados"
}

variable "vcn_name" {
  type        = string
  description = "Nome para a Rede Virtual"
}

variable "display_name_public_subnet" {
  type        = string
  description = "Nome de exibição da subnet pública"
}

variable "bucket_prefix" {
  type        = string
  description = "Prefixo aplicado ao nome de cada bucket (ex: agropulse, gera agropulse-bronze)"
}

variable "medallion_layers" {
  type        = list(string)
  description = "Camadas da arquitetura medallion que viram buckets"
  default     = ["bronze", "silver", "gold"]
}

variable "dynamic_group_name" {
  type        = string
  description = "Nome do dynamic group que agrupa as instâncias do projeto"
}

variable "dynamic_group_description" {
  type        = string
  description = "Descrição do dynamic group exibida no console OCI"
}

variable "policy_name" {
  type        = string
  description = "Nome da policy que concede permissões ao dynamic group"
}

variable "policy_description" {
  type        = string
  description = "Descrição da policy exibida no console OCI"
}
