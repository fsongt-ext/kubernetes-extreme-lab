##############################################################################
# DNS Module Variables
##############################################################################

variable "domain_name" {
  description = "The domain name for the DNS zone (e.g., example.com)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "a_records" {
  description = "Map of A records to create"
  type = map(object({
    ttl     = number
    records = list(string)
  }))
  default = {}
}

variable "cname_records" {
  description = "Map of CNAME records to create"
  type = map(object({
    ttl    = number
    record = string
  }))
  default = {}
}

variable "txt_records" {
  description = "Map of TXT records to create"
  type = map(object({
    ttl     = number
    records = list(string)
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to DNS resources"
  type        = map(string)
  default     = {}
}
