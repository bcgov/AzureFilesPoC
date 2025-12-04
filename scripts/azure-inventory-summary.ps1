param(
    [string]$InventoryPath = "$PSScriptRoot\azure-inventory",
    [string]$OutputFile = "$PSScriptRoot\azure-inventory-summary.md"
)

Write-Host "Azure Inventory Summary Report" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Output will be saved to: $OutputFile" -ForegroundColor Yellow
Write-Host ""

# Initialize output content
$output = @()
$output += "# Azure Inventory Summary Report"
$output += ""
$output += "**Generated on:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$output += "**Inventory data from:** $InventoryPath"
$output += ""

# Function to parse table data with full column information
function ConvertFrom-TableData {
    param([string]$FilePath)

    if (!(Test-Path $FilePath)) {
        return @()
    }

    $content = Get-Content $FilePath -Raw
    $lines = $content -split "`n" | Where-Object { $_.Trim() -ne "" }

    if ($lines.Count -lt 2) {
        return @()
    }

    # Parse header to get column names
    $headerLine = $lines[0]
    $separatorLine = $lines[1]

    # Extract column positions from separator line
    # Azure CLI tables use "  " (two spaces) as column separators
    $columnPositions = @()
    $parts = $separatorLine -split '  ' | Where-Object { $_.Trim() -ne "" -and $_ -match '^-+$' }

    $currentPos = 0
    foreach ($part in $parts) {
        $startPos = $separatorLine.IndexOf($part, $currentPos)
        if ($startPos -ge 0) {
            $endPos = $startPos + $part.Length - 1
            $columnPositions += @{ Start = $startPos; End = $endPos }
            $currentPos = $endPos + 1
        }
    }

    # Extract column names
    $columnNames = @()
    foreach ($col in $columnPositions) {
        $colName = $headerLine.Substring($col.Start, $col.End - $col.Start + 1).Trim()
        $columnNames += $colName
    }

    # Parse data rows
    $dataRows = @()
    for ($i = 2; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimEnd()
        if ($line -eq "") { continue }

        $rowData = @{}
        for ($j = 0; $j -lt $columnNames.Count; $j++) {
            $col = $columnPositions[$j]
            if ($col.Start -lt $line.Length) {
                $endPos = [Math]::Min($col.End, $line.Length - 1)
                $valueLength = $endPos - $col.Start + 1
                if ($valueLength -gt 0) {
                    $value = $line.Substring($col.Start, $valueLength).Trim()
                    $rowData[$columnNames[$j]] = $value
                } else {
                    $rowData[$columnNames[$j]] = ""
                }
            } else {
                $rowData[$columnNames[$j]] = ""
            }
        }
        $dataRows += $rowData
    }

    return $dataRows
}

# Initialize summary object
$summary = [ordered]@{
    "Virtual Machines" = @()
    "Virtual Networks" = @()
    "Subnets" = @()
    "Network Security Groups" = @()
    "Bastion Hosts" = @()
    "Public IP Addresses" = @()
    "Storage Accounts" = @()
    "Key Vaults" = @()
    "Log Analytics Workspaces" = @()
    "Azure AI/ML Services" = @()
    "Azure OpenAI" = @()
    "Managed Identities" = @()
    "Private Endpoints" = @()
    "Private DNS Zones" = @()
    "Role Assignments" = @()
}

# Parse Virtual Machines
$vmData = ConvertFrom-TableData "$InventoryPath\all-vms.txt"
$summary["Virtual Machines"] = $vmData

# Parse Virtual Networks
$vnetData = ConvertFrom-TableData "$InventoryPath\all-vnets.txt"
$summary["Virtual Networks"] = $vnetData

# Parse Storage Accounts
$storageData = ConvertFrom-TableData "$InventoryPath\all-storage-accounts.txt"
$summary["Storage Accounts"] = $storageData

# Parse Public IP Addresses
$publicIpData = ConvertFrom-TableData "$InventoryPath\all-public-ips.txt"
$summary["Public IP Addresses"] = $publicIpData

# Parse Log Analytics Workspaces
$logAnalyticsData = ConvertFrom-TableData "$InventoryPath\all-log-analytics-workspaces.txt"
$summary["Log Analytics Workspaces"] = $logAnalyticsData

# Parse AI/ML Workspaces
$mlData = ConvertFrom-TableData "$InventoryPath\all-ml-workspaces.txt"
$summary["Azure AI/ML Services"] = $mlData

# Parse Azure OpenAI accounts
$openaiData = ConvertFrom-TableData "$InventoryPath\all-openai-accounts.txt"
$summary["Azure OpenAI"] = $openaiData

# Parse Bastion Hosts
$bastionData = ConvertFrom-TableData "$InventoryPath\all-bastions.txt"
$summary["Bastion Hosts"] = $bastionData

# Parse Private DNS Zones
$dnsData = ConvertFrom-TableData "$InventoryPath\all-private-dns-zones.txt"
$summary["Private DNS Zones"] = $dnsData

# Parse NSGs
$nsgData = ConvertFrom-TableData "$InventoryPath\all-nsgs.txt"
$summary["Network Security Groups"] = $nsgData

# Parse Key Vaults
$keyVaultData = ConvertFrom-TableData "$InventoryPath\all-keyvaults.txt"
$summary["Key Vaults"] = $keyVaultData

# Parse Managed Identities
$managedIdentityData = ConvertFrom-TableData "$InventoryPath\all-user-assigned-identities.txt"
$summary["Managed Identities"] = $managedIdentityData

# Parse Subnets from subnet files
$subnetFiles = Get-ChildItem "$InventoryPath\subnets-*.txt"
foreach ($file in $subnetFiles) {
    $subnetData = ConvertFrom-TableData $file.FullName
    $summary["Subnets"] += $subnetData
}

# Parse Role Assignments
$roleData = ConvertFrom-TableData "$InventoryPath\role-assignments.txt"
$summary["Role Assignments"] = $roleData

# Parse Private Endpoints from all-resources.txt
$allResourcesData = ConvertFrom-TableData "$InventoryPath\all-resources.txt"
$privateEndpoints = @()
foreach ($resource in $allResourcesData) {
    if ($resource.Type -match "Microsoft.Network/privateEndpoints") {
        $privateEndpoints += $resource
    }
}
$summary["Private Endpoints"] = $privateEndpoints

# Display the summary and write to file
foreach ($category in $summary.Keys) {
    $items = $summary[$category]
    if ($items.Count -gt 0) {
        # Create Markdown table
        $tableRows = @()

        foreach ($item in $items) {
            if ($item -is [hashtable]) {
                # Build table row based on available columns
                $rowData = @{}

                # Always include Name if available
                if ($item.ContainsKey("Name") -and $item["Name"]) {
                    $rowData["Name"] = $item["Name"]
                }

                # Add other relevant columns
                $relevantColumns = @("ResourceGroup", "Location", "Type", "NumSubnets", "Prefixes", "Sku", "Kind", "ClientId", "PrincipalId", "TenantId")
                foreach ($col in $relevantColumns) {
                    if ($item.ContainsKey($col) -and $item[$col] -and $item[$col] -ne "N/A") {
                        $rowData[$col] = $item[$col]
                    }
                }

                if ($rowData.Count -gt 0) {
                    $tableRows += $rowData
                }
            }
        }

        if ($tableRows.Count -gt 0) {
            $sectionHeader = "## $category ($($tableRows.Count) items)"
            Write-Host $sectionHeader -ForegroundColor Yellow
            $output += $sectionHeader
            $output += ""

            # Get all unique column names from the data
            $allColumns = @()
            foreach ($row in $tableRows) {
                $allColumns += $row.Keys
            }
            $uniqueColumns = $allColumns | Select-Object -Unique | Sort-Object

            # Create table header
            $headerRow = "| " + ($uniqueColumns -join " | ") + " |"
            $separatorRow = "|" + (("---|" * $uniqueColumns.Count).TrimEnd('|'))

            $output += $headerRow
            $output += $separatorRow

            # Create table data rows
            foreach ($row in $tableRows) {
                $rowValues = @()
                foreach ($col in $uniqueColumns) {
                    $value = $row[$col]
                    if ($null -eq $value -or $value -eq "") {
                        $value = "-"
                    }
                    $rowValues += $value
                }
                $dataRow = "| " + ($rowValues -join " | ") + " |"
                $output += $dataRow
            }

            # Display a summary line for console
            Write-Host "  - Table with $($tableRows.Count) items created" -ForegroundColor White
        } else {
            Write-Host "  - No valid data found" -ForegroundColor Gray
            $output += "*No valid data found*"
        }

        $output += ""
    }
}

# Write output to file
$output | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "`nInventory Summary Complete!" -ForegroundColor Green
Write-Host "Markdown report saved to: $OutputFile" -ForegroundColor Green
Write-Host "Raw data available in: $InventoryPath" -ForegroundColor Gray
