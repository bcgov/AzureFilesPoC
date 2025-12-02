# Filename: scripts/bicep/teardown-all.ps1
# Master Teardown Orchestration Script
# This script tears down all Azure AI Foundry Landing Zone resources in reverse deployment order
#
# TEARDOWN ORDER: Phase 5 → 4 → 3 → 2 → 1 (reverse of deployment)
#
# Features:
# - Confirmation prompts per phase
# - Parallel teardown within phases where safe
# - Comprehensive error handling and logging
# - Idempotent (skips missing resources)
# - Progress tracking and status reporting

param(
    [switch]$Force,           # Skip all confirmation prompts
    [switch]$ContinueOnError, # Continue with next phase even if current phase fails
    [string]$LogFile = "teardown-all-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Initialize logging
$scriptStartTime = Get-Date
$logPath = Join-Path $PSScriptRoot $LogFile

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logPath -Value $logMessage
}

function Write-PhaseHeader {
    param([string]$PhaseName, [string]$Description)
    $header = "`n" + "=" * 60
    $header += "`n$PhaseName"
    $header += "`n" + "=" * 60
    Write-Log $header
    Write-Log $Description
}

function Invoke-TeardownScript {
    param(
        [string]$ScriptName,
        [string]$Description,
        [switch]$Required = $true
    )

    $scriptPath = Join-Path $PSScriptRoot $ScriptName

    if (-not (Test-Path $scriptPath)) {
        if ($Required) {
            Write-Log "ERROR: Required script '$ScriptName' not found at $scriptPath" "ERROR"
            return $false
        } else {
            Write-Log "Optional script '$ScriptName' not found, skipping" "WARN"
            return $true
        }
    }

    Write-Log "Executing: $ScriptName - $Description"

    try {
        $startTime = Get-Date
        if ($Force) {
            & $scriptPath -Force
        } else {
            & $scriptPath
        }
        $exitCode = $LASTEXITCODE
        $duration = (Get-Date) - $startTime

        if ($exitCode -eq 0) {
            Write-Log "SUCCESS: $ScriptName completed in $($duration.TotalSeconds.ToString("F1"))s" "SUCCESS"
            return $true
        } else {
            Write-Log "FAILED: $ScriptName exited with code $exitCode after $($duration.TotalSeconds.ToString("F1"))s" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "EXCEPTION: $ScriptName failed with error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Confirm-PhaseTeardown {
    param([string]$PhaseName, [string[]]$Scripts)

    if ($Force) {
        Write-Log "Force mode enabled, skipping confirmation for $PhaseName"
        return $true
    }

    Write-Host ""
    Write-Host "⚠️  PHASE $PhaseName TEARDOWN ⚠️" -ForegroundColor Red
    Write-Host "The following scripts will be executed:" -ForegroundColor Yellow
    foreach ($script in $Scripts) {
        Write-Host "  - $script" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "This will PERMANENTLY DELETE all resources in this phase!" -ForegroundColor Red
    Write-Host "This action cannot be undone." -ForegroundColor Red
    Write-Host ""

    $confirmation = Read-Host "Type 'yes' to proceed with $PhaseName teardown"
    return ($confirmation -eq 'yes')
}

# Main script execution
Write-Log "=========================================="
Write-Log "AZURE AI FOUNDRY LANDING ZONE - MASTER TEARDOWN"
Write-Log "=========================================="
Write-Log "Started at: $scriptStartTime"
Write-Log "Log file: $logPath"
Write-Log "Force mode: $Force"
Write-Log "Continue on error: $ContinueOnError"
Write-Log ""

# Track overall success
$overallSuccess = $true
$phasesCompleted = 0

# ==========================================
# PHASE 5: Private Connectivity Teardown
# ==========================================
Write-PhaseHeader "PHASE 5: Private Connectivity Teardown" "Removing all private endpoints (Storage, Key Vault, Foundry)"

$phase5Scripts = @(
    "teardown-private-endpoints.ps1"
)

if (Confirm-PhaseTeardown "5 (Private Connectivity)" $phase5Scripts) {
    $phaseSuccess = $true
    foreach ($script in $phase5Scripts) {
        $result = Invoke-TeardownScript $script "Remove Private Endpoints"
        if (-not $result) { $phaseSuccess = $false }
    }

    if ($phaseSuccess) {
        Write-Log "PHASE 5 COMPLETED SUCCESSFULLY" "SUCCESS"
        $phasesCompleted++
    } else {
        Write-Log "PHASE 5 COMPLETED WITH ERRORS" "ERROR"
        $overallSuccess = $false
        if (-not $ContinueOnError) {
            Write-Log "Stopping teardown due to errors. Use -ContinueOnError to proceed anyway." "ERROR"
            exit 1
        }
    }
} else {
    Write-Log "PHASE 5 SKIPPED by user" "WARN"
}

# ==========================================
# PHASE 4: AI Services Teardown
# ==========================================
Write-PhaseHeader "PHASE 4: AI Services Teardown" "Removing Azure AI Foundry workspaces (Project first, then Hub)"

$phase4Scripts = @(
    "teardown-foundry-project.ps1",
    "teardown-foundry.ps1"
)

if (Confirm-PhaseTeardown "4 (AI Services)" $phase4Scripts) {
    $phaseSuccess = $true
    foreach ($script in $phase4Scripts) {
        $description = if ($script -eq "teardown-foundry-project.ps1") { "Remove Foundry Project" } else { "Remove Foundry Hub" }
        $result = Invoke-TeardownScript $script $description
        if (-not $result) { $phaseSuccess = $false }
    }

    if ($phaseSuccess) {
        Write-Log "PHASE 4 COMPLETED SUCCESSFULLY" "SUCCESS"
        $phasesCompleted++
    } else {
        Write-Log "PHASE 4 COMPLETED WITH ERRORS" "ERROR"
        $overallSuccess = $false
        if (-not $ContinueOnError) {
            Write-Log "Stopping teardown due to errors. Use -ContinueOnError to proceed anyway." "ERROR"
            exit 1
        }
    }
} else {
    Write-Log "PHASE 4 SKIPPED by user" "WARN"
}

# ==========================================
# PHASE 3: Compute Resources Teardown
# ==========================================
Write-PhaseHeader "PHASE 3: Compute Resources Teardown" "Removing VM and Bastion (VM first, then Bastion)"

$phase3Scripts = @(
    "teardown-vm-lz.ps1",
    "teardown-bastion.ps1"
)

if (Confirm-PhaseTeardown "3 (Compute)" $phase3Scripts) {
    $phaseSuccess = $true
    foreach ($script in $phase3Scripts) {
        $description = if ($script -eq "teardown-vm-lz.ps1") { "Remove VM and associated resources" } else { "Remove Bastion Host" }
        $result = Invoke-TeardownScript $script $description
        if (-not $result) { $phaseSuccess = $false }
    }

    if ($phaseSuccess) {
        Write-Log "PHASE 3 COMPLETED SUCCESSFULLY" "SUCCESS"
        $phasesCompleted++
    } else {
        Write-Log "PHASE 3 COMPLETED WITH ERRORS" "ERROR"
        $overallSuccess = $false
        if (-not $ContinueOnError) {
            Write-Log "Stopping teardown due to errors. Use -ContinueOnError to proceed anyway." "ERROR"
            exit 1
        }
    }
} else {
    Write-Log "PHASE 3 SKIPPED by user" "WARN"
}

# ==========================================
# PHASE 2: Storage & Security Teardown
# ==========================================
Write-PhaseHeader "PHASE 2: Storage & Security Teardown" "Removing storage, security, and monitoring resources"

$phase2Scripts = @(
    "teardown-law.ps1",
    "teardown-uami.ps1",
    "teardown-keyvault.ps1",
    "teardown-storage.ps1"
)

if (Confirm-PhaseTeardown "2 (Storage & Security)" $phase2Scripts) {
    $phaseSuccess = $true
    foreach ($script in $phase2Scripts) {
        $description = switch ($script) {
            "teardown-law.ps1" { "Remove Log Analytics Workspace" }
            "teardown-uami.ps1" { "Remove User Assigned Managed Identity" }
            "teardown-keyvault.ps1" { "Remove Key Vault" }
            "teardown-storage.ps1" { "Remove Storage Account" }
        }
        $result = Invoke-TeardownScript $script $description
        if (-not $result) { $phaseSuccess = $false }
    }

    if ($phaseSuccess) {
        Write-Log "PHASE 2 COMPLETED SUCCESSFULLY" "SUCCESS"
        $phasesCompleted++
    } else {
        Write-Log "PHASE 2 COMPLETED WITH ERRORS" "ERROR"
        $overallSuccess = $false
        if (-not $ContinueOnError) {
            Write-Log "Stopping teardown due to errors. Use -ContinueOnError to proceed anyway." "ERROR"
            exit 1
        }
    }
} else {
    Write-Log "PHASE 2 SKIPPED by user" "WARN"
}

# ==========================================
# PHASE 1: Foundation Teardown
# ==========================================
Write-PhaseHeader "PHASE 1: Foundation Teardown" "Removing network security groups and subnets"

$phase1Scripts = @(
    "teardown-subnet-pe.ps1",
    "teardown-subnet-bastion.ps1",
    "teardown-subnet-vm.ps1",
    "teardown-nsgs.ps1"
)

if (Confirm-PhaseTeardown "1 (Foundation)" $phase1Scripts) {
    $phaseSuccess = $true
    foreach ($script in $phase1Scripts) {
        $description = switch ($script) {
            "teardown-subnet-pe.ps1" { "Remove Private Endpoints subnet" }
            "teardown-subnet-bastion.ps1" { "Remove Bastion subnet" }
            "teardown-subnet-vm.ps1" { "Remove VM subnet" }
            "teardown-nsgs.ps1" { "Remove all Network Security Groups" }
        }
        $result = Invoke-TeardownScript $script $description
        if (-not $result) { $phaseSuccess = $false }
    }

    if ($phaseSuccess) {
        Write-Log "PHASE 1 COMPLETED SUCCESSFULLY" "SUCCESS"
        $phasesCompleted++
    } else {
        Write-Log "PHASE 1 COMPLETED WITH ERRORS" "ERROR"
        $overallSuccess = $false
        if (-not $ContinueOnError) {
            Write-Log "Stopping teardown due to errors. Use -ContinueOnError to proceed anyway." "ERROR"
            exit 1
        }
    }
} else {
    Write-Log "PHASE 1 SKIPPED by user" "WARN"
}

# ==========================================
# FINAL SUMMARY
# ==========================================
$scriptEndTime = Get-Date
$duration = $scriptEndTime - $scriptStartTime

Write-Log ""
Write-Log "=========================================="
Write-Log "TEARDOWN COMPLETE - FINAL SUMMARY"
Write-Log "=========================================="
Write-Log "Start Time: $scriptStartTime"
Write-Log "End Time: $scriptEndTime"
Write-Log "Total Duration: $($duration.TotalMinutes.ToString("F1")) minutes"
Write-Log "Phases Completed: $phasesCompleted / 5"
Write-Log "Overall Status: $(if ($overallSuccess) { 'SUCCESS' } else { 'COMPLETED WITH ERRORS' })"
Write-Log "Log File: $logPath"

if ($overallSuccess) {
    Write-Log ""
    Write-Log "✅ MASTER TEARDOWN COMPLETED SUCCESSFULLY!" "SUCCESS"
    Write-Log "All Azure AI Foundry Landing Zone resources have been removed."
} else {
    Write-Log ""
    Write-Log "⚠️  MASTER TEARDOWN COMPLETED WITH ERRORS" "WARN"
    Write-Log "Some resources may not have been removed. Check the log file for details."
    Write-Log "You can re-run this script or run individual teardown scripts manually."
}

Write-Log ""
Write-Log "Next Steps:"
Write-Log "1. Verify all resources are removed using: .\azure-inventory.ps1"
Write-Log "2. Check Azure Portal for any remaining resources"
Write-Log "3. Review log file for any errors: $logPath"
Write-Log "4. If needed, manually remove any remaining resources"

exit $(if ($overallSuccess) { 0 } else { 1 })