output "id" {
  description = "The ID of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.main.id
}

output "name" {
  description = "The name of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.main.name
}
