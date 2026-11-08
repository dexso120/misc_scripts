# Disable prevent changing theme policy
$policy_path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$key_name = "NoThemesTab"
$value = 0

If (!(Test-Path $policy_path)){
    New-Item -Path $policy_path -Force | Out-Null
}
New-ItemProperty -Path $policy_path -Name $key_name -Value $value -PropertyType DWORD -Force

# Apply dark theme
$theme_path_lm = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes"
$theme_path_cu = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$name = "AppsUseLightTheme"
$value = 0

If (!(Test-Path $theme_path_lm)){
    New-Item -Path $theme_path_lm -Force | Out-Null
}

If (!(Test-Path $theme_path_cu)){
    New-Item -Path $theme_path_cu -Force | Out-Null
}

New-ItemProperty -Path $theme_path_lm -Name $name -Value $value -PropertyType DWORD -Force
New-ItemProperty -Path $theme_path_cu -Name $name -Value $value -PropertyType DWORD -Force

# Disable Windows Auto Update
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name NoAutoUpdate -Value 1

# Disable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name DisableAntiSpyware -Value 1 -PropertyType DWORD -Force

# Download PsExec
$tools_path = 'C:\Tools\'
$pstools_path = 'C:\Tools\pstools'
New-Item -ItemType Directory -Path $tools_path
New-Item -ItemType Directory -Path $pstools_path
Invoke-WebRequest https://download.sysinternals.com/files/PSTools.zip -outfile $tools_path'PsTools.zip'
Expand-Archive -Path $tools_path'PsTools.zip' -DestinationPath $pstools_path

# Guide to disable auto shutdown
Write-Host 'To disable auto shutdown on trial version.'
Write-Host 'Run "Psexec -i -s cmd.exe" and run "services.msc".'
Write-Host 'Go to "Windows Licensing Monitoring Service" > "Disable".'
Write-Host 'Then restart device.'

# Reboot to apply changes
# Restart-Computer