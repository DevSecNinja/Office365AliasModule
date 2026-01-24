# Introduction

This PowerShell Module creates mail aliases in Office 365. These mail aliases are created per domain name or organization. This is to make sure that organizations get unique email addresses.

**Requirements:**
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- ExchangeOnlineManagement module v2.0.0 or later
- Appropriate Exchange Online permissions (User Administrator + Exchange Administrator)

This module is tested in Azure PowerShell. The author recommends to run the code from Azure PowerShell to simplify authentication to Office 365.

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Office365MailAliases.svg?style=flat-square&label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/Office365MailAliases/)
[![Lint Code Base](https://github.com/DevSecNinja/Office365AliasModule/actions/workflows/linter.yml/badge.svg?branch=master)](https://github.com/DevSecNinja/Office365AliasModule/actions/workflows/linter.yml)
[![Run Pester Tests](https://github.com/DevSecNinja/Office365AliasModule/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/DevSecNinja/Office365AliasModule/actions/workflows/test.yml)

## Download

The module can be downloaded from [the PowerShell Gallery](https://www.powershellgallery.com/packages/Office365MailAliases) by running the following command in PowerShell:

``` powershell
Install-Module -Name Office365MailAliases
```

## Usage Examples

### Creating Mail Aliases

```powershell
# Create 10 mail aliases with prefix "COMP"
New-MailAlias -NumberOfAliases 10 -EmailDomain "contoso.com" -Owner "admin@contoso.com" -GroupNamePrefix "COMP" -Verbose
```

### Selecting/Claiming an Alias

```powershell
# Claim an alias for a specific domain
Select-MailAlias -DomainName "example.com" -Verbose

# Claim an alias and export used aliases to draft email
Select-MailAlias -DomainName "example.com" -ExportAliasesToMailDraft -Verbose
```

### Viewing Aliases

```powershell
# Get all used mail aliases
Get-UsedMailAlias

# Get unused (claimable) mail aliases
Get-UnusedMailAlias

# Get aliases with specific prefix
Get-UsedMailAlias -GroupNamePrefix "COMP"
```

### Archiving an Alias

```powershell
# Archive an alias when no longer needed
Set-MailAliasToArchived -DomainName "example.com" -Verbose
```

## Security Considerations

**Important:** This module configures distribution groups to accept mail from external (unauthenticated) senders. This is necessary for the alias functionality but creates potential security risks:

- Aliases can be targets for spam and phishing attempts
- Consider implementing additional security measures:
  - Mail flow rules to filter incoming mail
  - Advanced spam filtering
  - Regular monitoring of alias usage
  - Prompt archiving of unused aliases

## Feature requests

Please create a GitHub issue.

## Build and Test

The code is checked by running the PSScriptAnalyzer extension during the build. Comprehensive Pester tests are included to ensure code quality and reliability.

### Running Tests Locally

To run the Pester tests locally:

```powershell
# Install Pester if not already installed
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck

# Run all tests
Invoke-Pester -Path ./Tests

# Run tests with detailed output
Invoke-Pester -Path ./Tests -Output Detailed
```

### Test Coverage

The test suite includes comprehensive coverage for all public functions:

- **New-MailAlias** - Tests for creating mail aliases with various configurations
- **Select-MailAlias** - Tests for claiming and managing aliases
- **Get-UsedMailAlias** - Tests for retrieving used aliases
- **Get-UnusedMailAlias** - Tests for retrieving available aliases
- **Set-MailAliasToArchived** - Tests for archiving aliases

All tests use mocking to avoid requiring actual Exchange Online connections, making them safe to run in any environment.

### Continuous Integration

The repository uses GitHub Actions for automated testing:

- Tests run automatically on every push to master/main branches
- Tests run automatically on all pull requests
- Test results are uploaded as artifacts for review
- Test results are published as part of the workflow output

## Recent Updates (2026)

- ✅ Updated to use modern Exchange Online authentication (Get-ConnectionInformation)
- ✅ Added comprehensive input validation (email, domain, prefix patterns)
- ✅ Improved error handling with specific exception types
- ✅ Modernized PowerShell syntax (PSCustomObject, better pipeline usage)
- ✅ Added retry logic and timeout handling
- ✅ Updated GitHub Actions to latest versions
- ✅ Added PowerShell Core (7+) compatibility
- ✅ Enhanced security documentation
- ✅ Improved session management

## Contribute

Feel free to open up a PR!
