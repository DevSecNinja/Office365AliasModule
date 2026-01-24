# Introduction

This PowerShell Module creates mail aliases in Office 365. These mail aliases are created per domain name or organization. This is to make sure that organizations get unique email addresses.

This module is tested in Azure PowerShell. The author recommends to run the code from Azure PowerShell to simplify authentication to Office 365.

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Office365MailAliases.svg?style=flat-square&label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/Office365MailAliases/)
[![Lint Code Base](https://github.com/DevSecNinja/Office365AliasModule/actions/workflows/linter.yml/badge.svg?branch=master)](https://github.com/DevSecNinja/Office365AliasModule/actions/workflows/linter.yml)
[![Run Pester Tests](https://github.com/DevSecNinja/Office365AliasModule/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/DevSecNinja/Office365AliasModule/actions/workflows/test.yml)

## Download

The module can be downloaded from [the PowerShell Gallery](https://www.powershellgallery.com/packages/Office365MailAliases) by running the following command in PowerShell:

``` powershell
Install-Module -Name Office365MailAliases
```

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

## Contribute

Feel free to open up a PR!
