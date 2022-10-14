function Join-Vlab {
    <#
    .SYNOPSIS
    Establishes  connection to the provo vlab vsphere server system

    .DESCRIPTION
    This cmdlet establishes a connection to vlab server system in Provo, Utah. The cmdlet starts a new session or re-establishes a previous session with a vCenter Server system using the specified parameters.

    When you attempt to connect to a server, the server checks for credentials saved to the $VlabCredentialsFilePath. Otherwise a prompt will accept the username and password required to access the vlab, as you would through the browser. These credentials are not saved by the Connect-Vlab unless the -SaveCredentials flag is passed.

    .INPUTS
    - $VlabCredentialsFilePath is the credentials filepath to login to the vlab. This is to be a .cred filetype, which powershell can save with the Export-Clixml cmdlet. 
    - $ViServerAddress is the URL for the provo lab. 

    .OUTPUTS
    None. Join-Vlab establishes a connection and returns no values.

    .LINK
    http://developer.vmware.com/docs/powercli/latest/vmware.vimautomation.core/commands/connect-viserver

    .PARAMETER SaveCredentials
    Vall this switch if you want to save the credentials which will be entered. If credentials are already saved to the $VlabCredentialsFilePath, they will be overwritten when calling this flag. Credentials are only saved once an attempt to login to the vlab is successful.

    .PARAMETER SkipVPNTest
    Use of this flag will cause this cmdlet to skip validating that the vlab is pingable. 
    
    .EXAMPLE
    $VlabCredentialsFilePath = $PWD\vlab.cred
    Get-Credential | Export-Clixml $VlabCredentialsFilePath
    Join-Vlab
    *profites-en*
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [Switch] $SaveCredentials,
        [Parameter(Mandatory=$false)]
        [Switch] $SkipVPNTest
    )

    #  ----- validate expected vars and conditions -----

    if($null -eq $ViServerAddress){
        # if NewVIServer is set and the connection is successful, this new value will be saved to $PROFILE
        $NewVIServer = Read-Host -Prompt "the `$ViServer variable is not available. Please enter the url for the Provo Vlab [Enter to accept vlabw1vc.nqeng.lab]. This new variable will be saved to the current profile"
        if ($NewVIServer.Length -eq 0){
            $NewVIServer = 'vlabw1vc.nqeng.lab'
        }
    }

    if (!$SkipVPNTest.IsPresent){
        Test-Connection $Vlab -OutVariable Connected
        if($Connected.Status -ne "Success"){
            Write-Error "Cannot reach $($Vlab). Are you connected to the proper VPN?"
            return
    }   }
    
    #  ---------- Meat of the function ----------
    $CredsAvailable = Test-Path -PathType Leaf $VlabCredentialsFilePath

    if( !$CredsAvailable -or $SaveCredentials.IsPresent ){
        $Credentials = Get-Credential
        # Save Credentials only once the sign-in has been succeeded.
    }else {
        $Credentials = Import-Clixml $VlabCredentialsFilePath
    }
    $ErrorActionPreference = 'Stop'
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore
    try {  
        if ($Null -ne $NewVIServer){
            Connect-VIServer -Server $NewVIServer -Credential $Credentials
        }else{
            Connect-VIServer -Server $ViServerAddress -Credential $Credentials
        }
        
    }catch [ System.Management.Automation.ValidationMetadataException ] {
        $ThisError = $Error[0]
        Write-Error "The provided URL for the VI server is invalid.`n$($ThisError)"
    }catch {
        Write-Output "Failed to connect to $($ViServerAddress).`n$($Error[0])"
    }

    #  ------ Save new variables if needed ------
    if ($global:DefaultVIServer.Name -eq $NewVIServer) {
        Set-Variable -Scope global -Name "ViServerAddress" -Value $NewVIServer
        "`$ViServerAddress = $($NewVIServer)" | Tee-Object $PROFILE -Append
    }
    if ($SaveCredentials.IsPresent && $global:DefaultVIServer.Name -eq $ViServerAddress){
        Export-Clixml -InputObject $Credentials -Path -Force
    }
    # TODO(Jonathan) write pester test for Join-Vlab
}

New-Alias -Name "Punch-ItChewie" -Value Join-Vlab