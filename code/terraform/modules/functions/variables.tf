variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "keyvault_id" {
  type = string
}

variable "keyvault_uri" {
  type = string
}

variable "keyvault_name" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "storage_account_key" {
  type      = string
  sensitive = true
}

variable "sites_to_monitor" {
  type = list(string)
}
