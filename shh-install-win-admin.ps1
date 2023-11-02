#some good resources
#https://woshub.com/using-ssh-key-based-authentication-on-windows/
#https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse?tabs=powershell
#https://learn.microsoft.com/en-us/powershell/scripting/learn/remoting/ssh-remoting-in-powershell?view=powershell-7.3

# 👉 install ssh server on windows 
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
    # 📃 expected result
    #Name  : OpenSSH.Client~~~~0.0.1.0
    #State : NotPresent#

    #Name  : OpenSSH.Server~~~~0.0.1.0
    #State : NotPresent

# 👉 Install the OpenSSH Client
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# 👉 Install the OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

    # 📃 expected result
    #Path          :
    #Online        : True
    #RestartNeeded : False


# 👉 Start the sshd service
Start-Service sshd

# 👉 OPTIONAL but recommended:
Set-Service -Name sshd -StartupType 'Automatic'

# 👉 Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}

# 👉 copy you public key to remote server
#copy from local
#C:\Users\{user}\.ssh\id_rsa.pub
#copy to server
#C:\ProgramData\ssh\administrators_authorized_keys

# 👉🚨 add proper rules to file. without this line user still will get propmpt for password
#icacls.exe "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
#icacls.exe "C:\ProgramData\.ssh\authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"


# 👉 sshd_config file must be like this
#Match Group administrators
#       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys

# 👉 connect from local using:
#ssh -v user@ip

# 👉 connect from local using:
#your can add this config to 