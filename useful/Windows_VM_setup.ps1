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

# Reboot to apply changes
# Restart-Computer