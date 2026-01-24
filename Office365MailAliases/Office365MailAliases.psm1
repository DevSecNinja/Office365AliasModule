<#
.SYNOPSIS
  This module contains functions to create mail aliases in Office 365

.DESCRIPTION
  These mail aliases are created per domain name or organization. This is to make sure
  that organizations get unique email addresses. You need at least "User administrator"
  permissions and the appropriate Exchange permissions to run the "New-MailAlias" command.

.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Author: Jean-Paul van Ravensberg, Cloudenius.com

.EXAMPLE
  Select-MailAlias -DomainName Google.com -ExportAliasesToMailDraft -Verbose

  Create a mail alias for Google.com and provide Verbose output. After selecting the mail alias,
  create a draft mail in the mailbox of the user that contains all the used mail aliases.

.EXAMPLE
  New-MailAlias -NumberOfAliases 9 -Verbose

  Warm up aliases for later use and provide Verbose output.
#>

Function New-MailAlias {
    #Requires -Modules ExchangeOnlineManagement
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '*', Scope = 'Function', Target = '*', Justification = 'Does not change system state')]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Specify the amount of aliases required")]
        [ValidateRange(1, 100)]
        [int]$NumberOfAliases,

        [parameter(Mandatory = $true, HelpMessage = "Specify the domain name that is used for the email address. E.g. johndoe.com")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$')]
        [string]$EmailDomain,

        [parameter(Mandatory = $true, HelpMessage = "Specify the owner of the alias. E.g. john@johndoe.com")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
        [string]$Owner,

        [parameter(Mandatory = $true, HelpMessage = "Specify the prefix that will be used to create the alias. E.g. JD")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9]{1,10}$')]
        [string]$GroupNamePrefix,

        [parameter(Mandatory = $false, HelpMessage = "Keep the Exchange Online session alive for further use")]
        [switch]$KeepAlive
    )

    ## Connect to Exchange Online if not already connected
    # Modern session detection using Get-ConnectionInformation (ExchangeOnlineManagement v2.0+)
    try {
        $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if (-not $connectionInfo -or $connectionInfo.State -ne 'Connected') {
            Write-Verbose "Connecting to Exchange Online..."
            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        }
        else {
            Write-Verbose "Using existing Exchange Online connection"
        }
    }
    catch {
        Write-Error "Failed to connect to Exchange Online: $_"
        throw
    }

    Write-Verbose "Creating $NumberOfAliases aliases"

    $createdAliases = 0
    $maxRetries = 3

    foreach ($i in 1..$NumberOfAliases) {
        $retryCount = 0
        $aliasCreated = $false

        while (-not $aliasCreated -and $retryCount -lt $maxRetries) {
            $Random = Get-Random -Minimum 10000 -Maximum 99999
            $GroupName = $GroupNamePrefix + $Random
            $GroupEmail = ($GroupName + "@" + $EmailDomain)

            Write-Verbose "Creating alias $i with name $GroupName (attempt $($retryCount + 1))"

            # Check if group name already exists
            $existingGroup = Get-DistributionGroup -Filter "Name -like '*$GroupName*'" -ErrorAction SilentlyContinue

            if ($existingGroup) {
                Write-Verbose "Distribution Group name is not unique. Will skip name $GroupName"
                $retryCount++
                continue
            }

            # Create the new Distribution Group
            try {
                New-DistributionGroup -Name $GroupName -Type "Security" -ManagedBy $Owner -PrimarySmtpAddress $GroupEmail -ErrorAction Stop | Out-Null

                # SECURITY WARNING: This allows external (unauthenticated) senders to mail to the address
                # This is required for the alias functionality but creates potential spam/phishing risk
                # Consider implementing additional security measures such as mail flow rules or spam filtering
                Set-DistributionGroup -Identity $GroupName -RequireSenderAuthenticationEnabled:$false -DisplayName $($GroupName + "_CLAIMABLE") -ErrorAction Stop

                # Modify the new Distribution Group with SendOnBehalf permissions
                Add-RecipientPermission -Identity $GroupName -AccessRights SendAs -Trustee $Owner -Confirm:$false -ErrorAction Stop | Out-Null

                # Add the owner to the Distribution Group
                Add-DistributionGroupMember -Identity $GroupName -Member $Owner -ErrorAction Stop

                Write-Verbose "Created group called $GroupName with owner $Owner"
                $aliasCreated = $true
                $createdAliases++
            }
            catch [System.Management.Automation.RemoteException] {
                if ($_.Exception.Message -match "already exists") {
                    Write-Verbose "Distribution Group already exists. Retrying with new name..."
                    $retryCount++
                }
                else {
                    Write-Error "Failed to create Distribution Group '$GroupName': $_"
                    break
                }
            }
            catch {
                Write-Error "Unexpected error creating Distribution Group '$GroupName': $_"
                break
            }
        }

        if (-not $aliasCreated) {
            Write-Warning "Failed to create alias $i after $maxRetries attempts"
        }
    }

    Write-Verbose "Successfully created $createdAliases out of $NumberOfAliases requested aliases"

    # Disconnect the session to make sure we don't run out of maximum concurrent connections
    if (-not $KeepAlive) {
        $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if ($connectionInfo) {
            Write-Verbose "Disconnecting from Exchange Online"
            Disconnect-ExchangeOnline -Confirm:$false | Out-Null
        }
    }
}

Function Select-MailAlias {
    #Requires -Modules ExchangeOnlineManagement
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Specify the domain name of the website")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9]([a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$')]
        [string]$DomainName,

        [parameter(Mandatory = $false, HelpMessage = "Create a draft mail in the mailbox of the user that contains all the used mail aliases")]
        [switch]$ExportAliasesToMailDraft,

        [parameter(Mandatory = $false, HelpMessage = "Keep the Exchange Online session alive for further use")]
        [switch]$KeepAlive
    )

    ## Connect to Exchange Online if not already connected
    try {
        $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if (-not $connectionInfo -or $connectionInfo.State -ne 'Connected') {
            Write-Verbose "Connecting to Exchange Online..."
            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        }
        else {
            Write-Verbose "Using existing Exchange Online connection"
        }
    }
    catch {
        Write-Error "Failed to connect to Exchange Online: $_"
        throw
    }

    Write-Verbose "Claiming an alias for $DomainName"

    # Check if domain name already exists in Distribution Group
    $ExistingDistributionGroup = Get-DistributionGroup -Filter "DisplayName -like '$DomainName - *'" -ErrorAction SilentlyContinue

    if ($ExistingDistributionGroup) {
        Write-Output "Alias for domain name '$($DomainName)' already exists. Returning the alias already in use"

        $DistributionGroup = $ExistingDistributionGroup

        $EmailDomain = $DistributionGroup.PrimarySmtpAddress.Split('@')[1]
        $DisplayName = $DomainName + " - " + $EmailDomain
    }
    else {
        # Search for unused alias and return the oldest one
        $ClaimableDistributionGroups = Get-DistributionGroup -Filter "DisplayName -like '*_CLAIMABLE'" -ErrorAction SilentlyContinue |
            Sort-Object WhenCreatedUtc

        if (-not $ClaimableDistributionGroups) {
            Write-Error "No claimable Mail Aliases found. Please run New-MailAlias first."
            throw "No claimable aliases available"
        }

        # Implement timeout for waiting on new aliases
        $maxWaitSeconds = 60
        $waitCount = 0
        while (-not $ClaimableDistributionGroups -and $waitCount -lt ($maxWaitSeconds / 5)) {
            Write-Output "Waiting for a new claimable Distribution Group. Pause 5 seconds..."
            Start-Sleep -Seconds 5
            $waitCount++
            $ClaimableDistributionGroups = Get-DistributionGroup -Filter "DisplayName -like '*_CLAIMABLE'" -ErrorAction SilentlyContinue
        }

        if (-not $ClaimableDistributionGroups) {
            Write-Error "Timeout waiting for claimable Distribution Groups after $maxWaitSeconds seconds"
            throw "No claimable aliases became available"
        }

        Write-Verbose "Found $(@($ClaimableDistributionGroups).Count) claimable Distribution Group(s)"

        # Rename unused alias & change description
        $DistributionGroup = $ClaimableDistributionGroups[0]

        Write-Verbose "Picking $($DistributionGroup.Name) for the rename"

        if ($DistributionGroup.WhenCreated.AddHours(1) -gt (Get-Date)) {
            Write-Warning "Be aware that this alias is <60 minutes old and might not be active yet"
        }

        # Change the Display Name for the Distribution Group
        $EmailDomain = $DistributionGroup.PrimarySmtpAddress.Split('@')[1]
        $DisplayName = $DomainName + " - " + $EmailDomain

        try {
            Set-DistributionGroup -Identity $DistributionGroup.Name -DisplayName $DisplayName -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to update Distribution Group '$($DistributionGroup.Name)': $_"
            throw
        }
    }

    # Create the draft mail in the mailbox of the user that contains all the used mail aliases
    if ($ExportAliasesToMailDraft) {
        try {
            $usedAliases = Get-UsedMailAlias -KeepAlive
            $MailMessage = New-MailMessage -Body ($usedAliases | Select-Object Name, DisplayName | Sort-Object DisplayName | Out-String) -Subject "Used Mailbox Aliases" -ErrorAction Stop

            if ($MailMessage) {
                Write-Output "Successfully created draft mail message with subject '$($MailMessage.Subject)' and object state '$($MailMessage.ObjectState)'"
            }
        }
        catch {
            Write-Warning "Failed to create draft mail message: $_"
        }
    }

    # Disconnect the session to make sure we don't run out of maximum concurrent connections
    if (-not $KeepAlive) {
        $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if ($connectionInfo) {
            Write-Verbose "Disconnecting from Exchange Online"
            Disconnect-ExchangeOnline -Confirm:$false | Out-Null
        }
    }

    # Return the new name of the alias
    return [PSCustomObject]@{
        Name        = $DistributionGroup.Name
        DisplayName = $DisplayName
        Email       = $DistributionGroup.PrimarySmtpAddress
    }
}

Function Get-UsedMailAlias {
    #Requires -Modules ExchangeOnlineManagement
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false, HelpMessage = "Name prefix that is used to identify the Mail Aliases")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9\*]{1,10}$')]
        [string]$GroupNamePrefix = '*',

        [parameter(Mandatory = $false, HelpMessage = "Create a draft mail in the mailbox of the user that contains all the used mail aliases")]
        [switch]$ExportAliasesToMailDraft,

        [parameter(Mandatory = $false, HelpMessage = "Keep the Exchange Online session alive for further use")]
        [switch]$KeepAlive
    )

    ## Connect to Exchange Online if not already connected
    try {
        $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if (-not $connectionInfo -or $connectionInfo.State -ne 'Connected') {
            Write-Verbose "Connecting to Exchange Online..."
            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        }
        else {
            Write-Verbose "Using existing Exchange Online connection"
        }
    }
    catch {
        Write-Error "Failed to connect to Exchange Online: $_"
        throw
    }

    # Check if domain name already exists in Distribution Group
    $filterString = "Name -like '$GroupNamePrefix*' -and DisplayName -notlike '*_CLAIMABLE'"
    $ExistingDistributionGroup = Get-DistributionGroup -Filter $filterString -ErrorAction SilentlyContinue

    # Create the draft mail in the mailbox of the user that contains all the used mail aliases
    if ($ExistingDistributionGroup -and $ExportAliasesToMailDraft) {
        try {
            $MailMessage = New-MailMessage -Body ($ExistingDistributionGroup | Select-Object Name, DisplayName | Sort-Object DisplayName | Out-String) -Subject "Used Mailbox Aliases" -ErrorAction Stop

            if ($MailMessage) {
                Write-Output "Successfully created draft mail message with subject '$($MailMessage.Subject)' and object state '$($MailMessage.ObjectState)'"
            }
        }
        catch {
            Write-Warning "Failed to create draft mail message: $_"
        }
    }

    # Disconnect the session to make sure we don't run out of maximum concurrent connections
    if (-not $KeepAlive) {
        $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if ($connectionInfo) {
            Write-Verbose "Disconnecting from Exchange Online"
            Disconnect-ExchangeOnline -Confirm:$false | Out-Null
        }
    }

    # Return the names of the alias(es)
    if ($ExistingDistributionGroup) {
        return $ExistingDistributionGroup | Select-Object Name, DisplayName, PrimarySmtpAddress | Sort-Object DisplayName
    }
    else {
        return $null
    }
}

Function Get-UnusedMailAlias {
    #Requires -Modules ExchangeOnlineManagement
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false, HelpMessage = "Name prefix that is used to identify the Mail Aliases")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9\*]{1,10}$')]
        [string]$GroupNamePrefix = '*',

        [parameter(Mandatory = $false, HelpMessage = "Keep the Exchange Online session alive for further use")]
        [switch]$KeepAlive
    )

    ## Connect to Exchange Online if not already connected
    try {
        $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if (-not $connectionInfo -or $connectionInfo.State -ne 'Connected') {
            Write-Verbose "Connecting to Exchange Online..."
            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        }
        else {
            Write-Verbose "Using existing Exchange Online connection"
        }
    }
    catch {
        Write-Error "Failed to connect to Exchange Online: $_"
        throw
    }

    # Check if domain name already exists in Distribution Group
    $filterString = "Name -like '$GroupNamePrefix*' -and DisplayName -like '*_CLAIMABLE'"
    $ExistingDistributionGroup = Get-DistributionGroup -Filter $filterString -ErrorAction SilentlyContinue

    # Disconnect the session to make sure we don't run out of maximum concurrent connections
    if (-not $KeepAlive) {
        $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if ($connectionInfo) {
            Write-Verbose "Disconnecting from Exchange Online"
            Disconnect-ExchangeOnline -Confirm:$false | Out-Null
        }
    }

    # Return the names of the unused alias(es)
    if ($ExistingDistributionGroup) {
        return $ExistingDistributionGroup | Select-Object Name, DisplayName, PrimarySmtpAddress
    }
    else {
        return $null
    }
}

Function Set-MailAliasToArchived {
    #Requires -Modules ExchangeOnlineManagement
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '*', Scope = 'Function', Target = '*', Justification = 'Does not change system state')]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Specify the domain name of the website")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9]([a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$')]
        [string]$DomainName,

        [parameter(Mandatory = $false, HelpMessage = "Keep the Exchange Online session alive for further use")]
        [switch]$KeepAlive
    )

    ## Connect to Exchange Online if not already connected
    try {
        $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if (-not $connectionInfo -or $connectionInfo.State -ne 'Connected') {
            Write-Verbose "Connecting to Exchange Online..."
            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        }
        else {
            Write-Verbose "Using existing Exchange Online connection"
        }
    }
    catch {
        Write-Error "Failed to connect to Exchange Online: $_"
        throw
    }

    # Check if domain name already exists in Distribution Group
    $ExistingDistributionGroup = Get-DistributionGroup -Filter "DisplayName -like '$DomainName - *'" -ErrorAction SilentlyContinue

    if (-not $ExistingDistributionGroup) {
        $errorMessage = "Cannot find an existing Distribution Group with domain name '$($DomainName)'"
        Write-Error $errorMessage
        throw $errorMessage
    }

    try {
        Write-Output "Changing displayName from '$($ExistingDistributionGroup.DisplayName)' to '(Archived) $($ExistingDistributionGroup.DisplayName)'"
        Set-DistributionGroup -Identity $ExistingDistributionGroup.Identity -DisplayName "(Archived) $($ExistingDistributionGroup.DisplayName)" -ErrorAction Stop

        Write-Output "Removing members from distribution group"
        $members = Get-DistributionGroupMember -Identity $ExistingDistributionGroup.Identity -ErrorAction SilentlyContinue
        if ($members) {
            foreach ($member in $members) {
                try {
                    Remove-DistributionGroupMember -Identity $ExistingDistributionGroup.Identity -Member $member.Identity -Confirm:$false -ErrorAction Stop
                }
                catch {
                    Write-Warning "Failed to remove member $($member.Identity): $_"
                }
            }
        }

        # Return the new name of the alias
        Write-Output "Done, new result:"
    }
    catch {
        Write-Error "Failed to archive Distribution Group '$($ExistingDistributionGroup.Name)': $_"
        throw
    }

    $output = Get-DistributionGroup -Identity $ExistingDistributionGroup.Identity -ErrorAction Stop |
        Select-Object Name, DisplayName, PrimarySmtpAddress

    # Disconnect the session to make sure we don't run out of maximum concurrent connections
    if (-not $KeepAlive) {
        $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if ($connectionInfo) {
            Write-Verbose "Disconnecting from Exchange Online"
            Disconnect-ExchangeOnline -Confirm:$false | Out-Null
        }
    }

    return $output
}