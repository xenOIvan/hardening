<#
    .SYNOPSIS
        Install OpenSSH-Win64 and the associated ssh-agent service. Optionally install SSHD server and associated
        sshd service. Optionally install the latest PowerShell Core.
 
    .DESCRIPTION
        See .SYNOPSIS
 
    .NOTES
 
    .PARAMETER ConfigureSSHDOnLocalHost
        This parameter is OPTIONAL.
 
        This parameter is a switch. If used, the SSHD Server and associated sshd service will be installedm
        configured, and enabled on the local host.
 
    .PARAMETER RemoveHostPrivateKeys
        This parameter is OPTIONAL.
 
        This parameter is a switch. Use it to remove the Host Private Keys after they are added to the ssh-agent during
        sshd setup/config. Default is NOT to remove the host private keys.
 
        This parameter should only be used in combination with the -ConfigureSSHDOnLocalHost switch.
 
    .PARAMETER DefaultShell
        This parameter is OPTIONAL.
 
        This parameter takes a string that must be one of two values: "powershell","pwsh"
 
        If set to "powershell", when a Remote User connects to the local host via ssh, they will enter a
        Windows PowerShell 5.1 shell.
 
        If set to "pwsh", when a Remote User connects to the local host via ssh, the will enter a
        PowerShell Core 6 shell.
 
        If this parameter is NOT used, the Default shell will be cmd.exe.
 
        This parameter should only be used in combination with the -ConfigureSSHDOnLocalHost switch.
 
    .PARAMETER GiveWinSSHBinariesPathPriority
        This parameter is OPTIONAL, but highly recommended.
 
        This parameter is a switch. If used, ssh binaries installed as part of OpenSSH-Win64 installation will get
        priority in your $env:Path. This is especially useful if you have ssh binaries in your path from other
        program installs (like git).
 
    .PARAMETER GitHubInstall
        This parameter is OPTIONAL.
 
        This parameter is a switch. If used, OpenSSH binaries will be installed by downloading the .zip
        from https://github.com/PowerShell/Win32-OpenSSH/releases/latest/, expanding the archive, moving
        the files to the approproiate location(s), and setting permissions appropriately.
 
    .PARAMETER SkipWinCapabilityAttempt
        This parameter is OPTIONAL.
 
        This parameter is a switch.
         
        In more recent versions of Windows (Spring 2018), OpenSSH Client and SSHD Server can be installed as
        Windows Features using the Dism Module 'Add-WindowsCapability' cmdlet. If you run this function on
        a more recent version of Windows, it will attempt to use 'Add-WindowsCapability' UNLESS you use
        this switch.
 
        As of May 2018, there are reliability issues with the 'Add-WindowsCapability' cmdlet.
        Using this switch is highly recommend in order to avoid using 'Add-WindowsCapability'.
 
    .PARAMETER Force
        This parameter is a OPTIONAL.
 
        This parameter is a switch.
 
        If you are already running the latest version of OpenSSH, but would like to reinstall it and the
        associated ssh-agent service, use this switch.
 
    .EXAMPLE
        # Open an elevated PowerShell Session, import the module, and -
 
        PS C:\Users\zeroadmin> Install-WinSSH -GiveWinSSHBinariesPathPriority -ConfigureSSHDOnLocalHost -DefaultShell powershell -GitHubInstall
 
#>
function Install-WinSSH {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False)]
        [switch]$ConfigureSSHDOnLocalHost,

        [Parameter(Mandatory=$False)]
        [switch]$RemoveHostPrivateKeys,

        [Parameter(Mandatory=$False)]
        [ValidateSet("powershell","pwsh")]
        [string]$DefaultShell,

        # For situations where there may be more than one ssh.exe available on the system that are already part of $env:Path
        # or System PATH - for example, the ssh.exe that comes with Git
        [Parameter(Mandatory=$False)]
        [switch]$GiveWinSSHBinariesPathPriority,

        [Parameter(Mandatory=$False)]
        [switch]$GitHubInstall,

        [Parameter(Mandatory=$False)]
        [switch]$SkipWinCapabilityAttempt,

        [Parameter(Mandatory=$False)]
        [switch]$Force
    )

    ##### BEGIN Variable/Parameter Transforms and PreRun Prep #####

    if (!$(GetElevation)) {
        Write-Verbose "You must run PowerShell as Administrator before using this function! Halting!"
        Write-Error "You must run PowerShell as Administrator before using this function! Halting!"
        $global:FunctionResult = "1"
        return
    }

    if ($DefaultShell -and !$ConfigureSSHDOnLocalHost) {
        Write-Error "The -DefaultShell parameter is meant to set the configure the default shell for the SSHD Server. Please also use the -ConfigureSSHDOnLocalHost switch. Halting!"
        $global:FunctionResult = "1"
        return
    }

    $OpenSSHWinPath = "$env:ProgramFiles\OpenSSH-Win64"

    ##### END Variable/Parameter Transforms and PreRun Prep #####


    ##### BEGIN Main Body #####
    
    $InstallSSHAgentSplatParams = @{
        ErrorAction         = "SilentlyContinue"
        ErrorVariable       = "ISAErr"
    }
    if ($GitHubInstall) {
        $InstallSSHAgentSplatParams.Add("GitHubInstall",$True)
    }
    if ($SkipWinCapabilityAttempt) {
        $InstallSSHAgentSplatParams.Add("SkipWinCapabilityAttempt",$True)
    }
    if ($Force) {
        $InstallSSHAgentSplatParams.Add("Force",$True)
    }

    try {
        $InstallSSHAgentResult = Install-SSHAgentService @InstallSSHAgentSplatParams
        if (!$InstallSSHAgentResult) {throw "The Install-SSHAgentService function failed!"}
    }
    catch {
        Write-Error $_
        Write-Host "Errors for the Install-SSHAgentService function are as follows:"
        Write-Error $($ISAErr | Out-String)
        $global:FunctionResult = "1"
        return
    }

    Write-Host "Finished installing ssh-agent..." -ForegroundColor Green

    if ($ConfigureSSHDOnLocalHost) {
        $NewSSHDServerSplatParams = @{
            ErrorAction         = "SilentlyContinue"
            ErrorVariable       = "SSHDErr"
        }
        if ($RemoveHostPrivateKeys) {
            $NewSSHDServerSplatParams.Add("RemoveHostPrivateKeys",$True)
        }
        if ($DefaultShell) {
            $NewSSHDServerSplatParams.Add("DefaultShell",$DefaultShell)
        }
        if ($SkipWinCapabilityAttempt) {
            $NewSSHDServerSplatParams.Add("SkipWinCapabilityAttempt",$True)
        }
        
        try {
            $NewSSHDServerResult = New-SSHDServer @NewSSHDServerSplatParams
            if (!$NewSSHDServerResult) {throw "There was a problem with the New-SSHDServer function! Halting!"}
        }
        catch {
            Write-Error $_
            Write-Host "Errors for the New-SSHDServer function are as follows:"
            Write-Error $($SSHDErr | Out-String)
            $global:FunctionResult = "1"
            return
        }
    }

    # Update $env:Path to give the ssh.exe binary we just installed priority
    if ($GiveWinSSHBinariesPathPriority) {
        if ($($env:Path -split ";") -notcontains $OpenSSHWinPath) {
            if ($env:Path[-1] -eq ";") {
                $env:Path = "$OpenSSHWinPath;$env:Path"
            }
            else {
                $env:Path = "$OpenSSHWinPath;$env:Path"
            }
        }
    }
    else {
        if ($($env:Path -split ";") -notcontains $OpenSSHWinPath) {
            if ($env:Path[-1] -eq ";") {
                $env:Path = "$env:Path$OpenSSHWinPath"
            }
            else {
                $env:Path = "$env:Path;$OpenSSHWinPath"
            }
        }
    }

    $Output = [ordered]@{
        SSHAgentInstallInfo     = $InstallSSHAgentResult
    }
    if ($NewSSHDServerResult) {
        $Output.Add("SSHDServerInstallInfo",$NewSSHDServerResult)
    }

    if ($Output.Count -eq 1) {
        $InstallSSHAgentResult
    }
    else {
        [pscustomobject]$Output
    }
}