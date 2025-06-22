# --- terraform/modules/core/resource-group/main.tf ---
#
# This reusable module creates a single Azure Resource Group.

module "poc_resource_group" {
  source = "../../modules/core/resource-group"

  # On the left: The generic input name from the module's variables.tf
  # On the right: The specific variable name from this environment's variables.tf
  
  name     = var.dev_resource_group
  location = var.dev_location
  tags     = var.common_tags
}

