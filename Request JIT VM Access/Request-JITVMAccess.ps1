<#
.SYNOPSIS
Enable Just In Time VM access.

.DESCRIPTION
Automate Just in time VM request access with PowerShell.

.NOTES
File Name : Request-JITVMAccess.ps1
Author    : Charbel Nemnom
Version   : 2.0
Date      : 20-August-2018
Updated   : 15-October-2018
Requires  : PowerShell Version 5.1 or later
Module    : AzureRM Version 6.7.0 or later
Module    : AzureRM.Security Version 0.2.0 (preview)
Module    : PowerShellGet Version 1.6.7 or later
Module    : PowerShell PackageManagement Version 1.1.7.2 or later

.LINK
To provide feedback or for further assistance please visit:
https://charbelnemnom.com

.EXAMPLE1
.\Request-JITVMAccess.ps1 -VMName [VMName] -Credential [AzureUser@domain.com] -Port [PortNumber] -Time [Hours] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM from any source IP. The management port will be set as specified including the number of hours.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.

.EXAMPLE2
.\Request-JITVMAccess.ps1 -VMName [VMName] -Credential [AzureUser@domain.com] -Port [PortNumber] -AddressPrefix [AllowedSourceIP] -Time [Hours] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM including the management port, source IP, and number of hours.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.

.EXAMPLE3
.\Request-JITVMAccess.ps1 -VMName [VMName] -Credential [AzureUser@domain.com] -Port [PortNumber] -AddressPrefix [AllowedSourceIP] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM including the management port, and source IP address.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If Just in Time VM Access is already enabled, the tool will automatically extract the maximum requested time set by the policy, and then request VM access.

.EXAMPLE4
.\Request-JITVMAccess.ps1 -VMName [VMName] -Credential [AzureUser@domain.com] -Port [PortNumber] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM from any source IP. The management port will be set as specified.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If Just in Time VM Access is already enabled, the tool will automatically extract the maximum requested time set by the policy, and then request VM access.
#>

[CmdletBinding()]
Param(
    [Parameter(Position=0, Mandatory=$True, HelpMessage='Specify the VM Name')]
    [Alias('VM')]
    [String]$VMName,
 
    [Parameter(Position=1, Mandatory=$True, HelpMessage='Specify remote access port, must be a number between 1 and 65535.')]
    [Alias('AccessPort')]
    [ValidateRange(1,65535)]
    [Int]$Port,
    
    [Parameter(Position=2, HelpMessage='Source IP Address Prefix. (IP Address, CIDR block, or *) Default = * (Any)')]
    [Alias('SourceIP')]
    [String]$AddressPrefix = '*',

    [Parameter(Position=3, HelpMessage='Specify time range in hours, valid range: 1-24 hours')]
    [Alias('Hours')]
    [ValidateRange(1,24)]
    [Int]$Time    

)

Function Install-PackageManagement {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name PackageManagement -Force -Confirm:$false -Verbose:$false
}

Function Install-PowerShellGet {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name PowerShellGet -Force -Confirm:$false -Verbose:$false
}

Function Install-AzureRM {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name AzureRM -Confirm:$false -Verbose:$false
}

Function Install-AzureSecurity {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name AzureRM.Security -AllowPrerelease -Confirm:$false -Verbose:$false
}

Function ExtractMaxDuration ([string]$InStr){
   $Out = $InStr -replace("[^\d]")
   try{return [int]$Out}
       catch{}
   try{return [uint64]$Out}
       catch{return 0}}

Function Enable-JITVMAccess {
    $JitPolicy = (@{
        id="$($VMInfo.Id)"
            ports=(@{
            number=$Port;
            protocol="*";
            allowedSourceAddressPrefix=@("$AddressPrefix");
            maxRequestAccessDuration="PT$($time)H"})   
   })
    $JitPolicyArr=@($JitPolicy)
    #! Enable Access to the VM including management Port, and Time Range in Hours
    Write-Verbose "Enabling Just in Time VM Access Policy for ($VMName) on port number $Port for maximum $time hours..."
    Set-AzureRmJitNetworkAccessPolicy -VirtualMachine $JitPolicyArr -ResourceGroupName $VMInfo.ResourceGroupName -Location $VMInfo.Location -Name "default" -Kind "Basic" | Out-Null
}

Function Invoke-JITVMAccess {
    $JitPolicy = (@{
        id="$($VMInfo.Id)"
            ports=(@{
            number=$Port;
            allowedSourceAddressPrefix=@("$AddressPrefix");
            endTimeUtc="$endTimeUtc"})   
   })
    $JitPolicyArr=@($JitPolicy)
    Write-Verbose "Enabling VM Request access for ($VMName) for $Time hours on port number $Port..."
    Start-AzureRmJitNetworkAccessPolicy -VirtualMachine $JitPolicyArr -ResourceGroupName $VMInfo.ResourceGroupName -Location $VMInfo.Location -Name "default" | Out-Null
}

#! Check PowerShell Package Management Module
Try {
    Import-Module -Name PackageManagement -MinimumVersion 1.1.7.2 -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing PowerShell PackageManagement Module..."
    }
Catch {
    Write-Warning "PowerShell PackageManagement Module was not found..."
    Write-Verbose "Installing the latest PowerShell PackageManagement Module..."
    Install-PackageManagement
}

#! Check PowerShellGet Module
Try {
    Import-Module -Name PowerShellGet -MinimumVersion 1.6.7 -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing PowerShellGet Module..."
    }
Catch {
    Write-Warning "PowerShellGet Module was not found..."
    Write-Verbose "Installing the latest PowerShellGet Module..."
    Install-PowerShellGet
}

#! Check AzureRM PowerShell Module
Try {
    Import-Module -Name AzureRM -MinimumVersion 6.7.0 -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing Azure RM PowerShell Module..."
    }
Catch {
    Write-Warning "Azure RM Module was not found..."
    Write-Verbose "Installing Azure RM Module..."
    Install-AzureRM
}

#! Check Azure Security PowerShell Module
Try {
    Import-Module -Name AzureRM.Security -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing Azure Security PowerShell Module..."
    }
Catch {
    Write-Warning "Azure Security PowerShell Module was not found..."
    Write-Verbose "Installing Azure Security PowerShell Module..."
    Install-AzureSecurity
}

#! Check Azure Cloud Connection
Try {
    Write-Verbose "Connecting to Azure Cloud..."
    Login-AzureRmAccount -Environment AzureCloud -ErrorAction Stop | Out-Null
  }
Catch {
    Write-Warning "Cannot connect to Azure environment. Please check your credentials. Exiting!"
    Break
}

#! Get Azure Virtual Machine Info
Write-Verbose "Get all Azure Subscriptions..."
$AzureSubscriptions = Get-AzureRmSubscription | Where-Object {$_.Name -notlike "*Azure Active Directory*"}
$MaxSub = ($AzureSubscriptions.Count)-1
$Sub = 0
do {
    Set-AzureRmContext -SubscriptionId $AzureSubscriptions[$Sub].Id | Out-Null
    $VMInfo = Get-AzureRMVM | Where-Object {$_.Name -eq "$VMName"} 
    $Sub++ 
} Until ($VMInfo.Name -eq "$VMName" -or $Sub -gt $MaxSub)
   
If (!$VMInfo) {
Write-Warning "Azure virtual machine ($VMName) cannot be found. Please check your virtual machine name. Exiting!"
Break
}

$VMAccessPolicy = (Get-AzureRmJitNetworkAccessPolicy).VirtualMachines | Where-Object {$_.Id -like "*$VMName*"} | Select -ExpandProperty Ports

#! Check if Just in Time VM Access is enabled
If (!$VMAccessPolicy) {
    Write-Warning "Just in Time VM Access is not enabled for ($VMName)..."
    if (-Not $Time) {
    Try {
    $Time = Read-Host "`nEnter Max Requested Time in Hours, valid range: 1-24 hours"
        }
    Catch {
        Write-Warning "The maximum requested time entered is not in the valid range: 1-24 hours" 
        Break
        }
    }
    Enable-JITVMAccess    
}
Else {
#! Check if the specified Port is enabled in Azure Security Center
$value = $VMAccessPolicy | Where-Object {$_.Number -eq "$Port"}
    If (!$value) {
    Write-Warning "The Specified port for ($VMName) is not enabled in Azure Security Center..."
    Try {
    $Time = Read-Host "`nEnter Max Requested Time in Hours, valid range: 1-24 hours"
        }
    Catch {
        Write-Warning "The maximum requested time entered is not in the valid range: 1-24 hours" 
        Break
        }
    Enable-JITVMAccess
    }
}

#! Request Access to the VM including management Port, Source IP and Time range in Hours
If (!$Time) {
   $value = $VMAccessPolicy | Where-Object {$_.Number -eq "$Port"}
   $Time = ExtractMaxDuration $value.MaxRequestAccessDuration
   $Date = (Get-Date).ToUniversalTime().AddHours($Time) 
   $endTimeUtc = Get-Date -Date $Date -Format o
   Invoke-JITVMAccess
}
Else {
   $Date = (Get-Date).ToUniversalTime().AddHours($Time) 
   $endTimeUtc = Get-Date -Date $Date -Format o
   Invoke-JITVMAccess
}