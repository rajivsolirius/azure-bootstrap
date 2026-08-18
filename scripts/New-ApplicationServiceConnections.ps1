#Requires -Version 7.0

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$AzureDevOpsOrganizationUrl,

    [Parameter(Mandatory)]
    [string]$AzureDevOpsProjectName,

    [Parameter(Mandatory)]
    [string]$ManagementSubscriptionId,

    [Parameter(Mandatory)]
    [string]$ManagedIdentityResourceGroupName,

    [Parameter()]
    [string]$PlanManagedIdentityName = "uami-tf-app-plan",

    [Parameter()]
    [string]$ApplyManagedIdentityName = "uami-tf-app-apply",

    [Parameter()]
    [string]$PlanServiceConnectionName = "sc-app-lz-plan",

    [Parameter()]
    [string]$ApplyServiceConnectionName = "sc-app-lz-apply",

    [Parameter()]
    [string]$PlanFederatedCredentialName = "fic-ado-app-lz-plan",

    [Parameter()]
    [string]$ApplyFederatedCredentialName = "fic-ado-app-lz-apply"
)

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

function Assert-LastExitCode {
    param(
        [Parameter(Mandatory)]
        [string]$Action
    )

    if ($LASTEXITCODE -ne 0) {
        throw "$Action failed. Azure CLI exit code: $LASTEXITCODE"
    }
}

function Invoke-AzJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = & az @Arguments
    Assert-LastExitCode -Action "az $($Arguments -join ' ')"

    $text = $output -join "`n"

    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text | ConvertFrom-Json
}

function Invoke-AdoRest {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        $Body
    )

    $headers = @{
        Authorization = "Basic $script:AdoBasicToken"
        Accept        = "application/json"
    }

    $params = @{
        Method  = $Method
        Uri     = $Uri
        Headers = $headers
    }

    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ($Body | ConvertTo-Json -Depth 30)
    }

    try {
        return Invoke-RestMethod @params
    }
    catch {
        Write-Host ""
        Write-Host "Azure DevOps REST request failed:"
        Write-Host "$Method $Uri"

        if ($_.ErrorDetails.Message) {
            Write-Host $_.ErrorDetails.Message
        }

        throw
    }
}

function Get-AdoServiceConnection {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $encodedProject = [uri]::EscapeDataString($AzureDevOpsProjectName)

    $uri =
        "$script:AdoOrgBase/$encodedProject/_apis/serviceendpoint/endpoints" +
        "?type=AzureRM&api-version=7.1"

    $result = Invoke-AdoRest `
        -Method GET `
        -Uri $uri

    return $result.value |
        Where-Object { $_.name -eq $Name } |
        Select-Object -First 1
}

function New-OrGetAdoServiceConnection {
    param(
        [Parameter(Mandatory)]
        [string]$ServiceConnectionName,

        [Parameter(Mandatory)]
        [string]$ManagedIdentityClientId,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$SubscriptionId,

        [Parameter(Mandatory)]
        [string]$SubscriptionName,

        [Parameter(Mandatory)]
        [string]$ProjectId
    )

    $existing = Get-AdoServiceConnection `
        -Name $ServiceConnectionName

    if ($existing) {
        Write-Host "Service Connection '$ServiceConnectionName' already exists."
        return $existing
    }

    Write-Host "Creating Service Connection '$ServiceConnectionName'..."

    $body = @{
        data = @{
            subscriptionId   = $SubscriptionId
            subscriptionName = $SubscriptionName
            environment      = "AzureCloud"
            scopeLevel       = "Subscription"
            creationMode     = "Manual"
        }

        name = $ServiceConnectionName

        type = "AzureRM"

        url = "https://management.azure.com/"

        authorization = @{
            parameters = @{
                tenantid           = $TenantId
                serviceprincipalid = $ManagedIdentityClientId
            }

            scheme = "WorkloadIdentityFederation"
        }

        isShared = $false
        isReady  = $true

        serviceEndpointProjectReferences = @(
            @{
                projectReference = @{
                    id   = $ProjectId
                    name = $AzureDevOpsProjectName
                }

                name = $ServiceConnectionName
            }
        )
    }

    $uri =
        "$script:AdoOrgBase/_apis/serviceendpoint/endpoints" +
        "?api-version=7.1"

    $created = Invoke-AdoRest `
        -Method POST `
        -Uri $uri `
        -Body $body

    Write-Host "Created Service Connection '$ServiceConnectionName'."

    return $created
}

function New-OrValidateFederatedCredential {
    param(
        [Parameter(Mandatory)]
        [string]$ManagedIdentityName,

        [Parameter(Mandatory)]
        [string]$FederatedCredentialName,

        [Parameter(Mandatory)]
        [string]$Issuer,

        [Parameter(Mandatory)]
        [string]$Subject
    )

    $credentials = Invoke-AzJson -Arguments @(
        "identity",
        "federated-credential",
        "list",
        "--identity-name", $ManagedIdentityName,
        "--resource-group", $ManagedIdentityResourceGroupName,
        "--subscription", $ManagementSubscriptionId,
        "--output", "json"
    )

    $existing = $credentials |
        Where-Object { $_.name -eq $FederatedCredentialName } |
        Select-Object -First 1

    if ($existing) {

        Write-Host "Federated credential '$FederatedCredentialName' already exists."

        if ($existing.issuer -ne $Issuer) {
            throw @"
Existing federated credential issuer does not match Azure DevOps.

Existing:
$($existing.issuer)

Expected:
$Issuer
"@
        }

        if ($existing.subject -ne $Subject) {
            throw @"
Existing federated credential subject does not match Azure DevOps.

Existing:
$($existing.subject)

Expected:
$Subject
"@
        }

        Write-Host "Federated credential is correctly configured."

        return
    }

    Write-Host "Creating federated credential '$FederatedCredentialName'..."

    & az identity federated-credential create `
        --name $FederatedCredentialName `
        --identity-name $ManagedIdentityName `
        --resource-group $ManagedIdentityResourceGroupName `
        --subscription $ManagementSubscriptionId `
        --issuer $Issuer `
        --subject $Subject `
        --audiences "api://AzureADTokenExchange" `
        --output none

    Assert-LastExitCode `
        -Action "Create federated credential '$FederatedCredentialName'"

    Write-Host "Created federated credential '$FederatedCredentialName'."
}

function Configure-ServiceConnection {
    param(
        [Parameter(Mandatory)]
        [string]$ManagedIdentityName,

        [Parameter(Mandatory)]
        [string]$ServiceConnectionName,

        [Parameter(Mandatory)]
        [string]$FederatedCredentialName,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$SubscriptionId,

        [Parameter(Mandatory)]
        [string]$SubscriptionName,

        [Parameter(Mandatory)]
        [string]$ProjectId
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Configuring $ServiceConnectionName"
    Write-Host "============================================================"

    $identity = Invoke-AzJson -Arguments @(
        "identity",
        "show",
        "--name", $ManagedIdentityName,
        "--resource-group", $ManagedIdentityResourceGroupName,
        "--subscription", $ManagementSubscriptionId,
        "--output", "json"
    )

    Write-Host "Managed Identity : $ManagedIdentityName"
    Write-Host "Client ID        : $($identity.clientId)"
    Write-Host "Principal ID     : $($identity.principalId)"

    $serviceConnection =
        New-OrGetAdoServiceConnection `
            -ServiceConnectionName $ServiceConnectionName `
            -ManagedIdentityClientId $identity.clientId `
            -TenantId $TenantId `
            -SubscriptionId $SubscriptionId `
            -SubscriptionName $SubscriptionName `
            -ProjectId $ProjectId

    #
    # Azure DevOps returns the WIF information in the
    # authorization parameters.
    #
    $issuer =
        $serviceConnection.authorization.parameters.workloadIdentityFederationIssuer

    $subject =
        $serviceConnection.authorization.parameters.workloadIdentityFederationSubject

    #
    # If an existing Service Connection was returned from the LIST API
    # and details weren't included, retrieve that specific endpoint.
    #
    if (
        [string]::IsNullOrWhiteSpace($issuer) -or
        [string]::IsNullOrWhiteSpace($subject)
    ) {

        $encodedProject =
            [uri]::EscapeDataString($AzureDevOpsProjectName)

        $endpointUri =
            "$script:AdoOrgBase/$encodedProject/_apis/serviceendpoint/endpoints/" +
            "$($serviceConnection.id)?api-version=7.1"

        $serviceConnection =
            Invoke-AdoRest `
                -Method GET `
                -Uri $endpointUri

        $issuer =
            $serviceConnection.authorization.parameters.workloadIdentityFederationIssuer

        $subject =
            $serviceConnection.authorization.parameters.workloadIdentityFederationSubject
    }

    if ([string]::IsNullOrWhiteSpace($issuer)) {
        throw "Azure DevOps did not return a workload identity federation issuer for '$ServiceConnectionName'."
    }

    if ([string]::IsNullOrWhiteSpace($subject)) {
        throw "Azure DevOps did not return a workload identity federation subject for '$ServiceConnectionName'."
    }

    Write-Host "WIF Issuer  : $issuer"
    Write-Host "WIF Subject : $subject"

    New-OrValidateFederatedCredential `
        -ManagedIdentityName $ManagedIdentityName `
        -FederatedCredentialName $FederatedCredentialName `
        -Issuer $issuer `
        -Subject $subject

    return [PSCustomObject]@{
        ServiceConnectionName = $ServiceConnectionName
        ServiceConnectionId   = $serviceConnection.id
        ManagedIdentityName   = $ManagedIdentityName
        ClientId              = $identity.clientId
        PrincipalId           = $identity.principalId
        Issuer                = $issuer
        Subject               = $subject
    }
}


# ------------------------------------------------------------
# Prerequisite checks
# ------------------------------------------------------------

Write-Host ""
Write-Host "Application Service Connection Bootstrap"
Write-Host "========================================"

if ([string]::IsNullOrWhiteSpace($env:AZURE_DEVOPS_EXT_PAT)) {
    throw @"
AZURE_DEVOPS_EXT_PAT is not set.

Set your short-lived PAT in this PowerShell session:

`$env:AZURE_DEVOPS_EXT_PAT = "<PAT>"

The PAT should have Service Connections:
Read, query & manage.
"@
}

#
# PAT authentication uses Basic authentication where the username
# portion may be blank and the PAT is supplied as the password.
#
$basicBytes =
    [System.Text.Encoding]::ASCII.GetBytes(
        ":$($env:AZURE_DEVOPS_EXT_PAT)"
    )

$script:AdoBasicToken =
    [Convert]::ToBase64String($basicBytes)

#
# Normalize the Azure DevOps organization URL.
#
$script:AdoOrgBase =
    $AzureDevOpsOrganizationUrl.TrimEnd("/")

#
# Verify Azure CLI exists and that you are logged in.
#
& az account show --output none

if ($LASTEXITCODE -ne 0) {
    throw @"
Azure CLI is installed, but you are not logged in.

Run:

az login

and then run this script again.
"@
}


# ------------------------------------------------------------
# Azure subscription details
# ------------------------------------------------------------

$subscription = Invoke-AzJson -Arguments @(
    "account",
    "show",
    "--subscription", $ManagementSubscriptionId,
    "--output", "json"
)

$tenantId         = $subscription.tenantId
$subscriptionName = $subscription.name

Write-Host ""
Write-Host "Azure:"
Write-Host "  Subscription : $subscriptionName"
Write-Host "  ID           : $ManagementSubscriptionId"
Write-Host "  Tenant       : $tenantId"


# ------------------------------------------------------------
# Azure DevOps project details
# ------------------------------------------------------------

$encodedProjectName =
    [uri]::EscapeDataString($AzureDevOpsProjectName)

$projectUri =
    "$script:AdoOrgBase/_apis/projects/$encodedProjectName" +
    "?api-version=7.1"

$project =
    Invoke-AdoRest `
        -Method GET `
        -Uri $projectUri

$projectId = $project.id

Write-Host ""
Write-Host "Azure DevOps:"
Write-Host "  Organisation : $script:AdoOrgBase"
Write-Host "  Project      : $AzureDevOpsProjectName"
Write-Host "  Project ID   : $projectId"


# ------------------------------------------------------------
# Plan connection
# ------------------------------------------------------------

$planResult = Configure-ServiceConnection `
    -ManagedIdentityName $PlanManagedIdentityName `
    -ServiceConnectionName $PlanServiceConnectionName `
    -FederatedCredentialName $PlanFederatedCredentialName `
    -TenantId $tenantId `
    -SubscriptionId $ManagementSubscriptionId `
    -SubscriptionName $subscriptionName `
    -ProjectId $projectId


# ------------------------------------------------------------
# Apply connection
# ------------------------------------------------------------

$applyResult = Configure-ServiceConnection `
    -ManagedIdentityName $ApplyManagedIdentityName `
    -ServiceConnectionName $ApplyServiceConnectionName `
    -FederatedCredentialName $ApplyFederatedCredentialName `
    -TenantId $tenantId `
    -SubscriptionId $ManagementSubscriptionId `
    -SubscriptionName $subscriptionName `
    -ProjectId $projectId


# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host "Completed"
Write-Host "============================================================"

@(
    $planResult
    $applyResult
) |
    Format-Table `
        ServiceConnectionName,
        ManagedIdentityName,
        ClientId `
        -AutoSize

Write-Host ""
Write-Host "Expected Azure DevOps Service Connections:"
Write-Host "  $PlanServiceConnectionName"
Write-Host "  $ApplyServiceConnectionName"
Write-Host ""
Write-Host "Expected Federated Credentials:"
Write-Host "  $PlanFederatedCredentialName"
Write-Host "  $ApplyFederatedCredentialName"
Write-Host ""