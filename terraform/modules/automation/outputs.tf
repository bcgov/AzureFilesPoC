output "id" {
  description = "The ID of the Automation Account."
  value       = azurerm_automation_account.main.id
}

output "name" {
  description = "The name of the Automation Account."
  value       = azurerm_automation_account.main.name
}
