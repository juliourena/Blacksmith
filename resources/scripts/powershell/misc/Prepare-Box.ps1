# Author: Roberto Rodriguez (@Cyb3rWard0g)
# License: GPL-3.0

$ErrorActionPreference = "Stop"

# Network Changes
Write-host 'Setting network connection type to Private..'
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# Stop Windows Update
Write-Host "Disabling Windows Updates.."
Set-Service wuauserv -StartupType Disabled
Stop-Service wuauserv

# Firewall Changes
Write-Host "Allow ICMP Traffic through firewall"
& netsh advfirewall firewall add rule name="ALL ICMP V4" protocol=icmpv4:any,any dir=in action=allow

Write-Host "Enable File and Printer Sharing"
& netsh firewall set service type = fileandprint mode = enable

Write-Host "Enable WMI traffic through the firewall"
& netsh advfirewall firewall set rule group="windows management instrumentation (wmi)" new enable=yes

# Power Settings
Write-Host "Setting Power Performance"
$HPGuid = (Get-WmiObject -Class win32_powerplan -Namespace root\cimv2\power -Filter "ElementName='High performance'").InstanceID.tostring()
$regex = [regex]"{(.*?)}$"
$PowerConfig = $regex.Match($HPGuid).groups[1].value 
& powercfg -S $PowerConfig

# Set TimeZone
Write-host "Setting Time Zone to Eastern Standard Time"
Set-TimeZone -Name "Eastern Standard Time"

# Adding Authenticated Users to Remote Desktop Users
write-Host "Adding Authenticated Users to Remote Desktop Users.."
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "Authenticated Users"

# Removing OneDrive
Write-Host "Removing OneDrive..."
$onedrive = Get-Process onedrive -ErrorAction SilentlyContinue
if ($onedrive) {
  taskkill /f /im OneDrive.exe
}
if (Test-Path "$env:systemroot\SysWOW64\OneDriveSetup.exe") {
    & $env:systemroot\SysWOW64\OneDriveSetup.exe /uninstall /q
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
    if (Test-Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}") {
        Remove-Item -Force -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    }
    if (Test-Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}") {
        Remove-Item -Force -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    }
}

# Disabling A few Windows 10 Settings:
# Reference:
# https://docs.microsoft.com/en-us/windows/privacy/manage-connections-from-windows-operating-system-components-to-microsoft-services

$regConfig = @"
regKey,name,value,type
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE","DisablePrivacyExperience",1,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search","AllowCortana",0,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search","AllowSearchToUseLocation",0,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search","DisableWebSearch",1,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search","ConnectedSearchUseWeb",0,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata","PreventDeviceMetadataFromNetwork",1,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice","AllowFindMyDevice",0,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds","AllowBuildPreview",0,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications","NoCloudApplicationNotification",1,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive","DisableFileSyncNGSC",1,"DWord"
"HKLM:\SOFTWARE\Microsoft\OneDrive","PreventNetworkTrafficPreUserSignIn",1,"DWord"
"HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy","HasAccepted",0,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Speech","AllowSpeechModelUpdate",0,"DWord"
"HKCU:\SOFTWARE\Microsoft\InputPersonalization","RestrictImplicitTextCollection",1,"DWord"
"HKCU:\SOFTWARE\Microsoft\InputPersonalization","RestrictImplicitInkCollection",1,"DWord"
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo","Enabled",0,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo","DisabledByGroupPolicy",1,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy","LetAppsAccessLocation",2,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors","DisableLocation",1,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection","DoNotShowFeedbackNotifications",1,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection","AllowTelemetry",0,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent","DisableWindowsConsumerFeatures",1,"DWord"
"HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent","DisableTailoredExperiencesWithDiagnosticData",1,"DWord"
"HKLM:\SOFTWARE\Policies\Policies\Microsoft\Windows\System","EnableSmartScreen",0,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen","ConfigureAppInstallControlEnabled",1,"DWord"
"HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen","ConfigureAppInstallControl","Anywhere","String"
"@

Write-host "Setting up Registry keys for additional settings.."
$regConfig | ConvertFrom-Csv | ForEach-Object {
    if(!(Test-Path $_.regKey)){
        Write-Host $_.regKey " does not exist.."
        New-Item $_.regKey -Force
    }
    Write-Host "Setting " $_.regKey
    New-ItemProperty -Path $_.regKey -Name $_.name -Value $_.value -PropertyType $_.type -force
}

# Setting WDigest to use LogonCredentials
Write-Host "Setting WDigest to use logoncredential.."
Set-ItemProperty -Force -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -Value "1"

# Additional registry configurations
# References:
# https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-lan-manager-authentication-level
# https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-restrict-ntlm-outgoing-ntlm-traffic-to-remote-servers
$regConfig = @"
regKey,name,value,type
"HKLM:\SYSTEM\CurrentControlSet\Control\Lsa","LmCompatibilityLevel",3,"DWord"
"HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0","NTLMMinClientSec",537395200,"DWord"
"HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0","RestrictSendingNTLMTraffic",2,"DWord"
"@

Write-host "Setting up Registry keys for additional settings.."
$regConfig | ConvertFrom-Csv | ForEach-Object {
    if(!(Test-Path $_.regKey)){
        Write-Host $_.regKey " does not exist.."
        New-Item $_.regKey -Force
    }
    Write-Host "Setting " $_.regKey
    New-ItemProperty -Path $_.regKey -Name $_.name -Value $_.value -PropertyType $_.type -force
}