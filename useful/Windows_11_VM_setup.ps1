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
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name NoAutoUpdate -Value 1 -Force

# Disable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name DisableAntiSpyware -Value 1 -PropertyType DWORD -Force

# Download PsExec
$tools_path = 'C:\Tools\'
$pstools_path = 'C:\Tools\pstools'
If (-Not (Test-Path $pstools_path)){
	New-Item -ItemType Directory -Path $tools_path
	New-Item -ItemType Directory -Path $pstools_path
	Invoke-WebRequest https://download.sysinternals.com/files/PSTools.zip -outfile $tools_path'PsTools.zip'
	Expand-Archive -Path $tools_path'PsTools.zip' -DestinationPath $pstools_path -Force
}

# Disable auto shutdown for Windows 11 trial
Start-Process -FilePath "cmd.exe" -Verb RunAs -ArgumentList '/c c: && cd / && cd Tools\pstools && psexec -accepteula -i -s "reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WLMS /v Start /t REG_DWORD /d 4 /f"'

# Allow to modify Power Options
Start-Process -FilePath "cmd.exe" -Verb RunAs -ArgumentList '/c c: && cd / && cd Tools\pstools && psexec -accepteula -i -s "reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\7516b95f-f776-4464-8c53-06167f40cc99\8EC4B3A5-6868-48c2-BE75-4F3044BE88A7 /v Attributes /t REG_DWORD /d 2 /f"'

# Disable screen timeout
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name InactivityTimeoutSecs -Value 0 -PropertyType DWORD -Force

# Print info
Write-Host "All configuration applied. Please restart computer."

# Reboot to apply changes
# Restart-Computer