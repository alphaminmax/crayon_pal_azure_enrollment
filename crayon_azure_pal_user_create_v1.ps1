################################################################################################################################
# Written by Jared Griego | Crayon.com | 2.18.2025 | Rev 1.0 |jared.griego@crayon.com                                          #
# Based on the scripts created by the Crayon Help Desk Team | Hooman Haghighat hooman.haghighat@crayon.com &                   #
# Angela Martin angela.martin@crayon.com & Travis Hartman travis.hartman@crayon.com                                            #
# Azure PowerShell Script to create the PAL user account for client project tracking                                           #
# Requirements: Azure PowerShell Modules                                                                                       #
# Python = 3.12.6                                                                                                              #
# PowerShell 7.5.0 x64                                                                                                         #
# pip -r install requirements.txt                                                                                              #
################################################################################################################################

################################################################################################################################
#     ______ .______          ___   ____    ____  ______   .__   __.     __    __       _______.     ___                       #
#    /      ||   _  \        /   \  \   \  /   / /  __  \  |  \ |  |    |  |  |  |     /       |    /   \                      #
#   |  ,----'|  |_)  |      /  ^  \  \   \/   / |  |  |  | |   \|  |    |  |  |  |    |   (----`   /  ^  \                     #
#   |  |     |      /      /  /_\  \  \_    _/  |  |  |  | |  . `  |    |  |  |  |     \   \      /  /_\  \                    #
#   |  `----.|  |\  \----./  _____  \   |  |    |  `--'  | |  |\   |    |  `--'  | .----)   |    /  _____  \                   #
#    \______|| _| `._____/__/     \__\  |__|     \______/  |__| \__|     \______/  |_______/    /__/     \__\                  #
#                                                                                                                              #
################################################################################################################################

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$CrayonPALObjectId,

    [string]$Role = "Contributor"
)

# Define log file path
$logFilePath = "C:\Logs\RoleAssignment.log"

# Create log directory if it doesn't exist
$logDir = Split-Path $logFilePath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}

# Logging function for timestamped log entries
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Write-Output $logEntry
    Add-Content -Path $logFilePath -Value $logEntry
}

# Start transcript to capture all console output to the log file
Start-Transcript -Path $logFilePath -Append

Write-Log "Script started. Tenant: $TenantId, Role: $Role"

# Connect to Azure using interactive web authentication for the provided destinatin client tenant
try {
    Connect-AzAccount -Tenant $TenantId -ErrorAction Stop
    Write-Log "Successfully connected to Azure tenant $TenantId"
} catch {
    Write-Log "Error connecting to Azure: $_" "ERROR"
    Stop-Transcript
    exit 1
}

# Retrieve all subscriptions for the tenant
try {
    $subscriptions = Get-AzSubscription -ErrorAction Stop
    Write-Log "Retrieved $($subscriptions.Count) subscriptions."
} catch {
    Write-Log "Error retrieving subscriptions: $_" "ERROR"
    Stop-Transcript
    exit 1
}

$totalSubscriptions = $subscriptions.Count
$successCount = 0
$failureCount = 0

# Loop through each subscription to assign the role
for ($i = 0; $i -lt $totalSubscriptions; $i++) {
    $subscription = $subscriptions[$i]
    Write-Progress -Activity "Assigning Roles" -Status "Processing subscription $($subscription.Name)" -PercentComplete (($i / $totalSubscriptions) * 100)

    try {
        Set-AzContext -SubscriptionId $subscription.Id -ErrorAction Stop

        # Duplicate Check: Avoid reassigning if the role already exists
        $existingAssignment = Get-AzRoleAssignment -ObjectId $CrayonPALObjectId -Scope "/subscriptions/$($subscription.Id)" -ErrorAction SilentlyContinue
        if ($existingAssignment) {
            Write-Log "Role '$Role' is already assigned to object '$CrayonPALObjectId' in subscription $($subscription.Name) ($($subscription.Id)). Skipping assignment."
            $successCount++
            continue
        }

        # Assign the role to the PAL user in the current subscription
        New-AzRoleAssignment -ObjectId $CrayonPALObjectId -RoleDefinitionName $Role -Scope "/subscriptions/$($subscription.Id)" -ErrorAction Stop
        Write-Log "Role '$Role' assigned successfully in subscription $($subscription.Name) ($($subscription.Id))."
        $successCount++
    } catch {
        Write-Log "Error assigning role in subscription $($subscription.Name) ($($subscription.Id)): $_" "ERROR"
        $failureCount++
    }
}

Write-Log "Role assignment completed. Successes: $successCount, Failures: $failureCount"

# Disconnect from Azure
Disconnect-AzAccount | Out-Null
Write-Log "Disconnected from Azure."

Stop-Transcript

Write-Output "Script completed. Successes: $successCount, Failures: $failureCount"

