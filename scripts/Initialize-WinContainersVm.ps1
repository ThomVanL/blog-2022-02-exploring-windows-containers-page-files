#Requires -Version 5.1

<#
.SYNOPSIS
    Installs Windows containers features: Docker and Hyper-V.
.DESCRIPTION
    Installs Windows containers features: Docker and Hyper-V.
.INPUTS
    None. You cannot pipe objects to Initialize-WinContainersVm.
.OUTPUTS
    None.
.EXAMPLE
    PS C:\> .\Initialize-WinContainersVm.ps1
#>
[CmdletBinding()]
param ()
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12;

Install-PackageProvider NuGet -Force
Set-PSRepository PSGallery -InstallationPolicy Trusted

Install-Module  -Name DockerMsftProvider -Repository PSGallery -Force -Confirm:$false
Install-Package -Name docker -ProviderName DockerMsftProvider -Force -Confirm:$false

Install-WindowsFeature -Name "Containers", "Hyper-V" -IncludeManagementTools

Restart-Computer