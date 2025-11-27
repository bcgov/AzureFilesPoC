variable "resource_group_name" {
  description = "The name of the resource group for the firewall resource(s)."
  type        = string
}

variable "location" {
  description = "The Azure region for the firewall resource(s)."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to the resource(s)."
  type        = map(string)
  default     = {}
}
